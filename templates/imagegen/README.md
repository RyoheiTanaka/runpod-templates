# ImageGen RunPod template

静止画生成用の ComfyUI 環境を RunPod で起動します。
SDXL / Illustrious / Pony などの checkpoint を、**URL と SHA256 を環境変数で指定して**起動時に取得します。
特定のモデルに縛られないので、Civitai や Hugging Face のファイルをそのまま差し替えて使えます。

| Template | Container image |
|---|---|
| `ComfyUI-ImageGen-cuda12.8-FreeCraftLog` | `ghcr.io/ryoheitanaka/runpod-templates-imagegen:v3.5.0-cuda12.8` |

`v3.5.0` で追加しました。開発中の最新版を試す場合だけ `latest-cuda12.8` を使ってください。

## できること

- 起動時に GPU を初期化できるかを確かめ、できなければ ComfyUI を起動せずに止まる
- モデルを複数、URL / SHA256 / 置き場所の組で指定する。SHA256 が合わなければ ComfyUI を起動しない
- 認証トークン（Civitai / Hugging Face）は環境変数で受け、プロセス一覧に出さない
- 取得が固まったら速度下限で打ち切り、続きから取り直す
- カスタムノード **SaveImageExtended** と **UltimateSDUpscale** を同梱。その他は起動時に追加できる

## RunPod settings

| Item | Value |
|---|---|
| Cloud | **Secure Cloud** |
| CUDA Versions | **12.8 / 13.0**（template の `allowedCudaVersions` で設定済み） |
| GPU | RTX 4090 など VRAM 16GB 以上（SDXL 系 1024×1024 の場合） |
| Container Disk | `50 GB` |
| Volume | `0 GB` または未指定 |
| Ports | `8188/http`, `22/tcp` |
| Start Command | `/opt/runpod/start.sh` |

### Secure Cloud を勧める理由

**Community Cloud の RTX 4090 で、2台続けて GPU を初期化できない Pod に当たったためです。**
どちらもホストの CUDA が 13.0（ドライバ 580.178.04）でした。`nvidia-smi` は GPU を表示するのに、
ComfyUI の起動時に `RuntimeError: CUDA unknown error` で落ち、コンテナの再起動を繰り返しました。
PyTorch を通さずに `cuInit` を直接呼んでも `CUDA_ERROR_UNKNOWN` が返ったので、
イメージ側の PyTorch ではなく、ホストのドライバの段階で失敗しています。

Secure Cloud では、CUDA 12.8 と 13.0 のどちらのホストでも起動から生成まで通りました。

| Cloud | GPU | ホストの CUDA / ドライバ | 結果 |
|---|---|---|---|
| Community | RTX 4090 ×2台 | 13.0 / 580.178.04 | GPU を初期化できない |
| Secure | A100 SXM 80GB | 12.8 / 570.172.08 | 生成・アップスケールまで成功 |
| Secure | RTX 4090 | 13.0 / 580.159.04 | 生成・アップスケールまで成功 |

**原因がドライバのバージョンなのか、Community のホスト個別の問題なのかは特定できていません。**
観測したのは合わせて4台です。CUDA 13.0 そのものが原因ではないことは分かったので、
CUDA は 12.8 と 13.0 を許可し、Cloud は Secure を勧める形にしています。

許可する CUDA を 12.8 と 13.0 に限っているのは、確かめたのがこの2つだけだからです。
12.8 だけに絞ると在庫がかなり減ります（2026-10-13 には Secure の RTX 4090 で 12.8 の在庫が 0 でした）。

`start.sh` は最初に GPU を初期化してみるので、初期化できない host に当たった場合は数 GB のモデルを
取得する前に止まり、ログにこう出ます。

```text
[start] GPU check failed (exit 1). Output:
...
[start] error: CUDA could not be initialized on this host
[start] halted: ComfyUI was NOT started. The container stays up so you can inspect it.
```

**再起動では直りません。Pod を削除して、別の host で作り直してください。**
止まっている間も GPU の課金は続きます。

### 起動にかかる時間

Pod 作成から ComfyUI の起動までの実測です。イメージの取得時間は host のキャッシュで、
モデルの取得時間は Hugging Face の混み具合で大きく変わるので、目安にとどめてください。

| GPU | イメージ取得 | SDXL base（6.6GB）取得 + 照合 | 合計 |
|---|---|---|---|
| A100 SXM 80GB | 約2分 | 42秒 + 25秒 | 3分25秒 |
| RTX 4090 | 約3分20秒 | 143秒 + 32秒 | 約6分15秒 |

