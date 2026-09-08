# 2026-09-08 试玩反馈处理归档（v0.1.3）

## 原始反馈（人类试玩，v0.1.2 Pages 在线版）

> "没有初始员工呢 也没有背景介绍和新手引导"

## 分诊（gd-playtest-intake）

| # | 反馈 | 类别 | 定性 |
| :-- | :-- | :-- | :-- |
| 1 | 没有初始员工 | Bug（表达层） | 数据链路完好（opening.json 三研究员已入 roster），双层表达缺陷 |
| 2 | 无背景介绍/新手引导 | 表达缺失 | 文案真源齐备（opening_line_* 四句）无 UI 承载；GDD DR-029 D-3 已裁决形式 |

## 还原与根因

### 反馈①（Bug，双层根因）

1. `dashboard_presenter._workspace_view` 写键 `staff`，`main.gd::_update_views`
   读键 `staff_assigned`（不存在的键）→ `.size()` 恒 0；
2. `GameWorld.assign_staff/unassign_staff` 成功后不发任何信号 → 即使键名正确，
   指派后 UI 也永不刷新。

### 反馈②（表达缺失）

`texts.json` 的 `opening_line_intro/goal/rival/hint` 与 `naming_*` 系列键在
PR1 文本管线时已入库；GDD DR-029 D-3 裁决开场白"首局压缩、可跳过、不拦流淌"。
v0.1.2 之前没有任何 UI 消费 opening_line_*。

## 处理（PR #69，v0.1.3）

1. 员工三口径 `staff_total/assigned/idle`（Presenter 统计）+ 主台双标签
   「在岗研究员: 0/3人 ｜ 待命： 3人」；`assign/unassign` 广播 `resources_changed`。
2. 新增 `INTRO` 弹层（z1 常规层，不拦流淌）：四句开场白全走 TextService +
   「开始经营」按钮；仅启动推入一次。
3. W0 表达改「准备周」。
4. 随案重构：面板栈面板 id/层级枚举化（PanelId/Layer，用户裁决）。

## 验证证据

- GUT：178/178（新增 4 用例：三口径 / INTRO z1 不停喂 / 文案渲染 / 推入接线）
- 截图：`docs/playtest/screenshots/2026-09-08-v0.1.3/`（2 视口 × 5 场景，
  `*__home` 实证「0/3人｜待命 3人｜准备周」，`*__intro` 实证引导弹层）
- 交互自测：`2026-09-08-v0.1.3-selftest/` 8/8（真实鼠标事件走完开局流程）

## 遗留

- 反馈中"新手引导"的进阶形态（锚定气泡/博导手记，GDD §引导 DR-029 D-5）属
  v0.2 范围，本版仅交付开场白层。
- #67 暂停菜单面板缺失（交互自测顺带取证）另行跟踪。
