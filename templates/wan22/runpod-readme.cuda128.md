## Wan2.2 for ComfyUI (CUDA 12.8)

Wan2.2 video generation on RunPod. ComfyUI 0.32.0 and its Python dependencies are baked into the image; models download on first start.

**This is the recommended Wan2.2 template.** It declares `cuda>=12.8`, so it starts on both CUDA 12.8 and CUDA 13.0 hosts. The CUDA 13.0 build of this template declares `cuda>=13.0` and only starts on 13.0 hosts, so use it only if you specifically want CUDA 13.0.

### Getting Started

Deploy with a GPU that has at least 24GB of VRAM (RTX 4090 and up). Add your SSH public key when creating the pod if you want shell access.

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

`HF_TOKEN` is a placeholder and is ignored unless you replace it with a real token. A real token helps with rate limits on large downloads.

### Help

First boot is dominated by the model download, roughly 36GB for the 14B variants. Measured anywhere from under a minute to over 30 minutes depending on Hugging Face throughput, so give it room and watch the log rather than the clock.

Verified on an RTX 4090: 640x640, 81 frames, 4 steps takes about 60 to 75 seconds for the 14B variants.

Stop or delete the pod when you are done. GPU time bills while it runs.

Source and issues: https://github.com/RyoheiTanaka/runpod-templates
