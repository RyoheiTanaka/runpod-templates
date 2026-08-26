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
DOWNLOAD_TURBO_LORA="${H3_DOWNLOAD_TURBO_LORA:-0}"

export HF_HOME
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"

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

  install_model "diffusion_models" "minimax_h3_ref2va_pruned_int8_convrot.safetensors"
  install_model "text_encoders" "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
  install_model "vae" "minimax_h3_video_vae_fp16.safetensors"
  install_model "vae" "minimax_h3_audio_vae_fp32.safetensors"

  # Turbo LoRA はワークフロー側で無効にしているため既定では取得しない（1.96GB）。
  # 検証したい場合のみ H3_DOWNLOAD_TURBO_LORA=1 を指定する。
  if [ "${DOWNLOAD_TURBO_LORA}" = "1" ]; then
    download_model "loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
    install_model "loras" "minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
  else
    echo "[start] skip turbo LoRA (set H3_DOWNLOAD_TURBO_LORA=1 to fetch)"
  fi
}

download_r2v

echo "[start] ready: ComfyUI will listen on 0.0.0.0:${COMFY_PORT}"
cd "${COMFY_DIR}"
exec python main.py --listen 0.0.0.0 --port "${COMFY_PORT}" --output-directory "${OUTPUT_DIR}"
