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

echo "[start] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
exec python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --output-directory "${OUTPUT_DIR}"
