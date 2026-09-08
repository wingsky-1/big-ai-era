# Handoff — v0.1.5 实施轮（P1–P3 完成）→ 下一会话：**P4 串行数值链 + 剩余并行单**

> 日期：2026-09-08 ｜ 本会话：主程序席按 v0.1.5 的 13 张单实施（P1–P3 + 并行窗口 #67/#78）
> 下一会话焦点：**P4（#75 → #76 → #80 串行数值链）**，并在依赖满足处并行分派 #79/#81/#82
>
> **更新（会话末）**：#78 已由子 agent 交付并合并（PR #90）→ 已完成 7 单，剩余 6 单；main@9df9992，verify 41 scripts / 207 tests / 207 passing / 11807 asserts 全绿。

---

## 一、已完成（5 单 + 1 基础设施，全部已合并 main）

| 单 | PR | 交付要点 | verify |
|---|---|---|---|
| **#71** 批0 数值数据化 | [#83](https://github.com/wingsky-1/big-ai-era/pull/83) | K/θ/k/m/指数 → `benchmarks.json`；`techs.json` 加 `total_nodes/pity/domain_flags/opening_researchable`；`clock.json.ticks_per_week` 死键收口；19 处默认值删除；`naming.json` 新表；表现层 54 处 `# num-ok` 豁免；4 个门禁用例；ADR-0013 | 35/182 |
| **#84** verify 隔离（本会话新立） | [#86](https://github.com/wingsky-1/big-ai-era/pull/86) | `verify.sh` 导出 `XDG_DATA_HOME=$(mktemp -d)` + trap 清理，消除多 worktree 并发假失败 | 36/183 |
| **#67** 暂停菜单面板 | [#85](https://github.com/wingsky-1/big-ai-era/pull/85) | `PAUSE_MENU` 挂载分支 + `pause_menu_dialog`（继续/重开/设置）+ Esc/遮罩/幂等；子 agent 交付，主程序席已抽查证据并合并 | 37/186 |
| **#72** 收入口径改占槽 | [#87](https://github.com/wingsky-1/big-ai-era/pull/87) | 脉冲源退役；周结步序重排（任务结算→固定支出→ledger→破产判定→账期翻页）；周报 `rows` + `get_last_report()`；删第 4 随机消费点 + 读档不重抽 jitter；ADR-0015 | 40/196 |
| **#74** 买卡命令 + 周预算 | [#87](https://github.com/wingsky-1/big-ai-era/pull/87) | 命令面 11→12；`weekly_supply` 8/16/32/64；资源栏买卡按钮；训练每周占用卡时（不过账 money）；周供给不足拒绝；ADR-0011 | 40/196 |
| **#73** Σeff + 多人上桌 | [#88](https://github.com/wingsky-1/big-ai-era/pull/88) | `_slots` 改多人集合、`get_research_eff` 改 Σ、`get_slot_occupants` 新增、存档形状不变；`max_staff` 1/2/3 + 上桌校验 | 40/200 |
| **#78** 呈现层 | [#90](https://github.com/wingsky-1/big-ai-era/pull/90) | L2 四只读数据面（forecast/staff_view/domain_progress/rival_view）+ 四支撑面；`snapshot_codec` 删死代码；`dashboard_presenter` 改消费 L2；新建 `naming_dialog` + 资源栏预告副行；新建 `ui_display.json`；ADR-0016 | 41/207 |

**当前 main 基线**：`9df9992`，`bash scripts/verify.sh` = **41 scripts / 207 tests / 207 passing / 11807 asserts 全绿**（约 45s）。

**已创建 ADR**：`0013`（数值数据化边界）、`0011`（算力周预算）、`0015`（周结步序与账期契约）。
**待创建**：`0012`（RP 供给真源，随 #76）、`0014`（谓词单点真源，随 #81）。（`0016` 已随 #78 创建。）

---

## 二、进行中

**无**（#78 已合并）。

---

## 三、未完成（6 单，含 2 张 p0-critical-path）

```
【P4 串行数值链（同一会话内顺序执行，不可乱序）】
#75 事件闸（p_week + 冷却 + 预算闸）   ← 依赖 #72 ✅
 └→ #76 RP 供给标定 + cum_influence     ← 依赖 #73 ✅ / #75
     └→ #80 任务池联标（income + rp_output + 固定运维）  ← 依赖 #72 ✅ / 与 #76 互为输入

【P5】
#81 科技树口径收口（域计数 n/14）  ← 依赖 #76（可并行分派）
#77 竞对死表重标 + 竞对条修复      ← 依赖 #73 ✅ / #76 / #80

【P6】
#79 饱和护栏 + θ/k 参数通路        ← 依赖 #71 ✅ / #73 ✅ → **可立即并行分派**
#82 短单局收尾（三线 + 终局屏 + summary 六项）  ← 依赖 #76 / #80
```

