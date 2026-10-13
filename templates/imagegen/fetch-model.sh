#!/usr/bin/env bash
# モデルを1本取得し、SHA256 で照合する。start.sh から1ファイルごとに呼ばれる。
#
#   fetch-model.sh <url> <保存先の絶対パス> [sha256]
#
# 終了コード:
#   0 取得済み（または既に照合済みのファイルがある）
#   1 取得に失敗した（再試行を使い切った / 認証・URL の誤り）
#   2 SHA256 が一致しない
#   3 引数や環境変数の誤り
#
# start.sh と別のスクリプトにしている理由:
#   取得が固まったときに止める手段を、コンテナ本体を巻き込まない形で残すため。
#   start.sh はコンテナの主プロセスで、これが死ぬとコンテナごと再起動する。
#   URL は環境変数から読むので start.sh のコマンドラインには出ず、`pkill -f <URL>` でも
#   start.sh は巻き込まれない。止めるなら `pkill -x curl` が最も狭い。curl だけが終わり、
#   このスクリプトが続きから取り直す（--continue-at -）。
#
# 認証トークンについて:
#   コマンドライン引数に置くと `ps` で誰でも読める。printf（シェル組み込み）で
#   umask 077 の一時ファイルに書き、curl には --config で渡す。トークン自体は
#   環境変数から読み、このスクリプトの引数にも含めない。
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "[fetch] usage: fetch-model.sh <url> <dest> [sha256]" >&2
  exit 3
fi

url="$1"
dest="$2"
expected="${3:-}"
expected="${expected,,}"
name="$(basename "${dest}")"
part="${dest}.part"
marker="${dest}.sha256"

attempts="${MODEL_DOWNLOAD_ATTEMPTS:-5}"
# 1 MiB/s を 60 秒下回ったら、その試行を打ち切って続きから取り直す。
# 速度下限が無いと、接続が張られたまま止まった転送を永遠に待つ。
speed_limit="${MODEL_SPEED_LIMIT:-1048576}"
speed_time="${MODEL_SPEED_TIME:-60}"

if [ -n "${expected}" ] && ! [[ "${expected}" =~ ^[0-9a-f]{64}$ ]]; then
  echo "[fetch] error: ${name}: SHA256 must be 64 hex characters, got '${expected}'"
  exit 3
fi

case "${url}" in
  https://*) ;;
  *)
    echo "[fetch] error: ${name}: only https:// URLs are accepted"
    exit 3
    ;;
esac

case "${url}" in
  *[?\&]token=*)
    echo "[fetch] warning: ${name}: the URL carries token= in its query string."
    echo "[fetch] warning: it shows up in the process list. Set CIVITAI_TOKEN / HF_TOKEN instead."
    ;;
esac

sha256_of() {
  sha256sum "$1" | cut -d' ' -f1
}

# 既にあるファイルの扱い。照合済みの印（.sha256）が期待値と同じなら、
# 数 GB を毎回読み直さずに済ませる。
if [ -f "${dest}" ]; then
  if [ -z "${expected}" ]; then
    echo "[fetch] ${name}: already exists (no SHA256 given, not verified)"
    exit 0
  fi
  if [ -f "${marker}" ] && [ "$(cat "${marker}")" = "${expected}" ]; then
    echo "[fetch] ${name}: already exists and verified"
    exit 0
  fi
  echo "[fetch] ${name}: already exists, verifying SHA256"
  if [ "$(sha256_of "${dest}")" = "${expected}" ]; then
    printf '%s\n' "${expected}" > "${marker}"
    echo "[fetch] ${name}: verified"
    exit 0
  fi
  echo "[fetch] ${name}: existing file does not match the SHA256, downloading again"
  rm -f "${dest}" "${marker}"
fi

mkdir -p "$(dirname "${dest}")"
rm -f "${dest}.mismatch"

# トークンの選択はホストで決める。どの URL にどのトークンを送るかを
# 利用者の設定に委ねると、別のホストへ誤って送る経路ができる。
host="$(printf '%s' "${url}" | sed -E 's#^https://([^/:?]+).*#\1#')"
token=""
token_name=""
case "${host}" in
  civitai.com | *.civitai.com)
    token="${CIVITAI_TOKEN:-}"
    token_name="CIVITAI_TOKEN"
    ;;
  huggingface.co | *.huggingface.co)
    token="${HF_TOKEN:-}"
    token_name="HF_TOKEN"
    ;;
esac

# テンプレートの既定値（your-...）と、解決されなかった RunPod Secret の参照（{{ ... }}）は
# 未設定として扱う。そのまま送ると 401 になり、原因が分かりにくい。
case "${token}" in
  your-* | "{{"*) token="" ;;
