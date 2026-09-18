# 重いレイヤ（apt / torch / ComfyUI / requirements / runpod SDK）は base/Dockerfile に移した。
# 事前ビルド済みの GHCR イメージを FROM するだけなので、ここのビルドは COPY 数行で終わる。
#
# ベースの中身と、そこに何を置いたかの理由は base/Dockerfile を見る。
# ベースを更新したら base-v* タグを打ち、この FROM を明示的に上げる。
ARG BASE_IMAGE=ghcr.io/ryoheitanaka/runpod-comfyui-base:v1-cuda12.8
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/RyoheiTanaka/runpod-templates"

COPY templates/acestep15xl/start.sh /opt/runpod/start.sh
RUN chmod +x /opt/runpod/start.sh

WORKDIR /workspace
EXPOSE 8188 22
CMD ["/opt/runpod/start.sh"]
