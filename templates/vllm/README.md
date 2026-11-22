# vLLM with SSH tunneling

**Private Pod smoke test passed on 2026-11-20:** A40, host CUDA 13.2,
Qwen/Qwen3-8B, SSH authentication and forwarding, authenticated chat, and auto
tool-call response. No public RunPod template or Hub listing has been published.
Other models, OpenCode file creation with this image, and cache reuse after a
stop/start remain unverified.

The verified image is pinned in `template.json` by digest. It was built from
commit `ad5240a995d21145e335647681464fd333823b26`. Set your own API key and
SSH credentials before deployment; the example API-key placeholder is rejected.

Run an OpenAI-compatible vLLM API on a Pod and connect from a local coding agent
through SSH. OpenSSH is installed in the image; the entrypoint configures keys,
starts sshd, and starts vLLM. No package installation is needed at Pod startup.

The base is `vllm/vllm-openai:v0.34.0`. It is separate from this repository's
ComfyUI base image. Upstream's v0.34.0 Dockerfile defaults to CUDA 13.0.3; GPU,
driver, and model compatibility for other configurations must be verified before advertising supported
hardware. CUDA forward compatibility, if needed, is an upstream option and is
not automatically enabled here. The template conservatively selects host
CUDA 13.2 only, matching the A40 private Pod verification.
Expand that selection only after testing additional host configurations.

## Use with OpenCode

Follow the [Japanese Windows/PowerShell walkthrough](opencode-guide.ja.md), from
Pod deployment and explicit storage selection through SSH forwarding, API checks,
and creating a local ToDo file. The [configuration example](examples/opencode.json)
uses an environment variable for the key and declares tool support explicitly.
The example passes the official OpenCode configuration schema; end-to-end file
creation with this image is still pending a user test.

## Configure a Pod

1. Add your SSH public key in RunPod credentials, or set `SSH_PUBLIC_KEY` explicitly.
   Existing templates use the injected `PUBLIC_KEY`; this entrypoint accepts that
   too. `SSH_PUBLIC_KEY` takes precedence. Never provide a private key.
2. Set `VLLM_API_KEY` to your own secret. The placeholder is rejected at startup.
3. Set `MODEL_ID` to a Hugging Face model repository ID or a path to a model already
   present on the Pod. Default: `Qwen/Qwen3-8B`.
4. Set model-specific context length, tool parser, GPU resources, and disk sizes.
5. Expose **22/tcp** and use a Pod with a direct public TCP SSH connection. Leave
   the container start command empty: the image's entrypoint does the setup.

The API binds to `127.0.0.1:8000` **inside the Pod**. It is not a public HTTP
service, even if someone adds an 8000 port mapping. Remote clients use the tunnel.
This template does not provide Global Networking access to the API or a Hub worker.

From the Pod's **SSH over exposed TCP** command, add:

```bash
ssh root@<POD_HOST> -p <SSH_PORT> -i <PRIVATE_KEY_PATH> -L 8000:localhost:8000
```

Use `http://localhost:8000/v1` as the client's API base URL and the model's ID as
its model name. Keep the tunnel open. The `ssh.runpod.io` interactive-shell proxy
is not the direct SSH tunnel connection. Forwarding in this image is restricted
to Pod loopback port 8000; shell and SFTP access are also available.

## Select a different model

`MODEL_ID` is configurable without rebuilding this image. This does not mean that
every model can run: vLLM 0.34.0 must support its architecture and format, and
GPU memory, driver, context length, and disk capacity must be sufficient. Gated
repositories may require an authorized `HF_TOKEN` and acceptance of their terms.
Changing `MODEL_ID` does not delete previously cached models.

| Environment variable | Default | Meaning |
| --- | --- | --- |
| `MODEL_ID` | `Qwen/Qwen3-8B` | Hugging Face repository ID or local model path |
| `MODEL_REVISION` | unset | Optional model revision; prefer a commit for reproducibility |
| `MAX_MODEL_LEN` | `32768` | Combined context budget; set to a value supported by the model and GPU |
| `GPU_MEMORY_UTILIZATION` | `0.95` | vLLM GPU memory fraction, greater than 0 and at most 1 |
| `ENABLE_AUTO_TOOL_CHOICE` | `true` | Enable automatic tool choice; `true` or `false` |
| `TOOL_CALL_PARSER` | `hermes` | Qwen3 starting preset; choose the parser required by a different model |
| `ENFORCE_EAGER` | `true` | Starting preset from the experiment; can be `false` |
| `VLLM_EXTRA_ARGS_JSON` | `[]` | JSON array of additional vLLM CLI arguments, passed without a shell |
| `VLLM_API_KEY` | required | User-supplied API key, passed through the environment |
| `HF_TOKEN` | unset | Optional Hugging Face credential; the template placeholder is treated as unset |
| `WORKSPACE` | `/workspace` | Base for the default model cache |
| `HF_HOME` | `${WORKSPACE}/.cache/huggingface` | Override the Hugging Face cache location |
| `SSH_PUBLIC_KEY` | unset | Explicit public key, overriding injected `PUBLIC_KEY` |

