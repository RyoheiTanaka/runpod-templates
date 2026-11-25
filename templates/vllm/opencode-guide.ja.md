# RunPodのvLLMをOpenCodeから使う手順

WindowsのPowerShellとローカルのOpenCodeから、RunPod上のQwen3-8Bへ接続する。
接続経路は **OpenCode → ローカル8000番 → SSHトンネル → Pod内127.0.0.1:8000のvLLM**。
AIが作成するファイルは、OpenCodeを起動したローカルの作業フォルダへ保存される。
Git Bashで実行する場合のコマンドは、末尾の「付録 Git Bashで実行する場合」にまとめた。

## 確認済みの範囲

2026-11-20に、配布設定のイメージをA40・ホストCUDA 13.2で起動し、SSHの自動設定、
公開鍵認証、トンネル、API認証、チャット、`tool_choice:auto` のツール呼び出し応答を確認した。
実機検証時は50 GBのVolume Diskを使用した。配布設定の既定0 GB構成と、
このイメージでのOpenCodeによるファイル作成は、まだ実機確認していない。本手順で確認する。

OpenCodeのCLIは手順書作成時にWindows上の **v2.2.2** で確認した。設定例は
同日時点の公式JSONスキーマに基づく。別バージョンではCLIや設定の差を確認する。

## 1 前提を確認する

- RunPodアカウントと支払い設定。
- RunPodに登録したSSH公開鍵と、対応する手元の秘密鍵。
- OpenCodeとSSHクライアントが入ったWindows環境。
- このリポジトリの `templates/vllm/` 一式。

PowerShellで確認する。

```powershell
opencode --version
ssh -V
```

OpenCodeは手元で実行するため、手元のGPUやDockerはこの接続手順には必要ない。
秘密鍵・APIキーはリポジトリやスクリーンショットへ含めない。

## 2 Podを起動する

登録済みのプライベートテンプレートを使うか、RunPodで `template.json` の内容をもとに
Podテンプレートを用意する。JSONはこのリポジトリの配布設定例で、REST v2の作成リクエストへ
そのまま渡す形式ではない。v2では `disk` と `mounts.persistent` などに対応する。

RunPodのデプロイ画面で次を確認する。

| 項目 | 最初に試す設定 |
| --- | --- |
| イメージ | 同ディレクトリの `template.json` にあるdigest固定イメージ |
| GPU | A40を1台 |
| ホストCUDA | 13.2。今回実機確認した構成 |
| Container Disk | 30 GBを目安に、モデル容量に合わせて変更 |
| Volume Disk | **短期検証では0 GB**。モデルを停止後も残したい場合だけ明示的に追加 |
| 公開ポート | `22/tcp` |
| Container Start Command | 空欄。イメージの起動処理を使用 |
| SSH | 有効。自分の公開鍵が登録されていること |
| Jupyter | 無効 |

**既存テンプレートの容量は必ずデプロイ画面で確認する。** この検証用に過去登録した
プライベートテンプレートはVolume Diskが50 GBのままの場合がある。リポジトリの既定値を
0 GBへ直しても、登録済みのRunPodテンプレートには自動反映されない。
0 GBへ変更できない、または最終確認に50 GBが残る場合はデプロイせず、同じイメージと設定で
テンプレートを使わないPodを作成してVolume Diskを0 GBにする。

環境変数は次のとおり。

| 変数 | 値 |
| --- | --- |
| `MODEL_ID` | `Qwen/Qwen3-8B` |
| `MAX_MODEL_LEN` | `32768` |
| `GPU_MEMORY_UTILIZATION` | `0.95` |
| `ENABLE_AUTO_TOOL_CHOICE` | `true` |
| `TOOL_CALL_PARSER` | `hermes` |
| `ENFORCE_EAGER` | `true` |
| `VLLM_API_KEY` | 自分で用意した秘密の値。プレースホルダーから必ず変更 |
| `HF_TOKEN` | 必要なモデルの場合のみ設定 |
| `SSH_PUBLIC_KEY` | 通常は省略し登録済み公開鍵を使用。明示指定するときも公開鍵のみ |

起動前に表示される料金とディスク容量を確認してデプロイする。
SSHサーバーのインストール・鍵配置・起動はコンテナ側が行うため、Web Terminalでの手作業は不要。
初回はイメージ取得とモデル取得があり、すぐにはAPIを使えない。今回のイメージ取得・展開は
約7分だったが、ホストや回線によって変わる。

