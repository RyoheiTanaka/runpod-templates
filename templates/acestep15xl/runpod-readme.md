## ACE-Step 1.5 XL for ComfyUI

ACE-Step 1.5 XL music generation on RunPod. ComfyUI and its Python dependencies are baked into the image; models download on first start.

### Which CUDA version

Container images declare the CUDA version they need from the host driver, and a pod fails **before the container starts** if the host is older.

| Image | Requires | Starts on |
|---|---|---|
| `cuda12.8` | `cuda>=12.8` | CUDA 12.8 and CUDA 13.0 hosts |
| `cuda13.0` | `cuda>=13.0` | CUDA 13.0 hosts only |

**Prefer the CUDA 12.8 template.** It runs on strictly more hosts. If a CUDA 13.0 pod fails with:

```
nvidia-container-cli: requirement error: unsatisfied condition: cuda>=13.0
```

then redeploy to get a different host, pick a GPU that only ships CUDA 13.0 (RTX PRO 4500 Blackwell, for example), or switch to the CUDA 12.8 template.

### Getting Started

An RTX 3090 or better with 20GB+ of VRAM is enough. Set your SSH public key when creating the pod if you want shell access.

Wait for `[start] ready` in the pod log, then open ComfyUI:

```
https://<pod-id>-8188.proxy.runpod.net
```

This proxy URL is public and unauthenticated. Anyone with the link can drive ComfyUI and browse your inputs and outputs. For anything sensitive, tunnel instead:

```
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <your-key>
```

### Environment variables

`ACESTEP_XL_VARIANT` picks the diffusion model: `xl_base`, `xl_sft`, `xl_turbo`, or `all` (default).

`ACESTEP_LM` picks the text encoder: `qwen_0.6b`, `qwen_1.7b`, `qwen_4b`, or `all` (default).

`HF_TOKEN` is a placeholder and is ignored unless replaced with a real token.

### Help

Loading the base and sft models one after another in a single session can exhaust memory on a 24GB GPU and restart the container. Free memory between runs, or use one model per pod.

Startup time is dominated by the model download, and Hugging Face throughput varies a lot, so give the first boot room.

Remember to stop or delete the pod when you are done; GPU time bills while it runs.

Source and issues: https://github.com/RyoheiTanaka/runpod-templates
