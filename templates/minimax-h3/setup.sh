#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFYUI_REF="${COMFYUI_REF:-v0.32.0}"

COMFY_DIR="${WORKSPACE}/ComfyUI"
MODEL_ROOT="${WORKSPACE}/models/minimax-h3"
LOG_DIR="${WORKSPACE}/logs"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"
HF_REPO="Comfy-Org/MiniMax-H3"

export HF_HOME

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}"
exec > >(tee -a "${LOG_DIR}/setup_minimax_h3_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "[setup] start: $(date -Iseconds)"
echo "[setup] workspace: ${WORKSPACE}"
echo "[setup] mode: R2V (Ref2VA)"
echo "[setup] NOTICE: MiniMax H3 is licensed under the MiniMax H3 Community License Agreement,"
echo "[setup] NOTICE: Copyright (c) 2026 MiniMax. All Rights Reserved."
echo "[setup] NOTICE: The Applicable Territory excludes the EU, the UK, the Republic of Korea,"
echo "[setup] NOTICE: and the USA. Do not run this setup in a data center in those territories."

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git \
  git-lfs \
  curl \
  ca-certificates \
  ffmpeg \
  libgl1 \
  libglib2.0-0 \
  libsndfile1

python -m pip install --no-cache-dir \
  huggingface_hub \
  hf_transfer

export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"

if [ ! -d "${COMFY_DIR}/.git" ]; then
  echo "[setup] cloning ComfyUI ${COMFYUI_REF}"
  git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFY_DIR}"
  git -C "${COMFY_DIR}" checkout "${COMFYUI_REF}"
else
  echo "[setup] ComfyUI already exists, skip clone"
fi

echo "[setup] installing ComfyUI requirements"
python -m pip install --no-cache-dir -r "${COMFY_DIR}/requirements.txt"

download_model() {
  local include_pattern="$1"
  local source="${MODEL_ROOT}/comfy-org/${include_pattern}"

  if [ -f "${source}" ]; then
    echo "[setup] model already exists: $(basename "${include_pattern}")"
    return
  fi

  echo "[setup] downloading ${include_pattern}"
  hf download "${HF_REPO}" \
    --include "${include_pattern}" \
    --local-dir "${MODEL_ROOT}/comfy-org"
}

install_model() {
  local category="$1"
  local filename="$2"
  local source="${MODEL_ROOT}/comfy-org/${category}/${filename}"
  local target_dir="${COMFY_DIR}/models/${category}"

  mkdir -p "${target_dir}"
  if [ ! -f "${source}" ]; then
    echo "[setup] error: missing downloaded model file: ${source}"
    exit 1
  fi
  ln -sfn "${source}" "${target_dir}/${filename}"
}

download_r2v() {
  download_model "diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
  download_model "text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
  download_model "vae/minimax_h3_video_vae_fp16.safetensors"
  download_model "vae/minimax_h3_audio_vae_fp32.safetensors"
  download_model "loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"

  install_model "diffusion_models" "minimax_h3_ref2va_pruned_int8_convrot.safetensors"
  install_model "text_encoders" "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
  install_model "vae" "minimax_h3_video_vae_fp16.safetensors"
  install_model "vae" "minimax_h3_audio_vae_fp32.safetensors"
  install_model "loras" "minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
}

download_r2v

echo "[setup] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --enable-cors-header "*" &
APP_PID=$!
wait "${APP_PID}"
