# Wan2.2 RunPod template

Wan2.2 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

## RunPod settings

まずは CUDA 12.8 image を使ってください。起動できる host が最も広いためです。

`cuda12.8` image はベースを runtime 版に差し替えており、`NVIDIA_REQUIRE_CUDA` を持ちません。
旧版は要件を満たさない host で container 起動前に失敗しましたが、この image はそこを通過してしまい、
実行時に CUDA のエラーになります。**代わりに template の `allowedCudaVersions` で
`12.8` 以上のみを許可しています。** RunPod console から自分で template を作る場合は、
同じ設定を忘れないでください。

`cuda13.0` image は従来どおり `NVIDIA_REQUIRE_CUDA` で `cuda>=13.0` を要求するので、
13.0 host でしか起動しません。

| Template | Container image | Use case |
|---|---|---|
| `ComfyUI-Wan2.2-cuda12.8-v3-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-wan22:v3.2.0-cuda12.8` | 推奨。まずはこちら。 |
| `ComfyUI-Wan2.2-cuda130-v3-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-wan22:v3.2.0-cuda13.0` | 最新 CUDA を使いたい場合。host が CUDA 13.0 対応である必要があります。 |

### v3.2.0 でイメージを軽くしました

`cuda12.8` image のベースを devel から runtime に差し替えました。`devel` は nvcc やヘッダを含みますが、
ComfyUI は実行時にどれも使いません。

| | v3.1.0 | v3.2.0 |
|---|---|---|
| イメージ（圧縮後） | 10.10 GB | **4.81 GB** |
| PyTorch | `2.8.0.dev20250319+cu128` | `2.8.0+cu128` |

**環境に依存しない事実はイメージサイズが 52% 減ったことだけです。** 起動時間の短縮は
その結果として期待できますが、倍率は環境依存なので固定値として受け取らないでください。

`v3.2.0` の Pod 起動を1本測った内訳です（RTX 4090 / EUR-IS-1 / `t2v_a14b`）。

| 段階 | 所要 |
|---|---|
| イメージ pull + 展開 | 4分27秒（実効 約25 MB/s） |
| モデル DL | 約50秒 |
| ComfyUI 起動 | 12秒 |
| 合計 | 5分28秒 |

**モデルのダウンロードではなくイメージの取得が律速です**（全体の 81%）。そこを削ったのが
今回の変更です。ただし pull 速度はデータセンターで数倍振れ、同日・同一イメージでも
別の Pod では 4分01秒でした。モデル DL 側も Hugging Face の時間帯で二桁変わります。

サイズと時間は比例しません。同日の観測ではサイズ 52% 減に対して pull は 30% 減でした。
runtime イメージはレイヤ枚数が少なく（11枚 vs 34枚）、ダウンロードは並列化できても
巨大なレイヤの展開は直列になるためです。見積もりを立てるときはここを勘定に入れてください。

CUDA 12.4 image は `v3.0.0` で廃止しました（`v3.2.0` でも同じ）。ComfyUI `v0.32.0` が要求する `comfy-kitchen` が
PyTorch 2.5 以上を前提としており、CUDA 12.4 ベースイメージの PyTorch 2.4.0 では ComfyUI が起動しません。

GPU による image の出し分けは不要になりました。RTX 3090 / 4090 / 5090 いずれも CUDA 13.0 image を使えます。

## Deploy Links

| Template | RunPod deploy link |
|---|---|
| `ComfyUI-Wan2.2-cuda12.8-v3-FreeCraftLog`（**推奨**） | <https://console.runpod.io/deploy?template=tfcpp13sns&ref=zc2sdxqc> |
| `ComfyUI-Wan2.2-cuda130-v3-FreeCraftLog` | <https://console.runpod.io/deploy?template=429co6ch6n&ref=zc2sdxqc> |
| `ComfyUI-Wan2.2-FreeCraftLog`（v1.0.0 / CUDA 12.4） | <https://console.runpod.io/deploy?template=soj5tjnbex&ref=zc2sdxqc> |
| `ComfyUI-Wan2.2-cuda12.8-FreeCraftLog`（v1.0.0 / CUDA 12.8） | <https://console.runpod.io/deploy?template=x4ckgbo5gt&ref=zc2sdxqc> |

共通設定:

| Item | Value |
|---|---|
| Container Disk | `100 GB` |
| Volume | `0 GB` または未指定 |
| Ports | `8188/http`, `22/tcp` |
| Start Command | 下記参照 |

### Container Disk を 100 GB にした根拠

`v3.2.1` で `200 GB` から下げました。RTX 4090 の Pod で実測した値は以下です（2026-08-31）。

| 時点 | `df -h /` |
|---|---|
| 起動直後（モデル DL 前） | `200G  60K  200G   1%` |
| `t2v_a14b` の DL 完了後 | `200G   36G  165G  18%` |

**container image は container disk を消費しません。** 展開後のイメージは別枠で、
container disk が保持するのは `/workspace` 以下の書き込み分だけです。`start.sh` は
ダウンロードしたファイルを `ln -sfn` で ComfyUI に見せているので、二重保存もありません。

variant ごとのモデル実容量（Hugging Face の実ファイルサイズ、GiB）:

