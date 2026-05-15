# Wan2.2 RunPod template

Wan2.2 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

## RunPod settings

まずは CUDA 12.4 image の `ComfyUI-Wan2.2-FreeCraftLog` を使ってください。RunPod host driver との互換性が比較的高く、起動確認向けです。

CUDA 12.8 image を使う場合は、host driver が CUDA 12.8 要件を満たす環境で使ってください。満たさない場合は container 起動前に失敗します。

| Template | Container image | Use case |
|---|---|---|
| `ComfyUI-Wan2.2-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-wan22:v1.0.0-cuda12.4` | 安定版。まずはこちらを推奨。 |
| `ComfyUI-Wan2.2-cuda12.8-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-wan22:v1.0.0-cuda12.8` | CUDA 12.8 対応 driver の host 向け。 |

## Deploy Links

| Template | RunPod deploy link |
|---|---|
| `ComfyUI-Wan2.2-FreeCraftLog` | <https://console.runpod.io/deploy?template=soj5tjnbex&ref=zc2sdxqc> |
| `ComfyUI-Wan2.2-cuda12.8-FreeCraftLog` | <https://console.runpod.io/deploy?template=x4ckgbo5gt&ref=zc2sdxqc> |

共通設定:

| Item | Value |
|---|---|
| Container Disk | `200 GB` |
| Volume | `0 GB` または未指定 |
| Ports | `8188/http`, `22/tcp` |
| Start Command | 下記参照 |

## Start Command

既定では container image 内の `/opt/runpod/start.sh` を実行します。
template の既定値は `v1.0.0` です。開発中の最新版を試す場合だけ `main` に変更してください。

```bash
/opt/runpod/start.sh
```

公開 deploy link では再現性を重視し、`v1.0.0-cuda12.4` などの固定 image tag を使います。

## Environment variables

RunPod で Pod を起動する前に、必要に応じて template の環境変数を確認・変更してください。

| Name | Default | Description |
|---|---|---|
| `WAN_VARIANT` | `t2v_a14b` | ダウンロードするモデル variant。対応値は `t2v_a14b`, `i2v_a14b`, `ti2v_5b`。 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | `your-huggingface-token` | 推奨。Hugging Face の実 token に置き換えると rate limit を避けやすく、モデル download が速くなる場合があります。 |

`WAN_VARIANT=all` は、必要なモデル容量が大きすぎるため意図的に非対応です。
`HF_TOKEN=your-huggingface-token` はプレースホルダーとして扱い、setup script 内では token 未設定として無視します。

## WAN_VARIANT

RunPod の template UI では dropdown 形式の選択肢を定義できないため、`WAN_VARIANT` は環境変数の値を手入力で変更します。

| Value | Use case | Notes |
|---|---|---|
| `t2v_a14b` | text-to-video 14B | 既定値。まず試す場合はこちら。 |
| `i2v_a14b` | image-to-video 14B | 画像から動画を生成する場合。RTX 4090 向けに FP8 scaled モデルを配置します。 |
| `ti2v_5b` | text/image-to-video 5B | 14B より軽量な variant を使いたい場合。 |
| `all` | 非対応 | 容量が大きすぎるため、この template では使用しません。 |

未対応値を入力した場合、setup script は明示的に error 終了します。

## ComfyUI access

start log に `To see the GUI go to: http://0.0.0.0:8188` が出たら、ComfyUI は Pod 内で起動済みです。
RunPod console の Pod 詳細から `Connect to HTTP Service [Port 8188]` を開くか、次の形式の URL にアクセスします。

```text
https://<pod-id>-8188.proxy.runpod.net
```

Pod が `Running` でも HTTP service の公開には数分かかる場合があります。`Not Ready` が出る場合は、Pod の exposed HTTP ports に `8188/http` が入っていることと、ComfyUI の起動ログが出ていることを確認してから再読み込みしてください。

ComfyUI の cross-site request 保護により RunPod proxy 経由のアクセスが 403 になる場合があるため、この setup script では `--enable-cors-header "*"` を付けて ComfyUI を起動します。

## Paths

| Path | Purpose |
|---|---|
| `/opt/ComfyUI` | ComfyUI checkout |
| `/workspace/models/wan22/comfy-repackaged` | ダウンロードしたモデルファイル |
| `/opt/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | start log |

`WAN_VARIANT=t2v_a14b` と `WAN_VARIANT=i2v_a14b` では、ComfyUI の高速化 workflow で使われる LightX2V 4-step LoRA も `/opt/ComfyUI/models/loras` に配置します。
