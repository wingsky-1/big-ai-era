# #104 任务板真实渲染留档（玩家入口 P0）

- 日期: 2026-09-08
- 分支: `feat/104-task-board`
- 采集方式: **Web 导出真实链路**——`godot --headless --export-release Web` 产物由本地静态服务（正确 WASM MIME）承载，
  headless Chrome（CDP）分别模拟 **390×844@2x 竖屏（iPhone 12/13 逻辑视口）** 与 **1280×720@1x 桌面**，
  访问 `index.html?shot=<id>`，轮询 `window.__DSH_SHOT_READY__` 后就绪再 `Page.captureScreenshot` 像素级留档。
- 复现命令: `node scripts/capture_screens_web.mjs --out docs/playtest/screenshots/2026-09-08-104-task-board`
- 新增场景: `?shot=task`（任务板，本轮随 #104 加入 `SHOTS`）

## 截图清单与自证要点

| 文件 | 视口 | 场景 | 自证要点 |
| :--- | :--- | :--- | :--- |
| `portrait-390x844__task.png` | 390×844 | 任务板弹层 | 4 行任务（名称 + 工期/收入/声望/成本 + 状态）+ 3 个可用「接单」键 + 1 个置灰键（灵犀复现「未满足解锁条件」）；无横向溢出 |
| `desktop-1280x720__task.png` | 1280×720 | 任务板弹层 | 同上，桌面布局居中自适应 |
| `portrait-390x844__home.png` | 390×844 | 主工作台 | 工作区「接单」轻键可见；**Dock 仍为三键**（科技/周报/暂停，GDD §13 冻结裁决） |
| `desktop-1280x720__home.png` | 1280×720 | 主工作台 | 同上；任务进度条 + 接单轻键在位 |
| 其余 8 张 | 双视口 | home/intro/tech/report/gameover | 既有场景零回归（弹层居中、中文无豆腐块） |

## 结论（Agent 逐图核对，2026-09-08）

1. **入口可见**：工作区「接单」轻键在双视口均可见、触控高度 ≥48px，且**未动 Dock**（Dock 三键保持，符合 GDD §13）。
2. **拒绝分支可见**：`灵犀复现` 行显示「未满足解锁条件」且接单键置灰——满足 ui-state-visual-mapping「禁用表现」列要求。
3. **首轮踩坑（已修，并加门禁锁死）**：首次采集时接单按钮**空白**——根因是 L2 `get_task_board_view()` 漏返回 `accept_label` 文案键
   （L3 拿不到键 → 空按钮）。修复后重采本目录截图；新增门禁 `test_panel_buttons_have_labels` 防复发。
4. **无回归**：其余 10 张与 v0.1.2 留档观感一致（中文渲染、弹层尺寸、Dock 三键）。
