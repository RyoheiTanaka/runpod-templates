#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_PORT="${COMFY_PORT:-8188}"
ACESTEP_XL_VARIANT="${ACESTEP_XL_VARIANT:-all}"
ACESTEP_LM="${ACESTEP_LM:-qwen_1.7b}"

COMFY_DIR="${WORKSPACE}/ComfyUI"
MODEL_ROOT="${WORKSPACE}/models/acestep15xl"
LOG_DIR="${WORKSPACE}/logs"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"

export HF_HOME

mkdir -p "${MODEL_ROOT}" "${LOG_DIR}"
exec > >(tee -a "${LOG_DIR}/setup_acestep15xl_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "[setup] start: $(date -Iseconds)"
echo "[setup] workspace: ${WORKSPACE}"
echo "[setup] ACE-Step XL variant: ${ACESTEP_XL_VARIANT}"
echo "[setup] ACE-Step LM: ${ACESTEP_LM}"

if [ "${HF_TOKEN:-}" = "your-huggingface-token" ]; then
  echo "[setup] HF_TOKEN is a placeholder, ignoring it"
  unset HF_TOKEN
fi

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
  "huggingface_hub[cli]" \
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
  local source="${MODEL_ROOT}/comfy-files/${include_pattern}"

  if [ -f "${source}" ]; then
    echo "[setup] model already exists: ${include_pattern}"
    return
  fi

  echo "[setup] downloading ${include_pattern}"
  huggingface-cli download Comfy-Org/ace_step_1.5_ComfyUI_files \
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
    echo "[setup] error: missing downloaded model file: ${source}"
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
    echo "[setup] error: unsupported ACESTEP_XL_VARIANT=${ACESTEP_XL_VARIANT}. Use xl_base, xl_sft, xl_turbo, or all."
    exit 2
    ;;
esac

case "${ACESTEP_LM}" in
  qwen_0.6b)
    TEXT_ENCODER="qwen_0.6b_ace15.safetensors"
    ;;
  qwen_1.7b)
    TEXT_ENCODER="qwen_1.7b_ace15.safetensors"
    ;;
  qwen_4b)
    TEXT_ENCODER="qwen_4b_ace15.safetensors"
    ;;
  *)
    echo "[setup] error: unsupported ACESTEP_LM=${ACESTEP_LM}. Use qwen_0.6b, qwen_1.7b, or qwen_4b."
    exit 2
    ;;
esac

for diffusion_model in "${DIFFUSION_MODELS[@]}"; do
  download_model "split_files/diffusion_models/${diffusion_model}"
  install_from_split_files "diffusion_models" "${diffusion_model}"
done

download_model "split_files/text_encoders/${TEXT_ENCODER}"
download_model "split_files/vae/ace_1.5_vae.safetensors"

install_from_split_files "text_encoders" "${TEXT_ENCODER}"
install_from_split_files "vae" "ace_1.5_vae.safetensors"

echo "[setup] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --enable-cors-header "*" &
APP_PID=$!
wait "${APP_PID}"
