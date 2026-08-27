## Wan2.2 for ComfyUI

Wan2.2 video generation on RunPod. ComfyUI and its Python dependencies are baked into the image; models download on first start.

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

Deploy with a GPU that has at least 24GB of VRAM (RTX 4090 and up). Set your SSH public key when creating the pod if you want shell access.

Wait for `[start] ready` in the pod log, then open ComfyUI:

```
https://<pod-id>-8188.proxy.runpod.net
```

This proxy URL is public and unauthenticated. Anyone with the link can drive ComfyUI and browse your inputs and outputs. For anything sensitive, tunnel instead:

```
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <your-key>
```

### Environment variables

`WAN_VARIANT` picks the model set:

- `t2v_a14b` - text-to-video 14B (default)
- `i2v_a14b` - image-to-video 14B
- `ti2v_5b` - text/image-to-video 5B

`all` is intentionally unsupported; the combined download is too large.

`HF_TOKEN` is a placeholder and is ignored unless replaced with a real token. Setting a real one helps with rate limits on large downloads.

### Help

Startup time is dominated by the model download, roughly 36GB for the 14B variants. Measured anywhere from under a minute to over 30 minutes depending on Hugging Face throughput, so give the first boot room.

Remember to stop or delete the pod when you are done; GPU time bills while it runs.

Source and issues: https://github.com/RyoheiTanaka/runpod-templates