RTX 4090 で SDXL base 1024×1024・25 steps を1枚生成し、UltimateSDUpscale で 1536×1536 にするまで、
モデル読み込み済みで約 23 秒でした（初回は約 31 秒）。

### Pod 作成時の指定方法

template の `allowedCudaVersions` は Pod 作成時に引き継がれます。Cloud の種別は template に
保存できないので、Pod を作るたびに指定します。

**Console**: Deploy 画面で Secure Cloud を選び、template を選択します。CUDA の絞り込みは
template から入りますが、**Additional filters → CUDA Versions** で 12.8 と 13.0 だけになっていることを
確認してください。自分で template を作る場合は、この設定を template 側に入れてください。

**REST API**（`POST /v2/pods`）:

```json
{
  "name": "imagegen",
  "templateId": "<template-id>",
  "cloud": "SECURE",
  "gpu": { "id": "NVIDIA GeForce RTX 4090", "count": 1 }
}
```

`gpu.allowedCudaVersions` を body に書くと、template の指定は**丸ごと置き換わります**（足し合わせではありません）。

**runpodctl**: `--cloud-type SECURE` を付けます。`runpodctl` には CUDA を集合で指定する
オプションが無く、`--min-cuda-version` は下限しか決められません。template 経由で作成してください。

### 絞り込みを広げる

在庫が無いときは、自分の責任で範囲を広げられます。

- REST API で `gpu.allowedCudaVersions` を `["12.8", "12.9", "13.0", "13.2"]` などにする
- Console の **Additional filters → CUDA Versions** で追加する
- Community Cloud を使う

広げた結果 GPU の初期化に失敗する host に当たっても、`start.sh` がモデル取得の前に止まります。
ログを見て、Pod を作り直してください。

## Start Command

```bash
/opt/runpod/start.sh
```

起動の順序:

1. `PUBLIC_KEY` から `authorized_keys` を作り、sshd を起動する
2. PyTorch で GPU を初期化してみる。失敗したら止まる
3. 環境変数で指定したモデルを取得し、SHA256 で照合する。1つでも失敗したら止まる
4. `CUSTOM_NODES` で指定したカスタムノードを入れる（失敗しても続ける）
5. ComfyUI を `--listen 0.0.0.0 --port 8188` で起動する

**「止まる」は終了ではありません。** ComfyUI を起動せず、`sleep` でコンテナを生かしたままにします。
終了するとコンテナが再起動して同じ失敗を繰り返し、最初のエラーがログから流れてしまうためです。
sshd とログは残るので、SSH で入って原因を調べられます。

## モデルの指定

1 ファイルを 3 つの環境変数で指定します。

| Name | 内容 |
|---|---|
| `MODEL_URL` | 取得元。`https://` のみ |
| `MODEL_SHA256` | 照合する SHA256（64 桁の 16 進）。空なら照合せず、警告と実際の値をログに出す |
| `MODEL_DEST` | ComfyUI の `models/` からの相対パス。例: `checkpoints/model.safetensors`。ディレクトリを書かなければ `checkpoints/` に置く |

2 本目以降は番号を付けます。番号は 1〜20 で、飛んでいても構いません。

```text
MODEL_URL       = https://civitai.com/api/download/models/<version-id>
MODEL_SHA256    = <sha256>
MODEL_DEST      = checkpoints/my-checkpoint.safetensors

MODEL_1_URL     = https://civitai.com/api/download/models/<version-id>
MODEL_1_SHA256  = <sha256>
MODEL_1_DEST    = loras/my-lora.safetensors

MODEL_2_URL     = https://huggingface.co/<repo>/resolve/main/<file>
MODEL_2_SHA256  = <sha256>
MODEL_2_DEST    = vae/my-vae.safetensors
```

既定値は SDXL base 1.0（`stabilityai/stable-diffusion-xl-base-1.0`、約 6.9 GB）です。
自分のモデルを使う場合は `MODEL_URL` / `MODEL_SHA256` / `MODEL_DEST` を書き換えてください。
`MODEL_URL` を空にすれば、モデルを取得せずに起動します。

SHA256 は、Civitai ならモデルページのファイル情報に、Hugging Face ならファイルページに載っています。

### 置き場所と2回目以降

実体は `MODEL_ROOT`（既定 `/workspace/models/imagegen`）に置き、ComfyUI の `models/` には symlink で見せます。

照合が済んだファイルの横に `<ファイル名>.sha256` を残すので、Pod を再起動しても数 GB を読み直さずに
取得を飛ばします。`MODEL_SHA256` を変えた場合だけ照合し直し、合わなければ取り直します。

