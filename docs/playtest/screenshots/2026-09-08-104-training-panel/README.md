# #104 PR-B 训练板真实渲染留档（玩家入口·训练侧）

- 日期: 2026-09-08
- 分支: `feat/104-training-panel`
- 采集方式: **Web 导出真实链路**——`godot --headless --export-release Web` 产物由本地静态服务（正确 WASM MIME）承载，
  headless Chrome（CDP）分别模拟 **390×844@2x 竖屏** 与 **1280×720@1x 桌面**，访问 `index.html?shot=<id>`，
  轮询 `window.__DSH_SHOT_READY__` 就绪后 `Page.captureScreenshot` 像素级留档。
- 复现命令: `node scripts/capture_screens_web.mjs --out docs/playtest/screenshots/2026-09-08-104-training-panel`
- 新增场景: `?shot=training`（训练板；该模式下预派 1 人上桌，使同一张图同时呈现「可启动」与「算力档不足」两态）

## 截图清单与自证要点

| 文件 | 视口 | 场景 | 自证要点 |
| :--- | :--- | :--- | :--- |
| `portrait-390x844__training.png` | 390×844 | 训练板弹层 | 3 个基座（名称 + 工期/成本/质量/所需算力档/上桌上限/每周卡时 + 状态）：`璞石·洗尘 1b` = **可启动**（按钮可点），`玄冰·照夜 7b` / `深渊·观澜 70b` = **算力档不足**（按钮置灰 + 原因文案）；无横向溢出 |
| `desktop-1280x720__training.png` | 1280×720 | 训练板弹层 | 同上，桌面布局居中自适应 |
| `portrait-390x844__home.png` | 390×844 | 主工作台 | 工作区「训练」轻键与训练进度行在位；**Dock 仍为三键** |
| `desktop-1280x720__home.png` | 1280×720 | 主工作台 | 同上 |
| 其余 10 张 | 双视口 | home/intro/tech/report/gameover/task | 既有场景零回归（含 PR-A 的任务板） |

## 结论（Agent 逐图核对，2026-09-08）

1. **入口可见**：工作区「训练」轻键与训练进度行在双视口均可见，触控高度 ≥48px；**未动 Dock**（三键保持，GDD §13）。
2. **两态同图**：`璞石·洗尘 1b` 可启动（按钮亮）与 `玄冰/深渊` 算力档不足（按钮置灰 + 原因）在同一张图内可核，满足 ui-state-visual-mapping「禁用表现」列。
3. **元信息无死键**：行内只出现 `max_staff`（上桌上限），**未出现 `min_staff`**（DR-031/P5 本版不启用，避免给玩家看假需求）。
4. **无回归**：其余 10 张与既有留档观感一致（中文渲染、弹层尺寸、Dock 三键、任务板正常）。
