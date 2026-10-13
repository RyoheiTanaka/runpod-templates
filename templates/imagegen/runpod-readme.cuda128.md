## ComfyUI for still images (CUDA 12.8)

Still image generation on RunPod with any checkpoint you point it at: SDXL, Illustrious, Pony and so on. ComfyUI 0.32.0 is baked into the image; models download on first start from URLs you set, and are verified by SHA256 before ComfyUI starts.

Bundled custom nodes: **SaveImageExtended** and **UltimateSDUpscale**, both pinned to a commit.

### Getting Started

Deploy on **Secure Cloud**. This template limits the host CUDA version to **12.8**. We hit two Community Cloud RTX 4090 hosts in a row (CUDA 13.0 / driver 580) where `nvidia-smi` saw the GPU but CUDA failed to initialize. Secure Cloud with CUDA 12.8 did not show this. If no host is available, you can widen the CUDA filter under Additional filters at your own risk.

The start script tests the GPU first. If CUDA cannot be initialized, it stops before downloading anything and logs `[start] halted`. Restarting will not help; delete the pod and deploy again. The GPU bills while a pod is halted.

Wait for `[start] ready` in the pod log, then open:

```
https://<pod-id>-8188.proxy.runpod.net
```

This proxy URL is public and unauthenticated. For anything sensitive, use an SSH tunnel through the exposed TCP port instead:

```
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <your-key>
```

### Models

Each file takes three variables. Add more with `MODEL_1_*`, `MODEL_2_*` and so on, up to 20.

- `MODEL_URL` - https only
- `MODEL_SHA256` - if it does not match, ComfyUI is not started
- `MODEL_DEST` - path under ComfyUI `models/`, such as `checkpoints/model.safetensors` or `loras/style.safetensors`

The default is SDXL base 1.0. Clear `MODEL_URL` to start without downloading.

Put tokens in RunPod Secrets and reference them: `CIVITAI_TOKEN` = `{{ RUNPOD_SECRET_civitai_token }}`. The token is chosen by URL host (civitai.com or huggingface.co) and never appears on a command line. Do not put `token=` in the URL; it shows up in the process list.

A stalled download is cut off below 1 MiB/s for 60 seconds and resumed. To stop one by hand, run `pkill -x curl`; the download resumes from where it stopped.

### Custom nodes

`CUSTOM_NODES` takes space-separated git URLs, optionally pinned with `@<commit>`:

```
https://github.com/<owner>/<repo>@<commit-sha>
```

They install on every new pod, so they slow down the start. PyTorch stays pinned.

### Help

Full documentation: https://github.com/RyoheiTanaka/runpod-templates/tree/main/templates/imagegen

Stop or delete the pod when you are done. GPU time bills while it runs.
