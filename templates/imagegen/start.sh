#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORKSPACE}/outputs}"
MODEL_ROOT="${MODEL_ROOT:-${WORKSPACE}/models/imagegen}"
LOG_DIR="${LOG_DIR:-${WORKSPACE}/logs}"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"
RUNPOD_SCRIPTS="${RUNPOD_SCRIPTS:-/opt/runpod}"
# MODEL_URL に加えて MODEL_1_URL 〜 MODEL_<この数>_URL を見る
MODEL_MAX_SLOTS="${MODEL_MAX_SLOTS:-20}"

export HF_HOME COMFY_DIR

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}" "${OUTPUT_DIR}"
LOG_FILE="${LOG_DIR}/start_imagegen_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[start] start: $(date -Iseconds)"
echo "[start] workspace: ${WORKSPACE}"
echo "[start] models: ${MODEL_ROOT}"
echo "[start] ComfyUI: ${COMFY_DIR}"
echo "[start] output: ${OUTPUT_DIR}"
echo "[start] log: ${LOG_FILE}"

# 起動を続けられない問題が見つかったときは、exit せずにここで止まる。
#
# exit するとコンテナが再起動し、同じ失敗を繰り返す。そのたびにログが流れて
# 最初のエラーが読めなくなり、イメージの取得からやり直す分だけ時間も失う。
# 止まったままにしておけば、sshd とログは残るので原因を調べられる。
#
# ただし GPU の課金は止まらない。メッセージでそう伝える。
halt() {
  echo "[start] error: $*"
  echo "[start] halted: ComfyUI was NOT started. The container stays up so you can inspect it."
  echo "[start] halted: log file: ${LOG_FILE}"
  echo "[start] halted: the GPU is still billed. Fix the cause and restart the pod, or delete it."
  exec sleep infinity
}

# CMD でイメージの entrypoint を置き換えているため、PUBLIC_KEY を authorized_keys へ
# 展開して sshd を起動する処理はこの script が持つ必要がある。
# 後の halt でも原因を調べられるよう、何より先に起動する。
start_sshd() {
  if [ -z "${PUBLIC_KEY:-}" ]; then
    echo "[start] PUBLIC_KEY is empty, skip sshd"
    return
  fi

  mkdir -p /root/.ssh /run/sshd
  chmod 700 /root/.ssh
  # RunPod が渡す PUBLIC_KEY を正とし、再起動のたびに上書きする（追記だと重複が溜まる）
  printf '%s\n' "${PUBLIC_KEY}" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys

  mkdir -p /etc/ssh/sshd_config.d
  printf 'PermitRootLogin prohibit-password\nPasswordAuthentication no\n' \
    > /etc/ssh/sshd_config.d/runpod.conf

  ssh-keygen -A
  /usr/sbin/sshd
  echo "[start] sshd started"
}

# sshd が起動できなくても ComfyUI は動かす
start_sshd || echo "[start] warning: failed to start sshd"

# --- GPU の初期化確認 -------------------------------------------------------
#
# nvidia-smi が GPU を表示していても、CUDA の初期化（cuInit）だけが失敗するホストがある。
# そのまま ComfyUI を起動すると `RuntimeError: CUDA unknown error` で落ち、
# コンテナの再起動を繰り返す。モデルを数 GB 取得してから落ちるのも無駄なので、最初に確かめる。
#
# GPU_CHECK=off で飛ばせる。
check_gpu() {
  if [ "${GPU_CHECK:-on}" = "off" ]; then
    echo "[start] GPU_CHECK=off, skip GPU check"
    return
  fi

  local out rc=0
  out="$(timeout 180 python - <<'PY' 2>&1
import torch
torch.cuda.init()
x = torch.ones(1, device="cuda") + 1
torch.cuda.synchronize()
print(f"{torch.cuda.get_device_name(0)} / torch {torch.__version__} / CUDA {torch.version.cuda}")
PY
)" || rc=$?

  if [ "${rc}" -eq 0 ]; then
    echo "[start] gpu: ${out##*$'\n'}"
    return
  fi

  echo "[start] GPU check failed (exit ${rc}). Output:"
  printf '%s\n' "${out}" | sed 's/^/[start]   /'
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "[start] nvidia-smi:"
    nvidia-smi 2>&1 | sed 's/^/[start]   /' || true
  fi
  echo "[start] This is a host-side problem in most cases; restarting will not fix it."
  echo "[start] Deploy a new pod on another machine. Limiting the host CUDA version to 12.8"
  echo "[start] (and Secure Cloud) avoided this in our tests. See the template README."
  halt "CUDA could not be initialized on this host"
}