| ファイル | 意味 |
|---|---|
| `*.part` | 取得途中。次回はここから続きを取る |
| `*.mismatch` | SHA256 が合わなかったファイル。調べ終わったら消してよい |
| `*.sha256` | 照合済みの値 |

### 認証トークン

URL のホストで、送るトークンが決まります。他のホストへは送りません。

| ホスト | 環境変数 |
|---|---|
| `civitai.com` | `CIVITAI_TOKEN` |
| `huggingface.co` | `HF_TOKEN` |

**値は RunPod の Secret に入れ、環境変数からは参照だけにしてください。**
環境変数の値に `{{ RUNPOD_SECRET_<secret 名> }}` と書くと、Pod 起動時に Secret の値が入ります。

```text
CIVITAI_TOKEN = {{ RUNPOD_SECRET_civitai_token }}
```

`your-` で始まる値（template の既定値）と、解決されずに残った `{{ ... }}` は未設定として扱います。

トークンはコマンドラインに出しません。`curl -H "Authorization: Bearer ..."` の形で渡すと、
展開後の値が `ps` で誰にでも読めてしまうためです。`start.sh` はトークンをシェル組み込みの `printf` で
権限 600 の一時ファイルに書き、`curl --config` で渡し、終わったら消します。

URL のクエリに `token=...` を付ける方法（Civitai が案内している形式）も同じ理由で避けてください。
付いていた場合は警告を出します。

### 取得が固まったとき

`curl` には速度下限を付けています。1 MiB/s を 60 秒下回ったら、その回を打ち切って続きから取り直します。
5 回失敗したら諦めて止まります。値は環境変数で変えられます（下の表）。

それでも手で止めたい場合は、**`curl` だけを止めてください。**

```bash
pkill -x curl
```

取得スクリプトが続きから取り直します。`pkill -f <URL>` のように広く当てるのは避けてください。
このテンプレートでは URL を起動スクリプトの引数に載せていないので、本体を巻き込むことはありません。
ただ、取得スクリプトごと止めると、そのモデルは失敗扱いになり ComfyUI は起動しません。

## カスタムノード

### 同梱しているもの