Volume Diskが0 GBなら、キャッシュ先 `/workspace/.cache/huggingface` もコンテナ内となる。
停止・再起動後はモデル再取得を見込む。Volume Diskを使う場合は同じパスが永続化され、
停止中も保管料金がかかる。どちらもPodを削除するとPod内のデータは消える。

## 3 SSHトンネルを開く

PodのConnect画面で **SSH over exposed TCP** の接続先IP・ポートを確認する。
`ssh.runpod.io` 経由の対話シェル用コマンドとは区別する。削除済みテストPodの接続先は再利用しない。

**ターミナルA**で実値に置き換えて実行する。

```powershell
$podHost = 'PODのIPアドレス'
$sshPort = 22000 # Connect画面に表示されたポートへ変更
$keyPath = Join-Path $env:USERPROFILE '.ssh\自分の秘密鍵ファイル名'

ssh -i "$keyPath" -p $sshPort `
  -o ExitOnForwardFailure=yes `
  -o ServerAliveInterval=30 `
  -N -L 127.0.0.1:8000:localhost:8000 "root@$podHost"
```

初回のホスト鍵は表示されたfingerprintを確認して登録する。既知の接続先で鍵が変わった場合は
Pod再作成などの理由を確認し、ホスト鍵のチェックを無効化して回避しない。

接続後に何も表示されなくても、`-N` を使っているため正常。**このターミナルは開いたままにする。**
今回のSSH転送先はPod内8000番に限定されている。

ローカル8000番が使用中なら、`-L 127.0.0.1:18000:localhost:8000` に変更し、
以下のAPI確認URLとOpenCodeの `baseURL` も18000番へ合わせる。Pod側の8000番は変更しない。

## 4 APIの準備と認証を確認する

**ターミナルB**を開き、以下を実行する。

```powershell
Invoke-WebRequest -Uri 'http://127.0.0.1:8000/health' -TimeoutSec 5 |
  Select-Object StatusCode
```

200になればAPIの準備完了。SSHが先に使える状態でも、モデル読み込み中は接続拒否になることがある。
Podのログを見ながら待つ。SSHトンネル自体が終了していないことも確認する。

次に、**Podに設定したものと同じAPIキー**をターミナルBへ読み込む。入力値は画面へ表示しない。

```powershell
$secureKey = Read-Host 'Podに設定したVLLM_API_KEY' -AsSecureString
$env:VLLM_API_KEY = [System.Net.NetworkCredential]::new('', $secureKey).Password
Remove-Variable secureKey

$headers = @{ Authorization = "Bearer $env:VLLM_API_KEY" }
$models = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/v1/models' -Headers $headers
$models.data | Select-Object id, max_model_len
```

`Qwen/Qwen3-8B` とサーバーの上限を確認する。401なら、Podと手元のキーが一致しているか確認する。
`/health` の200だけでは認証が通ったとは判断しない。

チャットも単独で確認したい場合：

```powershell
$payload = @{
  model = 'Qwen/Qwen3-8B'
  messages = @(@{ role = 'user'; content = 'Reply with the word OK.' })
  max_tokens = 128
  chat_template_kwargs = @{ enable_thinking = $false }
} | ConvertTo-Json -Depth 6

$reply = Invoke-RestMethod -Method Post `
  -Uri 'http://127.0.0.1:8000/v1/chat/completions' `
  -Headers $headers -ContentType 'application/json' -Body $payload
$reply.choices[0].message.content
```

## 5 ローカルの作業フォルダとOpenCode設定を用意する

ターミナルBで、このリポジトリのルートにいる状態から実行する。
元の実験ファイルを上書きしないよう、新しい作業フォルダを使う。

```powershell
$repoRoot = (Get-Location).Path
$workDir = Join-Path $env:USERPROFILE 'Projects\runpod-opencode-test'
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$configPath = Join-Path $workDir 'opencode.json'
if (Test-Path -LiteralPath $configPath) {
  throw 'opencode.jsonが既にあります。上書きせず別フォルダを選んでください。'
}
Copy-Item -LiteralPath (Join-Path $repoRoot 'templates\vllm\examples\opencode.json') `
  -Destination $configPath
Set-Location -LiteralPath $workDir
```

設定例は [examples/opencode.json](examples/opencode.json)。要点は以下。

- 既定モデルは `runpod/qwen3`、サーバーへ送るモデルIDは `Qwen/Qwen3-8B`。
- 接続先は `http://127.0.0.1:8000/v1`。
- APIキーは `{env:VLLM_API_KEY}` でターミナルBの環境変数から取得し、ファイルへ直書きしない。
- `capabilities.tools:true` と上限 `context:32768`、`output:4096` を明示。
- 最初の短い検証では `compaction.auto:false`。長い作業の履歴圧縮を検証した設定ではない。
- `body.chat_template_kwargs.enable_thinking:false` は今回のAPI検査と同じ指定。