esac

cfg=""
watcher=""
# EXIT trap の最後のコマンドの終了コードがスクリプトの終了コードを上書きするので、
# `[ ... ] && ...` で終えず、元の終了コードを明示的に返す。
cleanup() {
  local rc=$?
  if [ -n "${watcher}" ]; then
    kill "${watcher}" 2>/dev/null || true
  fi
  if [ -n "${cfg}" ]; then
    rm -f "${cfg}"
  fi
  exit "${rc}"
}
trap cleanup EXIT

if [ -n "${token}" ]; then
  # curl の config ファイルは二重引用符で囲んだ値を解釈する。
  # 引用符や改行が混ざると別の指定として読まれうるので、ここで弾く。
  if ! [[ "${token}" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; then
    echo "[fetch] error: ${name}: ${token_name} contains unexpected characters"
    exit 3
  fi
  cfg="$(umask 077 && mktemp)"
  printf 'header = "Authorization: Bearer %s"\n' "${token}" > "${cfg}"
  echo "[fetch] ${name}: using ${token_name}"
elif [ -n "${token_name}" ]; then
  echo "[fetch] ${name}: ${token_name} is not set, downloading without auth"
fi

# 進み具合を 30 秒ごとに出す。curl の進捗表示は \r 区切りでログが読めなくなる。
(
  while sleep 30; do
    if size="$(stat -c %s "${part}" 2>/dev/null)"; then
      echo "[fetch] ${name}: $(( size / 1048576 )) MiB"
    fi
  done
) &
watcher=$!

echo "[fetch] ${name}: downloading from ${host}"
started="$(date +%s)"
ok=0
for i in $(seq 1 "${attempts}"); do
  # --fail が無いと、5xx のエラーページが .part の続きに書き足されて壊れる
  curl_args=(
    --fail
    --location
    --silent --show-error
    --connect-timeout 30
    --speed-limit "${speed_limit}"
    --speed-time "${speed_time}"
    --continue-at -
    --output "${part}"
    --write-out '%{http_code}'
  )
  if [ -n "${cfg}" ]; then
    curl_args+=(--config "${cfg}")
  fi

  rc=0
  code="$(curl "${curl_args[@]}" "${url}")" || rc=$?

  case "${code}" in
    200 | 206)
      if [ "${rc}" -eq 0 ]; then
        ok=1
        break
      fi
      ;;
    416)
      # 続きを要求したが、もう残りが無い。.part が完成している。
      echo "[fetch] ${name}: server reports nothing left to download"
      ok=1
      break
      ;;
    401 | 403)
      echo "[fetch] error: ${name}: HTTP ${code}. Check ${token_name:-the token} and that the file is accessible."
      exit 1
      ;;
    404)
      echo "[fetch] error: ${name}: HTTP 404. Check the URL."
      exit 1
      ;;
  esac

  if [ "${rc}" -eq 33 ]; then
    # サーバが Range を受け付けない。続きからは取れないので最初からやり直す。
    echo "[fetch] ${name}: server does not support resume, restarting from zero"
    rm -f "${part}"
  fi

  echo "[fetch] ${name}: attempt ${i}/${attempts} failed (curl exit ${rc}, HTTP ${code:-none})"
  if [ "${i}" -lt "${attempts}" ]; then
    sleep 5
  fi
done

kill "${watcher}" 2>/dev/null || true
wait "${watcher}" 2>/dev/null || true
watcher=""

if [ "${ok}" -ne 1 ]; then
  echo "[fetch] error: ${name}: gave up after ${attempts} attempts. ${part} is kept for the next try."
  exit 1
fi

elapsed=$(( $(date +%s) - started ))
size_mib=$(( $(stat -c %s "${part}") / 1048576 ))
echo "[fetch] ${name}: downloaded ${size_mib} MiB in ${elapsed}s, verifying"

actual="$(sha256_of "${part}")"
if [ -z "${expected}" ]; then
  echo "[fetch] warning: ${name}: no SHA256 given, the file was not verified"
  echo "[fetch] warning: ${name}: its SHA256 is ${actual}. Set it to pin this file."
elif [ "${actual}" != "${expected}" ]; then
  mv -f "${part}" "${dest}.mismatch"
  echo "[fetch] error: ${name}: SHA256 mismatch"
  echo "[fetch] error:   expected ${expected}"
  echo "[fetch] error:   actual   ${actual}"
  echo "[fetch] error: kept as ${dest}.mismatch for inspection"
  exit 2
fi

mv -f "${part}" "${dest}"
printf '%s\n' "${actual}" > "${marker}"
echo "[fetch] ${name}: ok (${actual})"
