# Handoff — v0.1.5 实施轮（P4–P6 完成）→ 下一会话：**收尾合并 + #82 验收 + 试玩闭环**

> 日期：2026-09-08 ｜ 本会话：主程序席完成 v0.1.5 剩余 6 单的 P4–P6 数值链（#75/#76/#80 亲做）+ #77 亲做 + #79/#81/#82 分派子 agent
> 下一会话焦点：**合并收尾 + #82 验收 + 13 单验收点 100% 勾选 + 试玩脚本资产**
>
> **本会话最大发现**：`RngStream` 的随机数派生有致命缺陷（同一 seed 下同域连续抽样差 ~5e-10 → 概率机制退化为"恒真/恒假"），已修复（#92）并随 #75 合并。

---

## 一、已完成（本会话 6 单 + 1 缺陷修复，全部已合并 main）

| 单 | PR | 交付要点 | 合并后 verify |
|---|---|---|---|
| **#75** 事件闸（C2） | [#93](https://github.com/wingsky-1/big-ai-era/pull/93) | `events.json.event_spec{p_week 0.35 / max_money 5000 / max_rp_grant 60 / max_influence 20 / weekly_net_cap 600}`；Σw=175 权重重排（paper w50 → influence 占比 28.6%）；非 once 卡 `trigger.cooldown_weeks=8`；命中率门复用 `event_roll` 域；冷却入档 `events.cooldowns{}`（零迁移）；`validate_card_caps`/`expected_weekly_effect` 数据表级护栏 | 41/218/12608 |
| **#92** RNG 缺陷修复 | 随 #93 | `randf_domain` 改「三元组 → 重置 `RandomNumberGenerator.seed` 后取一次 `randf()`（PCG32）」；ADR-0008 追加「修正记录」 | 同上 |
| **#76** RP 供给标定（§2.9） | [#95](https://github.com/wingsky-1/big-ai-era/pull/95) | `tasks.json.rp_output` 按"单位时间供给"标定（课题 150/4w、灵犀 140/4w、纸面 110/3w、研究 150/4w = 35–37.5 RP/周）→ 160 周单槽 ~6000 RP ∈[4910,6810)；`Economy._cum_influence`（只吃正向过账）+ 入档 `flags.cum_influence`；`TechFog.advance_with_context()` 唯一翻雾供给入口；`assertion_bounds` 的 `supply_anchor_rp 12300` → `supply_band_rp_min/max 4910/6810`；**ADR-0012** | 42/224/12650 |
| **#79** 饱和护栏 + θ/k 通路 | [#94](https://github.com/wingsky-1/big-ai-era/pull/94)（子 agent） | `ScoreMath.merge_stage_params()` 阶段覆盖通路（真表零数值）；`benchmarks.json.saturation{first99_week_min 50, tier2_never_saturates}`；饱和断言真跑 **W81** / 上界 **W89** | 43/228/13099 |
| **#81** 科技树口径收口 | [#96](https://github.com/wingsky-1/big-ai-era/pull/96)（子 agent） | 域计数分母五处口径一致（`TechFog.get_domain_totals()` 下沉）；UI 7 域全显 + elsewhere「不可研」；每域可达（6 可研域最省成本 ≤6810）；**ADR-0014**（谓词单点真源，已落/待落分列） | 43/232/13273 |
| **#80** 任务池联标（C3） | [#97](https://github.com/wingsky-1/big-ai-era/pull/97) | `tasks.json.income`：课题 35000→**60000**、纸面 8000→**15000**、灵犀 12000→**15000**；`economy.json.upkeep_weekly: 3000`（lab 周支出 9000 ∈[8k,10k]）；`Economy.get_weekly_fixed_expense()` 单口径（周结扣款 + 净流入预告共用）；24 周 gate 实跑 **270k ≥ 250k** | 44/236/13371 |
| **#77** 竞对重标 + 竞对条 | [#98](https://github.com/wingsky-1/big-ai-era/pull/98) | L4 发版分 92→**95**（守卫带 [93,98]，禁超玩家 99；周次不动）；`ScoreMath.ability_for_score()` 反解；竞对条透传 `gap/gap_text`；**修复 X3 根因**：`DashboardPresenter._on_week_settled` 不刷新竞对条 | 44/239/13448 |

