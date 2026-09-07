# v0.1.2 真实渲染截图留档（CJK 字体 + 竖屏内容基准）

- 日期: 2026-09-07
- 分支: `fix/v0.1.2-cjk-font-and-portrait-render`
- 采集方式: **Web 导出真实链路**——`godot --headless --export-release Web` 产物
  由本地静态服务（正确 WASM MIME）承载，headless Chrome（CDP）分别模拟
  **390×844@2x 竖屏（iPhone 12/13 逻辑视口）** 与 **1280×720@1x 桌面** 访问
  `index.html?shot=<id>`，轮询引擎就绪信号 `window.__DSH_SHOT_READY__` 后
  `Page.captureScreenshot` 像素级留档。
- 复现命令: `node scripts/capture_screens_web.mjs`（Node ≥ 22，需本机 godot 与 chrome）

## 截图清单与自证要点

| 文件 | 视口 | 场景 | 自证要点 |
| :--- | :--- | :--- | :--- |
| `portrait-390x844__home.png` | 390×844 | 主工作台 | 中文可读（非豆腐块）、无横向溢出、Dock 三键可见 |
| `portrait-390x844__tech.png` | 390×844 | 科技树弹层 | 弹层居中、宽度 ≤ 视口、滚动可用 |
| `portrait-390x844__report.png` | 390×844 | 周报弹层 | 弹层居中自适应、确认键可达 |
| `portrait-390x844__gameover.png` | 390×844 | 终局结算 | 弹层居中、文字完整 |
| `desktop-1280x720__home.png` | 1280×720 | 主工作台 | 与 v0.1.1 桌面观感一致（零回归） |
| `desktop-1280x720__tech.png` | 1280×720 | 科技树弹层 | 520×440 期望尺寸完整呈现 |
| `desktop-1280x720__report.png` | 1280×720 | 周报弹层 | 360×320 期望尺寸完整呈现 |
| `desktop-1280x720__gameover.png` | 1280×720 | 终局结算 | 文字完整、居中 |

## 结论（Agent 逐图核对，2026-09-08）

1. **中文渲染**：8/8 张截图中所有界面中文（资金/算力/声誉/周/科技树/周报/终局结算/
   按钮）全部以文泉驿微米黑正常渲染，**零豆腐块**；`‖ ✕ ● ✓` 等 UI 符号
   亦正常（原 `⏸` U+23F8 为 WQY 缺字形符号，已替换为 `‖`，见 main.tscn）。
2. **竖屏 390×844**：内容基准切换生效（480×854，缩放 ≈0.81），文字清晰可读；
   无横向溢出、无按钮遮挡；资源栏副行按 DR-009 折叠（对比桌面截图可见差异）；
   三类弹层均居中且宽度 ≤ 视口-48px，科技树滚动条可用。
3. **桌面 1280×720**：基准与 v0.1.1 完全一致（零回归），资源副行展开，
   科技树 520×440、周报 360×320 期望尺寸完整呈现且居中。

## 关联

- 修复内容: ADR-0010（CJK 字体内嵌 + 移动端内容基准切换）
- 回归门禁: `tests/unit/test_theme_font.gd`、`tests/unit/test_portrait_modal_sizing.gd`、
  `scripts/verify.sh` 资产完整性门禁
