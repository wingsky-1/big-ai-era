# Handoff — #104 玩家入口三段落地（PR #108/#109/#110）→ 下一会话：**v0.1.5 试玩轮次 + `[P]` 勾选**

> 日期：2026-09-08 ｜ 本会话：v0.1.5 收尾验收（#82/scripts.md/ADR-0016）+ **P0 玩家入口三段（#104）**
> 下一会话焦点：**打 tag `v0.1.5` 交付试玩构建 → 按 `docs/playtest/scripts.md` 跑 13 个 `[P]` → 回写勾选 + 归档**
>
> **本会话最大发现**：13 单 `[T]` 100% 达成、verify 全绿、ADR 齐全，但**玩家玩不到核心循环**——`enqueue_task`/`start_training` 在 `src/ui/**` 零调用方、`decision_pending` 是 11 个契约信号中唯一的零 emit 点。三段已全部补齐。

---

## 一、本会话已完成（7 个 PR，全部合并 main@`178ca59`）

| 项 | PR | 要点 | verify |
|---|---|---|---|
| #82 短单局收尾 | [#99](https://github.com/wingsky-1/big-ai-era/pull/99) | 自由期三线 + 终局屏 + summary 六项 + 5 个 [T] 用例 | 45/244/14687 |
| #100 试玩脚本资产 | [#105](https://github.com/wingsky-1/big-ai-era/pull/105) | `docs/playtest/scripts.md`（13 锚点 + 七段）+ 门禁用例 | 46/248/14829 |
| ADR-0016 补建 | [#106](https://github.com/wingsky-1/big-ai-era/pull/106) | L2 数据面契约（R1–R6）+ 遗留归 #103 | 45/244/14687 |
| 交接 017 | [#107](https://github.com/wingsky-1/big-ai-era/pull/107) | 完成定义核对 + P0 风险 | — |
| **#104 PR-A 任务板** | [#108](https://github.com/wingsky-1/big-ai-era/pull/108) | 接单入口 + L2 数据面 + 工作区 `active_task` 可见性 + 去重 + **#101** | 48/260/15704 |
| **#104 PR-B 训练板** | [#109](https://github.com/wingsky-1/big-ai-era/pull/109) | 训练入口 + 训练进度可见性 + `min_staff` 死键不进视野 | 50/270/16587 |
| **#104 PR-C 决策卡** | [#110](https://github.com/wingsky-1/big-ai-era/pull/110) | 决策卡接线 + 手动存档 + **孤儿 modal 修复** + 契约可达性门禁 | 52/278/16843 |

**当前 main 基线**：`178ca59`，`bash scripts/verify.sh` = **52 scripts / 278 tests / 278 passing / 16843 asserts 全绿**（约 50s）。

---

## 二、#104 三段解决了什么（含连带缺陷）

| 缺陷 | 症状 | 修复 |
|---|---|---|
| **P0-1** 接任务无入口 | `enqueue_task` 在 `src/ui/**` 零调用方 → 新开局约 W6 破产 | 工作区「接单」→ z1 任务板（PR-A） |
| **P0-2** 开训练无入口 | `start_training` 零调用方 → 训练/出分/命名/竞对/封顶全不可达 | 工作区「训练」→ z1 训练板（PR-B） |
| **P0-3** 决策卡永不显示 | `decision_pending` **零 emit 点**；`settle_week` 无 policy 时自动选 0 号并清卡 | 一律入 pending + 广播；presenter 推 z2（PR-C） |
| **P0-4** 接单后工作区不显示任务 | `_workspace_view` 缺 `active_task` 键 → 恒显"当前无进行中任务"、进度条恒 0 | 补键 + 任务/资金/周结信号刷新（PR-A） |
| **P0-5** 训练启动后无显示 | `main.gd` 完全不渲染 `training` → 10–26 周黑箱 | 工作区训练行（名称 + 剩余周 + 进度条）（PR-B） |
| **P0-6** 重复接单刷钱 | `TaskQueue.enqueue` 无去重；每次点击先扣 cost → 连点 N 次 = N 倍收入 | 去重（进行中/已排队拒绝）（PR-A） |
| **#101** 资金转负即断流 | 资金门连 `cost=0` 也拒 → 零成本任务也接不了 | 资金门只对 `cost > 0` 生效（PR-A） |
| **孤儿 modal** | 同 id 重复入栈覆盖 `_active_modals` → 旧实例永挂屏上 | `_on_panel_pushed` 通用回收旧实例（PR-C） |

**防复发门禁**（新增）：`test_contract_reachability.gd`（11 信号 emit 点 / 12 命令 UI 调用点 / 12 面板挂载点）、两个面板的"按钮文案非空"回归锁、孤儿 modal 回归锁、`test_playtest_scripts.gd`（锚点/七段/数值对账）。

**渲染证据**：`docs/playtest/screenshots/2026-09-08-104-{task-board,training-panel,decision-card}/`（Web 导出 + headless Chrome，双视口共 42 张；新增 `?shot=task|training|decision`）。

---

## 三、v0.1.5 完成定义核对（更新）

| # | 完成定义 | 结论 |
|---|---|---|
| 1 | 13 单合并 | ✅ 全 CLOSED（+ #100 试玩资产单） |
| 2 | `[T]` 100% 勾选 | ✅ 52 项全勾 |
| 3 | verify 全绿 | ✅ 52/278/16843 |
| 4 | 同 seed 万周双跑哈希一致 | ✅ `test_same_seed_hash_stable_after_data_migration` |
| 5 | 短单局专项 | ✅ `[T]`；`[P]` 待试玩（功能已可达） |
| 6 | ADR-0011~0016 齐全 | ✅ |

**产品侧**：13 单的 `[P]` **功能已全部可执行**（7 个此前阻塞的锚点随 PR #108/#109/#110 解锁），但**尚未真人试玩** → `[P]` 仍 0/13 勾选。

---

## 四、下一步（下一会话）

1. **打 tag `v0.1.5`**（需制作人确认）→ CI 三端构建 + Release + Pages → 拿到可试玩构建。
2. 按 `docs/playtest/scripts.md` 排试玩轮次（建议顺序：`#RE-02` → `#RT-01` → `#RC-02` → `#RP-02` → `#RU-02` → `#REV-03` → `#RK-04`/`#RK-06` → `#RR-02` → `#RS-05` → `#RF-02`；`#批0`/`#V1-04` 需对照构建/PR-γ）。
3. 试玩通过后：勾选 `[P]` + 归档 `docs/playtest/2026-09-08-v015-feedback.md`（`scripts.md` §5 有记录模板与回写纪律）。
4. 遗留按需：**#111**（读档入口，需先裁契约路径与存档槽策略）/ **#102**（toast 文案键）/ **#103**（ADR-0016 收口）/ L5（`game_world.gd` 已 1474 行，建议拆类）。

---

## 五、遗留清单（更新）

| # | 遗留 | 建议 |
|---|---|---|
| **L1** | **试玩轮次未跑**：13 单 `[P]` 0/13 | 打 tag → 试玩 → 勾选（§四） |
| **L2** | **读档入口缺失** | 已立 **#111**（含"启动期覆盖旧档"与"读档后 HUD 不刷新"两个坑的处置要求） |
| **L3** | 复现线死亡螺旋 | **#101 已在 PR #108 修复**（资金门只对 cost>0 生效）；`TaskQueue` 侧无遗留 |
| **L4** | `naming_sensitive_reject` 文案键缺失 + `ui_display.json` 双轨 | **#102**（未动） |
| **L5** | **`game_world.gd` 已 1474 行**（三段又 +175；靠 `# gdlint:disable` 豁免） | 后续单**必须**拆类；建议下一批先做 `report_builder` / `view_builders` 拆分 |
| **L6** | 无 tag/Release → 人类无试玩构建 | §四第 1 步 |
| **L7** | 封顶周次口径三处不一致（W54/W61/W89/W81） | `scripts.md` 已不绑定周次；数值席收口 |
| **L8** | 每周结自动弹 z2 周报（160 周 = 160 次；长帧跨周还可能连弹多张） | `scripts.md` C-7；建议立单收敛（≥5% 显著变化才弹，映射表 V1-06 规划未落地） |
| **L9** | 任务池 RP 密度趋同（37.5/37.5/36.7/35 RP/周） | `scripts.md` C-11；v0.2 复议（触供给带需重算） |
| **L10** | ADR-0016 三项收口（决策③ 调试入口 / L3 直读内部字段 / R6 门禁 4/15 文件） | **#103** |
| **L11** | `AutoTaskPolicy` 注释仍写旧 income（33000/4 周），#80 已改 60000/4 周 | 顺手修 |
| **L12** | 竞对 L1–L3 未重标（35/58/75） | 只改 `rivals.json`，非阻塞 |

---

## 六、本会话踩坑记录（新增 8 条，下会话直接复用）

| # | 坑 | 结论 |
|---|---|---|
| 1 | **PR 与 main 冲突时 GitHub 不跑 CI**（`gh pr checks` = "no checks reported"，runs 计数 0） | 先 `git merge origin/main` 解冲突再 push，CI 才会触发 |
| 2 | **数据面漏返回文案键 → 按钮空白**（渲染取证实测） | `get_task_board_view()` 漏 `accept_label` → 接单键无字；已加门禁 `test_panel_buttons_have_labels`（断言按钮文案非空且来自 L2） |
| 3 | **同 id 重复入栈孤儿化 modal** | `_active_modals` 按 id 覆盖 → 旧实例永挂屏上；`_on_panel_pushed` 先回收旧实例；门禁 `test_same_panel_id_push_does_not_orphan_modals` |
| 4 | **决策卡改为"入 pending"后打破 6 个无 policy 长跑用例** | `simulate_weeks` 遇 pending 即 break；修法：长跑注入 `AutoDecisionPolicy`（与原"自动选 0"逐位一致，数值断言不变） |
| 5 | **`PackedStringArray` 与 `Array` 断言不相等** | 逐元素 `str()` 比对，或两侧同类型 |
| 6 | **新 `class_name` 未注册** | 新建脚本后必须 `godot --headless --import --quit` 生成 `.uid` 并提交，否则 `Could not find type` |
| 7 | **JSON 冲突手工解**：闭合括号常落在冲突公共上下文 | 解完 `json.load` 验一遍（缺 `}` / 尾逗号 / 缺逗号三连都踩过） |
| 8 | **枚举显式值触发 #71 数值门禁** | 用隐式枚举值（白名单只有 0/1/-1）；新增枚举项**追加到末尾**避免隐式值位移 |
| 9 | **`user://` 按 verify 运行隔离、按用例复用** | 断言"无存档"前先删文件（`DirAccess.remove_absolute(ProjectSettings.globalize_path(...))`） |
| 10 | **截图管线需先导出再采集** | `capture_screens_web.mjs` 第一步 `--import` 时 PNG 还不存在 → 新截图目录的 `.import` 需在采集后再跑一次 import 才会生成 |

---

## 七、下个会话唤起 Prompt（复制直接发送）

```markdown
你是《大 AI 时代》项目（Godot 4.7.2 + GUT，仓库 /home/tangyi/dev/game/big-ai-era）的**主程序席兼实施协调者**。
上一会话完成 v0.1.5 收尾验收 + P0 玩家入口三段（#104）：PR #99/#105/#106/#107/#108/#109/#110 全部合并 main@178ca59，
verify 52/278/16843 全绿，13 单 [T] 100% 勾选，[P] 0/13（功能已可达，待真人试玩）。

## 先读
1. `docs/discussion/handoffs/2026-09-08-018-player-entry-handoff.md`（本交接：三段交付 + 踩坑 10 条 + 遗留 L1–L12）
2. `docs/playtest/scripts.md`（13 单 [P] 验收脚本；§0.5 能力边界已更新为"接单/训练可达"）
3. `docs/discussion/handoffs/2026-09-08-016-v015-closeout-handoff.md` §4（硬约束与参数组）
4. `AGENTS.md` + `docs/standards/{code-style,testing,scene-asset}.md`

## 任务（按序）
1. **打 tag `v0.1.5`**（制作人确认后）→ CI 三端构建 + Release + Pages。
2. 按 `docs/playtest/scripts.md` 排试玩轮次；`[P]` 通过后勾选 + 归档 `docs/playtest/2026-09-08-v015-feedback.md`。
3. 试玩反馈走 `gd-playtest-intake` 分诊 → 修复单。
4. 按需处置遗留：**#111**（读档入口）/ **#102**（toast 文案键）/ **#103**（ADR-0016 收口）/ L5（`game_world.gd` 1474 行拆分）。

## 硬约束
Σrp_cost 14210 禁调；RP 供给带 [4910,6810)；竞对 L4 ∈[93,98] 禁超玩家；卡时=周预算；
`base.cost` 即全程卡时费；存档零迁移；RNG 消费点 3 处；**Dock 保持三键**（GDD §13 冻结裁决）。

## 每批结束给四行汇报
`批次 / verify / 断言（新增 [T] 数 + 勾选 [P] 数）/ 风险`
```

---

## 八、持久事实源

- **main**：**`178ca59`**（本会话 7 个 squash：`ffce0f3` → `0dc37ea` → `889bdad` → `de2eabb` → `713a9e9` → `7098291` → `178ca59`）。
- **verify**：**52 scripts / 278 tests / 278 passing / 16843 asserts**。
- **issue**：v0.1.5 13 单 + #92 + #100 全 CLOSED；新立 **#101**（已随 PR #108 修复，待关）、**#102**、**#103**、**#104**（三段完成，`[T]` 已勾、`[P]` 待试玩）、**#111**（读档）。
- **ADR**：0001–0016 齐全。
- **试玩资产**：`docs/playtest/scripts.md`（1487 行）+ 三个截图留档目录（`2026-09-08-104-*`）。
- **worktree**：`/home/tangyi/dev/game/wt-82`（已合并，可清理）。
- **分支**：本会话分支均已随 squash 合并删除。
