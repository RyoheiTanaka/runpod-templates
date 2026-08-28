#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
WAN_VARIANT="${WAN_VARIANT:-t2v_a14b}"
COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORKSPACE}/outputs}"
MODEL_ROOT="${WORKSPACE}/models/wan22"
LOG_DIR="${WORKSPACE}/logs"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"

export HF_HOME
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}" "${OUTPUT_DIR}"
exec > >(tee -a "${LOG_DIR}/start_wan22_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "[start] start: $(date -Iseconds)"
echo "[start] workspace: ${WORKSPACE}"
echo "[start] ComfyUI: ${COMFY_DIR}"
echo "[start] output: ${OUTPUT_DIR}"
echo "[start] variant: ${WAN_VARIANT}"

if [ "${HF_TOKEN:-}" = "your-huggingface-token" ]; then
  echo "[start] HF_TOKEN is a placeholder, ignoring it"
  unset HF_TOKEN
fi

# CMD で公式イメージの entrypoint を置き換えているため、PUBLIC_KEY を authorized_keys へ
# 展開して sshd を起動する処理はこの script が持つ必要がある。
# exec でプロセスが置き換わるので、必ず末尾の exec より前に実行すること。
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

if [ "${WAN_VARIANT}" = "all" ]; then
  echo "[start] error: WAN_VARIANT=all is intentionally unsupported. Use t2v_a14b, i2v_a14b, or ti2v_5b."
  exit 2
fi

download_model() {
  local include_pattern="$1"
  local source="${MODEL_ROOT}/comfy-repackaged/${include_pattern}"

  if [ -f "${source}" ]; then
    echo "[start] model already exists: $(basename "${include_pattern}")"
    return
  fi

  echo "[start] downloading ${include_pattern}"
  hf download Comfy-Org/Wan_2.2_ComfyUI_Repackaged \
    --include "${include_pattern}" \
    --local-dir "${MODEL_ROOT}/comfy-repackaged"
}

install_from_split_files() {
  local category="$1"
  local filename="$2"
  local source="${MODEL_ROOT}/comfy-repackaged/split_files/${category}/${filename}"
  local target_dir="${COMFY_DIR}/models/${category}"

  mkdir -p "${target_dir}"
  if [ ! -f "${source}" ]; then
    echo "[start] error: missing downloaded model file: ${source}"
    exit 1
  fi
  ln -sfn "${source}" "${target_dir}/${filename}"
}

download_common_models() {
  download_model "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
  install_from_split_files "text_encoders" "umt5_xxl_fp8_e4m3fn_scaled.safetensors"
}

download_t2v_a14b() {
  download_model "split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
  download_model "split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
  download_model "split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors"
  download_model "split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors"
  download_model "split_files/vae/wan_2.1_vae.safetensors"

  install_from_split_files "diffusion_models" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
  install_from_split_files "diffusion_models" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
  install_from_split_files "loras" "wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors"
  install_from_split_files "loras" "wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors"
  install_from_split_files "vae" "wan_2.1_vae.safetensors"
}

download_i2v_a14b() {
  download_model "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
  download_model "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
  download_model "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
  download_model "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
  download_model "split_files/vae/wan_2.1_vae.safetensors"

  install_from_split_files "diffusion_models" "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
  install_from_split_files "diffusion_models" "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
  install_from_split_files "loras" "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
  install_from_split_files "loras" "wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
  install_from_split_files "vae" "wan_2.1_vae.safetensors"
}

download_ti2v_5b() {
  download_model "split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors"
  download_model "split_files/vae/wan2.2_vae.safetensors"

  install_from_split_files "diffusion_models" "wan2.2_ti2v_5B_fp16.safetensors"
  install_from_split_files "vae" "wan2.2_vae.safetensors"
}

download_common_models

case "${WAN_VARIANT}" in
  t2v_a14b)
    download_t2v_a14b
    ;;
  i2v_a14b)
    download_i2v_a14b
    ;;
  ti2v_5b)
    download_ti2v_5b
    ;;
  *)
    echo "[start] error: unsupported WAN_VARIANT=${WAN_VARIANT}. Use t2v_a14b, i2v_a14b, or ti2v_5b."
    exit 2
    ;;
esac

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
    limit_gb=$((limit_b / 1024 / 1024 / 1024))
    host_gb=$((host_b / 1024 / 1024 / 1024))
    echo "[start] memory: container limit ${limit_gb}GB / host ${host_gb}GB"
    # 上限がホストの 80% 未満なら、ComfyUI が見ている値は実態より大きい
    if [ "${limit_b}" -lt $((host_b / 10 * 8)) ]; then
      echo "[start] container limit is well below host RAM, disabling pinned memory"
      echo "[start] set COMFY_PINNED_MEMORY=on to keep it enabled"
      COMFY_ARGS+=(--disable-pinned-memory)
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