OpenCodeによるvLLMの自動検出だけでは、ツール対応を十分に伝えられないため、
ここでは明示的なカスタムプロバイダー設定を使う。

## 6 OpenCodeを起動してファイル作成を試す

APIキーを設定した**同じターミナルB**で実行する。

```powershell
opencode --standalone
```

独立したサーバーを使い、このターミナルの環境変数を引き継がせる。
別のPowerShellで設定した環境変数は引き継がれない。

`/models` で **RunPod vLLM / Qwen3 8B（runpod/qwen3）** が選択されていることを確認してから送信する。
別プロバイダーのモデルが選ばれている場合は、そのまま送信しない。
この手順は環境変数で認証するため、通常は `/connect` でAPIキーを再登録する必要はない。

まず「こんにちは」と送り、応答があることを確認する。次に、前回の実験と同じ依頼を送る。

```text
このディレクトリに、HTML・CSS・JavaScriptを使ったシンプルなToDoアプリを作成してください。タスクの追加、完了、削除ができるようにしてください。
```

コードを表示するだけで保存しなかった場合は、前回と同じ追加依頼を送る。

```text
あなたがファイルを作成して保存してくれますか？
```

ファイル作成などの権限確認が出たら、対象がこの作業フォルダであることを確認して許可する。
モデルの作成報告だけで判断せず、エクスプローラーまたは別ターミナルで実在を確認する。

```powershell
Set-Location -LiteralPath (Join-Path $env:USERPROFILE 'Projects\runpod-opencode-test')
Get-Item -LiteralPath '.\todo-app.html'
Start-Process -FilePath '.\todo-app.html'
```

ブラウザでタスクの追加、完了のオン・オフ、削除を試す。別のファイル名で作成された場合はその実名を使う。
操作結果、追加依頼の回数、エラー、開始・終了時刻を記録する。成功結果は実際に確認した範囲だけを書く。

## 7 終了する

1. OpenCodeを終了する。
2. ターミナルAでCtrl+Cを押し、SSHトンネルを閉じる。
3. RunPodで今回のPodを停止する。短期検証で不要になったPodは、必要なデータを回収後に削除する。
4. Volume Diskを追加した場合、停止中も保管料金が残ることを確認する。

SSHトンネルを閉じただけではPodは止まらない。ローカルのToDoファイルはPod削除後も残る。
ターミナルBの一時的なキーを消す場合は以下を実行する。

```powershell
Remove-Item Env:VLLM_API_KEY
Remove-Variable headers, models, reply, payload -ErrorAction SilentlyContinue
```

## 付録 Git Bashで実行する場合

本文の§1・§3〜§7のコマンドを、Git for WindowsのGit Bashで実行する形に置き換えたもの。
手順の順番と注意点は本文と同じ。ここではコマンドだけを示す。
Git Bash同梱の `ssh`・`curl` を使い、`jq` やPythonは使わない。

OpenCodeの画面を崩さないため、Git BashはWindows Terminalのタブで開く。
mintty単体では、貼り付けがShift+Insertになるなど操作が変わる。

2026-11-25に、Git Bash（OpenSSH 10.2）で各コマンドが存在すること、JSONの取り出しを見本のJSONで、
トンネルなしで `/health` が `000` になることまでを確認した。Podへ接続した状態での実行は未確認。

| 本文（PowerShell） | Git Bash |
| --- | --- |
| `Read-Host -AsSecureString`（`*` が表示される） | `read -rs`（何も表示されない） |
| `Invoke-WebRequest` / `Invoke-RestMethod` | `curl` |
| `$env:USERPROFILE\Projects\runpod-opencode-test` | `~/Projects/runpod-opencode-test` |
| `Get-Item` / `Start-Process` | `ls -l` / `start` |

### §1 前提

```bash
opencode --version
ssh -V
```

### §3 SSHトンネル（ターミナルA）

```bash
POD_HOST='PODのIPアドレス'
SSH_PORT=22000 # Connect画面に表示されたポートへ変更
KEY_PATH=~/.ssh/自分の秘密鍵ファイル名

ssh -i "$KEY_PATH" -p "$SSH_PORT" \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -N -L 127.0.0.1:8000:localhost:8000 "root@$POD_HOST"
```

