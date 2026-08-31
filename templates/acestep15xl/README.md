# ACE-Step 1.5 XL RunPod template

ACE-Step 1.5 XL 用の ComfyUI 環境を RunPod 起動時に自動セットアップします。

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
| `ComfyUI-ACE-Step1.5XL-cuda12.8-v3-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-acestep15xl:v3.2.0-cuda12.8` | 推奨。まずはこちら。 |
| `ComfyUI-ACE-Step1.5XL-cuda130-v3-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-acestep15xl:v3.2.0-cuda13.0` | 最新 CUDA を使いたい場合。host が CUDA 13.0 対応である必要があります。 |

### v3.2.0 でイメージを軽くしました

`cuda12.8` image のベースを devel から runtime に差し替えました。`devel` は nvcc やヘッダを含みますが、
ComfyUI は実行時にどれも使いません。

| | v3.1.0 | v3.2.0 |
|---|---|---|
| イメージ（圧縮後） | 10.10 GB | **4.81 GB** |
| PyTorch | `2.8.0.dev20250319+cu128` | `2.8.0+cu128` |

**環境に依存しない事実はイメージサイズが 52% 減ったことだけです。** 起動時間の短縮は
その結果として期待できますが、倍率は環境依存なので固定値として受け取らないでください。

`v3.2.0` の Pod 起動を1本測った内訳です（RTX 4090 / `all` + `all`）。

| 段階 | 所要 |
|---|---|
| イメージ pull + 展開 | 4分01秒 |
| モデル DL | 40.5GB を約1分50秒（約 547 MB/s） |
| ComfyUI 起動 | 6秒 |
| 合計 | 5分56秒 |

**モデルのダウンロードではなくイメージの取得が律速です**（全体の 68%）。そこを削ったのが
今回の変更です。ただし pull 速度はデータセンターで数倍振れ、同日・同一イメージでも
wan22 の Pod では 4分27秒（実効 約25 MB/s）でした。モデル DL 側も Hugging Face の
時間帯で二桁変わります。

サイズと時間は比例しません。同日の観測ではサイズ 52% 減に対して pull は 30% 減でした。
runtime イメージはレイヤ枚数が少なく（11枚 vs 34枚）、ダウンロードは並列化できても
巨大なレイヤの展開は直列になるためです。見積もりを立てるときはここを勘定に入れてください。

CUDA 12.4 image は `v3.0.0` で廃止しました（`v3.2.0` でも同じ）。ComfyUI `v0.32.0` が要求する `comfy-kitchen` が
PyTorch 2.5 以上を前提としており、CUDA 12.4 ベースイメージの PyTorch 2.4.0 では ComfyUI が起動しません。

**GPU 世代による image の出し分けは不要になりました。** RTX 3090 / 4090 / 5090 いずれも CUDA 13.0 image を使えます。

## Deploy Links

| Template | RunPod deploy link |
|---|---|
| `ComfyUI-ACE-Step1.5XL-cuda12.8-v3-FreeCraftLog`（**推奨**） | <https://console.runpod.io/deploy?template=02uvewl5gg&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-cuda130-v3-FreeCraftLog` | <https://console.runpod.io/deploy?template=lebbkuupd8&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-FreeCraftLog`（v1.0.0 / CUDA 12.4） | <https://console.runpod.io/deploy?template=whhlf8rbip&ref=zc2sdxqc> |
| `ComfyUI-ACE-Step1.5XL-cuda12.8-FreeCraftLog`（v1.0.0 / CUDA 12.8） | <https://console.runpod.io/deploy?template=0obn96ivv6&ref=zc2sdxqc> |

| Item | Value |
|---|---|
| Container image | `ghcr.io/ryoheitanaka/runpod-templates-acestep15xl:v3.2.0-cuda12.8` |
| Container Disk | `100 GB` |
| Volume | `0 GB` または未指定 |
| Ports | `8188/http`, `22/tcp` |
| Recommended GPU | RTX 3090 以上。20GB+ VRAM 推奨。 |
| Start Command | 下記参照 |

## Start Command

既定では container image 内の `/opt/runpod/start.sh` を実行します。
template JSON の既定値は `v3.2.0` です。開発中の最新版を試す場合だけ `latest-cuda12.8` に変更してください。

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
| `HF_XET_HIGH_PERFORMANCE` | `1` | Hugging Face download の高速化（Xet）を有効化します。`HF_HUB_ENABLE_HF_TRANSFER` は deprecated で効きません。 |
| `WORKSPACE` | `/workspace` | ComfyUI、モデル、cache、ログの基準ディレクトリ。 |
| `HF_HOME` | `/workspace/.cache/huggingface` | Hugging Face cache ディレクトリ。 |
| `HF_TOKEN` | `your-huggingface-token` | 推奨。Hugging Face の実 token に置き換えると rate limit を避けやすく、モデル download が速くなる場合があります。 |
| `COMFY_PINNED_MEMORY` | `auto` | pinned memory の扱い。`auto` はコンテナのメモリ上限を cgroup から読み、ホスト RAM より明らかに小さければ自動で無効化します。`on` で常に有効、`off` で常に無効。 |
| `COMFY_EXTRA_ARGS` | 未設定 | ComfyUI に渡す追加引数。例: `--lowvram`、`--fast-disk`、`--cache-none`、`--reserve-vram 2`。空白区切りで複数指定できます。 |

`HF_TOKEN=your-huggingface-token` はプレースホルダーとして扱い、setup script 内では token 未設定として無視します。
`ACESTEP_XL_VARIANT=all` は XL base / SFT / turbo の 3 model をすべて配置します。
`ACESTEP_LM=all` は qwen 0.6B / 1.7B / 4B text encoder をすべて配置します。
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

## Paths

| Path | Purpose |
|---|---|
| `/opt/ComfyUI` | ComfyUI checkout |
| `/workspace/models/acestep15xl/comfy-files` | ダウンロードしたモデルファイル |
| `/opt/ComfyUI/models/*` | ダウンロード済みモデルへの symlink |
| `/workspace/logs` | start log |
