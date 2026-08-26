#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORKSPACE}/outputs}"
MODEL_ROOT="${WORKSPACE}/models/minimax-h3"
LOG_DIR="${WORKSPACE}/logs"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"
HF_REPO="Comfy-Org/MiniMax-H3"

export HF_HOME
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}" "${OUTPUT_DIR}"
exec > >(tee -a "${LOG_DIR}/start_minimax_h3_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "[start] start: $(date -Iseconds)"
echo "[start] workspace: ${WORKSPACE}"
echo "[start] ComfyUI: ${COMFY_DIR}"
echo "[start] output: ${OUTPUT_DIR}"
echo "[start] mode: R2V (Ref2VA)"
echo "[start] NOTICE: MiniMax H3 is licensed under the MiniMax H3 Community License Agreement,"
echo "[start] NOTICE: Copyright (c) 2026 MiniMax. All Rights Reserved."
echo "[start] NOTICE: The Applicable Territory excludes the EU, the UK, the Republic of Korea,"
echo "[start] NOTICE: and the USA. Do not run this template in a data center in those territories."

download_model() {
  local include_pattern="$1"
  local source="${MODEL_ROOT}/comfy-org/${include_pattern}"

  if [ -f "${source}" ]; then
    echo "[start] model already exists: $(basename "${include_pattern}")"
    return
  fi

  echo "[start] downloading ${include_pattern}"
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
    echo "[start] error: missing downloaded model file: ${source}"
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

echo "[start] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
exec python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --enable-cors-header "*" --output-directory "${OUTPUT_DIR}"
