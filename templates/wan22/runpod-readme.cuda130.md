## Wan2.2 for ComfyUI (CUDA 13.0)

Wan2.2 video generation on RunPod, built on CUDA 13.0. ComfyUI 0.32.0 and its Python dependencies are baked into the image; models download on first start.

### This image needs a CUDA 13.0 host

It declares `cuda>=13.0`, so on an older host the pod fails **before the container starts**:

```
nvidia-container-cli: requirement error: unsatisfied condition: cuda>=13.0,
please update your driver to a newer version, or use an earlier cuda container
```

If that happens you have three options:

- Redeploy until you land on a CUDA 13.0 host. On RTX 4090 this can take several tries.
- Pick a GPU that only ships CUDA 13.0, such as RTX PRO 4500 Blackwell. It is cheaper than an RTX 4090 and gets you a 13.0 host first try.
- Use the CUDA 12.8 build of this template, which starts on both 12.8 and 13.0 hosts.

**If you do not specifically need CUDA 13.0, use the CUDA 12.8 template instead.**

### Getting Started

Deploy with a GPU that has at least 24GB of VRAM. Add your SSH public key when creating the pod if you want shell access.

Wait for `[start] ready` in the pod log, then open ComfyUI:

```
https://<pod-id>-8188.proxy.runpod.net
```

This proxy URL is public and unauthenticated. Anyone with the link can drive ComfyUI and browse your inputs and outputs. For anything sensitive, use an SSH tunnel instead:

```
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <your-key>
```

### Environment variables

`WAN_VARIANT` picks the model set:

- `t2v_a14b` - text-to-video 14B (default)
- `i2v_a14b` - image-to-video 14B
- `ti2v_5b` - text/image-to-video 5B

`all` is intentionally unsupported; the combined download is too large.

`HF_TOKEN` is a placeholder and is ignored unless you replace it with a real token.

### Help

First boot is dominated by the model download, roughly 36GB for the 14B variants. Measured anywhere from under a minute to over 30 minutes depending on Hugging Face throughput, so give it room and watch the log rather than the clock.

Stop or delete the pod when you are done. GPU time bills while it runs.

Source and issues: https://github.com/RyoheiTanaka/runpod-templates
