# runpod-templates

RunPod で AI 環境を起動するためのテンプレート用 setup script 集です。

この repo には公開利用者向けの配布物だけを置きます。作業メモ、検証ログ、API key、template ID、pod ID は含めません。

## テンプレート

| 名前 | スクリプト | 用途 | UI | ポート |
|---|---|---|---|---|
| `wan22` | `scripts/setup_wan22.sh` | Wan2.2 動画生成用 ComfyUI 環境 | ComfyUI | `8188/http` |

## Wan2.2

Wan2.2 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

### 推奨 RunPod 設定

| 項目 | 値 |
|---|---|
| テンプレート名 | `wan22` |
| コンテナイメージ | `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu24.04` |
| Container Disk | `200 GB` |
| Volume | `0 GB` または未指定 |
| 公開ポート | `8188/http`, `22/tcp` |
| Start Command | 下記参照 |

### Start Command

検証中は `main` branch を参照します。

```bash
bash -c "curl -fsSL https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/main/scripts/setup_wan22.sh | bash"
```

安定運用時は release tag または commit SHA に固定してください。

```bash
bash -c "curl -fsSL https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/<tag-or-commit>/scripts/setup_wan22.sh | bash"
```

### 環境変数

| 名前 | 既定値 | 説明 |
|---|---|---|
| `WAN_VARIANT` | `t2v_a14b` | ダウンロードするモデル variant。対応値は `t2v_a14b`, `i2v_a14b`, `ti2v_5b`。 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | 未設定 | 任意。Hugging Face の認証が必要な場合は RunPod の環境変数として設定します。 |

`WAN_VARIANT=all` は、必要なモデル容量が大きすぎるため初期版では意図的に非対応です。

### 配置先

| パス | 用途 |
|---|---|
| `/workspace/ComfyUI` | ComfyUI checkout |
| `/workspace/models/wan22/comfy-repackaged` | ダウンロードしたモデルファイル |
| `/workspace/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | setup log |

## 注意

- 初回起動では依存関係の install とモデル download が走るため時間がかかります。
- モデルファイルはこの repo には含めません。
- 検証後は想定外の GPU 課金を避けるため、test pod を停止または削除してください。

## ライセンス

MIT License
