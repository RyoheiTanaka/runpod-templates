# runpod-templates

RunPod で AI 環境を起動するためのテンプレート用 setup script 集です。

この repo には公開利用者向けの配布物だけを置きます。作業メモ、検証ログ、API key、template ID、pod ID は含めません。

## テンプレート

| 名前 | スクリプト | 用途 | UI | ポート |
|---|---|---|---|---|
| `wan22` | `scripts/setup_wan22.sh` | Wan2.2 動画生成用 ComfyUI 環境。CUDA 12.4 安定版 | ComfyUI | `8188/http` |
| `wan22-cuda128` | `scripts/setup_wan22.sh` | Wan2.2 動画生成用 ComfyUI 環境。CUDA 12.8 最新版 | ComfyUI | `8188/http` |

## Wan2.2

Wan2.2 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

### 推奨 RunPod 設定

まずは `wan22` を使ってください。CUDA 12.4 image を使うため、RunPod host driver との互換性が比較的高く、起動確認向けです。

`wan22-cuda128` は CUDA 12.8 image を使う最新版です。新しい driver の host に当たれば使えますが、host driver が CUDA 12.8 要件を満たさない場合は container 起動前に失敗します。

| テンプレート名 | コンテナイメージ | 用途 |
|---|---|---|
| `wan22` | `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04` | 安定版。まずはこちらを推奨。 |
| `wan22-cuda128` | `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04` | 最新版。CUDA 12.8 対応 driver の host 向け。 |

共通設定:

| 項目 | 値 |
|---|---|
| Container Disk | `200 GB` |
| Volume | `0 GB` または未指定 |
| 公開ポート | `8188/http`, `22/tcp` |
| Start Command | 下記参照 |

### Start Command

既定では `RUNPOD_TEMPLATES_REF` の値を参照します。
template の既定値は `main` です。安定運用時は `v1.0.0` のような release tag または commit SHA に変更してください。

```bash
bash -c 'RUNPOD_TEMPLATES_REF="${RUNPOD_TEMPLATES_REF:-main}"; curl -fsSL "https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/${RUNPOD_TEMPLATES_REF}/scripts/setup_wan22.sh" | bash'
```

`RUNPOD_TEMPLATES_REF=main` は常に最新の `main` を使います。`latest` という branch または tag を作れば `RUNPOD_TEMPLATES_REF=latest` でも運用できますが、再現性を重視する場合は `v1.0.0` などの固定 tag を推奨します。

### 環境変数

RunPod で Pod を起動する前に、必要に応じて template の環境変数を確認・変更してください。

| 名前 | 既定値 | 説明 |
|---|---|---|
| `WAN_VARIANT` | `t2v_a14b` | ダウンロードするモデル variant。対応値は `t2v_a14b`, `i2v_a14b`, `ti2v_5b`。 |
| `RUNPOD_TEMPLATES_REF` | `main` | setup script を取得する Git ref。`main`, `v1.0.0`, commit SHA, `latest` branch/tag など。 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | `your-huggingface-token` | 推奨。Hugging Face の実 token に置き換えると rate limit を避けやすく、モデル download が速くなる場合があります。 |

`WAN_VARIANT=all` は、必要なモデル容量が大きすぎるため初期版では意図的に非対応です。
`HF_TOKEN=your-huggingface-token` はプレースホルダーとして扱い、setup script 内では token 未設定として無視します。

### ComfyUI へのアクセス

setup log に `To see the GUI go to: http://0.0.0.0:8188` が出たら、ComfyUI は Pod 内で起動済みです。
RunPod console の Pod 詳細から `Connect to HTTP Service [Port 8188]` を開くか、次の形式の URL にアクセスします。

```text
https://<pod-id>-8188.proxy.runpod.net
```

Pod が `Running` でも HTTP service の公開には数分かかる場合があります。`Not Ready` が出る場合は、Pod の exposed HTTP ports に `8188/http` が入っていることと、ComfyUI の起動ログが出ていることを確認してから再読み込みしてください。

ComfyUI の cross-site request 保護により RunPod proxy 経由のアクセスが 403 になる場合があるため、この setup script では `--enable-cors-header "*"` を付けて ComfyUI を起動します。

### 起動前に設定する項目

#### WAN_VARIANT

RunPod の template UI では dropdown 形式の選択肢を定義できないため、`WAN_VARIANT` は環境変数の値を手入力で変更します。

| 値 | 用途 | 目安 |
|---|---|---|
| `t2v_a14b` | text-to-video 14B | 既定値。まず試す場合はこちら。 |
| `i2v_a14b` | image-to-video 14B | 画像から動画を生成する場合。RTX 4090 向けに FP8 scaled モデルを配置します。 |
| `ti2v_5b` | text/image-to-video 5B | 14B より軽量な variant を使いたい場合。 |
| `all` | 非対応 | 容量が大きすぎるため、この template では使用しません。 |

未対応値を入力した場合、setup script は明示的に error 終了します。

#### HF_TOKEN

既定値は `your-huggingface-token` です。

Hugging Face の認証が必要なモデルでなくても、モデル download の高速化や rate limit 回避のため、Pod 起動前に RunPod の環境変数画面で実 token に置き換えることを推奨します。
`your-huggingface-token` のまま起動した場合は、setup script がプレースホルダーとして扱い、token 未設定として無視します。

### 配置先

| パス | 用途 |
|---|---|
| `/workspace/ComfyUI` | ComfyUI checkout |
| `/workspace/models/wan22/comfy-repackaged` | ダウンロードしたモデルファイル |
| `/workspace/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | setup log |

`WAN_VARIANT=t2v_a14b` と `WAN_VARIANT=i2v_a14b` では、ComfyUI の高速化 workflow で使われる LightX2V 4-step LoRA も `/workspace/ComfyUI/models/loras` に配置します。

## 注意

- 初回起動では依存関係の install とモデル download が走るため時間がかかります。
- モデルファイルはこの repo には含めません。
- 検証後は想定外の GPU 課金を避けるため、test pod を停止または削除してください。

## ライセンス

MIT License
