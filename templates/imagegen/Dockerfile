# 静止画生成用。重いレイヤ（apt / torch / ComfyUI / requirements）は base/Dockerfile にある。
# ここで足すのは起動スクリプトと、静止画のワークフローでよく使うカスタムノード2つだけ。
#
# ベースの中身と、そこに何を置いたかの理由は base/Dockerfile を見る。
# ベースを更新したら base-v* タグを打ち、この FROM を明示的に上げる。
#
# CUDA 12.8 のイメージしか作らない。template で host の CUDA を 12.8 に絞っており
# （README 参照）、13.0 のイメージを用意しても使う場面が無いため。
ARG BASE_IMAGE=ghcr.io/ryoheitanaka/runpod-comfyui-base:v1-cuda12.8
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/RyoheiTanaka/runpod-templates"

COPY templates/imagegen/start.sh templates/imagegen/fetch-model.sh templates/imagegen/install-custom-node.sh /opt/runpod/
RUN chmod +x /opt/runpod/*.sh

# カスタムノードは commit SHA で固定する。ブランチやタグを指すと、ビルド日で中身が変わる
# （v2 の wan22 は浮動指定の依存が原因で ComfyUI が起動しなくなった）。
#
# 依存の pip install には、ベースに入っている全パッケージの版を constraints として渡す。
# ノードの requirements.txt は numpy / pillow を裸で書いており、何かのはずみで
# 上げられると ComfyUI 側が壊れうる。既存の版を動かす要求が出たら、ビルドが落ちて分かる。
#
# - save-image-extended-comfyui: SaveImageExtended。保存先のサブフォルダやファイル名を
#   ノードの入力から組み立てられる。追加の依存は画像形式のプラグイン（wheel 合計 約34MB）
# - ComfyUI_UltimateSDUpscale: タイル分割のアップスケール。pip の依存は無い。
#   A1111 版のスクリプトを git submodule で持つので、install-custom-node.sh が submodule も取る
#
# Impact Pack（FaceDetailer など）は入れていない。ultralytics と opencv 5.0（通常版と headless 版の二重）、
# git から入れる sam2 を引き込み、wheel だけで 約224MB 増えるうえ、ビルドの再現性が落ちるため。
# 必要なら Pod の環境変数 CUSTOM_NODES で起動時に入れる。
ARG SAVE_IMAGE_EXTENDED_REF=d49387f000b2febcfa9e27a5235b5d3fdde1e335
ARG ULTIMATE_SD_UPSCALE_REF=a5547db9e1d07d3318bb21e9e9c474f4c1e9c8df
RUN set -eu \
    && python -m pip list --format=freeze > /opt/imagegen-constraints.txt \
    && /opt/runpod/install-custom-node.sh \
         https://github.com/audioscavenger/save-image-extended-comfyui \
         "${SAVE_IMAGE_EXTENDED_REF}" /opt/imagegen-constraints.txt \
    && /opt/runpod/install-custom-node.sh \
         https://github.com/ssitu/ComfyUI_UltimateSDUpscale \
         "${ULTIMATE_SD_UPSCALE_REF}" /opt/imagegen-constraints.txt \
    && test -f "${COMFY_DIR}/custom_nodes/ComfyUI_UltimateSDUpscale/repositories/ultimate_sd_upscale/scripts/ultimate-upscale.py" \
    && python -c 'import piexif, imagecodecs, pillow_avif, pillow_jxl; print("save-image-extended deps: ok")' \
    && python -c 'import torch, torchvision; print("torch:", torch.__version__, torchvision.__version__)' \
    && rm -rf /root/.cache/pip

WORKDIR /workspace
EXPOSE 8188 22
CMD ["/opt/runpod/start.sh"]
