#!/usr/bin/env bash
# 批7.3 #190 导出物校验：Web 构建产物完整性与信标可达性（CI/本地同命令）。
# 用法: bash scripts/export_html_check.sh [输出目录]
# 依赖: godot + 导出模板（export_all.sh 同款）；产物契约：
#   index.html / index.wasm / index.pck 三件套存在且非零字节。
set -euo pipefail

OUT_DIR="${1:-build/web}"
GODOT_BIN="${GODOT_BIN:-godot}"

echo "[html-check] 导出 Web 构建 -> ${OUT_DIR}"
bash scripts/export_all.sh web "$OUT_DIR" >/dev/null 2>&1

# 实际产物在 ${OUT_DIR}/web/（export_all.sh 的 Web preset 输出目录）
ARTIFACT_DIR="${OUT_DIR}/web"
for f in index.html index.wasm index.pck; do
    if [ ! -s "${ARTIFACT_DIR}/${f}" ]; then
        echo "[html-check] 致命: 缺产物 ${ARTIFACT_DIR}/${f}"
        exit 1
    fi
    echo "[html-check] OK: ${f} ($(stat -c%s "${ARTIFACT_DIR}/${f}") bytes)"
done

# 信标可达性：main.gd 含 Web 调试信标（?shot= 启用；截图管线轮询）
if ! grep -q "__DSH_SHOT_READY__" src/ui/main/main.gd; then
    echo "[html-check] 致命: main.gd 缺 __DSH_SHOT_READY__ 信标"
    exit 1
fi
echo "[html-check] OK: 信标就绪"
echo "[html-check] 全部通过 ✔"
