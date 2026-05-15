#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
ACESTEP_XL_VARIANT="${ACESTEP_XL_VARIANT:-all}"
ACESTEP_LM="${ACESTEP_LM:-all}"
COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORKSPACE}/outputs}"
MODEL_ROOT="${WORKSPACE}/models/acestep15xl"
LOG_DIR="${WORKSPACE}/logs"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"

export HF_HOME
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}" "${OUTPUT_DIR}"
exec > >(tee -a "${LOG_DIR}/start_acestep15xl_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "[start] start: $(date -Iseconds)"
echo "[start] workspace: ${WORKSPACE}"
echo "[start] ComfyUI: ${COMFY_DIR}"
echo "[start] output: ${OUTPUT_DIR}"
echo "[start] ACE-Step XL variant: ${ACESTEP_XL_VARIANT}"
echo "[start] ACE-Step LM: ${ACESTEP_LM}"

if [ "${HF_TOKEN:-}" = "your-huggingface-token" ]; then
  echo "[start] HF_TOKEN is a placeholder, ignoring it"
  unset HF_TOKEN
fi

download_model() {
  local include_pattern="$1"
  local source="${MODEL_ROOT}/comfy-files/${include_pattern}"

  if [ -f "${source}" ]; then
    echo "[start] model already exists: ${include_pattern}"
    return
  fi

  echo "[start] downloading ${include_pattern}"
  hf download Comfy-Org/ace_step_1.5_ComfyUI_files \
    --include "${include_pattern}" \
    --local-dir "${MODEL_ROOT}/comfy-files"
}

install_from_split_files() {
  local category="$1"
  local filename="$2"
  local source="${MODEL_ROOT}/comfy-files/split_files/${category}/${filename}"
  local target_dir="${COMFY_DIR}/models/${category}"

  mkdir -p "${target_dir}"
  if [ ! -f "${source}" ]; then
    echo "[start] error: missing downloaded model file: ${source}"
    exit 1
  fi
  ln -sfn "${source}" "${target_dir}/${filename}"
}

case "${ACESTEP_XL_VARIANT}" in
  xl_base)
    DIFFUSION_MODELS=("acestep_v1.5_xl_base_bf16.safetensors")
    ;;
  xl_sft)
    DIFFUSION_MODELS=("acestep_v1.5_xl_sft_bf16.safetensors")
    ;;
  xl_turbo)
    DIFFUSION_MODELS=("acestep_v1.5_xl_turbo_bf16.safetensors")
    ;;
  all)
    DIFFUSION_MODELS=(
      "acestep_v1.5_xl_base_bf16.safetensors"
      "acestep_v1.5_xl_sft_bf16.safetensors"
      "acestep_v1.5_xl_turbo_bf16.safetensors"
    )
    ;;
  *)
    echo "[start] error: unsupported ACESTEP_XL_VARIANT=${ACESTEP_XL_VARIANT}. Use xl_base, xl_sft, xl_turbo, or all."
    exit 2
    ;;
esac

case "${ACESTEP_LM}" in
  qwen_0.6b)
    TEXT_ENCODERS=("qwen_0.6b_ace15.safetensors")
    ;;
  qwen_1.7b)
    TEXT_ENCODERS=("qwen_1.7b_ace15.safetensors")
    ;;
  qwen_4b)
    TEXT_ENCODERS=("qwen_4b_ace15.safetensors")
    ;;
  all)
    TEXT_ENCODERS=(
      "qwen_0.6b_ace15.safetensors"
      "qwen_1.7b_ace15.safetensors"
      "qwen_4b_ace15.safetensors"
    )
    ;;
  *)
    echo "[start] error: unsupported ACESTEP_LM=${ACESTEP_LM}. Use qwen_0.6b, qwen_1.7b, qwen_4b, or all."
    exit 2
    ;;
esac

for diffusion_model in "${DIFFUSION_MODELS[@]}"; do
  download_model "split_files/diffusion_models/${diffusion_model}"
  install_from_split_files "diffusion_models" "${diffusion_model}"
done

for text_encoder in "${TEXT_ENCODERS[@]}"; do
  download_model "split_files/text_encoders/${text_encoder}"
  install_from_split_files "text_encoders" "${text_encoder}"
done

download_model "split_files/vae/ace_1.5_vae.safetensors"
install_from_split_files "vae" "ace_1.5_vae.safetensors"

echo "[start] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
exec python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --enable-cors-header "*" --output-directory "${OUTPUT_DIR}"
