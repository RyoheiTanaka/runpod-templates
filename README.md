# runpod-templates

RunPod で AI 環境を起動するための template setup scripts です。

この repository は公開利用者向けの配布物だけを置きます。作業メモ、検証ログ、API key、template ID、pod ID は含めません。

## Templates

| Name | Script | Purpose | UI | Port |
|---|---|---|---|---|
| `wan22` | `scripts/setup_wan22.sh` | Wan2.2 video generation environment | ComfyUI | `8188/http` |

## Wan2.2

Wan2.2 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

### Recommended RunPod Settings

| Item | Value |
|---|---|
| Template name | `wan22` |
| Container image | `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu24.04` |
| Container disk | `200 GB` |
| Volume | `0 GB` or unset |
| Ports | `8188/http`, `22/tcp` |
| Start command | See below |

### Start Command

During testing, use the `main` branch:

```bash
bash -c "curl -fsSL https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/main/scripts/setup_wan22.sh | bash"
```

For stable operation, pin the URL to a release tag or commit SHA:

```bash
bash -c "curl -fsSL https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/<tag-or-commit>/scripts/setup_wan22.sh | bash"
```

### Environment Variables

| Name | Default | Description |
|---|---|---|
| `WAN_VARIANT` | `t2v_a14b` | Model variant to download. Supported: `t2v_a14b`, `i2v_a14b`, `ti2v_5b`. |
| `COMFY_PORT` | `8188` | ComfyUI listen port. |
| `WORKSPACE` | `/workspace` | Base directory for ComfyUI, models, cache, and logs. |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache directory. |
| `HF_TOKEN` | unset | Optional. Set this in RunPod environment variables if Hugging Face requires authentication. |

`WAN_VARIANT=all` is intentionally unsupported because the required model size is too large for the initial template.

### Installed Paths

| Path | Purpose |
|---|---|
| `/workspace/ComfyUI` | ComfyUI checkout |
| `/workspace/models/wan22/comfy-repackaged` | Downloaded model files |
| `/workspace/ComfyUI/models/*` | Symlinks to downloaded model files |
| `/workspace/logs` | Setup logs |

## Notes

- First boot can take a long time because the script installs dependencies and downloads model files.
- Model files are not stored in this repository.
- Stop or delete test pods after verification to avoid unexpected GPU costs.

## License

MIT License
