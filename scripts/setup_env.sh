#!/usr/bin/env bash
# 开发环境自举脚本：安装本地自验证所需的引擎与静态检查工具。
# 用法: bash scripts/setup_env.sh [--with-lint]
#   --with-lint  同时安装 gdtoolkit（gdformat/gdlint，需要 python3 + pip）
#
# 安装内容：
#   1. Godot headless（GODOT_VERSION 指定版本）到 ~/.local/bin
#   2. （可选）gdtoolkit 静态检查工具
set -euo pipefail

# ---------- 可配置参数（可用环境变量覆盖） ----------
GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
GODOT_INSTALL_DIR="${HOME}/.local/bin"
GODOT_BIN_NAME="${GODOT_BIN_NAME:-godot}"

log() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[setup] 错误:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 1. 安装 Godot headless ----------
GODOT_ARCHIVE="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ARCHIVE}"

# 跨环境解压：优先 unzip，回退 7z / python zipfile（部分精简系统无 unzip）
unzip_any() {
    local archive="$1" dest="$2"
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$archive" -d "$dest"
    elif command -v 7z >/dev/null 2>&1; then
        7z x -y -o"$dest" "$archive" >/dev/null
    else
        python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
            "$archive" "$dest"
    fi
}

if command -v "$GODOT_BIN_NAME" >/dev/null 2>&1; then
    INSTALLED_VERSION="$("$GODOT_BIN_NAME" --version 2>/dev/null || echo 'unknown')"
    # 版本比对：已安装版本与请求版本不符时覆盖升级（官方版本串形如 4.7.2.stable.official.xxx）
    case "$INSTALLED_VERSION" in
        "${GODOT_VERSION/-/.}"*|*"${GODOT_VERSION}"*)
            log "Godot 已存在且版本匹配: $INSTALLED_VERSION"
            exit 0
            ;;
        *)
            log "检测到版本不匹配 (已装: $INSTALLED_VERSION, 请求: $GODOT_VERSION)，覆盖安装..."
            ;;
    esac
fi

log "下载 Godot ${GODOT_VERSION} ..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fL --retry 3 -o "${TMP_DIR}/godot.zip" "$GODOT_URL" \
    || die "Godot 下载失败: $GODOT_URL"
unzip_any "${TMP_DIR}/godot.zip" "$TMP_DIR"
mkdir -p "$GODOT_INSTALL_DIR"
install -m 755 "${TMP_DIR}/Godot_v${GODOT_VERSION}_linux.x86_64" "${GODOT_INSTALL_DIR}/${GODOT_BIN_NAME}"
log "Godot 已安装: ${GODOT_INSTALL_DIR}/${GODOT_BIN_NAME} ($("$GODOT_BIN_NAME" --version))"
case ":${PATH}:" in
    *":${GODOT_INSTALL_DIR}:"*) ;;
    *) log "提示: 请确保 ${GODOT_INSTALL_DIR} 在 PATH 中（通常 ~/.profile 已包含）" ;;
esac

# ---------- 2. 可选：安装 gdtoolkit ----------
if [[ "${1:-}" == "--with-lint" ]]; then
    if command -v gdformat >/dev/null 2>&1 && command -v gdlint >/dev/null 2>&1; then
        log "gdtoolkit 已存在: $(gdformat --version 2>/dev/null | head -1)"
    else
        log "安装 gdtoolkit 4.3.4 ..."
        # PEP 668 环境（Ubuntu 23.04+/Debian 12+）会拒绝 --user 安装，
        # 依次尝试: pipx（推荐）-> pip --user（带 --break-system-packages 兜底）
        if command -v pipx >/dev/null 2>&1; then
            pipx install "gdtoolkit==4.3.4" \
                || die "pipx 安装 gdtoolkit 失败"
        elif pip3 install --user "gdtoolkit==4.3.4" 2>/dev/null; then
            log "gdtoolkit 已通过 pip --user 安装"
        else
            pip3 install --user --break-system-packages "gdtoolkit==4.3.4" \
                || die "gdtoolkit 安装失败，请确认 python3/pip 可用"
        fi
        log "gdtoolkit 安装完成（可执行文件在 ~/.local/bin）"
    fi
fi

log "环境自举完成。运行 bash scripts/verify.sh 开始本地自验证。"
