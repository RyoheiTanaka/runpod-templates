# ComfyUI 共通ベース。ここには「重いがテンプレート間で変わらないもの」だけを置く。
#
# 切り出した理由は Hub のビルド上限。RunPod Hub の docker build は 30分で打ち切られる
# （総ビルド枠 160分とは別枠）。v0.4.0 のビルドは Dockerfile を1行も変えていないのに
# ビルダーの pip download が 68〜80 kB/s しか出ず、この30分に当たって落ちた。
# Hub にはビルド再実行のボタンが無いため、タグを切り直すしかなく、
# 一時的な失敗がバージョン番号を1つ食う。
#
# RunPod のドキュメントが案内している回避策がまさにこれで、
# 「pre-build your image locally and push to a container registry」。
# 事前ビルドしたこのイメージを FROM するだけにすれば、
# Hub 側に残るのは COPY 数個になり、pip の速度に依存しなくなる。
#
# 前提: このイメージは GHCR で public であること。
# Hub は privately hosted image をベースにできない。
ARG BASE_IMAGE=pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime
FROM ${BASE_IMAGE}

ARG COMFYUI_REPO=https://github.com/Comfy-Org/ComfyUI.git
ARG COMFYUI_REF=v0.32.0

LABEL org.opencontainers.image.source="https://github.com/RyoheiTanaka/runpod-templates"
LABEL org.opencontainers.image.description="Prebuilt ComfyUI runtime shared by the runpod-templates images and the Hub listings."

ENV DEBIAN_FRONTEND=noninteractive \
    COMFY_DIR=/opt/ComfyUI \
    HF_XET_HIGH_PERFORMANCE=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# openssh-server: CMD で公式イメージの entrypoint を置き換えるため、sshd は start.sh が起動する
#
# libsndfile1 は acestep15xl（音声）だけが要るが、1MB 程度なので分けずに共通で入れる。
# ベースを構成ごとに割るほうが、イメージが1MB太るより高くつく。
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

# ComfyUI の requirements.txt は torch / torchvision を裸で要求するため、pip がベースイメージの
# PyTorch を PyPI の既定ビルドで置き換えうる。CUDA ビルドが変わると壊れるので constraints で固定する。
#
# ただし torch だけ固定すると torchvision が PyPI から浮いてペアが崩れ、C++ 拡張が噛み合わずに
# `RuntimeError: operator torchvision::nms does not exist` で ComfyUI が起動しなくなる。
# cu130 ベースには torchvision が入っていないため、torch と同じ PyTorch index から先に入れておく。
#
# --depth 1 で全履歴の取得を避ける（ComfyUI の .git は数百MB になる）
RUN set -eu \
    && TORCH_CU="$(python -c 'import re, torch; m = re.search(r"\+(cu[0-9]+)", torch.__version__); print(m.group(1) if m else "")')" \
    && echo "base torch: $(python -c 'import torch; print(torch.__version__)') (index: ${TORCH_CU:-pypi})" \
    && python -m pip install --upgrade pip \
    && python -m pip freeze | grep -E '^(torch|torchaudio)==' > /opt/torch-constraints.txt \
    && test -s /opt/torch-constraints.txt \
    && if ! python -c 'import torchvision' >/dev/null 2>&1; then \
         if [ -n "${TORCH_CU}" ]; then \
           python -m pip install torchvision --index-url "https://download.pytorch.org/whl/${TORCH_CU}" -c /opt/torch-constraints.txt; \
         else \
           python -m pip install torchvision -c /opt/torch-constraints.txt; \
         fi; \
       fi \
    && python -m pip freeze | grep -E '^(torch|torchvision|torchaudio)==' > /opt/torch-constraints.txt \
    && cat /opt/torch-constraints.txt \
    && git clone --depth 1 --branch "${COMFYUI_REF}" "${COMFYUI_REPO}" "${COMFY_DIR}" \
    && cd "${COMFY_DIR}" \
    && python -m pip install huggingface_hub \
    && python -m pip install -r requirements.txt -c /opt/torch-constraints.txt \
    && python -c 'import torch, torchvision; print("after install:", torch.__version__, torchvision.__version__)' \
    && python -c 'import torchvision; torchvision.ops.nms' \
    && rm -rf /root/.cache/pip

# runpod SDK は handler 専用のディレクトリに入れ、ComfyUI の環境から分離する。
#
# 同じ環境に入れると cu130 ベース（ubuntu24.04 のシステム Python）で失敗する。
# runpod は fastapi[all] を引き込み、pip が apt 由来のパッケージを置き換えようとするが、
# それらは RECORD ファイルを持たないため `error: uninstall-no-record-file` で落ちる。
# --target は何もアンインストールしないので、この経路を踏まない。
#
# import 検証を同じレイヤに置き、インストールが効かなければビルドを落とす。
# 一度これを怠って「入ったつもり」のイメージを出し、3リリース分を無駄にした。
#
# Pod テンプレート（wan22 など）は handler を使わないので、これは 50MB ほどの余剰になる。
# それでも共通ベースに入れているのは、Hub 側の docker build から pip を完全に無くすため。
# ここに残すと、Hub のビルドが再び pip の速度に依存する。
RUN python -m pip install --no-cache-dir --target /opt/runpod/pylibs runpod \
    && PYTHONPATH=/opt/runpod/pylibs python -c 'import runpod; print("runpod:", runpod.__version__)'

WORKDIR /workspace
