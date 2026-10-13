#!/usr/bin/env bash
# ComfyUI のカスタムノードを1つ入れる。Dockerfile（焼き込み）と start.sh（CUSTOM_NODES）の両方から使う。
#
#   install-custom-node.sh <https の git URL> [ref] [constraints ファイル]
#
# ref は tag / branch / commit SHA のどれでもよい。省略するとリモートの HEAD になり、
# 取得する日によって中身が変わる。再現性が要るなら commit SHA を渡すこと。
#
# 依存の pip install は constraints 付きで行う。ノードの requirements.txt が
# torch を裸で要求していても、ベースの CUDA ビルドを置き換えさせないため。
# 既定は base/Dockerfile が作る /opt/torch-constraints.txt。
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "[node] usage: install-custom-node.sh <git-url> [ref] [constraints]" >&2
  exit 3
fi

url="$1"
ref="${2:-}"
constraints="${3:-/opt/torch-constraints.txt}"
COMFY_DIR="${COMFY_DIR:-/opt/ComfyUI}"

case "${url}" in
  https://*) ;;
  *)
    echo "[node] error: only https:// git URLs are accepted: ${url}"
    exit 3
    ;;
esac

name="$(basename "${url%.git}")"
target="${COMFY_DIR}/custom_nodes/${name}"
if [ -d "${target}" ]; then
  echo "[node] ${name}: already installed, skip"
  exit 0
fi

# 途中で失敗したときに、半端なディレクトリを ComfyUI に読ませない。
# 一時ディレクトリで揃えてから mv する。
tmp="${target}.tmp.$$"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${COMFY_DIR}/custom_nodes"

echo "[node] ${name}: fetching ${ref:-HEAD}"
git init -q "${tmp}"
git -C "${tmp}" remote add origin "${url}"
# fetch は commit SHA も受け付ける（GitHub は対応している）。clone --branch は SHA を取れない。
git -C "${tmp}" fetch -q --depth 1 origin "${ref:-HEAD}"
git -C "${tmp}" checkout -q FETCH_HEAD
# submodule も浅く取る。全履歴だと UltimateSDUpscale で 33MB になる（中身は 84KB）。
# 記録された commit が先端から遠いと浅い取得に失敗するので、そのときだけ全履歴で取り直す。
if [ -f "${tmp}/.gitmodules" ]; then
  git -C "${tmp}" submodule update -q --init --recursive --depth 1 \
    || git -C "${tmp}" submodule update -q --init --recursive
fi
echo "[node] ${name}: at $(git -C "${tmp}" rev-parse --short HEAD)"

if [ -f "${tmp}/requirements.txt" ]; then
  echo "[node] ${name}: installing requirements"
  python -m pip install --no-cache-dir -r "${tmp}/requirements.txt" -c "${constraints}"
fi

mv "${tmp}" "${target}"
trap - EXIT
echo "[node] ${name}: installed"