Git BashのホームはWindowsのユーザーフォルダと同じなので、`~/.ssh` は本文の `$env:USERPROFILE\.ssh` と同じ場所。

### §4 APIの確認（ターミナルB）

```bash
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://127.0.0.1:8000/health
```

`200` で準備完了。`000` は接続拒否で、モデル読み込み中のことが多い。待つ場合は15秒おきに確認できる。

```bash
until [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8000/health)" = 200 ]; do
  echo "$(date +%T)  まだ"; sleep 15
done; echo "$(date +%T)  200"
```

APIキーを読み込む。入力値は画面へ表示されない。`export` してOpenCodeへ引き継がせる。

```bash
read -rsp 'Podに設定したVLLM_API_KEY: ' VLLM_API_KEY; echo
export VLLM_API_KEY

curl -s -H "Authorization: Bearer $VLLM_API_KEY" http://127.0.0.1:8000/v1/models \
  | grep -oE '"(id|max_model_len)": ?("[^"]*"|[0-9]+)'
```

`"id":"Qwen/Qwen3-8B"` と `"max_model_len":32768` が出ればよい。何も出ない場合は、`| grep ...` を外して
応答をそのまま見る。401なら、Podと手元のキーが一致しているか確認する。

チャット：

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H "Authorization: Bearer $VLLM_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-8B","messages":[{"role":"user","content":"Reply with the word OK."}],"max_tokens":128,"chat_template_kwargs":{"enable_thinking":false}}' \
  | grep -oE '"content": ?"[^"]*"'
```

### §5 作業フォルダとOpenCode設定（ターミナルB、リポジトリのルートで）

```bash
REPO_ROOT=$(pwd)
WORK_DIR=~/Projects/runpod-opencode-test
mkdir -p "$WORK_DIR"
if [ -e "$WORK_DIR/opencode.json" ]; then
  echo 'opencode.jsonが既にあります。上書きせず別フォルダを選んでください。'
else
  cp "$REPO_ROOT/templates/vllm/examples/opencode.json" "$WORK_DIR/opencode.json"
  cd "$WORK_DIR"
fi
```

ローカル8000番を18000番へ変えた場合は、`baseURL` も合わせる。

```bash
sed -i 's/127.0.0.1:8000/127.0.0.1:18000/' opencode.json
```

### §6 OpenCodeの起動とファイルの確認

APIキーを `export` した**同じターミナルB**で実行する。

```bash
opencode --standalone
```

依頼文と追加依頼は本文と同じ。ファイルの実在は別のGit Bashで確認する。

```bash
cd ~/Projects/runpod-opencode-test && ls -l
start todo-app.html
```

### §7 終了

OpenCodeを終了し、ターミナルAでCtrl+C、RunPodでPodを停止・削除する（本文と同じ）。
ターミナルBの一時的なキーを消す場合：

```bash
unset VLLM_API_KEY
```

## 困ったときの確認先

| 症状 | 確認すること |
| --- | --- |
| SSHの接続拒否・タイムアウト | コンテナ起動完了、22/tcp、Connect画面の現在のIPとポート、直接TCP接続か |
| `Permission denied (publickey)` | 登録公開鍵と `-i` の秘密鍵が対になっているか |
| ローカル8000番を使えない | 別プロセスとの競合。18000番へ変更しURLと設定をそろえる |
| SSH接続後もAPIが接続拒否 | モデル読み込み待ちかvLLM起動失敗か、Podログで区別する |
| APIが401 | PodとターミナルBのAPIキーが一致しているか |
| OpenCodeにモデルがない | 作業フォルダの設定ファイル、環境変数、`/models` の選択を確認 |
| auto tool choiceのエラー | `ENABLE_AUTO_TOOL_CHOICE=true` とモデルに合うパーサーを確認 |
| トークン上限エラー | サーバー上限とOpenCodeのcontext/outputをそろえる |
| 保存されたファイルがない | 明示的な保存依頼、権限確認、実際の出力先を確認 |

別モデルを使う場合は `MODEL_ID`、`modelID`、上限、ツール対応、パーサー、GPUメモリを合わせる。
Qwen3用の設定をすべてのモデルへそのまま流用しない。

## 参照

- [OpenCode カスタムプロバイダー](https://opencode.ai/docs/providers/)
- [OpenCode ローカルモデルとツール対応](https://opencode.ai/docs/models/)
- [OpenCode 設定と環境変数](https://opencode.ai/docs/config/)
- [RunPod SSH](https://docs.runpod.io/pods/configuration/use-ssh)
- [RunPod ストレージ](https://docs.runpod.io/pods/storage/types)
