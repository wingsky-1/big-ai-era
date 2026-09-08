# #104 PR-C 决策卡真实渲染留档（决策卡接线 + 手动存档）

- 日期: 2026-09-08
- 分支: `feat/104-decision-card`
- 采集方式: **Web 导出真实链路**——`godot --headless --export-release Web` 产物由本地静态服务（正确 WASM MIME）承载，
  headless Chrome（CDP）模拟 **390×844@2x 竖屏** 与 **1280×720@1x 桌面**，访问 `index.html?shot=<id>`，
  轮询 `window.__DSH_SHOT_READY__` 就绪后 `Page.captureScreenshot` 像素级留档。
- 复现命令: `node scripts/capture_screens_web.mjs --out docs/playtest/screenshots/2026-09-08-104-decision-card`
- 新增场景: `?shot=decision`（决策卡：固定 seed 推进到事件层出卡，清掉附带面板后只留决策卡）

## 截图清单与自证要点

| 文件 | 视口 | 场景 | 自证要点 |
| :--- | :--- | :--- | :--- |
| `portrait-390x844__decision.png` | 390×844 | 决策卡（z2） | 卡面完整：标题「集群电力检修」+ 两个选项（停机维护 / 花费备用电费抢修 资金 -5k）；遮罩变暗、世界停喂；无横向溢出 |
| `desktop-1280x720__decision.png` | 1280×720 | 决策卡（z2） | 同上，桌面居中自适应 |
| `portrait-390x844__home.png` | 390×844 | 主工作台 | 工作区「接单 / 训练」轻键、训练行、Dock 三键 |
| `desktop-1280x720__home.png` | 1280×720 | 主工作台 | 同上 |
| 其余 12 张 | 双视口 | home/intro/tech/report/gameover/task/training | 既有场景零回归 |

## 结论（Agent 逐图核对，2026-09-08）

1. **决策卡可达**：修复前 `decision_pending` 是 11 个契约信号中唯一的零 emit 点（`settle_week` 无 policy 时自动选 0 号选项），
   玩家永远看不到卡；本 PR 后卡面真实渲染并阻塞世界（DR-022①「带卡不结周」）。
2. **首轮取证实测踩到孤儿 modal**：第一次采集时决策卡后面压着两张旧周报——根因是 `_active_modals` 按面板 id 覆盖，
   同 id 重复入栈会孤儿化旧实例。已修（`_on_panel_pushed` 通用回收旧实例）并加门禁
   `test_same_panel_id_push_does_not_orphan_modals`；本目录为修复后重采。
3. **无回归**：其余 12 张与既有留档观感一致（中文渲染、弹层尺寸、Dock 三键、任务板/训练板正常）。