**建议下一步**：
1. **立即并行分派 #79**（依赖已满足；改动面 `benchmarks.json`/`score_math`/`stages`/`training_project`，与 P4 不重叠）；
2. 主程序席串行做 **#75 → #76 → #80**；
3. #76 合并后分派 **#81**；#80 合并后做 **#77** 与分派 **#82**。

### 3.1 #78 遗留（需下会话处置，均不阻塞 P4）

| # | 遗留 | 建议 |
|---|---|---|
| L1 | **`docs/playtest/scripts.md` 在 main 上不存在**，而 13 张单的 `[P]` 验收点都引用它（如 `#RU-02`/`#RE-02`） | **需裁决**：从 `docs/discussion/2026-09-08-v1-requirements.md` 各模块的"试玩脚本"段提取，新建该流程资产（否则 `[P]` 无法按脚本验收）。属试玩席职责，可立 issue |
| L2 | #78 新建 `src/data/ui_display.json` 承载 UI 文案键（未动 `texts.json`） | 另立收口 issue：统一迁入 `texts.json`（需同步 `test_texts.gd` TEST_KEYS + `test_data_loader.gd` + `test_main_scene_smoke.gd` 三处键数） |
| L3 | 显示分级阈值 t2/t3/t4 = 35/58/75 锚 `rivals.json` 深巷 L1/L2/L3 发版分 | 可接受（json 内 `_comment` 已注明出处）；#77 重标竞对时需同步复核该阈值 |
| L4 | `tech_tree_dialog` 域口径已按真实域修正（5 mainline 域 + 总探明 n/14） | #81 的范围相应缩小为"每域 ≥1 可达 + 分母一致性断言" |

---

## 四、下个会话必须知道的硬约束与参数

### 4.1 红线（不变）

1. 无 issue 不合码（PR body 引用 issue）；2. `bash scripts/verify.sh` 全绿才可汇报；
3. 分层单向 L0→L4 / 核心逻辑 RefCounted / 数值进 `src/data/` / autoload 禁 `class_name` / `.tscn` 禁 merge=union；
4. 存档零迁移（`staff.assigned` 保持 `staff→slot`；事件冷却新增 `cooldowns` 键，不改 `fired`）；
5. 账期契约（非周结过账计入当前未结算周）+ 破产判定在收支步之后；RNG 消费点 **3 处**；
6. 不重开已裁 DR；复议 4 项未齐材料不动工（θ/k 阶段化、V6 占比、18 节点扩树、N6 多任务槽）。

### 4.2 #75 参数组（纪要 §2.6「闸值自洽组」，已实算自洽）

- `p_week = 0.35`（命中率门，**复用 `event_roll` 域**，不新增 RNG 域）；
- 权重重排：influence 卡 `w50`（Q2 联标要求 ≥25%）；
- 单卡上限：`money ≤ 5000` / `rp_grant ≤ 60` / `influence ≤ 20`；
- 总闸：事件期望净效果 `≤ 600/周`；
- 冷却：非 once 卡加 `cooldown_weeks`（建议 8）；once 卡沿用 `fired` 永久排除；
- **入档**：`events.cooldowns{}`（开放容器零迁移），`save_migrator.gd:36` 的 `V1_SHELL["events"]` 加 `"cooldowns": {}`；
- 现值需重标：`evt_academic_grant.money 15000`、`evt_paper_accepted.influence 100`、`evt_advisor_visit.rp_grant 200`、`evt_hardware_sponsor` 选项 `money 30000`。

### 4.3 #76 / #80 参数（禁调表项）

- **Σrp_cost 维持 14210**（撤销调表，A2 裁决）；红线带以 DR-027① 为准；
- RP 供给目标 **P50 ∈ [4910, 6810)** → V6 点亮 6/7/7（P10/P50/P90）；
- `cum_influence` 入 `flags{}`（只增不减），`tech_fog.advance_with_context()` **保留旧签名**；
- #80：课题 `~60k/4 周` + `rp_output ~150`；复现 `~15k/3 周` + `rp_output ~100–150`；**新增固定运维键 `upkeep_weekly ~3000`**（lab 周支出 ~9k）；gate **250k @ lab 24 周**（含教学链占槽 7 周）；
- `economy.json` 的 `duration_min/max` 已随 #72 删除（死参数），勿复活。

### 4.4 #77 / #81 / #82

- #77：竞对 L4 标到 **~95 分（约束 [93,98]，禁超玩家 99）**；预警公式已数据键化（`warn_red_weeks`/`warn_yellow_factor`）；
- #81：域计数分母 = `techs.json.total_nodes`（14），显示真实域名（`deep_thought/dandelion/…`），`elsewhere` 显示 ??? 但注明不可研；`test_tech_and_staff_panels.gd:26–28` 的假绿断言必须重写；
- #82：W25 弱展示 → W54 升主权重；W160 自动弹终局屏（非破产专属）；summary 六项；三线计数器入 `flags{}`。

---

## 五、本会话踩坑记录（下会话直接复用结论）

