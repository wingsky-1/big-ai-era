#!/usr/bin/env bash
# 本地一键自验证（与 CI 完全同一命令，CI 只是本脚本的远程回放）。
# 用法: bash scripts/verify.sh
#
# 步骤:
#   1. 静态检查: gdformat --check + gdlint（若工具可用）
#   2. 引擎导入校验: godot --headless --import --quit（暴露 UID/场景破损）
#   3. GUT 单元测试: 任何断言失败 => 进程退出非 0
#      防假绿兜底: 还要求输出中出现 "All tests passed" 且 Tests 数 >= 1，
#      防御 GUT 因脚本解析失败整体跳过却仍退出 0 的路径。
set -euo pipefail

cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-godot}"
command -v "$GODOT_BIN" >/dev/null 2>&1 \
    || GODOT_BIN="${HOME}/.local/bin/godot"
command -v "$GODOT_BIN" >/dev/null 2>&1 \
    || { echo "[verify] 错误: 未找到 godot，请先运行 bash scripts/setup_env.sh"; exit 1; }

GUT_CMDLINE="res://addons/gut/gut_cmdln.gd"
GUT_ARGS=(-gdir=res://tests -ginclude_subdirs -gexit)

step() { printf '\n\033[1;34m[verify]\033[0m==> %s\n' "$*"; }

IMPORT_LOG="$(mktemp)"
GUT_LOG="$(mktemp)"
trap 'rm -f "$IMPORT_LOG" "$GUT_LOG"' EXIT

# ---------- 1. 静态检查 ----------
step "静态检查 (gdformat --check + gdlint)"
if command -v gdformat >/dev/null 2>&1 && command -v gdlint >/dev/null 2>&1; then
    gdformat --check src tests
    gdlint src tests
else
    echo "[verify] 跳过（gdformat/gdlint 未安装；可运行 scripts/setup_env.sh --with-lint）"
fi

# ---------- 2. 引擎导入校验 ----------
step "引擎导入校验 (暴露 UID 丢失/场景破损/资源损坏)"
if ! "$GODOT_BIN" --headless --import --quit >"$IMPORT_LOG" 2>&1; then
    cat "$IMPORT_LOG"
    echo "[verify] 导入进程非零退出"
    exit 1
fi
if grep -qiE "SCRIPT ERROR|ERROR:" "$IMPORT_LOG"; then
    grep -iE "SCRIPT ERROR|ERROR:" "$IMPORT_LOG" | head -10
    echo "[verify] 导入阶段存在 ERROR（常见原因: autoload 解析失败/资源断链），见上方"
    exit 1
fi

# ---------- 3. GUT 单元测试 ----------
step "GUT 单元测试 (headless)"
# GUT 个别路径（如测试脚本解析失败整体跳过）会退出 0 造成假绿，
# 因此 tee 输出做双重断言：进程退出码 + "All tests passed" + Tests>=1。
set +e
"$GODOT_BIN" --headless --audio-driver Dummy \
    -s "$GUT_CMDLINE" "${GUT_ARGS[@]}" 2>&1 | tee "$GUT_LOG"
GUT_EXIT="${PIPESTATUS[0]}"
set -e
if [[ "$GUT_EXIT" -ne 0 ]]; then
    echo "[verify] GUT 进程退出码 $GUT_EXIT"
    exit 1
fi
if ! grep -q "All tests passed" "$GUT_LOG"; then
    echo "[verify] 未检测到 'All tests passed'（可能存在被跳过的测试脚本），判定失败"
    exit 1
fi
if ! grep -Eq "Tests +[1-9]" "$GUT_LOG"; then
    echo "[verify] GUT 汇总 Tests 数为 0（没有任何测试被执行），判定失败"
    exit 1
fi

printf '\n\033[1;32m[verify]\033[0m全部通过 ✔\n'
