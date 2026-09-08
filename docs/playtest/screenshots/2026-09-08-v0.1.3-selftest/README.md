# v0.1.3 Web 构建交互体验自测（真实鼠标事件）

- 日期: 2026-09-08
- 方式: 本地 `godot --headless --export-release Web` 构建产物，headless Chrome（CDP）
  模拟 **390×844@2x 竖屏**，派发真实 `Input.dispatchMouseEvent` 鼠标事件走完整
  玩家流程；断言依据面板栈信标 `window.__DSH_PANEL_STATE__`（确定性），且每步
  以 `waitForDepth` 等待状态收敛（杜绝单帧时序误判），关键步骤截图留档。
- 复现: 重导出 `build/web/` 后 `node scripts/selftest_web.mjs`
- 结果: **8/8 通过**（v0.1.3 新增 S0 开场引导步骤）

## 步骤与结果

| 步骤 | 操作 | 断言 | 结果 |
| :--- | :--- | :--- | :--- |
| S0 | 加载页面 | 开场引导自动弹出（z1，深度 1） | ✅ |
| S1 | 点击「开始经营」 | 面板栈清空 | ✅ |
| S2 | 点击 Dock「科技」 | 面板深度 1 | ✅ |
| S3 | 点击弹层「✕」 | 面板栈清空 | ✅ |
| S4 | 点击 Dock「周报」 | 面板深度 1 | ✅ |
| S5 | 点击「确认」 | 面板栈清空 | ✅ |
| S6 | 点击 Dock「暂停」 | #67 取证（depth=1 + 无面板） | ✅ |
| S7 | 点击遮罩 | 面板栈清空 | ✅ |

## #67 现场证据（S6 截图）

`depth=1`（PANEL_PAUSE_MENU 成功入栈）+ 截图仅遮罩无菜单面板。代码根因见 issue #67。
S7 证明遮罩点击可退出、无死锁。

## 截图清单

- `S0-intro.png` 开场引导（四句文案 + 开始经营）
- `S1-home.png` 主工作台（准备周 / 0/3人 / 待命 3人）
- `S2-tech-open.png` 科技树（432 逻辑宽收敛）
- `S4-report-open.png` 周报弹层
- `S6-pause-issue67.png` #67 现场
