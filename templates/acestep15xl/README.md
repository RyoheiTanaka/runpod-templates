# ACE-Step 1.5 XL RunPod template

ACE-Step 1.5 XL 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

## RunPod settings

まずは CUDA 12.4 image を使ってください。RunPod host driver との互換性が比較的高く、起動確認向けです。

| Item | Value |
|---|---|
| Container image | `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04` |
| Container Disk | `80 GB` |
| Volume | `0 GB` または未指定 |
| Ports | `8188/http`, `22/tcp` |
| Recommended GPU | RTX 3090 以上。20GB+ VRAM 推奨。 |
| Start Command | 下記参照 |

## Start Command

既定では `RUNPOD_TEMPLATES_REF` の値を参照します。
template の既定値は `main` です。安定運用時は release tag または commit SHA に変更してください。

```bash
bash -c 'RUNPOD_TEMPLATES_REF="${RUNPOD_TEMPLATES_REF:-main}"; curl -fsSL "https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/${RUNPOD_TEMPLATES_REF}/templates/acestep15xl/setup.sh" | bash'
```

## Environment variables

RunPod で Pod を起動する前に、必要に応じて template の環境変数を確認・変更してください。

| Name | Default | Description |
|---|---|---|
| `ACESTEP_XL_VARIANT` | `all` | ダウンロードする diffusion model。対応値は `xl_base`, `xl_sft`, `xl_turbo`, `all`。 |
| `ACESTEP_LM` | `qwen_1.7b` | ダウンロードする text encoder。対応値は `qwen_0.6b`, `qwen_1.7b`, `qwen_4b`。 |
| `RUNPOD_TEMPLATES_REF` | `main` | setup script を取得する Git ref。`main`, release tag, commit SHA など。 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `HF_HUB_ENABLE_HF_TRANSFER` | `1` | Hugging Face download の高速化を有効化します。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | `your-huggingface-token` | 推奨。Hugging Face の実 token に置き換えると rate limit を避けやすく、モデル download が速くなる場合があります。 |

`HF_TOKEN=your-huggingface-token` はプレースホルダーとして扱い、setup script 内では token 未設定として無視します。
`ACESTEP_XL_VARIANT=all` は XL base / SFT / turbo の 3 model をすべて配置します。
未対応値を入力した場合、setup script は明示的に error 終了します。

## ComfyUI access

setup log に `To see the GUI go to: http://0.0.0.0:8188` が出たら、ComfyUI は Pod 内で起動済みです。
RunPod console の Pod 詳細から `Connect to HTTP Service [Port 8188]` を開くか、次の形式の URL にアクセスします。

```text
https://<pod-id>-8188.proxy.runpod.net
```

Pod が `Running` でも HTTP service の公開には数分かかる場合があります。`Not Ready` が出る場合は、Pod の exposed HTTP ports に `8188/http` が入っていることと、ComfyUI の起動ログが出ていることを確認してから再読み込みしてください。

## Paths

| Path | Purpose |
|---|---|
| `/workspace/ComfyUI` | ComfyUI checkout |
| `/workspace/models/acestep15xl/comfy-files` | ダウンロードしたモデルファイル |
| `/workspace/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | setup log |