For non-tool chat, set `ENABLE_AUTO_TOOL_CHOICE=false`. For coding-agent use,
select a model with compatible tool calling and its appropriate parser. `hermes`
is not a universal parser. The client must also advertise the right model name,
context and output limits; changing server settings does not configure OpenCode.

Example additional arguments for a model that supports them:

```json
["--quantization", "awq", "--tensor-parallel-size", "1"]
```

Do not enable AWQ for a model that is not in that format. Additional arguments
cannot explicitly override the networking/authentication and model options
managed by the entrypoint; use the documented environment variables instead.
Do not put credentials in extra arguments. Remote model code is not enabled by
default; evaluate the model before opting into `--trust-remote-code`.

## Disk sizes and persistence

The template defaults to **Container Disk 30 GB** and **Volume Disk 0 GB**.
Persistent storage is opt-in. Without a volume, the default model cache under
`/workspace` is part of the ephemeral container filesystem and must be downloaded
again after a stop/restart. For repeated use, explicitly choose a sufficiently
large Volume Disk (for example 50 GB); it continues billing while the Pod is stopped.
These are editable provisioning settings (`containerDiskInGb`, `volumeInGb`), not
environment variables that a startup script can use to grow a disk.

The completed private smoke test used an explicitly provisioned 50 GB Volume Disk.
The new container-only default has not yet been tested on a GPU. Storage selection
does not change the entrypoint or require rebuilding the image. Already registered
RunPod templates do not automatically inherit this file's updated default; check
the deployment form before creating a Pod.

| Storage | Purpose in this template | Persistence |
| --- | --- | --- |
| Container Disk | Image filesystem, packages, temporary files, SSH host keys | Temporary; do not rely on it across Pod stops |
| Volume Disk at `/workspace` | Hugging Face model cache | Survives stops/restarts; deleted when the Pod is terminated |
| Network volume at `/workspace` | Optional replacement for Volume Disk | Independent of Pod lifetime |

Choose capacities at Pod creation. A larger model needs enough cache space for
the files fetched, temporary download data, and any older cached revisions, plus
enough GPU memory. Increasing disk space does not increase GPU memory. If using a
different volume mount path, set `WORKSPACE` or `HF_HOME` accordingly.

Container disk is configurable; Volume Disk can be increased, according to
RunPod's storage documentation. Do not treat this as automatic growth while
vLLM runs. Follow the current console's resize procedure for an existing Pod.

SSH host keys are generated per container rather than baked into the image.
Replacing the container may change its host key. Verify a changed fingerprint
through a trusted channel; do not disable SSH host-key checking.

## Readiness and failures

The first startup downloads the selected model. SSH starts before vLLM loads the
model; an SSH connection alone does not mean that the API is ready. The Docker
health check queries loopback `/health`; the vLLM startup log reports API startup.
RunPod's handling of image health metadata must still be verified on an actual Pod.

Missing API/public-key configuration fails before starting services. Invalid keys
are rejected without printing them. If sshd or vLLM exits, the supervisor terminates
both process groups and exits; SIGTERM/SIGINT also clean up the services. There is
no infinite idle fallback. Check the Pod logs and stop a failing deployment to avoid
repeated failures and ongoing GPU billing. Original vLLM request logging behavior
still applies; do not submit secrets as test prompts.

## Local checks and image build

From the repository root (Python 3.10+):

```bash
python -m unittest discover -s templates/vllm -p 'test_*.py' -v
```

The unit tests run without a GPU, SSH daemon, network, or model download. They cover
configuration, key synchronization with mocked validation, and service-failure
cleanup. They are not a substitute for a Linux image build or an actual SSH/GPU test.

To rebuild locally (downloads dependencies):

```bash
docker build -f templates/vllm/Dockerfile -t runpod-vllm-ssh:dev .
```

The `Build vLLM SSH image` workflow uses the shared build workflow and publishes to GHCR on main,
release tags, or manual invocation. Documentation-only pushes do not rebuild the
image. Its base is pinned to vLLM 0.34.0. Deployment stays pinned to the verified
digest until a replacement image has been tested.

Before publication, verify: image build and CUDA/driver compatibility; key
injection; direct SSH and local forwarding; absence of public API access; `/v1/models`
and chat authentication; tool calling and actual file creation through OpenCode;
selected alternative model; cache persistence across stop/start; clean shutdown
and failure handling. Record actual results and disk usage separately from presets.

## References

- [RunPod storage options](https://docs.runpod.io/pods/storage/types)
- [RunPod template configuration](https://docs.runpod.io/pods/templates/manage-templates)
- [RunPod direct SSH requirements](https://docs.runpod.io/pods/configuration/use-ssh)
- [vLLM supported models](https://docs.vllm.ai/en/v0.34.0/models/supported_models/)
- [vLLM v0.34.0 Dockerfile](https://github.com/vllm-project/vllm/blob/v0.34.0/docker/Dockerfile)