check_gpu

# --- モデルの取得 -----------------------------------------------------------
#
# 1ファイルを3つの環境変数で指定する。
#
#   MODEL_URL      取得元（https）
#   MODEL_SHA256   照合する SHA256。空なら照合しない（警告を出す）
#   MODEL_DEST     ComfyUI の models/ からの相対パス。例: checkpoints/foo.safetensors
#                  ディレクトリを含まなければ checkpoints/ に置く
#
# 2本目以降は MODEL_1_URL / MODEL_1_SHA256 / MODEL_1_DEST、MODEL_2_... の形で足す。
# 番号は飛んでいてもよい。
#
# 実体は MODEL_ROOT に置き、ComfyUI の models/ へは symlink で見せる。

FETCH_FAILURES=()

link_model() {
  local rel="$1"
  local source="${MODEL_ROOT}/${rel}"
  local target="${COMFY_DIR}/models/${rel}"
  mkdir -p "$(dirname "${target}")"
  ln -sfn "${source}" "${target}"
}

fetch_slot() {
  local prefix="$1"
  local url_var="${prefix}_URL" sha_var="${prefix}_SHA256" dest_var="${prefix}_DEST"
  local url="${!url_var:-}"
  local sha="${!sha_var:-}"
  local rel="${!dest_var:-}"

  [ -n "${url}" ] || return 0

  if [ -z "${rel}" ]; then
    echo "[start] error: ${url_var} is set but ${dest_var} is empty"
    FETCH_FAILURES+=("${prefix}: ${dest_var} is empty")
    return 0
  fi
  case "${rel}" in
    */) rel="" ;;
    */*) ;;
    *) rel="checkpoints/${rel}" ;;
  esac
  case "/${rel}/" in
    //* | */../* | */./*) rel="" ;;
  esac
  if [ -z "${rel}" ]; then
    echo "[start] error: ${dest_var} must be a relative path ending in a file name, like checkpoints/model.safetensors"
    FETCH_FAILURES+=("${prefix}: invalid ${dest_var}")
    return 0
  fi

  # 取得は別プロセスで行う。トークンは引数に載せず、環境変数のまま fetch-model.sh に引き継ぐ。
  local rc=0
  "${RUNPOD_SCRIPTS}/fetch-model.sh" "${url}" "${MODEL_ROOT}/${rel}" "${sha}" || rc=$?
  case "${rc}" in
    0) link_model "${rel}" ;;
    2) FETCH_FAILURES+=("${prefix}: SHA256 mismatch for ${rel}") ;;
    *) FETCH_FAILURES+=("${prefix}: download failed for ${rel} (exit ${rc})") ;;
  esac
}

fetch_slot MODEL
for n in $(seq 1 "${MODEL_MAX_SLOTS}"); do
  fetch_slot "MODEL_${n}"
done

if [ "${#FETCH_FAILURES[@]}" -gt 0 ]; then
  for f in "${FETCH_FAILURES[@]}"; do
    echo "[start] model error: ${f}"
  done
  halt "${#FETCH_FAILURES[@]} model(s) could not be prepared"
fi

# 以前の起動で取得済みのファイルも ComfyUI から見えるようにする。
# 環境変数から外したモデルが MODEL_ROOT に残っている場合も、消さずに見せておく。
while IFS= read -r -d '' f; do
  link_model "${f#"${MODEL_ROOT}/"}"
done < <(find "${MODEL_ROOT}" -type f \
  ! -name '*.part' ! -name '*.sha256' ! -name '*.mismatch' -print0)

# --- 追加のカスタムノード ---------------------------------------------------
#
# CUSTOM_NODES に「https の git URL」または「URL@ref」を空白区切りで並べる。
# 例: https://github.com/owner/repo@<commit-sha> https://github.com/owner/other
# 失敗してもそのノードが読めないだけなので、ComfyUI は起動する。
if [ -n "${CUSTOM_NODES:-}" ]; then
  read -r -a node_entries <<< "${CUSTOM_NODES}"
  for entry in "${node_entries[@]}"; do
    url="${entry}"
    ref=""
    rest="${entry#https://}"
    if [[ "${rest}" == *@* ]]; then
      url="https://${rest%@*}"
      ref="${rest##*@}"
    fi
    if [ -z "${ref}" ]; then
      echo "[start] warning: ${url} has no @ref, using its current HEAD (not reproducible)"
    fi
    "${RUNPOD_SCRIPTS}/install-custom-node.sh" "${url}" "${ref}" \
      || echo "[start] warning: failed to install ${url}, continuing without it"
  done
fi

# --- ComfyUI の起動 ---------------------------------------------------------
#
# ComfyUI と comfy-aimdo はホストの RAM を見ており、コンテナに与えられた上限を見ない。
# ホストが大きくコンテナの取り分が小さい環境では、2本目のモデルを積んだ時点で pinned memory が
# コンテナ上限を超え、traceback を出さずに OOM kill される（コンテナごと再起動する）。
# cgroup から実際の上限を読み、ホスト RAM より明らかに小さければ pinned memory を切る。
#
# COMFY_PINNED_MEMORY=auto（既定）/ on（常に使う）/ off（常に切る）で上書きできる。
container_memory_limit_bytes() {
  local limit=""
  if [ -r /sys/fs/cgroup/memory.max ]; then
    limit="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)"
  elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    limit="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || true)"
  fi
  case "${limit}" in
    "" | max | *[!0-9]*) return 1 ;;
  esac
  echo "${limit}"
}

host_memory_bytes() {
  local kb
  kb="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo 2>/dev/null || true)"
  case "${kb}" in
    "" | *[!0-9]*) return 1 ;;
  esac
  echo $((kb * 1024))
}

COMFY_ARGS=(--listen 0.0.0.0 --port "${COMFY_PORT}" --output-directory "${OUTPUT_DIR}")

pinned_mode="${COMFY_PINNED_MEMORY:-auto}"
if [ "${pinned_mode}" = "off" ]; then
  echo "[start] COMFY_PINNED_MEMORY=off, disabling pinned memory"
  COMFY_ARGS+=(--disable-pinned-memory)
elif [ "${pinned_mode}" = "auto" ]; then
  if limit_b="$(container_memory_limit_bytes)" && host_b="$(host_memory_bytes)"; then
    host_gb=$((host_b / 1024 / 1024 / 1024))
    # cgroup v2 は「上限なし」を max ではなく巨大な数値で返すことがあり、その場合
    # 上の max 判定を素通りする。ホスト RAM 以上の上限は実質「上限なし」なので、
    # 桁の狂った GB を表示せずにそう扱う。
    if [ "${limit_b}" -ge "${host_b}" ]; then
      echo "[start] memory: no container limit / host ${host_gb}GB"
    else
      limit_gb=$((limit_b / 1024 / 1024 / 1024))
      echo "[start] memory: container limit ${limit_gb}GB / host ${host_gb}GB"
      # 上限がホストの 80% 未満なら、ComfyUI が見ている値は実態より大きい
      if [ "${limit_b}" -lt $((host_b / 10 * 8)) ]; then
        echo "[start] container limit is well below host RAM, disabling pinned memory"
        echo "[start] set COMFY_PINNED_MEMORY=on to keep it enabled"
        COMFY_ARGS+=(--disable-pinned-memory)
      fi
    fi
  else
    echo "[start] memory: could not read the container limit, leaving pinned memory as-is"
  fi
fi

# 追加の ComfyUI 引数を環境変数から渡せるようにする（--lowvram, --fast-disk, --cache-none など）。
# 意図的に単語分割する。
if [ -n "${COMFY_EXTRA_ARGS:-}" ]; then
  echo "[start] extra args: ${COMFY_EXTRA_ARGS}"
  # shellcheck disable=SC2206
  COMFY_ARGS+=(${COMFY_EXTRA_ARGS})
fi

echo "[start] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
echo "[start] args: ${COMFY_ARGS[*]}"
cd "${COMFY_DIR}"
exec python main.py "${COMFY_ARGS[@]}"