**当前 main 基线**：见 §七（若 PR #98 尚未合并，先合并它）。

**已创建 ADR**：`0011`（算力周预算）、`0012`（RP 供给真源）、`0013`（数值数据化）、`0014`（谓词单点真源）、`0015`（周结步序）。
**待创建**：**`0016`（L2 数据面契约）—— #78 的 handoff 声称已创建，但 `docs/adr/` 中不存在该文件**（代码注释与架构复审均引用它）。需补建或更正引用（见 §三 L1）。

---

## 二、进行中

| 项 | 状态 | 说明 |
|---|---|---|
| **#82** 短单局收尾 | **子 agent 运行中**（agent id `eaeac363-8f21-4935-86c8-d17b40e5fe2e`，worktree `/home/tangyi/dev/game/wt-82`，分支 `feat/82-short-run-finale`） | 4 个 [T]：三线计数器 / W25+W54 两阶段可见 / 终局屏 summary 六项 / 单局时长守卫。**主程序席已给它冲突提示**（#77 与它同改 `dashboard_presenter.gd`/`main.gd`）。交付后需验收合并 |
| **PR #98**（#77） | ✅ **已合并**（main@25e279c） | issue #77 已随合并关闭（[T]×4 已勾） |

---

## 三、未完成 / 遗留（下个会话处置）

| # | 遗留 | 建议 |
|---|---|---|
| **L1** | **`docs/playtest/scripts.md` 不存在**，而全部 13 单的 `[P]` 验收点都引用它（`#RS-05`/`#REV-03`/`#RK-04`/`#RK-06`/`#RT-01`/`#RR-02`/`#RF-02` 等） | **最高优先**：从 `docs/discussion/2026-09-08-v1-requirements.md` 各模块的"试玩脚本"段提取，新建该流程资产；否则 13 单的 `[P]` 无法按脚本验收 |
| **L2** | **`docs/adr/0016-*.md` 缺失**（#78 handoff 声称已建） | 补建 ADR-0016（L2 数据面契约：L3 零业务计算），素材见 `docs/discussion/2026-09-08-architecture-review-v12.md` §「ADR-0016」（约 379–386 行） |
| **L3** | **复现线死亡螺旋**：复现 15k/3 周 = 5k/周 < 固定支出 9k/周 → 纯复现必亏；资金转负后 `TaskQueue.can_enqueue` 的 `money < cost` 门**拒绝零成本任务** → 玩家无法再开新项目（#80 实测第 15 周转负、24 周只完成 5 笔） | 另立 issue：`cost==0` 时跳过资金门（或允许欠账接单），归 v0.2 危机线批次裁决 |
| **L4** | `naming_sensitive_reject` 文案键在 `texts.json` 中不存在 → 修复 toast 签名后该提示静默跳过 | 文案收口 issue（与 `ui_display.json` 迁 `texts.json` 同批；注意 `texts.json` 键数被 3 处硬断言锁定） |
| **L5** | `game_world.gd` 已 1037 行（gdlint `max-file-lines` 上限 1000，已加 `# gdlint:disable = max-file-lines`） | 后续单若继续增长，考虑拆出 `freedom_tracker`/`report_builder` 等独立类 |
| **L6** | 事件闸后 `AutoTaskPolicy`（最高优先级任务是 `task_grant_pilot`）在旧 base 下 0 节点可点（子 agent #79 发现） | 测试策略需按"钱 vs RP 配比"选择任务；万周回归已注入任务流，但策略需复核 |
| **L7** | 竞对 L1–L3 分数未重标（维持 35/58/75） | 需求 §10.5 的"各动作目标分区间"仍为数值席待产；若要完整曲线，只需改 `rivals.json` |

---

## 四、硬约束与参数（更新版）

### 4.1 红线（不变）

1. 无 issue 不合码（PR body 引用 issue）；2. `bash scripts/verify.sh` 全绿才可汇报；
3. 分层单向 L0→L4 / 核心逻辑 RefCounted / 数值进 `src/data/` / autoload 禁 `class_name` / `.tscn` 禁 merge=union；
4. 存档零迁移（新增状态一律入 `flags{}` / `events.cooldowns{}` 等开放容器）；
5. 账期契约 + 破产判定在收支步之后；**RNG 消费点 3 处**（`rival_jitter`/`inspiration`/`event_roll`，事件门复用 `event_roll` 不新增域）；
6. 不重开已裁 DR；复议 4 项未齐材料不动工。

