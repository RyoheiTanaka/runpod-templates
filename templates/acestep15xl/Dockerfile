ARG BASE_IMAGE=runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
FROM ${BASE_IMAGE}

ARG COMFYUI_REPO=https://github.com/Comfy-Org/ComfyUI.git
ARG COMFYUI_REF=v0.19.3

LABEL org.opencontainers.image.source="https://github.com/RyoheiTanaka/runpod-templates"

ENV DEBIAN_FRONTEND=noninteractive \
    COMFY_DIR=/opt/ComfyUI \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      git-lfs \
      curl \
      ca-certificates \
      ffmpeg \
      libgl1 \
      libglib2.0-0 \
      libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone "${COMFYUI_REPO}" "${COMFY_DIR}" \
    && cd "${COMFY_DIR}" \
    && git checkout "${COMFYUI_REF}" \
    && python -m pip install --upgrade pip \
    && python -m pip install huggingface_hub hf_transfer \
    && python -m pip install -r requirements.txt

COPY templates/acestep15xl/start.sh /opt/runpod/start.sh
RUN chmod +x /opt/runpod/start.sh

WORKDIR /workspace
EXPOSE 8188
CMD ["/opt/runpod/start.sh"]