| # | 坑 | 结论 |
|---|---|---|
| 1 | 多 worktree 共享 `user://` → 并发 verify 假失败 | 已修（#84）：`verify.sh` 自带 `XDG_DATA_HOME` 隔离，直接跑即可 |
| 2 | **C1 后无任务的纯模拟约 290 周破产** | 万周回归必须注入任务流：`tests/support/auto_task_policy.gd`（优先 `task_grant_pilot`，周均 8250 > 工资 6000） |
| 3 | `gdlint` 的 `max-public-methods`（>20）在门面/服务类触发 | 在文件**第 1 行**写 `# gdlint:ignore = max-public-methods`（ignore 按行号匹配，放 class_name 前一行无效；注释里规则名后不能带其他文字） |
| 4 | 新 `class_name` 脚本未被识别 | 必须跑一次 `godot --headless --import --quit` 生成并提交 `.gd.uid` |
| 5 | `texts.json` 键数被 3 处硬断言锁定 | 加键需同步：`test_texts.gd`（`TEST_KEYS` + size）、`test_data_loader.gd`、`test_main_scene_smoke.gd`（当前均为 **43**） |
| 6 | `gdformat --check` 是 verify 第一步 | 改完先 `gdformat src tests` 再跑 verify |
| 7 | `require_key` 零默认值纪律会让残缺测试夹具熔断 | 测试夹具应直接 `DataLoader.load_json(<真表>)`，别手写残缺字典 |
| 8 | 子 agent 与主程序席并行时的分支管理 | 子 agent 用独立 `git worktree`（`/home/tangyi/dev/game/wt-*`）；主程序席在 `/home/tangyi/dev/game/big-ai-era` |

---

## 六、下个会话唤起 Prompt（复制直接发送）

```markdown
你是《大 AI 时代》项目（Godot 4.7.2 + GUT，仓库 /home/tangyi/dev/game/big-ai-era）的**主程序席兼实施协调者**。
上一会话已完成 v0.1.5 的 P1–P3 + 并行窗口（#71 / #84 / #67 / #72+#74 / #73 / #78 全部合并 main@9df9992，
verify 41 scripts / 207 tests / 207 passing / 11807 asserts 全绿），剩余 6 单：#75/#76/#77/#79/#80/#81/#82。

## 先读
1. `docs/discussion/handoffs/2026-09-08-015-dev-progress-handoff.md`（本交接：已完成/未完成/参数组/踩坑/遗留）
2. `docs/discussion/handoffs/2026-09-08-decision-to-015-dev-handoff.md`（依赖拓扑 + 10 条硬约束）
3. `docs/discussion/2026-09-08-decision-session-minutes.md` §2.6/§2.9/§十二/§十五
4. `docs/discussion/2026-09-08-v1-requirements.md` 模块 2/5/6/7/8/10/11
5. `AGENTS.md` + `docs/standards/{code-style,testing,scene-asset}.md`

## 任务
1. **立即并行分派 #79**（饱和护栏 + θ/k 通路，依赖 #71/#73 已满足，改动面与 P4 不重叠）；
2. 主程序席串行做 **#75 → #76 → #80**（P4 数值链，参数组见交接 §4.2/§4.3）；
3. #76 合并后分派 #81；#80 合并后做 #77 + 分派 #82；
4. 每单闭环：读 issue 验收点 → 实施（红线）→ `bash scripts/verify.sh` 全绿 → 自证表 → PR（引用 issue）→ 回写 issue 勾选；
5. 每批结束给四行汇报：`批次 / verify / 断言（新增 [T] 数 + 勾选 [P] 数）/ 风险`。

## 硬约束
同交接 §4.1；尤其：Σrp_cost 禁调（14210）、RP 供给带 [4910,6810)、竞对 L4 ∈[93,98] 禁超玩家、
卡时=周预算、`base.cost` 即全程卡时费（不得再计 money）、存档零迁移、RNG 消费点 3 处。

## 完成定义（v0.1.5）
13 单全部合并且验收点 100% 勾选（[T] 由 GUT 证明、[P] 真人试玩）；verify 全绿；同 seed 万周双跑哈希一致；
短单局专项通过；ADR-0011~0016 全部随 PR 创建。

请立刻开始：分派 #79 → 从 #75 开工。
```

---

## 七、持久事实源

- **GitHub**：v0.1.5 milestone 13 单，已完成 7（#67/#71/#72/#73/#74/#78 + 新立 #84），剩余 6（#75/#76/#77/#79/#80/#81/#82）。
- **ADR**：`docs/adr/0011`、`0013`、`0015`、`0016` 已建；`0012`/`0014` 随 #76/#81 创建。
- **worktree**：仅剩 `/home/tangyi/dev/game/wt-78`（#78 已合并，可清理）；`wt-67`/`wt-84` 已清理。
- **分支**：`main` 为唯一主干；每个已完成单的分支已随 squash 合并（本地远端可删）。