| variant | 内訳 | 合計 |
|---|---|---|
| `t2v_a14b` | high 13.31 + low 13.31 + lora×2 2.29 + umt5 6.27 + vae2.1 0.24 | **35.4** |
| `i2v_a14b` | high 13.31 + low 13.31 + lora×2 2.29 + umt5 6.27 + vae2.1 0.24 | **35.4** |
| `ti2v_5b` | 5B fp16 9.31 + umt5 6.27 + vae2.2 1.31 | **16.9** |

`start.sh` は既存ファイルがあれば skip するだけで削除しないため、`WAN_VARIANT` を
切り替えると古いモデルが残ります。`umt5` と `vae2.1` は共有されるので、累積は次のとおりです。

| 使い方 | 累積 |
|---|---|
| 1 variant のみ | 35.4 GB |
| `t2v_a14b` → `i2v_a14b` | 64.3 GB |
| 3 variant すべて | 74.9 GB |

最大 74.9 GB に出力動画（`/workspace/outputs`）の分を足しても `100 GB` に収まります。
acestep15xl の template と同じ値なので、説明も揃います。

## Start Command

既定では container image 内の `/opt/runpod/start.sh` を実行します。
template JSON の既定値は `v3.2.0` です。開発中の最新版を試す場合だけ `latest-cuda12.8` に変更してください。

```bash
/opt/runpod/start.sh
```

公開 deploy link では再現性を重視し、`v3.2.0-cuda12.8` などの固定 image tag を使います。

## Environment variables

RunPod で Pod を起動する前に、必要に応じて template の環境変数を確認・変更してください。

| Name | Default | Description |
|---|---|---|
| `WAN_VARIANT` | `t2v_a14b` | ダウンロードするモデル variant。対応値は `t2v_a14b`, `i2v_a14b`, `ti2v_5b`。 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | `your-huggingface-token` | 推奨。Hugging Face の実 token に置き換えると rate limit を避けやすく、モデル download が速くなる場合があります。 |
| `COMFY_PINNED_MEMORY` | `auto` | pinned memory の扱い。`auto` はコンテナのメモリ上限を cgroup から読み、ホスト RAM より明らかに小さければ自動で無効化します。`on` で常に有効、`off` で常に無効。 |
| `COMFY_EXTRA_ARGS` | 未設定 | ComfyUI に渡す追加引数。例: `--lowvram`、`--fast-disk`、`--cache-none`、`--reserve-vram 2`。空白区切りで複数指定できます。 |

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

## メモリ不足でコンテナが落ちる場合

大きなモデルを続けて読み込むと、traceback を出さずにコンテナごと再起動することがあります。
**VRAM ではなくホスト RAM の見え方が原因です。**

ComfyUI と `comfy-aimdo` はホストの RAM を見ており、コンテナに与えられた上限を見ていません。
ホストが大きくコンテナの取り分が小さいマシンでは、ホスト RAM を基準に pinned memory を確保するため、
2本目のモデルを積んだ時点でコンテナの上限を超えて OOM kill されます。

`v3.1.0` からは `start.sh` が cgroup を読んで自動判定し、必要なら `--disable-pinned-memory` を付けます。

`v3.2.0` では、cgroup が「上限なし」を巨大な数値で返す環境で桁の狂った値を表示していたのを直しました。
判定結果は元から正しく、表示だけの問題です。上限が無い場合はこう出ます。

```text
[start] memory: no container limit / host 1511GB
```
起動ログにこう出ます。

```text
[start] memory: container limit 32GB / host 252GB
[start] container limit is well below host RAM, disabling pinned memory
```

自動判定を上書きしたい場合は `COMFY_PINNED_MEMORY` を `on` / `off` にしてください。
それでも落ちる場合は `COMFY_EXTRA_ARGS` に `--lowvram` や `--cache-none` を渡して様子を見てください。

## ComfyUI access

start log に `To see the GUI go to: http://0.0.0.0:8188` が出たら、ComfyUI は Pod 内で起動済みです。
RunPod console の Pod 詳細から `Connect to HTTP Service [Port 8188]` を開くか、次の形式の URL にアクセスします。

```text
https://<pod-id>-8188.proxy.runpod.net
```

Pod が `Running` でも HTTP service の公開には数分かかる場合があります。`Not Ready` が出る場合は、Pod の exposed HTTP ports に `8188/http` が入っていることと、ComfyUI の起動ログが出ていることを確認してから再読み込みしてください。

`v1.x` では RunPod proxy 経由のアクセスが 403 になる事例があり、`--enable-cors-header "*"` を付けて起動していました。
このオプションは公開範囲を広げるため `v2.0.0` で削除しています。proxy 経由で 403 になる場合は、SSH port forward で
`localhost:8188` に繋いでください。

```bash
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <秘密鍵>
```

`8188/http` の RunPod proxy URL は認証なしで公開されます。URL を知っていれば誰でも ComfyUI を操作でき、
`input/` と `output/` も見えます。扱う内容によっては SSH port forward を既定にしてください。

## Paths

| Path | Purpose |
|---|---|
| `/opt/ComfyUI` | ComfyUI checkout |
| `/workspace/models/wan22/comfy-repackaged` | ダウンロードしたモデルファイル |
| `/opt/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | start log |

`WAN_VARIANT=t2v_a14b` と `WAN_VARIANT=i2v_a14b` では、ComfyUI の高速化 workflow で使われる LightX2V 4-step LoRA も `/opt/ComfyUI/models/loras` に配置します。