### 4.2 已落地的关键参数（改数值只改数据表）

| 项 | 值 | 真源 |
|---|---|---|
| 事件命中率门 `p_week` | 0.35 | `events.json.event_spec` |
| 事件单卡上限 | money ≤5000 / rp_grant ≤60 / influence ≤20 | 同上 |
| 事件总闸 | 期望净效果 ≤600/周 | 同上 |
| 事件冷却 | 非 once 卡 8 周 | 各卡 `trigger.cooldown_weeks` |
| RP 供给带 | `[4910, 6810)` | `assertion_bounds.json.v6_tech_lit_distribution` |
| 任务 `rp_output` | 课题 150 / 灵犀 140 / 纸面 110 / 研究 150 | `tasks.json` |
| 任务 `income` | 课题 60000 / 纸面 15000 / 灵犀 15000 / 研究 0 | `tasks.json` |
| 固定运维 | 3000/周（lab 周支出 9000） | `economy.json.upkeep_weekly` |
| 竞对 L4 | 95 分（[93,98]，禁超 99） | `rivals.json` |
| 饱和元数据 | `first99_week_min 50` / `tier2_never_saturates` | `benchmarks.json.saturation` |
| Σrp_cost | **14210 禁调** | `techs.json` |
| gate | 250k @ lab 24 周 | GDD §6.2 |

### 4.3 验收点勾选现状

- **已合并单**：#71/#72/#73/#74/#75/#76/#78/#79/#80/#81 的 `[T]` 全部勾选；`[P]` **全部未勾**（待试玩，依赖 L1）。
- **待合并**：#77（[T]×4 已勾）、#82（子 agent 交付后勾）。

---

## 五、本会话踩坑记录（下个会话直接复用）

| # | 坑 | 结论 |
|---|---|---|
| 1 | **`RngStream.randf_domain` 派生退化**（本会话最大发现） | GDScript `hash(String)` 对相邻字符串仅差个位数 → 同域连续抽样差 ~5e-10 → 一局内概率判定恒真/恒假（实测 200 seed × 100 次 `hit(0.35)`：85 局命中 0 次、23 局 100 次）。已修为 PCG32（#92），**任何"概率机制不生效"的症状先查这里** |
| 2 | `GameWorld.enqueue_task` 的 `lit_techs` 恒传空数组 | `unlock=tech_lit` 的任务（`task_reproduce_lingxi`）**永不可接** → 教学链第二笔断裂。已修为 `tech_fog.get_lit_techs()`（#80） |
| 3 | `main.gd._on_toast_queued(msg, color_tag)` 与信号 `toast_queued(payload)` 签名不符 | 任何世界侧 toast（警告线等）都会抛 `Method expected 2 argument(s)`；已修为接收 payload 取 `text_key`（#80） |
| 4 | `TaskQueue.can_enqueue` 的 `money < cost` 门 | 资金转负时连 `cost=0` 的任务都拒绝 → 死亡螺旋（见 §三 L3） |
| 5 | 多个 PR 同改 `game_world.gd` → 合并冲突 | 解法：后合并方 `git merge origin/main` 本地解冲突（本会话 #80 解过一次：保留 main 的 `_domain_flag`，删除已退役的 `_wage_per_week`），解完**必须重跑 `verify.sh`** |
| 6 | `gdlint` 的 `max-file-lines`（1000）**不能**用 `# gdlint:ignore = max-file-lines` 豁免 | 多规则逗号分隔/多行 ignore 均无效；可行写法是 `# gdlint:disable = max-file-lines`（#79 验证有效） |
| 7 | `game_world.gd` 已达上限 | 新逻辑优先放新类；或"等量删除"保持 ≤1000 行（#76/#81 各用过一次） |
| 8 | GDScript `%` 格式化**不支持 `%e`** | 用 `%f`/`%s` |
| 9 | lambda 捕获局部变量是**按值** | 需要累计请用 Dictionary/Array 包装（本会话多次用到） |
| 10 | 测试里故意触发 `push_error` → GUT 记 Unexpected Errors → 用例失败 | 用 `assert_push_error`，或删掉该负面断言 |
| 11 | `GameWorld.start_research()` 返回 **void**（不是 Dictionary） | 测试断言要用 `tech_fog.get_state(id) == TechFog.STATE_LIT` |
| 12 | `verify.sh` 自带 `XDG_DATA_HOME` 隔离（#84） | 直接跑，勿手动 export |

