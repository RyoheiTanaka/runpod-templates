# ACE-Step 1.5 XL RunPod template

ACE-Step 1.5 XL 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

## RunPod settings

まずは CUDA 12.4 image を使ってください。RunPod host driver との互換性が比較的高く、RTX 3090 / RTX 4090 の起動確認向けです。
RTX 5090 など Blackwell 世代の GPU では CUDA 12.8 / PyTorch 2.8 image の `ComfyUI-ACE-Step1.5XL-cuda12.8-FreeCraftLog` template を使ってください。

| Template | Container image | Use case |
|---|---|---|
| `ComfyUI-ACE-Step1.5XL-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-acestep15xl:v1.0.0-cuda12.4` | RTX 3090 / RTX 4090 など、まず通常検証する場合 |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-acestep15xl:v1.0.0-cuda12.8` | RTX 5090 など CUDA 12.8 対応が必要な GPU |

## Deploy Links

| Template | RunPod deploy link |
|---|---|
| `ComfyUI-ACE-Step1.5XL-FreeCraftLog` | <https://console.runpod.io/deploy?template=whhlf8rbip&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-FreeCraftLog` | <https://console.runpod.io/deploy?template=0obn96ivv6&ref=zc2sdxqc> |

| Item | Value |
|---|---|
| Container image | `ghcr.io/ryoheitanaka/runpod-templates-acestep15xl:v1.0.0-cuda12.4` |
| Container Disk | `100 GB` |
| Volume | `0 GB` または未指定 |
| Ports | `8188/http`, `22/tcp` |
| Recommended GPU | RTX 3090 以上。20GB+ VRAM 推奨。 |
| Start Command | 下記参照 |

## Start Command

既定では container image 内の `/opt/runpod/start.sh` を実行します。
template の定定値は `v1.0.0` です。開発中の最新版を試す場合だけ `main` に変更してください。

```bash
/opt/runpod/start.sh
```

## Environment variables

RunPod で Pod を起動する前に、必要に応じて template の環境変数を確認・変更してください。

| Name | Default | Description |
|---|---|---|
| `ACESTEP_XL_VARIANT` | `all` | ダウンロードする diffusion model。対応値は `xl_base`, `xl_sft`, `xl_turbo`, `all`。 |
| `ACESTEP_LM` | `all` | ダウンロードする text encoder。対応値は `qwen_0.6b`, `qwen_1.7b`, `qwen_4b`, `all`。 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `HF_HUB_ENABLE_HF_TRANSFER` | `1` | Hugging Face download の高速化を有効化します。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | `your-huggingface-token` | 推奨。Hugging Face の実 token に置き換えると rate limit を避けやすく、モデル download が速くなる場合があります。 |

`HF_TOKEN=your-huggingface-token` はプレースホルダーとして扱い、setup script 内では token 未設定として無視します。
`ACESTEP_XL_VARIANT=all` は XL base / SFT / turbo の 3 model をすべて配置します。
`ACESTEP_LM=all` は qwen 0.6B / 1.7B / 4B text encoder をすべて配置します。
未対応値を入力した場合、setup script は明示的に error 終了します。

## ComfyUI access

start log に `To see the GUI go to: http://0.0.0.0:8188` が出たら、ComfyUI は Pod 内で起動済みです。
RunPod console の Pod 詳細から `Connect to HTTP Service [Port 8188]` を開くか、次の形式の URL にアクセスします。

```text
https://<pod-id>-8188.proxy.runpod.net
```

Pod が `Running` でも HTTP service の公開には数分かかる場合があります。`Not Ready` が出る場合は、Pod の exposed HTTP ports に `8188/http` が入っていることと、ComfyUI の起動ログが出ていることを確認してから再読み込みしてください。

## Paths

| Path | Purpose |
|---|---|
| `/opt/ComfyUI` | ComfyUI checkout |
| `/workspace/models/acestep15xl/comfy-files` | ダウンロードしたモデルファイル |
| `/opt/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | start log |