| Node pack | 固定している commit | 主なノード |
|---|---|---|
| [save-image-extended-comfyui](https://github.com/audioscavenger/save-image-extended-comfyui) | `d49387f`（2.88） | `SaveImageExtended` |
| [ComfyUI_UltimateSDUpscale](https://github.com/ssitu/ComfyUI_UltimateSDUpscale) | `a5547db` | `UltimateSDUpscale` |

どちらも commit SHA で固定しています。依存は、ベースに入っている全パッケージの版を
constraints にして入れており、ComfyUI 側のパッケージは1つも動かしていません。

同梱するかどうかは、追加量と依存の性質で決めました（ComfyUI `v0.32.0` の依存に対する差分）。

| Node pack | 追加の pip 依存（wheel） | 判断 |
|---|---|---|
| save-image-extended | 約 34 MB（imagecodecs / avif / jxl / piexif） | 同梱 |
| UltimateSDUpscale | なし | 同梱 |
| Impact Pack + Subpack | 約 224 MB。opencv 5.0 が通常版と headless 版の二重で入り、sam2 を git から入れる | 同梱しない |
| IPAdapter_plus | なし | 同梱しない（上流の更新が止まっている） |

### 起動時に追加する

`CUSTOM_NODES` に、https の git URL を空白区切りで並べます。`@` の後ろに tag / branch / commit SHA を付けられます。

```text
CUSTOM_NODES = https://github.com/<owner>/<repo>@<commit-sha> https://github.com/<owner>/<other>
```

- **commit SHA を付けることを勧めます。** 付けないと取得した日の HEAD が入り、再現しません
- 依存は `requirements.txt` から入れます。PyTorch の版は constraints で固定しているので、
  torch を入れ替えようとするノードは入りません
- 失敗しても、そのノードが読めないだけで ComfyUI は起動します
- イメージではなくコンテナに入るので、Pod を作り直すたびに入れ直します（起動が遅くなります）

## Environment variables

| Name | Default | Description |
|---|---|---|
| `MODEL_URL` / `MODEL_SHA256` / `MODEL_DEST` | SDXL base 1.0 | 取得するモデル。上の「モデルの指定」を参照 |
| `MODEL_<n>_URL` / `_SHA256` / `_DEST` | 未設定 | 2 本目以降（n は 1〜20） |
| `CIVITAI_TOKEN` | `your-civitai-token` | Civitai の API キー。RunPod Secret で渡す |
| `HF_TOKEN` | `your-huggingface-token` | Hugging Face の token。gated なモデルに必要 |
| `CUSTOM_NODES` | 未設定 | 起動時に追加するカスタムノード |
| `GPU_CHECK` | `on` | `off` で起動時の GPU 確認を飛ばす |
| `MODEL_DOWNLOAD_ATTEMPTS` | `5` | 1 ファイルあたりの取得の試行回数 |
| `MODEL_SPEED_LIMIT` | `1048576` | 速度下限（bytes/s）。これを下回り続けたら打ち切る |
| `MODEL_SPEED_TIME` | `60` | 速度下限を下回ってから打ち切るまでの秒数 |
| `COMFY_PORT` | `8188` | ComfyUI の listen port |
| `WORKSPACE` | `/workspace` | モデル、cache、ログ、出力の基準ディレクトリ |
| `MODEL_ROOT` | `/workspace/models/imagegen` | モデルの実体の置き場所 |
| `OUTPUT_DIR` | `/workspace/outputs` | 生成画像の出力先 |
| `LOG_DIR` | `/workspace/logs` | 起動ログの出力先 |
| `COMFY_PINNED_MEMORY` | `auto` | pinned memory の扱い。wan22 の README を参照 |
| `COMFY_EXTRA_ARGS` | 未設定 | ComfyUI に渡す追加引数。例: `--lowvram` |

## ComfyUI access

ログに `[start] ready` が出たら、次の URL で開けます。

```text
https://<pod-id>-8188.proxy.runpod.net
```

この URL は認証なしで公開されます。URL を知っていれば誰でも ComfyUI を操作でき、
`input/` と `output/` も見えます。扱う内容によっては SSH トンネルを使ってください。

```bash
ssh -N -L 8188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <秘密鍵>
```

`<pod-ip>` と `<ssh-port>` は、Pod の Connect 画面の **SSH over exposed TCP** に出ます
（RunPod の SSH プロキシ `ssh.runpod.io` はシェル専用で、ポート転送ができません）。

## MCP クライアントからつなぐ

ComfyUI を操作する MCP サーバ（comfy-cli 経由のものなど）から、この Pod の ComfyUI を使う場合の注意です。

### https の URL を受け付けないクライアントがある

RunPod の HTTP プロキシは **https だけ**です。一方、`--host` / `--port` で接続先を組み立てるクライアントは
http しか扱えないことがあり、`https://<pod-id>-8188.proxy.runpod.net` を渡しても接続できません。

その場合は SSH トンネルで、手元の http のポートを Pod の 8188 につなぎます。
手元で ComfyUI を動かしていることも多いので、8188 とぶつからないポートにします。

```bash
ssh -N -L 18188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <秘密鍵>
```

クライアントの接続先を `http://127.0.0.1:18188` にします。設定の場所はクライアントによります。
多くの場合 MCP サーバの環境変数（例 `COMFYUI_URL`）で、MCP サーバの設定を読み直すまで反映されません。

### 一部のツールは接続先の設定を見ない

クライアントによっては、ワークフローの検証のような一部のツールが接続先の設定を見ず、
**常に手元の `127.0.0.1:8188` に問い合わせる**ことがあります。この場合、検証だけ手元の ComfyUI に対して
行われ、Pod とは別のノード構成・モデル一覧で判定されます。

Pod 側で検証させたいときは、手元の ComfyUI を止め、8188 にもトンネルを張ります。

```bash
ssh -N -L 8188:localhost:8188 -L 18188:localhost:8188 root@<pod-ip> -p <ssh-port> -i <秘密鍵>
```

### 作業が終わったら

1. **接続先の設定を元に戻す**（環境変数を消す、または元の値に戻して MCP サーバを読み直す）。
   戻し忘れると、Pod を削除した後もクライアントが存在しない接続先を見続ける
2. **SSH トンネルを閉じる。** バックグラウンドで張った `ssh` はターミナルを閉じても残ることがあり、
   残ると手元のポート（8188 など）を掴み続けて、手元の ComfyUI が起動できなくなる。
   プロセスが残っていないか確認する
3. Pod を削除する

## Paths

| Path | Purpose |
|---|---|
| `/opt/ComfyUI` | ComfyUI checkout |
| `/opt/ComfyUI/custom_nodes` | 同梱・追加したカスタムノード |
| `/workspace/models/imagegen` | 取得したモデルの実体 |
| `/opt/ComfyUI/models/*` | モデルへの symlink |
| `/workspace/outputs` | 生成画像 |
| `/workspace/logs` | 起動ログ（`start_imagegen_*.log`） |
| `/opt/runpod/fetch-model.sh` | モデル取得（1 ファイルずつ） |
| `/opt/runpod/install-custom-node.sh` | カスタムノードの追加 |
