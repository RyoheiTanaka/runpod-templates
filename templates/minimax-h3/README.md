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
`12.4 → available: false`）ためです。

| Template | Container image | Use case |
|---|---|---|
| `ComfyUI-MiniMaxH3-R2V-cuda130-FreeCraftLog` | `...runpod-templates-minimax-h3:latest-cuda13.0` | **推奨。** CUDA 13.0 ホスト向け |
| `ComfyUI-MiniMaxH3-R2V-cuda128-FreeCraftLog` | `...runpod-templates-minimax-h3:latest-cuda12.8` | CUDA 13.0 が確保できない場合のフォールバック |

**cuda13.0 版を推奨します。** cuda12.8 版では ComfyUI が次の警告を出し、`comfy_kitchen` の
`cuda` / `triton` バックエンドが両方 `disabled` になって `eager` へ fallback します。

```
WARNING: You need pytorch with cu130 or higher to use optimized CUDA operations.
```

このテンプレートが使う diffusion モデルは `int8_convrot` 版で、**毎サンプリングステップで回る本体**です。
その native パスが cu128 では無効化されるため、生成速度に直接効きます。

⚠️ **cuda13.0 版は CUDA 13.0 のホストでしか動きません。** CUDA 13.x はメジャーバージョンが上がるため、
12.8 のドライバでは動作しません。Pod 作成時にホストの CUDA を制約してください（下記）。

公開 deploy link を出す際は、`latest-cuda13.0` を release tag（例: `v1.1.0-cuda13.0`）に固定してください。

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
| システム RAM | 64GB 以上（AP-JP-1 の H100 実機では 2.0TB だった） |
| `allowedCudaVersions` | cuda13.0 版なら `13.0` / cuda12.8 版なら `12.8`（**`12.4` は H100 で使用不可**） |
| `dataCenterIds` | `AP-JP-1` / `AP-IN-1` / `CA-MTL-1` のみ（**地域制約**、上記参照） |
| Network volume | 使用しない |

### CUDA ホストの指定方法

REST v2 API の `CreateGpuConfig` は CUDA 制約を持っています（`POST /v2/pods`）:

| フィールド | 意味 |
|---|---|
| `gpu.allowedCudaVersions` | 許可する CUDA を完全一致で指定（例 `["13.0"]`） |
| `gpu.minCudaVersion` | 下限を指定（例 `"13.0"`）。`allowedCudaVersions` と同時指定は 400 |

`runpodctl` にも RunPod MCP の `create-pod` にもこの項目はありません（MCP tools は API の
curated projection）。**cuda13.0 版を使うときは REST API か console から作成してください。**
DC も同様に `dataCenterIds` を必ず明示します（地域制約）。

作成後は `get-pod` の `cudaVersion` を確認し、意図したホストに乗っているか確かめてください。

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
| `HF_XET_HIGH_PERFORMANCE` | `1` | Xet 転送の高速モード。 |
| `H3_DOWNLOAD_TURBO_LORA` | `0` | `1` で Turbo LoRA（1.96GB）も取得します。既定は取得しません。 |

`HF_TOKEN` は不要です。`Comfy-Org/MiniMax-H3` は gated ではないため、ライセンス同意も token も要りません。

`HF_HUB_ENABLE_HF_TRANSFER` は**使いません**。`hf_transfer` は既に非推奨で、
huggingface_hub は Xet を使うようになっています（設定しても no-op で、実行時に警告が出るだけです）。

## 接続方法 — `8188/http` の proxy を常用しないこと

RunPod の HTTP proxy（`https://<pod-id>-8188.proxy.runpod.net`）は **認証なしで公開されます。**
URL を知っていれば誰でも ComfyUI を操作でき、`input/` と `output/` の中身も見えます。

参照画像や生成物を扱うため、**SSH ポートフォワード経由で `localhost:8188` に繋ぐことを既定にしてください。**

```bash
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <秘密鍵>
```

Pod 作成時、`sshPublicKey` に公開鍵の**中身**（`ssh-ed25519 AAAA...` の1行そのもの。ファイルパスではない）を
渡すと `PUBLIC_KEY` がセットされ `22/tcp` が開きます。

このイメージは `CMD` で公式イメージの entrypoint を置き換えているため、**`PUBLIC_KEY` を
`authorized_keys` に展開して sshd を起動するのは `start.sh` の役割**です。起動ログに
`[start] sshd started` が出ていれば成功しています。sshd の起動に失敗しても ComfyUI は起動します。

> RunPod の proxy SSH（`ssh.runpod.io`）は**アカウント設定**に登録した公開鍵で認証します。
> Pod の `PUBLIC_KEY` とは別系統なので、使うなら Settings → SSH Public Keys にも登録が必要です。

`8188/http` はデバッグ用に残していますが、常用しないでください。ポート自体を落とす選択もあります。
`--enable-cors-header "*"` は**外しました**。comfy-mcp は HTTP でサーバ側から叩くため CORS は不要で、
付けたままだとブラウザで開いた任意のサイトからトンネル先の ComfyUI を操作できてしまいます。

## Models

すべて [`Comfy-Org/MiniMax-H3`](https://huggingface.co/Comfy-Org/MiniMax-H3) から取得します
（既定は Turbo LoRA を除く **42.47 GB**。AP-JP-1 の H100 実機で約 90 秒でした）。

| ComfyUI の配置先 | ファイル | サイズ |
|---|---|---|
| `diffusion_models/` | `minimax_h3_ref2va_pruned_int8_convrot.safetensors` | 20.97 GB |
| `text_encoders/` | `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 15.69 GB |
| `vae/` | `minimax_h3_video_vae_fp16.safetensors` | 5.21 GB |
| `vae/` | `minimax_h3_audio_vae_fp32.safetensors` | 0.61 GB |
| `loras/` | `minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | 1.96 GB（既定では取得しない） |

- Text encoder は NVFP4 AWQ 版です。NVFP4 は H100（sm_90）では emulated になりますが、
  TE は生成中1回しか通らないため実質的な影響はありません。
  VRAM/RAM が足りない場合だけ `qwen3vl_32b_minimax_h3_int8_convrot.safetensors`（27.14 GB、合計 55.9 GB）を検討してください。
- Turbo LoRA は**ワークフロー側で無効**の想定のため、既定では取得しません
  （もや・低コントラスト・色転びの原因）。検証する場合のみ `H3_DOWNLOAD_TURBO_LORA=1` を指定してください。

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