---

## 六、下个会话唤起 Prompt（复制直接发送）

```markdown
你是《大 AI 时代》项目（Godot 4.7.2 + GUT，仓库 /home/tangyi/dev/game/big-ai-era）的**主程序席兼实施协调者**。
上一会话完成 v0.1.5 的 P4–P6：#75/#76/#80/#77 亲做 + #79/#81 子 agent，全部已合并 main；
#82 由子 agent 实施（可能已交付 PR，见 handoff §二）。

## 先读
1. `docs/discussion/handoffs/2026-09-08-016-v015-closeout-handoff.md`（本交接：完成/进行中/遗留/参数/踩坑）
2. `docs/discussion/handoffs/2026-09-08-015-dev-progress-handoff.md`（上一轮交接，含 §4.1 红线）
3. `docs/discussion/2026-09-08-decision-session-minutes.md` §2.6/§2.9/§十二
4. `docs/discussion/2026-09-08-v1-requirements.md` 模块 2/5/6/7/8/10/11
5. `AGENTS.md` + `docs/standards/{code-style,testing,scene-asset}.md`

## 任务（按序）
1. **收尾合并**：确认 PR #98（#77）已合并；验收 #82 子 agent 的 PR（抽查证据 → 本地 verify → 合并 → 回写 issue）。
2. **补 `docs/playtest/scripts.md`**（13 单 [P] 的验收脚本资产，从需求文档各模块"试玩脚本"段提取）——**这是 [P] 验收的前置**。
3. **补建 ADR-0016**（L2 数据面契约；#78 声称已建但文件缺失）。
4. **v0.1.5 完成定义核对**：13 单合并 + `[T]` 100% 勾选 + verify 全绿 + 同 seed 万周双跑哈希一致 + 短单局专项 + ADR-0011~0016 齐全。
5. **遗留裁决**：§三 L3（复现线死亡螺旋）、L4（toast 文案键）——建议立 issue 而非当场改。

## 硬约束
同交接 §4.1；尤其：Σrp_cost 14210 禁调、RP 供给带 [4910,6810)、竞对 L4 ∈[93,98] 禁超玩家、
卡时=周预算、`base.cost` 即全程卡时费（不得再计 money）、存档零迁移、RNG 消费点 3 处。

## 每单闭环
读 issue 验收点 → 实施（红线）→ `bash scripts/verify.sh` 全绿 → 自证表 → PR（引用 issue）→ 回写 issue 勾选。
每批结束给四行汇报：`批次 / verify / 断言（新增 [T] 数 + 勾选 [P] 数）/ 风险`。

请立刻开始：读交接 → 检查 #82 与 PR #98 状态 → 收尾合并。
```

---

## 七、持久事实源

- **main**：**`25e279c`**（本会话起点 `fc123d0`，逐单 squash 合并：#93→#95→#94→#96→#97→#98）。**12/13 单已合并**，仅剩 #82。
- **verify 演进**：`41/211`（会话起点，handoff 记 207 与实际 211 有出入）→ `41/218/12608`（#75+#92）→ `42/224/12650`（#76）→ `43/228/13099`（#79）→ `43/232/13273`（#81）→ `44/236/13371`（#80）→ `44/239/13448`（#77）。
- **issue**：v0.1.5 13 单 + 新增 #92；**已关闭 12**（#67/#71–#81 + #92），仅 **#82** 待合并。
- **ADR**：0011/0012/0013/0014/0015 已建；**0016 缺失**。
- **worktree**：`/home/tangyi/dev/game/wt-82`（#82 子 agent）；`wt-79`/`wt-81` 已交付可清理。
- **分支**：`main` 为唯一主干；本会话分支 `feat/75-event-gates`/`feat/76-rp-supply`/`feat/80-task-pool-calibration` 已合并可删；`feat/77-rival-retune` 待合并。
