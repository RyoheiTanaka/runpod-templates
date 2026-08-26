# MiniMax H3 (Ref2VA) RunPod template

MiniMax H3 の **R2V（Ref2VA: 参照画像から映像＋音声を生成）** 用 ComfyUI 環境を、RunPod 起動時に自動セットアップします。

## ⚠️ 地域制約（必ず読んでください）

MiniMax H3 Community License には **Excluded Territories** があります。

> Applicable Territory = worldwide, **excluding** the European Union, the United Kingdom,
> the Republic of Korea, and the United States of America.

Pod を起動するデータセンターがこの除外地域に入っていると、ライセンス違反になります。
**Pod 作成時に `dataCenterIds` を必ず明示してください。**

| RunPod DC | 可否 |
|---|---|
| `AP-IN-1` / `AP-JP-1` / `CA-MTL-1` | OK |
| `EUR-NO-2` | ノルウェーは EU 非加盟のため文言上は可。利用者判断 |
| `EU-FR-1` / `EU-NL-1` | **不可（EU）** |
| `US-CA-2` / `US-GA-2` / `US-MO-1` / `US-NE-1` | **不可（米国）** |

```text
MiniMax H3 is licensed under the MiniMax H3 Community License Agreement,
Copyright © 2026 MiniMax. All Rights Reserved.
```

## RunPod settings

CUDA 12.4 版はありません。H100 80GB HBM3 では **CUDA 12.4 が使えない**（RunPod の GPU 情報で
`12.4 → available: false`）ため、この template は **CUDA 12.8 版のみ**です。

| Template | Container image | Use case |
|---|---|---|
| `ComfyUI-MiniMaxH3-R2V-cuda128-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-minimax-h3:latest-cuda12.8` | H100 など CUDA 12.8 以上の GPU 向け |

公開 deploy link を出す際は、`latest-cuda12.8` を release tag（例: `v1.1.0-cuda12.8`）に固定してください。

共通設定:

| Item | Value |
|---|---|
| Container Disk | `100 GB`（モデル 44.4GB + ComfyUI + 出力） |
| Volume | `0 GB`（ネットワークボリューム不使用） |
| Ports | `8188/http`, `22/tcp` |
| Start Command | `/opt/runpod/start.sh` |

ネットワークボリュームを使わない方針のため、**Pod を落とすたびに 44.4GB を再取得します。**
1日の作業は1つの Pod にまとめてください。

## 推奨 Pod 設定（テンプレートには保存できない項目）

GPU・データセンター・CUDA バージョン制限は **RunPod の Pod テンプレートに保存できません**
（保存できるのは image / disk / ports / env / start command のみ。GPU とリージョンを設定に持てるのは
Serverless の Endpoint 側です）。Pod 作成のたびに毎回指定してください。

| 項目 | 値 |
|---|---|
| GPU | `NVIDIA H100 80GB HBM3` |
| GPU 数 | 1 |
| システム RAM | 64GB 以上（下回る構成なら上位プランへ） |
| `allowedCudaVersions` | `12.8`, `13.0`（**`12.4` は H100 で使用不可**） |
| `dataCenterIds` | `AP-JP-1` / `AP-IN-1` / `CA-MTL-1` のみ（**地域制約**、上記参照） |
| Network volume | 使用しない |

```bash
runpodctl create pod \
  --name minimax-h3-test \
  --templateId <TEMPLATE_ID> \
  --gpuType "NVIDIA H100 80GB HBM3" \
  --gpuCount 1
```

`runpodctl` にはデータセンター指定のオプションが無いため、**DC を固定したい場合は RunPod console か
REST API（`dataCenterIds`）から作成してください。** 地域制約があるので、ここは必ず明示します。

## Start Command

```bash
/opt/runpod/start.sh
```

## Environment variables

| Name | Default | Description |
|---|---|---|
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `WORKSPACE` | `/workspace` | モデル、cache、出力、ログの基準ディレクトリ。 |
| `OUTPUT_DIR` | `/workspace/outputs` | 生成物の出力先。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_HUB_ENABLE_HF_TRANSFER` | `1` | 大容量モデルの download を高速化します。 |

`HF_TOKEN` は不要です。`Comfy-Org/MiniMax-H3` は gated ではないため、ライセンス同意も token も要りません。

## 接続方法 — `8188/http` の proxy を常用しないこと

RunPod の HTTP proxy（`https://<pod-id>-8188.proxy.runpod.net`）は **認証なしで公開されます。**
URL を知っていれば誰でも ComfyUI を操作でき、`input/` と `output/` の中身も見えます。

参照画像や生成物を扱うため、**SSH ポートフォワード経由で `localhost:8188` に繋ぐことを既定にしてください。**

```bash
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <秘密鍵>
```

Pod 作成時、`sshPublicKey` に公開鍵の**中身**（`ssh-ed25519 AAAA...` の1行そのもの。ファイルパスではない）を
渡すと `PUBLIC_KEY` がセットされ `22/tcp` が開きます。

`8188/http` はデバッグ用に残していますが、常用しないでください。ポート自体を落とす選択もあります。

## Models

すべて [`Comfy-Org/MiniMax-H3`](https://huggingface.co/Comfy-Org/MiniMax-H3) から取得します（合計 44.43 GB）。

| ComfyUI の配置先 | ファイル | サイズ |
|---|---|---|
| `diffusion_models/` | `minimax_h3_ref2va_pruned_int8_convrot.safetensors` | 20.97 GB |
| `text_encoders/` | `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 15.69 GB |
| `vae/` | `minimax_h3_video_vae_fp16.safetensors` | 5.21 GB |
| `vae/` | `minimax_h3_audio_vae_fp32.safetensors` | 0.61 GB |
| `loras/` | `minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | 1.96 GB |

- Text encoder は NVFP4 AWQ 版です。NVFP4 は H100（sm_90）では emulated になりますが、
  TE は生成中1回しか通らないため実質的な影響はありません。
  VRAM/RAM が足りない場合だけ `qwen3vl_32b_minimax_h3_int8_convrot.safetensors`（27.14 GB、合計 55.9 GB）を検討してください。
- Turbo LoRA は取得しますが、**ワークフロー側では無効**の想定です（もや・低コントラスト・色転びの原因）。

## Recommended workflow settings

| 項目 | 値 |
|---|---|
| モード | R2V（Ref2VA） |
| Turbo LoRA | 無効 |
| scheduler / sampler | `beta` / `res_multistep` |
| steps | 20（30 は +49% のコストで効果薄） |
| `ref_image_size` | `max` |
| 尺 | 345f = 14.375 秒（フレーム数は 17の倍数+5 に量子化される） |
| 解像度 | 1344x768（0.98MP） |
| 参照音声 | 使わない（H3 に音楽ごと生成させる） |

## Paths

| Path | Purpose |
|---|---|
| `/opt/ComfyUI` | ComfyUI checkout（`v0.32.0`。H3 には 0.30.0 以上が必要） |
| `/workspace/models/minimax-h3/comfy-org` | ダウンロードしたモデルファイル |
| `/opt/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/outputs` | 生成物 |
| `/workspace/logs` | start log |

## Not covered

- FL2VA / T2VA など R2V 以外のバリアント
- Turbo LoRA を有効にした構成
- ネットワークボリュームの利用
