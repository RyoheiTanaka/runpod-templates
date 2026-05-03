#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
WAN_VARIANT="${WAN_VARIANT:-t2v_a14b}"

COMFY_DIR="${WORKSPACE}/ComfyUI"
MODEL_ROOT="${WORKSPACE}/models/wan22"
LOG_DIR="${WORKSPACE}/logs"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"

export HF_HOME

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}"
exec > >(tee -a "${LOG_DIR}/setup_wan22_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "[setup] start: $(date -Iseconds)"
echo "[setup] workspace: ${WORKSPACE}"
echo "[setup] variant: ${WAN_VARIANT}"

if [ "${HF_TOKEN:-}" = "your-huggingface-token" ]; then
  echo "[setup] HF_TOKEN is a placeholder, ignoring it"
  unset HF_TOKEN
fi

if [ "${WAN_VARIANT}" = "all" ]; then
  echo "[setup] error: WAN_VARIANT=all is intentionally unsupported. Use t2v_a14b, i2v_a14b, or ti2v_5b."
  exit 2
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git \
  git-lfs \
  curl \
  ca-certificates \
  ffmpeg \
  libgl1 \
  libglib2.0-0

python -m pip install --no-cache-dir \
  huggingface_hub \
  hf_transfer

export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"

if [ ! -d "${COMFY_DIR}/.git" ]; then
  echo "[setup] cloning ComfyUI"
  git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFY_DIR}"
else
  echo "[setup] ComfyUI already exists, skip clone"
fi

echo "[setup] installing ComfyUI requirements"
python -m pip install --no-cache-dir -r "${COMFY_DIR}/requirements.txt"

download_model() {
  local include_pattern="$1"
  local source="${MODEL_ROOT}/comfy-repackaged/${include_pattern}"

  if [ -f "${source}" ]; then
    echo "[setup] model already exists: $(basename "${include_pattern}")"
    return
  fi

  echo "[setup] downloading ${include_pattern}"
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
    echo "[setup] error: missing downloaded model file: ${source}"
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
  download_model "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors"
  download_model "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors"
  download_model "split_files/vae/wan_2.1_vae.safetensors"

  install_from_split_files "diffusion_models" "wan2.2_i2v_high_noise_14B_fp16.safetensors"
  install_from_split_files "diffusion_models" "wan2.2_i2v_low_noise_14B_fp16.safetensors"
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
    echo "[setup] error: unsupported WAN_VARIANT=${WAN_VARIANT}. Use t2v_a14b, i2v_a14b, or ti2v_5b."
    exit 2
    ;;
esac

echo "[setup] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --enable-cors-header "*" &
APP_PID=$!
wait "${APP_PID}"
