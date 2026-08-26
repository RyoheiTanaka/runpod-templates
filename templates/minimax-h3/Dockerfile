ARG BASE_IMAGE=runpod/pytorch:1.1.0-cu1300-torch291-ubuntu2404
FROM ${BASE_IMAGE}

ARG COMFYUI_REPO=https://github.com/Comfy-Org/ComfyUI.git
ARG COMFYUI_REF=v0.32.0

LABEL org.opencontainers.image.source="https://github.com/RyoheiTanaka/runpod-templates"

ENV DEBIAN_FRONTEND=noninteractive \
    COMFY_DIR=/opt/ComfyUI \
    HF_XET_HIGH_PERFORMANCE=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# openssh-server: CMD で公式イメージの entrypoint を置き換えるため、sshd は start.sh が起動する
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      curl \
      ca-certificates \
      ffmpeg \
      libgl1 \
      libglib2.0-0 \
      libsndfile1 \
      openssh-server \
    && mkdir -p /run/sshd \
    && rm -rf /var/lib/apt/lists/*

# --depth 1 で全履歴の取得を避ける（ComfyUI の .git は数百MB になる）
RUN git clone --depth 1 --branch "${COMFYUI_REF}" "${COMFYUI_REPO}" "${COMFY_DIR}" \
    && cd "${COMFY_DIR}" \
    && python -m pip install --upgrade pip \
    && python -m pip install huggingface_hub \
    && python -m pip install -r requirements.txt \
    && rm -rf /root/.cache/pip

COPY templates/minimax-h3/start.sh /opt/runpod/start.sh
RUN chmod +x /opt/runpod/start.sh

WORKDIR /workspace
EXPOSE 8188 22
CMD ["/opt/runpod/start.sh"]
