"""Start an SSH-accessible vLLM Pod; no third-party Python dependencies."""

import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def enabled(env, name, default):
    value = env.get(name, default).lower()
    if value not in {"true", "false"}:
        raise ValueError(f"{name} must be true or false")
    return value == "true"


def build_command(env):
    model = env.get("MODEL_ID", "Qwen/Qwen3-8B").strip()
    if not model or model.startswith("-"):
        raise ValueError("MODEL_ID must be a model ID or an absolute local path")
    try:
        length = int(env.get("MAX_MODEL_LEN", "32768"))
        utilization = float(env.get("GPU_MEMORY_UTILIZATION", "0.95"))
    except ValueError:
        raise ValueError("Invalid MAX_MODEL_LEN or GPU_MEMORY_UTILIZATION") from None
    if length < 1 or not math.isfinite(utilization) or not 0 < utilization <= 1:
        raise ValueError("MAX_MODEL_LEN must be positive; GPU_MEMORY_UTILIZATION must be in (0, 1]")
    command = [
        "vllm", "serve", model,
        "--host", "127.0.0.1", "--port", "8000",
        "--max-model-len", str(length),
        "--gpu-memory-utilization", str(utilization),
    ]
    if env.get("MODEL_REVISION", "").strip():
        command += ["--revision", env["MODEL_REVISION"].strip()]
    if enabled(env, "ENABLE_AUTO_TOOL_CHOICE", "true"):
        parser = env.get("TOOL_CALL_PARSER", "hermes").strip()
        if not parser or parser.startswith("-"):
            raise ValueError("TOOL_CALL_PARSER is required when auto tool choice is enabled")
        command += ["--enable-auto-tool-choice", "--tool-call-parser", parser]
    if enabled(env, "ENFORCE_EAGER", "true"):
        command += ["--enforce-eager"]
    try:
        extra = json.loads(env.get("VLLM_EXTRA_ARGS_JSON", "[]"))
    except json.JSONDecodeError:
        raise ValueError("VLLM_EXTRA_ARGS_JSON must be a JSON array of strings") from None
    if not isinstance(extra, list) or any(not isinstance(arg, str) or "\0" in arg for arg in extra):
        raise ValueError("VLLM_EXTRA_ARGS_JSON must be a JSON array of strings")
    # Keep networking/auth and explicitly configured model settings under this entrypoint's control.
    managed = {"--host", "--port", "--api-key", "--config", "--uds", "--model",
               "--revision", "--max-model-len", "--gpu-memory-utilization",
               "--enable-auto-tool-choice", "--tool-call-parser", "--enforce-eager"}
    if any(arg.split("=", 1)[0] in managed for arg in extra):
        raise ValueError("VLLM_EXTRA_ARGS_JSON overrides a managed setting; use the documented environment variables")
    return command + extra


def prepare_environment(env):
    result = dict(env)
    key = result.get("VLLM_API_KEY", "").strip()
    if not key or key in {"your-vllm-api-key", "change-me"}:
        raise ValueError("Set your own VLLM_API_KEY before starting this Pod")
    result["VLLM_API_KEY"] = key
    workspace = result.get("WORKSPACE", "/workspace")
    result.setdefault("HF_HOME", str(Path(workspace) / ".cache" / "huggingface"))
    Path(result["HF_HOME"]).mkdir(parents=True, exist_ok=True)
    if result.get("HF_TOKEN") == "your-huggingface-token":
        result.pop("HF_TOKEN")
    return result


def prepare_ssh(env, ssh_dir=Path("/root/.ssh")):
    # PUBLIC_KEY is used by existing RunPod templates; accept an explicit override too.
    public = env.get("SSH_PUBLIC_KEY", "").strip() or env.get("PUBLIC_KEY", "").strip()
    if not public or "PRIVATE KEY" in public:
        raise ValueError("Set a public SSH key in RunPod credentials or SSH_PUBLIC_KEY")
    keys = [line.strip() for line in public.splitlines() if line.strip()]
    for key in keys:
        check = subprocess.run(["ssh-keygen", "-l", "-f", "-"], input=key + "\n",
                               text=True, capture_output=True)
        if check.returncode:
            raise ValueError("Invalid public SSH key; key contents are not logged")
    ssh_dir.mkdir(parents=True, exist_ok=True)
    ssh_dir.chmod(0o700)
    authorized = ssh_dir / "authorized_keys"
    # Replace rather than append: restarts must not accumulate duplicate keys.
    authorized.write_text("\n".join(keys) + "\n", encoding="utf-8")
    authorized.chmod(0o600)


def stop_process(process):
    # A group can outlive its leader (vLLM starts workers), so do not rely on poll().
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        process.poll()
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.1)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    process.wait()


def supervise(command, env):
    processes = []
    stopping = False

    def request_stop(signum, frame):
        nonlocal stopping
        stopping = True

    previous = {sig: signal.signal(sig, request_stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        processes.append(subprocess.Popen(
            ["/usr/sbin/sshd", "-D", "-e", "-f", "/opt/runpod/sshd_config"],
            env=env, start_new_session=True,
        ))
        time.sleep(0.2)
        if stopping:
            return 0
        if processes[0].poll() is not None:
            raise RuntimeError("sshd failed to start")
        print("[start] sshd running; starting vLLM on Pod loopback port 8000", flush=True)
        print("[start] Model loading may take time. API readiness is reported by the health check.", flush=True)
        processes.append(subprocess.Popen(command, env=env, start_new_session=True))
        while not stopping:
            for name, process in zip(("sshd", "vLLM"), processes):
                code = process.poll()
                if code is not None:
                    print(f"[start] {name} exited ({code}); stopping the container", flush=True)
                    return code if code > 0 else 1
            time.sleep(0.2)
        return 0
    finally:
        for process in reversed(processes):
            stop_process(process)
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def main():
    try:
        command = build_command(os.environ)
        env = prepare_environment(os.environ)
        prepare_ssh(env)
        Path("/run/sshd").mkdir(parents=True, exist_ok=True)
        subprocess.run(["ssh-keygen", "-A"], check=True, capture_output=True)
        subprocess.run(["/usr/sbin/sshd", "-t", "-f", "/opt/runpod/sshd_config"], check=True)
        return supervise(command, env)
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        # Do not print subprocess argv or the environment (they may contain secrets).
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else type(error).__name__
        print(f"[start] error: {message}", file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
