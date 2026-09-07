#!/usr/bin/env bash
# 多平台导出脚本（本地与 CI 共用）。
# 用法: bash scripts/export_all.sh [windows|linux|web|all] [输出目录]
#
# 依赖: godot 在 PATH（或 GODOT_BIN 指定）；
#       导出模板需位于 ~/.local/share/godot/export_templates/<version>/
#       （本地可手动从 godotengine.org 安装；CI 由 workflow 自动下载）。
set -euo pipefail

TARGET="${1:-all}"
OUT_DIR="${2:-build}"

GODOT_BIN="${GODOT_BIN:-godot}"
command -v "$GODOT_BIN" >/dev/null 2>&1 \
    || GODOT_BIN="${HOME}/.local/bin/godot"
command -v "$GODOT_BIN" >/dev/null 2>&1 \
    || { echo "[export] 错误: 未找到 godot，请先运行 bash scripts/setup_env.sh"; exit 1; }

# 引擎版本串形如 4.7.2.stable.official.xxx，去掉 .official 尾巴
# 得到导出模板目录名 4.7.2.stable（与 export_templates/ 下实际目录一致）
GODOT_VERSION="$("$GODOT_BIN" --version | sed 's/\.official.*//')"
echo "[export] Godot 版本: $GODOT_VERSION"

cd "$(dirname "$0")/.."
mkdir -p "$OUT_DIR"

step() { printf '\n\033[1;34m[export]\033[0m==> %s\n' "$*"; }

# 先做一次无头导入，保证资源注册完整
"$GODOT_BIN" --headless --import --quit >/dev/null 2>&1 || true

export_one() {
    local preset_name="$1" export_path="$2"
    step "导出 ${preset_name} -> ${export_path}"
    mkdir -p "$(dirname "$export_path")"
    "$GODOT_BIN" --headless --export-release "$preset_name" "$export_path"
}

case "$TARGET" in
    windows) export_one "Windows Desktop" "${OUT_DIR}/windows/big-ai-era.exe" ;;
    linux)   export_one "Linux"           "${OUT_DIR}/linux/big-ai-era.x86_64" ;;
    web)     export_one "Web"             "${OUT_DIR}/web/index.html" ;;
    all)
        export_one "Windows Desktop" "${OUT_DIR}/windows/big-ai-era.exe"
        export_one "Linux"           "${OUT_DIR}/linux/big-ai-era.x86_64"
        export_one "Web"             "${OUT_DIR}/web/index.html"
        ;;
    *) echo "[export] 用法: $0 [windows|linux|web|all] [输出目录]"; exit 1 ;;
esac

printf '\n\033[1;32m[export]\033[0m完成。产物位于 %s/\n' "$OUT_DIR"
