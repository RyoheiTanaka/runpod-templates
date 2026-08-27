## ACE-Step 1.5 XL for ComfyUI (CUDA 12.8)

ACE-Step 1.5 XL music generation on RunPod. ComfyUI 0.32.0 and its Python dependencies are baked into the image; models download on first start.

**This is the recommended ACE-Step template.** It declares `cuda>=12.8`, so it starts on both CUDA 12.8 and CUDA 13.0 hosts. The CUDA 13.0 build of this template declares `cuda>=13.0` and only starts on 13.0 hosts, so use it only if you specifically want CUDA 13.0.

### Getting Started

An RTX 3090 or better with 20GB+ of VRAM is enough. Add your SSH public key when creating the pod if you want shell access.

Wait for `[start] ready` in the pod log, then open ComfyUI:

```
https://<pod-id>-8188.proxy.runpod.net
```

This proxy URL is public and unauthenticated. Anyone with the link can drive ComfyUI and browse your inputs and outputs. For anything sensitive, use an SSH tunnel instead:

```
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <your-key>
```

### Environment variables

`ACESTEP_XL_VARIANT` picks the diffusion model:

- `xl_base` - base model
- `xl_sft` - fine-tuned model
- `xl_turbo` - distilled, few-step model
- `all` - all three (default)

`ACESTEP_LM` picks the text encoder: `qwen_0.6b`, `qwen_1.7b`, `qwen_4b`, or `all` (default).

`HF_TOKEN` is a placeholder and is ignored unless you replace it with a real token.

### Help

Loading the base and sft models one after another inside a single session can exhaust memory on a 24GB GPU and restart the container. Free memory between runs, or use one model per pod.

Verified on an RTX 4090 for a 30 second track: turbo at 8 steps takes about 17 seconds, base and sft at 20 steps about 40 seconds.

First boot is dominated by the model download, and Hugging Face throughput varies a lot, so give it room and watch the log rather than the clock.

Stop or delete the pod when you are done. GPU time bills while it runs.

Source and issues: https://github.com/RyoheiTanaka/runpod-templates
