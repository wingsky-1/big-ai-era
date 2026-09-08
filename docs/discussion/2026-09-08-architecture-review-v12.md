# 架构复审 v12 —— 基于 DR-031 的代码架构再审视

> **性质**：架构复审（**只产出本文档**；不建 ADR 文件、不改任何代码、不建 issue）。
> **输入**：`docs/discussion/2026-09-08-decision-session-minutes.md`（DR-031 全文）、`docs/discussion/decision-log.md`（DR-000~031）、`docs/gdd/gdd.md`（v3 已同步稿）、`docs/adr/0001~0010`、`AGENTS.md` 红线、`docs/standards/{code-style,testing,scene-asset}.md`、`src/**` 与 `tests/**` 全量。
> **证据纪律**：本文**一切结论以 `文件:行号` 为唯一证据**，不采信稿面。凡与纪要/GDD 表述不一致处，一律标注「**勘误**」并给出代码实证。
> **基线状态**（本次实跑）：`bash scripts/verify.sh` **全绿** —— 34 个测试脚本 / **178** 用例 / 9607 断言 / 11.25s（`scripts/verify.sh:66–86`）。
> **仓库状态**：`main@48c1eae`；工作区另有 3 个已改文档 + 2 个未跟踪文档（含 `docs/discussion/2026-09-08-v1-requirements.md`），本次复审不触碰。

---

## 0. 一页速览

### 0.1 结论摘要（6 条）

| # | 结论 | 判定 | 关键证据 |
|---|---|---|---|
| 1 | **单向分层成立**：L0→L1→L2→L3 无逆向依赖，L4 只被读取；L2 全 RefCounted、零 Node | ✅ 成立 | `src/entities/*.gd:2` 全 `extends RefCounted`；全仓无 L2→L3 / L1→L2 引用 |
| 2 | **但分层有三处"字面违规 + 语义擦边"**：L1 同层互引、L3 直接读 L4 数据表、L3 直写 L2 内部状态 | ⚠️ 有风险 | `text_service.gd:41/141`、`tech_tree_dialog.gd:51`、`main.gd:119–120` |
| 3 | **红线 3（数值禁硬编码）全仓 19 处违规**（远超纪要点名的 `score_math`/`tech_fog` 两处） | ❌ 不成立 | 见 §1.4 全量清单（含 Cobb-Douglas 指数 0.7/0.3、`event_engine.gd:84` 第二处 14、`clock.json.ticks_per_week` 死键） |
| 4 | **确定性真源已被破坏**：存在 ADR-0008 明令禁止的**第 4 个随机消费点**，且读档后 RNG 序列漂移（两处） | ❌ 不成立 | `game_world.gd:460–463/561–570`；`restore()` 缺 `_income_roll_seed`；`rival_track.setup` 在读档时多消费 4 次 |
| 5 | **契约面 11 命令 / 11 信号中有 2 个信号从未发出**，另有 1 个信号载荷缺字段导致买卡（改动 4）无法驱动 UI | ⚠️ 有风险 | `fog_changed`/`stage_advanced` 仅声明未 emit；`resources_changed` 不含 `compute_tier` |
| 6 | **12 项改动中 11 项零 schema 迁移**，唯一有迁移分叉的是改动 3（`staff.assigned` 的形状）；**但 3 项改动有"入档缺口"**（`cum_influence`、`flag_set`、事件文案快照） | ⚠️ 需决策 | 见 §2.1/§2.2 |

### 0.2 必须最先做的 3 件事

1. **批 0 的"数值数据化 + 死键清理"**（零行为变更、解锁后续全部数值联调）：
   `score_math.gd:9–18`（K/θ/k/**m/指数 0.7/0.3**）→ `benchmarks.json`；`tech_fog.gd:18`（`TOTAL_NODES`）+ `event_engine.gd:84`（第二处硬编码 14）→ 数据键；`clock.json:3`（`ticks_per_week` 死键）与 `game_world.gd:426`（用常量绕过注入）收口；`rival_track.gd:96/101`、`economy.gd:111–112/205`、`training_project.gd:56/61/124`、`sota_board.gd:18/20`、`tech_fog.gd:33–34/320`、`event_engine.gd:29–31/66–68/127` 的"代码默认值 vs 数据表"双真源逐项收口。
   *理由*：饱和断言（`test_saturation_first99_week`）、竞对重标、V6 复算三者的前提都是"K/m 由数据驱动"；先做断言后做数据化 = 断言重写一遍。
2. **批 1a 的"C1 三件套 + 确定性修复"**：周报收支裂缝（`game_world.gd:463` vs `:484`）+ 破产步序重排（`:469–477` 早于 `:479–491`）+ **顺手修掉第 4 随机消费点与读档 RNG 漂移**。
   *理由*：纪要已明确"1a 是 1d/1g 的前提"（纪要 `:521`），且事件闸（C2）在脉冲口径下**鉴别力为零**（GDD `:231` 自述"现状自动合规 4.9%"）。若先做闸，参数白标一次。
3. **批 1b 的 Σeff + `max_staff`**：`staff_roster.gd:113–119` 单人 → Σ；`_slots` 单人槽 → 多人槽；新增 `max_staff` 校验（`min_staff` 全仓零消费，见 §1.4 证据）。
   *理由*：竞对死表重标（1f）、霸榜可达性、A 上限（213.4）三者的共同前提；后做则竞对表要标两遍。

### 0.3 最危险的 3 条架构风险

| # | 风险 | 为什么危险 | 证据 |
|---|---|---|---|
| **R1** | **周结"收支账期归属"无契约**：`_week_revenue/_week_expense` 是"自上次 `accrue_week` 以来的累计"，而买卡/研究/入队/事件等**非周结过账**都经 `apply_delta` 累加 → 周报收支行不闭合、净流入预告（改动 12）无法定义 | 改动 1（裂缝）与改动 12（预告）都在这一条上；只挪步序不定账期，预告与实际周结永远对不上 | `economy.gd:62–82`（累加）、`:127–128`（重置时机）、`game_world.gd:236/463/484`、`tech_tree.gd:67–69`、`training_project.gd:53` |
| **R2** | **确定性真源受损**：ADR-0008 决策 3 写"消费点恰 3 处、grep 可验"，现状有第 4 处（`RandomNumberGenerator` 收入脉冲）；且读档后 `_income_roll_seed` 未恢复、`rival_track.setup` 在读档时多消费 4 次 jitter → **同 seed 双跑 / 存档回放 / 分位数断言建立在漂移的地基上** | V6/V10/V1 全部区间断言、竞对 ε、nightly 蒙卡的可复现性都依赖它；C1 退役脉冲时若只是删除而不收敛到 `RngStream`，等于把第 4 点变成隐性第 5 点 | `game_world.gd:460–463/561–570`、`:335–394`（无 `_income_roll_seed`）、`:355–360`、`rival_track.gd:33–48`、ADR-0008 决策 3 |
| **R3** | **供给/成本/出分三个真源被同批改动**（`rp_output` 标定 + `income` 标定 + `K/m` 数据化 + `max_staff`/Σeff + `Σtb` 冻结），彼此的断言互相咬合（V6 / 饱和 W54 / 竞对 L4 ~95–98 / gate 250k） | 纪要已发生过一次"调表方案撤销"（纪要 `:271–280`）；没有"单点冻结 + 逐项解锁"的顺序保障，任何一项先做都会触发全组重标 | 纪要 `:242`（依赖图）、`:521`（批次依赖）、`:275`（撤销留痕） |

### 0.4 需要制作人拍板的架构级问题（7 条）

| # | 问题 | 选项 | 影响 |
|---|---|---|---|
| **P1** | `get_income_forecast()`（净流入预告，改动 12）**是否进契约命令面**？ | (a) 进命令面 → 11→**13**；(b) **并入 `get_ui_snapshot()` + `week_settled` 载荷**（推荐）；(c) 作为非契约查询方法（同 `get_clock/get_money`） | 决定 `CONTRACT_COMMANDS` 与 `test_game_world.gd:62` 的断言值；纪要只写了"11→12"（买卡），未覆盖预告 |
| **P2** | `staff.assigned` 的**存档形状**：保持 `{staff_id: slot_id}` 还是允许 `{slot: [staff_id]}`？ | (a) 保持 staff→slot（**零迁移**，推荐）；(b) 改 slot→数组（**破坏 schema → SaveMigrator v2 + 迁移链**） | 决定改动 3 的迁移成本；纪要"零迁移"结论**只在 (a) 下成立** |
| **P3** | 破产判定修法二选一 | (a) 任务结算**并入步序 1**（"收支"定义扩展为工资+运维+任务结算）；(b) 短路**后移**到任务结算之后（修订 DR-021 B3 措辞） | 两者在"周报闭合"上等价、**语义不同**；纪要 `:351` 与 `2026-09-08-v1-requirements.md:1066` 均列为待拍板 |
| **P4** | 事件文案迁 `texts.json`（改动 11）后，**pending 卡入档的是"已插值文案"还是"texts 键 + 参数"**？ | (a) 已插值文案（现状形状，旧档兼容但改文案后旧档显示旧文）；(b) 键+参数（需改 `events.pending` 结构 → 破坏 schema） | 决定改动 11 是否需要 SaveMigrator；影响 i18n |
| **P5** | `min_staff` 与 `max_staff` 关系（纪要 R-5 / GDD Q11） | (a) 仅新增 `max_staff` 校验（min 维持零消费）；(b) 同时启用 `min_staff` 下桌校验（**行为变更**） | 决定改动 3 是"从零新增一条校验"还是"两条" |
| **P6** | 卡时"每周预算"与 `compute_tiers.capacity` 的**语义边界** | (a) 供给仅作每周重置值，容量仅作 `apply_delta` 上限（推荐）；(b) 供给同时受容量约束 | 决定 `apply_delta("compute")`（`economy.gd:72–78`）是否要改；`opening.json:8` 开局 `hours_remaining=0` 与"每周重置"的交互须定义 |
| **P7** | 是否接受"**非周结过账计入下一周周报**"（账期归属） | (a) 接受并写入契约（推荐，零代码改动）；(b) 按周编号归集（需 ledger 加周键 → 存档变更） | 决定净流入预告的口径与周报对账的验收标准（R1） |

---

## 1. 分层与依赖体检

### 1.1 L0→L4 单向依赖逐层核对

**结论：主方向成立（零逆向依赖），但有 3 处字面违规与 1 处边界模糊。**

| 层 | 规范（ADR-0002:16–22） | 实测 | 判定 |
|---|---|---|---|
| L0 `src/core/` | 零依赖 | `clock_math.gd:1–2`、`score_math.gd:1–2` 均仅 `class_name`+`RefCounted`，无 `preload`/`DataLoader` | ✅ |
| L1 `src/systems/` | 仅依赖 L0 | 6 个文件全部无 L2/L3 引用（全仓 grep 无命中） | ✅ |
| L1 内部 | ADR-0002:14「禁止…同层互引」 | `text_service.gd:41` 与 `:141` 依赖 `DataLoader`（L1）；`data_loader.gd` 在 L1 | ⚠️ **字面违规**：建议在 ADR 明确 L1 内部分层（`data/` 为 L1 基础服务，其余 L1 可依赖它） |
| L2 `src/entities/` | 依赖 L0/L1 | `tech_fog.gd:275` 用 `DataLoader`（L1）；`game_clock.gd:46` 用 `ClockMath`（L0）；全仓无 L2→L3 | ✅ |
| L3 `src/ui/` | 依赖 L0/L1，经注入触达 L2 | 见下方 3 条 | ⚠️ |
| L4 `src/data/` | 被读取，不反向 | 纯 JSON，无代码 | ✅ |

**L3 的三处越界（逐条证据）**：

1. **L3 直接读 L4 数据表**：`tech_tree_dialog.gd:51` `DataLoader.load_json("res://src/data/techs.json")`。
   - ADR-0002:21 允许 L3 读 L4，但此处**绕过 L2 真源**：迷雾态来自 `_world.tech_fog`（`:34`），节点表却另起一次磁盘读 → 两者可不同步（且重复 IO）。`TechFog` 自己持有 `_nodes_data`（`tech_fog.gd:31`）但**没有对外暴露节点表的只读接口**，L3 只能自己读盘。
2. **L3 直写 L2 内部状态**：`main.gd:119–120` 调试驱动调用 `_world.set_pending_decision({})`。
   - `set_pending_decision` **不在 11 契约命令面**（`game_world.gd:24–36`），且语义是"事件引擎与装配层使用；UI 不调用"（`:440` 注释自述）。当前唯一调用点就是 L3。
3. **L3 直读 L2 内部字段（绕过 SnapshotCodec）**：`main.gd:269` `world.pending_decision`、`main.gd:371/384/396` `_world.user_paused`、`staff_roster_dialog.gd:36` `_world.roster.get_all_staff()`、`tech_tree_dialog.gd:34` `_world.tech_fog`。
   - ADR-0002:20 说"经注入可触达 L2 数据"，但**没有界定"数据"是快照还是内部对象**。改动 12（呈现层）必须把这条收口，否则"L3 只格式化"无法验收。

**L3 零写路径门禁的覆盖缺口**：`test_playtest_loop_headless.gd:87–93` 只禁 5 种模式（`SaveSystem.save_game` / `FileAccess.open` / `.money +=` / `.money -=` / `.apply_delta`），因此 `main.gd:119–120` 的直写**不会被拦截**；且 L3 直读字段也不在门禁范围。

### 1.2 RefCounted 化程度 / Node 混入逻辑

| 文件 | 基类 | 是否混入逻辑 | 判定 |
|---|---|---|---|
| `src/entities/*.gd`（13 个） | 全 `RefCounted` | — | ✅ 红线 2 达标 |
| `src/core/*.gd` | `RefCounted` | 纯静态 | ✅ |
| `src/systems/data/data_loader.gd`、`predicate_registry.gd`、`rng/rng_stream.gd`、`save/save_migrator.gd`、`stats/stat_attribute.gd`、`state_machine/*.gd`、`text/*.gd` | `RefCounted` | — | ✅ |
| `src/systems/save/save_system.gd:1` | `extends Node`（autoload） | 纯 IO 服务 | ✅ 合规（ADR-0005） |
| `src/ui/game_loop_driver.gd:2` | `extends Node` | 含 `_process`→`feed_frame`→`clock.advance` 的调用编排 + weakref 解析（`:31–45/62–70`） | ⚠️ 可接受（ADR-0006 明确"变速属 View"），但它是**唯一吃帧的地方**，逻辑略重于"表现" |
| `src/ui/main/main.gd:1` | `extends Control` | **混入调试/自动化逻辑**：`_setup_debug_shot_driver()`（`:108–142`）、`JavaScriptBridge.eval`（`:111–113/142/153`）、`_update_debug_beacon()`（`:146–159`） | ⚠️ Minor：截图/自测信标应与 AppShell 主职责分离（独立 `debug_beacon.gd`），否则每次改 UI 都碰调试代码 |
| `src/ui/modals/*.gd` | `PanelContainer` | 表现 | ✅ |

### 1.3 autoload 与 `class_name` 合规

- autoload 清单：`project.godot:19–21` **仅 `SaveSystem`** 一项 → 符合"保持最少"（AGENTS.md §2）。
- `save_system.gd:1` 为 `extends Node` 且**无 `class_name`** → 符合红线 5（`code-style.md:104–107`）。
- 其余 40+ 脚本均有 `class_name`（L0/L1/L2/L3），无 autoload 重名。
- **无违规**。

### 1.4 数值硬编码全仓扫描（红线 3）

> 扫描口径：`src/**/*.gd` 全部数值字面量，剔除纯索引/0/1 边界与格式化系数，逐条判定"是否属于游戏数值/配置"。**共 19 处数值硬编码（A 类 2 + B 类 17），其中 9 处是"代码默认值 vs 数据表"双真源；另有 1 处 stringly-typed 封闭集合违规（B10）。**

**A 类：已被纪要点名（2 处）**

| # | 位置 | 违规内容 | 数据表对应 |
|---|---|---|---|
| A1 | `score_math.gd:9–18` | `K=4.0` / `θ=95.0` / `k=13.0` / `m={1:0.6,2:0.75,3:0.9,4:1.05}` | `benchmarks.json:4–5` 已有 θ/k；K/m 无 |
| A2 | `tech_fog.gd:18` | `TOTAL_NODES=14` | `techs.json` 节点数（14） |

**B 类：本次全量扫描新增（17 处数值 + 1 处 stringly-typed）**

| # | 位置 | 违规内容 | 判定 |
|---|---|---|---|
| B1 | `score_math.gd:34–35` | Cobb-Douglas **指数 `0.7` / `0.3`** | ❌ 硬编码：调权重必须改码；纪要只提 K/m，**漏了指数** |
| B2 | `event_engine.gd:84` | `fog.get_discovered_count() >= 14` | ❌ **第二处硬编码总节点数**（A2 之外的独立副本） |
| B3 | `event_engine.gd:85` | 顺延 `pity - 2` 的魔法数 `2` | ❌ 硬编码（GDD Q3 兜底行为未定稿） |
| B4 | `event_engine.gd:29–31`、`66–68` | 灵感三键默认 `0.1/8/12` | ❌ 双真源（`events.json:2–6` 已有） |
| B5 | `event_engine.gd:127/137` | 事件权重默认 `10` | ❌ 魔法数（`events.json` 每卡显式给 weight，默认值无意义） |
| B6 | `tech_fog.gd:19–20` | `PITY_THRESHOLD=8`（**全仓零消费**）、`PITY_CAP=12` | ❌ 双真源（`events.json:4–5` pity/cap）；且 `PITY_THRESHOLD` 是死常量（仅 `test_tech_fog.gd:21` 断言） |
| B7 | `tech_fog.gd:24–29` | `OPENING_RESEARCHABLE_NODES` 硬编码 4 个节点 id | ❌ 应为 `techs.json` 节点级键（如 `opening_researchable:true`） |
| B8 | `tech_fog.gd:33–34` | fog gate 默认 `200/600` | ❌ 双真源（`techs.json:11–14`） |
| B9 | `tech_fog.gd:318–320` | `node_id == "mirror_mind"` + `required_lit_count` 默认 `6` | ❌ 节点 id 与阈值双双硬编码（`techs.json:223–228` 已有） |
| B10 | `tech_fog.gd:339–340` | 域名字符串 `"elsewhere"` / `"crossover"` 判定 | ⚠️ stringly-typed（`code-style.md:36–49` 禁封闭集合字符串）；`domain_enum`（`techs.json:2–10`）未枚举化 |
| B11 | `economy.gd:111–112/205` | `-30000` / `-200000` / `150` 默认值 | ❌ 双真源（`economy.json:3–4/8`） |
| B12 | `training_project.gd:37/56/61/124` | `min_tier` 默认 1、`train_weeks` 默认 10、`quality` 默认 0.55 | ❌ 双真源（`model_bases.json`） |
| B13 | `sota_board.gd:18/20` | 基线 `24.0`、默认名 `"灵犀 Chat"` | ❌ 双真源（`opening.json:5/9`、`benchmarks.json:6–7`） |
| B14 | `rival_track.gd:22/28/96/101` | jitter `0.15` 默认、红灯 `<=2` 周、黄灯 `⌈0.15t⌉` | ❌ 双真源（`rivals.json:6`）+ **预警公式硬编码**（DR-027④ 的 ⌈0.15t⌉ 应是数据键） |
| B15 | `game_clock.gd:15` + `game_world.gd:426` | `TICKS_PER_WEEK=40` 且 `settle` 用它而非注入值；`clock.json:3` 的 `ticks_per_week` **零读取** | ❌ **双真源 + 死键**：数据表改 40 不生效 |
| B16 | `text_service.gd:13–24` | `DEFAULT_NAMES` 10 个名字硬编码 | ❌ 双真源（`texts.json:77–126` 已有 `naming_fallback_01..10`） |
| B17 | `game_world.gd:295` | 命名长度上限 `20` | ❌ 与 `texts.json:33`「2~12 个字符」与 `text_service.gd:157` 默认 `limit=12` **三处不一致** |
| B18 | `tech_tree_dialog.gd:40–44` | 域计数分母硬编码 `4/5/5`，域名 `architecture/algorithm/infrastructure` | ❌ **既硬编码又已失效**：`get_domain_counts()`（`tech_fog.gd:224–234`）返回的是 `{域: 整数}`，实表域名为 `deep_thought/dandelion/...`（`techs.json:2–10`）→ 三个键全 miss，UI **恒显示 `(0/4) (0/5) (0/5)`**（见 §3.6） |

**表现层常量（建议数据化但不构成红线违规）**：`game_loop_driver.gd:12`（速度档）、`modal_sizing.gd:9–22`、`responsive_layout_manager.gd:22–23`、`main.gd:240`（遮罩 alpha）。

**最小改动路径**：B 类全部走"**数据键 + 代码默认值删除**"（不是"加默认值"）——把 `_config.get(key, <字面量>)` 改为 `_config.get(key)` 并断言键存在（缺失即 push_error），否则"双真源"会在下次改表时再次漂移。

### 1.5 单点真源四项核对

| 真源 | 规范出处 | 实测 | 判定 |
|---|---|---|---|
| `apply_delta` 唯一过账口 | `economy.gd:5–6`、DR-021 M3 | 全部 money/influence/compute 变更均经它：`game_world.gd:236/484/487`、`tech_tree.gd:67/69`、`training_project.gd:53`、`event_engine.gd:185/187/189/191`；Economy 内部无第二写点 | ✅ **但账期语义有缺陷**（见 R1） |
| RNG 消费点恰 3 处 | ADR-0008 决策 3 | `rng_stream.gd` 三大域被消费于 `rival_track.gd:42`、`event_engine.gd:75/77`、`event_engine.gd:133`；**但 `game_world.gd:460–463` + `:561–570` 另起 `RandomNumberGenerator` 作为第 4 个随机源** | ❌ **违规**（见 §3.5） |
| 周结管线唯一写盘点 | ADR-0005 决策 1 | `game_world.gd:556` 是唯一周界存档点；`request_save` 三路径（`:474/556/330`）均经 `SaveSystem` | ✅ |
| `SaveSystem` 唯一写入口 | `save_system.gd:10–11` | 全仓 `FileAccess.open(..., WRITE)` 仅 `save_system.gd:81` | ✅ |

### 1.6 契约面实证（命令 / 信号 / 载荷）

| 项 | 规范 | 实测 | 判定 |
|---|---|---|---|
| 命令数 | 11（DR-026） | `game_world.gd:24–36` 列 11；`test_game_world.gd:62` 断言 11 | ✅（改动 4 要 →12） |
| 信号数 | 11（DR-026） | `game_world.gd:37–49` 列 11；`test_game_world.gd:63` 断言 11 | ⚠️ 见下 |
| **死信号 1** | — | `fog_changed`（`game_world.gd:15`）**全仓无 `emit`**；`tech_fog.fog_changed`（`tech_fog.gd:10`）也**从未被 GameWorld 连接** | ❌ 契约虚设：GDD `:189` 说"域计数入 fog_changed 载荷"未兑现 |
| **死信号 2** | — | `stage_advanced`（`game_world.gd:17`）**全仓无 `emit`**；`stages.stage_advanced`（`stages.gd:9`）未被连接（GameWorld 改用返回值，`:536–541`） | ❌ 同上；GDD `:54` 说"stage_advanced 信号+晋升并入周报头条"未兑现 |
| **载荷缺字段** | — | `resources_changed(money, compute_hours, influence)`（`:11`）**不含 `compute_tier`**；presenter 只在全量快照里取 tier（`dashboard_presenter.gd:76`）→ 买卡后若只靠信号，tier 不刷新 | ⚠️ 改动 4 必须定契约（见 §2.4） |
| **命令无 UI 落点** | GDD `:259`「9 命令落点核对无缺 UI」 | `submit_model_name`（`game_world.gd:33/279`）在 `src/ui/` **零调用**；`open_naming_dialog()`（`dashboard_presenter.gd:169–171`）**无生产调用点**（仅 `test_dashboard_presenter.gd:72`），且 `src/ui/modals/` **不存在 `naming_dialog.tscn`**，`main.gd:267–324` 的 `_on_panel_pushed` 无 `NAMING_DIALOG` 分支 → 命名仪式（DR-002/GDD §9）从 UI 不可达 | ❌ 12 项改动之外，但属契约面欠账 |
| L3 调非契约命令 | — | `main.gd:120` `set_pending_decision`（不在 11 命令面） | ❌ |
| L2 封装泄漏 | — | `game_world.gd:444` 写 `event_engine._pending_card`；`:529` 调 `event_engine._pending_card.clear()` | ❌ 见 §3.4 |

---

## 2. 契约面与 schema 影响

### 2.1 12 项改动 × 契约 / schema 变化矩阵

> 判据：**命令面**=是否新增/修改 `CONTRACT_COMMANDS`；**信号面**=是否新增/改签名；**schema**=存档字典键/类型/语义是否变化；**迁移**=是否需 `SaveMigrator`。

| # | 改动 | 命令面 | 信号面 | schema 变化 | 需迁移？ | 依据 |
|---|---|---|---|---|---|---|
| 1 | 收入口径改占槽结算 | 无 | `week_settled` 载荷（`report.money_row`）**值语义变**，形状不变 | `resources.money`/`cum_income` 语义不变 | ❌ 无 | `game_world.gd:463/479–491/542–551` |
| 1' | 破产步序重排 | 无 | 无 | 无 | ❌ 无 | `game_world.gd:469–477` |
| 2 | 卡时每周预算 | 无 | 建议 `resources_changed` 载荷加 `compute_supply`（**签名变更**，3 个 connect 点）或走快照 | `resources.compute.hours_remaining` **值语义变**（周预算余额），键/类型不变 | ❌ 无（语义变更需记录） | `economy.json:9–14` 无 `weekly_supply`；`economy.gd:72–78` |
| 3 | Σeff + `max_staff` | 无 | 无 | `staff.assigned{staff→slot}`：**保持形状=零迁移**；改 `{slot:[staff]}`=**破坏 → v2** | ⚠️ **取决于 P2** | `staff_roster.gd:144–153`、`snapshot_codec.gd:82` |
| 4 | 买卡契约命令 | **11→12**（新增，如 `upgrade_compute`） | 可选：新增 `compute_upgraded`（→信号 12）或复用 `resources_changed`（→11） | 无（`compute.tier` 已在档） | ❌ 无 | `economy.gd:149–159`；`game_world.gd:24–36` 无该命令 |
| 5 | 事件命中率门 + 冷却 | 无 | 无 | `events` 容器**新增 `cooldowns{}`**（开放容器加键） | ❌ 零迁移（`events` 已有壳 `save_migrator.gd:36`） | `event_engine.gd:231–237`、`save_migrator.gd:69–78` |
| 6 | RP 供给标定 + 翻雾供给源 | 无 | 无 | **新增累计计数器 `cum_influence`** —— 放 `flags{}`（推荐）或 `resources{}`；**不入档则读档后翻雾进度漂移** | ❌ 零迁移（加键），但**必须入档** | `game_world.gd:514`；`snapshot_codec.gd:90` |
| 7 | `K`/`m` 数据化 | 无 | 无 | 无（数据表键） | ❌ 无 | `score_math.gd:9–18` → `benchmarks.json` |
| 8 | `TOTAL_NODES` 数据化 | 无 | `fog_changed` 载荷 `total_nodes` 值来源变（信号本身是死的，见 §1.6） | 无 | ❌ 无 | `tech_fog.gd:18/371`、`event_engine.gd:84` |
| 9 | 谓词三处收口 | 无 | 无 | 无 | ❌ 无 | `predicate_registry.gd`、`task_queue.gd:120–145`、`tech_fog.gd:313–331` |
| 10 | 饱和护栏断言 | 无 | 无 | 无 | ❌ 无 | 新用例 |
| 11a | `flag_set` 入档 | 无 | 无 | `flags{}` 加键（**但当前 flag_set 写的是 Object meta，根本不落盘** → 需新增 `GameWorld` 状态字段 + `SnapshotCodec` 读写） | ❌ 零迁移（`flags` 开放容器） | `event_engine.gd:201–202`；`snapshot_codec.gd:90` |
| 11b | 事件文案迁 `texts.json` | 无 | 无 | `events.pending[]` 的 `title/description` **语义变更**（键 vs 文案） | ⚠️ **取决于 P4** | `event_engine.gd:148–154`；`events.json:17–18` |
| 12 | 呈现层 | **取决于 P1**（若 `get_income_forecast()` 进命令面 → 11→13） | 建议 `week_settled`/`ui_snapshot` 加预告字段 | 无 | ❌ 无 | `dashboard_presenter.gd:104–113`、`main.gd:448–459`、`snapshot_codec.gd:13–25` |

**汇总**：**11 项零迁移 + 1 项条件迁移（改动 3，取决于 P2）**；**3 项有"入档缺口"**（`cum_influence`、`flag_set`、事件文案），这 3 项若不做，读档后行为与存档前不一致（属于隐性坏档）。

### 2.2 `SaveMigrator` 迁移判定（逐项依据）

**判据**（`save_migrator.gd:12–14` 与 ADR-0003）：
- **开放容器加键**（`rng{}` / `flags{}` / `events{}` / `sota.by_key{}`）= **零迁移**：`_fill_shell` 只补缺失键、已有键不动（`save_migrator.gd:69–78`），`restore()` 用 `.get()` 兜底。
- **固定容器的键/类型变更、语义不兼容变更、字段重命名** = **破坏性** → `CURRENT_VERSION +1` + match 分支 + 单测（ADR-0003 决策 5）。

| 改动 | 判定 | 说明 |
|---|---|---|
| 3（Σeff + max_staff） | **零迁移（条件）** | 只要 `to_save()` 保持 `{"assigned": {staff_id: slot_id}}`（`staff_roster.gd:144–153`）就零迁移；`_slots` 在内存里改多人槽（`staff_roster.gd:17–20`）不影响存档形状。**若改成 `{slot:[staff]}` 则是值类型变更 → 必须 v2 迁移**（老档是 string，新代码期望 Array）。**这条是本次唯一真正的迁移分叉**（P2）。 |
| 5（冷却） | 零迁移 | `events` 是开放容器（`save_migrator.gd:36`）；建议同时在 `V1_SHELL["events"]` 加 `"cooldowns": {}`，让旧档经 `_fill_shell` 自动补键（`save_migrator.gd:69–78`）。 |
| 6（`cum_influence`） | 零迁移 | 建议入 `flags{}`（`snapshot_codec.gd:90` 已写 flags、`game_world.gd:381–383` 已读 flags）；**不加则读档后计数器归零 → 翻雾进度重置（行为不一致）**。 |
| 11a（`flag_set`） | 零迁移 | `flags` 开放容器加键；但需新增 `GameWorld` 的 flags 状态与读写（当前 `set_meta` 不落盘，`snapshot_codec.gd` 也不序列化 meta）。 |
| 11b（文案入档） | **条件迁移** | 若选 P4(a)（已插值文案）→ 零迁移；若选 P4(b)（键+参数）→ `events.pending[]` 元素结构变更 → **破坏性 → v2**。 |
| 2（卡时语义） | 零迁移（**但需文档记录**） | 键与类型不变，老档 `hours_remaining` 语义从"卡池余量"变"周预算余额"；读档后下一周被重置。建议在 ADR 中声明"语义变更不影响解析，不回滚"。 |
| 4（买卡命令） | 零迁移 | `compute.tier` 已在档（`snapshot_codec.gd:70`）。 |

### 2.3 DR-021 B3「破产判定写死在收支后」的契约修订方案

**现状证据**：`game_world.gd:463`（收支）→ `:469–477`（破产短路，含终局档+`return`）→ `:479–491`（任务结算过账）。C1 改占槽口径后，任务收入落在破产判定**之后**。

**两种修法与语义差异**：

| 方案 | 实现 | 语义 | 代价 |
|---|---|---|---|
| **(a) 任务结算并入步序 1** | 把 `task_queue.settle_week()` + 过账上移到 `accrue_week` 之后、`check_lines()` 之前 | "收支"的定义从"工资+脉冲"扩展为"**工资+运维+任务结算**"；DR-021 B3 的"收支后"字面成立，但"收支"内涵变 | 需保证任务完成信号（`task_state_changed`）与周报顺序不破；`accrue_week` 的 `ledger` 需在任务过账后再取（否则 D-11 裂缝复现） |
| **(b) 短路后移** | 保持任务结算位置，把 `check_lines()` 短路移到任务结算之后 | 明确修订 DR-021 B3 的"写死在收支后"为"**写死在全部收入结算后**" | 短路位置从步序 2 变步序 ~3.5；ADR/GDD §5.2 管线图要改；破产时已执行任务结算（`task_state_changed`/RP 入账已发生），终局档内容随之变化 |

**推荐 (a)**，理由（三条实证）：
1. 周报闭合口径天然成立：`accrue_week` 的 ledger 与任务过账同处一步，`game_world.gd:542–551` 的报告无需二次拼装（顺带修 D-11 裂缝）；
2. 破产判定"看到本周全部收入"语义最直观，且 `get_income_forecast()`（改动 12）的预告口径与之一致；
3. 短路语义不变（仍在收入结算后），DR-021 B3 只需把"收支"括注为"工资+运维+任务结算"。

**无论选哪条，必须随行**：
- `test_weekly_ledger_includes_task_income`（新）：`report.money_row.income` 含任务收入（D-11）；
- `test_bankruptcy_after_task_income`（新）：资金 −210k 且本周任务结算 +60k → **不**破产（若设计意图是"结算后仍破产"则相反，须在 issue 里写死口径）；
- 修订 `DR-021 B3` 表述 + GDD §5.2 管线图 + `docs/adr/0005` 的"周结末步"映射（新 ADR-0015，见 §4）。

### 2.4 契约面同步清单（改动落地时一次性改齐）

| 文件 | 同步点 |
|---|---|
| `src/entities/game_world.gd:24–36` | `CONTRACT_COMMANDS` 11→12（买卡）；按 P1 决定是否 +预告 |
| `src/entities/game_world.gd:37–49` | 信号数：若新增 `compute_upgraded` → 12；否则维持 11 |
| `src/entities/game_world.gd:11` | 若扩 `resources_changed` 载荷（加 `compute_supply`/`compute_tier`）→ **3 个 connect 点同步改**：`dashboard_presenter.gd:54`、`main.gd:361`、`test_game_world.gd:17`（`code-style.md:50–51` 纪律） |
| `src/entities/game_world.gd:15/17` | 死信号二选一：**接上**（tech_fog/stages → GameWorld 转发）或**删除**（契约 11→9）。建议接上：GDD `:189`/`:54` 依赖它们 |
| `tests/unit/test_game_world.gd:62–63` | 11→12 对账断言（纪要已列） |
| `src/entities/snapshot_codec.gd:90` | `flags` 加 `cum_influence` 与事件 flag 键 |
| `src/systems/save/save_migrator.gd:36` | `events` 壳加 `"cooldowns": {}`（旧档自动补键） |
| `tests/unit/test_schema_freeze.gd:24–41` | 顶层键清单（若新增顶层键） |

---

## 3. 架构风险与返工点

### 3.1 依赖拓扑（12 项改动的偏序）

```
【批 0】数值数据化（K/m/指数/节点数/死键收口）
   └─→ 饱和断言 test_saturation_first99_week
          └─→ 竞对 L4 目标分（~95–98，GDD §2）

【1a】C1 收入口径（含 D-11 裂缝 + B-2 步序 + 确定性修复）
   ├─→ 事件闸 C2（鉴别力依赖占槽口径：GDD :231「现状自动合规 4.9% → 闸失效」）
   ├─→ 呈现层净流入预告（预告要预测"占槽结算 + 非周结过账"）
   ├─→ V1 破产率重标（随收入形态失效：GDD :121）
   └─→ 批 2 任务池 income/固定运维联标

【1b】Σeff + max_staff
   └─→ 竞对死表重标（1f）→ 霸榜可达性
          └─→ 呈现层分级显示（RU-01 的档位阈值依赖玩家曲线）

【1c】买卡命令 + 卡时周预算（强耦合，不可拆）
   ├─→ 训练成本/时长断言（防双重计费）
   └─→ 竞对时间线（训练周期改变出分时点）

【1e】任务池 rp_output 标定 → V6 复算（P10/P50/P90=6/7/7）→（条件项）Σrp_cost 调表
   └─→ 每域 ≥1 可达节点校验（批 3）
   └─→ 翻雾供给源 cum_influence（与谓词收口/域计数同批，避免 V10 空窗重算两次）

【批 2】C3 任务收益/固定运维 + V1 重标 ← 与 1e 互为输入（同一张 tasks.json）
【批 3】域计数分母 + D-1/D-6 口径 + 每域可达性
```

### 3.2 顺序做错即大返工的 6 条（含证据）

| # | 做错的顺序 | 后果 | 证据 |
|---|---|---|---|
| 1 | 先做事件闸（C2）后做 C1 | 闸值在脉冲口径下自动合规（4.9%）→ 参数白标；influence 上限也无法与"任务+事件"总曲线联标 | GDD `:231–233`、`game_world.gd:463` |
| 2 | 先重标竞对（1f）后落 Σeff（1b） | 玩家 eff 从 70 → Σ 后可达 187 → 竞对目标分要重标一次（GDD §2 的 L4 ~95–98 也随之漂移） | `staff_roster.gd:113–119`、纪要 `:521`（"1b 是 1f 的前提"） |
| 3 | 先调 Σrp_cost 后标 `rp_output` | 纪要已撤销一次调表（原方案唯一依据 12.3k 锚无产出通路）；重蹈则调表要再撤一次 | 纪要 `:271–280`、`:581` |
| 4 | 先写饱和断言后做 K/m 数据化 | 断言里写死 K/m → 数据化后断言重写；且饱和阈值 A=154.74 依赖 θ/k | `score_math.gd:9–18`、GDD `:203` |
| 5 | 先做呈现层预告后定账期（R1/P7） | 预告口径与周结实际不一致 → 预告断言（"预告=实际周结"）返工 | `economy.gd:62–82/127–128` |
| 6 | 先改翻雾谓词/域计数后改供给源 | V10 空窗（≤40 周）与域可达性要在新供给曲线下重算两次 | `game_world.gd:514`、GDD `:190` |

### 3.3 分层污染风险（本次 12 项）

| 风险 | 现状证据 | 若按纪要"最小改动路径"实现的隐患 |
|---|---|---|
| **L3 算业务** | `dashboard_presenter.gd:104–113` 在 L3 统计员工三口径（total/assigned/idle）；`main.gd:448–454` 拼文案；`tech_tree_dialog.gd:36–46` 拼域计数 | 改动 12 若让周报/资源栏**自己算净流入预告** → L3 变业务层。必须由 L2 `get_income_forecast()` 出数（纪要 §八已写） |
| **L2 依赖 L3** | 无（全仓 grep 零命中） | 保持 |
| **L3 直读 L4** | `tech_tree_dialog.gd:51` | 域计数收口（批 3）时若继续在 L3 读 `techs.json` 算分母 → 与 `TechFog` 真源再分叉 |
| **L3 直写 L2 内部** | `main.gd:119–120` | 呈现层改造时若保留 `set_pending_decision` → 契约面 12 项对账失真 |
| **L1 同层互引** | `text_service.gd:41/141` | 事件文案迁 texts（改动 11）会加深这条依赖；建议 ADR 明确 L1 内部层级 |

### 3.4 隐藏耦合清单（逐条证据）

| # | 耦合 | 证据 | 风险 |
|---|---|---|---|
| H1 | **GameWorld 直写 `EventEngine._pending_card`** | `game_world.gd:444`（写）、`:529`（清）；`event_engine.gd:17` 是私有字段 | 事件引擎的 pending 语义被门面破坏；改动 5（事件闸）若在引擎内部加冷却/命中率门，必须同时维护这条旁路 |
| H2 | **pending 双份状态** | `game_world.gd:390–391` 读档时把引擎 pending 复制到 `world.pending_decision`；`event_engine.to_save()` 也存 pending（`event_engine.gd:234`） | 两处可不同步（例如 `main.gd:120` 清 world 的 pending 而不清引擎的 → 下周结事件引擎仍认为有卡） |
| H3 | **`flag_set` 走 Object meta 通道，且与策略注入共用命名空间** | `event_engine.gd:202` `world.set_meta(StringName(target), val)`；`game_world.gd:51` `DECISION_POLICY_META=&"decision_policy"` | ①meta 不落盘（改动 11 要修）；②若 `events.json` 的 `target` 取 `"decision_policy"` 会**覆盖测试注入的决策策略**（当前数据没有，但属未设防的命名冲突） |
| H4 | **账期归属未定义**（R1） | `economy.gd:62–82` 累加、`:127–128` 重置；非周结过账点：`game_world.gd:236`（入队 cost）、`tech_tree.gd:69`（研究 cost）、`training_project.gd:53`（训练 cost）、`event_engine.gd:185`（事件 money）、买卡（待做） | 周报收支行归属漂移；预告无法定义 |
| H5 | **双周计数** | `world.week`（`game_world.gd:53`）vs `clock.week`（`game_clock.gd:17`），测试锁定一致（`test_game_world.gd:178–181`） | 改动 1 重排步序时若误用 `clock.week` → 静默错位 |
| H6 | **`_last_signal_report` 单槽** | `game_world.gd:83/414–415/552` | 周报数据只有最近一周；呈现层"周报归档"重看（`dashboard_presenter.gd:162–165`）实际拿的是**当前资源视图**（`main.gd:281`），非历史周报 → 与"周报流"设计有落差（Major，非本次 12 项，但改动 12 会碰这块） |
| H7 | **`_income_roll_seed` 死赋值** | `game_world.gd:143` 赋 `seed+1`，`:183` 又赋 `rng_seed` 覆盖 | 无害但误导；退役脉冲时一并删 |

### 3.5 确定性真源受损（专项，最危险）

| # | 缺陷 | 证据 | 影响 |
|---|---|---|---|
| D1 | **第 4 个随机消费点**：收入脉冲用 `RandomNumberGenerator` + `hash(seed, week)` 播种，绕开 `RngStream` | `game_world.gd:460–463`、`:561–570`（内部类 `_DeterministicRoll`） | 直接违反 ADR-0008 决策 3「消费点恰 3 处，grep 可验」；`docs/adr/0008:21–22` 明写"不设第 4 消费点" |
| D2 | **读档不恢复 `_income_roll_seed`** | `game_world.gd:335–394`（`restore()` 无该字段赋值） | 读档后收入脉冲序列与存档前不同 → "存档回放"不成立 |
| D3 | **读档时 `rival_track.setup` 多消费 4 次 jitter** | `game_world.gd:355`（rng 恢复）→ `:359`（`rival_track.setup` 内部对 4 个 launch 各抽一次：`rival_track.gd:33–48`，`rivals.json` 有 4 个 launch）→ `:360`（再用存档值覆盖 `_action_actual_weeks`） | 计数器被推进 4 次且结果被丢弃 → 读档后 `rival_jitter` 域序列漂移；后续若有新消费点会放大 |
| D4 | **`clock.json.ticks_per_week` 死键** | `clock.json:3` 有值，`game_clock.gd:31` 只读 `tick_seconds`；`game_world.gd:426` 用常量 `GameClock.TICKS_PER_WEEK` | 数据表改周长不生效（B15） |

**建议**（随批 0/1a 落地）：
- D1：C1 退役脉冲源时**不要保留 `_DeterministicRoll`**；若仍需要确定性随机，一律经 `RngStream` 域（改动 5 复用 `event_roll` 是正确先例，纪要 `:563`）；
- D2/D3：补 `test_save_restore_rng_determinism`：`start_new_game(42)` → 模拟 20 周 → 存档 → 读档 → 再模拟 20 周，与"不存档直接模拟 40 周"的 `SnapshotCodec.state_digest`（`snapshot_codec.gd:95–96`）**必须一致**；
- D4：`GameClock.setup` 读 `ticks_per_week` 并删除常量（或保留常量仅作断言基准）。

### 3.6 L2 数据面缺口（L3 被迫硬编码/造数）

| # | L3 想要的数据 | L2 是否提供 | 现状后果 | 证据 |
|---|---|---|---|---|
| G1 | 各域"已探明/总数" | ❌ `get_domain_counts()` 只给"已探明数"（整数），**无总数**；且载荷里键是域名不是 `{lit,total}` | L3 自己硬编码 `4/5/5` 且用了**已废弃域名** → UI 恒显示 `模型架构 (0/4) | 算法演进 (0/5) | 工程基建 (0/5)` | `tech_fog.gd:224–234` vs `tech_tree_dialog.gd:36–46` |
| G2 | 员工三口径（在岗/待命/总） | ❌ 快照只有 `staff[]` 行 | L3 自己遍历统计 | `dashboard_presenter.gd:104–113` |
| G3 | 竞对条（名称/差距/进度） | ❌ `rival_view` 只写 `sota_best/rival_best/cursor`（`dashboard_presenter.gd:90–94`），而 `main.gd:456–459` 读 `rival_name/gap_text/rival_progress` | **竞对条恒显示"深巷科技 / 追赶中 / 0%"**；`rival_warned` 信号（`rival_track.gd:10/97/104`）**从未被连接** → 预警灯（DR-027④）零落地 | 两侧字段名不匹配，测试只断言 `sota_best/rival_best` 存在（`test_dashboard_presenter.gd:34–36`） |
| G4 | 下周净流入预告 | ❌ 无 | 改动 12 必须新增 L2 数据面（纪要 §八已定） | — |
| G5 | 节点表只读视图 | ❌ `TechFog._nodes_data` 私有 | L3 另读磁盘 `techs.json` | `tech_fog.gd:31`、`tech_tree_dialog.gd:51` |
| G6 | 员工 `research/engineering/wage` | ✅ **已提供** | **勘误**：纪要 §八「`snapshot_codec.gd:20–24` 员工快照缺 `research`」**表述不准确**：`ui_snapshot["staff"]` 实际来自 `roster.to_snapshot()`（`snapshot_codec.gd:45`），而 `to_snapshot()` 返回含 `research/engineering/wage` 的完整行（`staff_roster.gd:136–140`）。真正的问题是 `snapshot_codec.gd:13–25` 构造的 `staff_list` **是死代码（从未被返回或使用）**，且名册弹窗绕过快照直读 `roster`（`staff_roster_dialog.gd:36`）→ 存在**两种 staff 形状** | 见左 |

---

## 4. ADR 建议（**只写建议，不创建文件**）

> 格式：标题 / 状态 / 决策 / 备选 / 后果 / 与现有 ADR 的关系。所有条目**待制作人批准后另批落笔**。

### ADR-0011 算力供给模型：每周预算（weekly budget）而非卡池余量

- **状态**：新增（accepted 建议）。
- **决策**：`compute_hours_remaining` 的语义 = **本周可用预算**；每周期结（步序 1）重置为 `economy.json` 新增键 `compute_tiers[].weekly_supply`（GDD §6.3 的 8/16/32/64）；`capacity`（40/80/160/320）**仅作 `apply_delta("compute")` 的上限校验**，不参与每周重置。训练按 `model_bases.hours_per_week` 逐周扣减本周预算；`base.cost` 是**全程卡时费**，卡时只作门槛/占用，**不得再过账 money**（`economy.training_cost()` 建议删除或改为纯门槛函数）。
- **备选**：(a) 卡池扣减（**否决**：璞石全程 60 卡时 > tier1 容量 40 → 训练不可行，D-10 实算）；(b) 供给与容量合并为一个键（**否决**：两者是不同概念，D-6 已判分键）。
- **后果**：正向——训练永远供得上、买卡动机清晰（升档=提高每周供给）、防双重计费有唯一解；代价——`hours_remaining` 存档语义变更（零迁移但需 ADR 记录）、`opening.json:8` 开局 `hours_remaining=0` 需改为"首周即重置为供给"或开局预置一份供给。
- **关系**：落 DR-031/D1②·D-9·D-10 与 GDD §6.3；修订 DR-018（"卡池规模档"表述）；不触碰 ADR-0008。

### ADR-0012 RP 供给真源与翻雾供给源（RP=影响力同一池）

- **状态**：新增（accepted 建议）。
- **决策**：①RP 与影响力**同一资源**，唯一来源 = 任务 `rp_output`（`game_world.gd:481–487`）+ 事件 `rp_grant`（`event_engine.gd:190–191`）；**不存在"研究力每周产 RP"通路**，任何新增供给必须经 `apply_delta("influence")`。②翻雾推进的实参改为**独立累计计数器 `cum_influence`**（`apply_delta` 成功入账 influence 时同步累加，只增不减），`tech_fog.advance(cum_influence)` 不再读当前余额（修 D-12：点树花影响力不再拖慢翻雾）。③`cum_influence` 入 `flags{}`（开放容器，零迁移）。
- **备选**：(a) 继续用余额（**否决**：点树改变翻雾语义）；(b) 新建独立资源"研究力"（**否决**：与"三资源不可逆"设计原则冲突，且需全链改造）。
- **后果**：正向——供给模型单点真源、翻雾语义与消耗解耦、V6/V10 可复算；代价——`cum_influence` 必须随存档往返（否则读档进度漂移）、`fog_gate`（200/600）的量纲改为"累计影响力"需在数据表注明。
- **关系**：落 DR-031/§2.9 第 1·4 条与 GDD §6.1/§7；与 ADR-0009（TechFog 纯函数）兼容——`advance()` 入参语义变更，建议**保留旧签名并新增 `advance_with_context()`**（纪要 §八"最小改动路径"）。

### ADR-0013 数值数据化边界与"零默认值"纪律

- **状态**：新增（accepted 建议）；**同时修订 ADR-0009**（TechFog 的 `TOTAL_NODES`/pity/开局可研节点改数据键）。
- **决策**：①**一切可调数值必须来自 `src/data/*.json`**，代码内 `_config.get(key, <字面量>)` 的**字面量默认值一律删除**，改为"缺键即 `push_error` 并熔断"（防双真源漂移）；②明确"公式形态 vs 数值"边界：**公式形态**（Cobb-Douglas 乘积结构、sigmoid 形态）可留代码，**系数/指数/阈值**（K、m、θ、k、0.7、0.3、`TOTAL_NODES`、pity、fog_gate、jitter、预警公式系数）全部进表；③`benchmarks.json` 扩为出分参数真源（`k`/`compute_multipliers`/`ability_exponents`），`techs.json` 提供 `total_nodes` 或由 `nodes.size()` 派生，`economy.json` 提供 `weekly_supply`/`upkeep_weekly`。
- **备选**：(a) 只迁纪要点名的 K/m/节点数（**否决**：指数 0.7/0.3、`event_engine.gd:84` 的第二处 14、`clock.json.ticks_per_week` 死键会留下新的双真源）；(b) 全量迁 JSON 含公式结构（**否决**：过度设计，YAGNI）。
- **后果**：正向——改数值不改码、grep 可审计、D-7/M-9 收口；代价——数据表键增多、需为每键补"缺键即报错"的测试；迁移风险为零（数据表非 schema）。
- **关系**：落 DR-031/D-7·D3·B1 与 AGENTS.md 红线 3；与 ADR-0009 的"迷雾调参纯数据"一致，需在其后果段补"节点总数与开局可研节点亦数据键"。

### ADR-0014 谓词单点真源（PredicateRegistry 唯一求值口）

- **状态**：新增（accepted 建议）；**同时修订 ADR-0009 的"tech_fog 消费同一注册表"条款落地**。
- **决策**：①**一切 `{predicate, params}` / `{any_of}` 结构必须经 `PredicateRegistry.evaluate()` 求值**，禁止任何调用方自实现 `match predicate` 分支；②`tech_fog` 的"可研判定"改为"`parents` 全 lit"→ `tech_lit{tech_ids}` 谓词 + `crossover_count` 谓词 + 节点级 `unlock` 字段统一求值（删除 `node_id == "mirror_mind"` 特例，`tech_fog.gd:318`）；③`task_queue._check_unlock`（`:120–145`）改为薄封装：构造 context 后调用注册表；④`techs.json` 的 `unlock` 字段**必须被消费**（当前 `rp_threshold` 门在 `long_scroll`/`arm_will` 上完全无效）；⑤`min_week` 若保留为硬门，必须实现（当前**零消费**，`grep` 仅命中 `tests/unit/test_techs_data.gd:83`）。
- **备选**：(a) 保留三处分叉（**否决**：新谓词要改三处、行为不一致、ADR-0009 已声明共用注册表）；(b) 做表达式引擎/DSL（**否决**：DR-011 明确 YAGNI）。
- **后果**：正向——谓词扩展单点、`tech_tree.gd:5` 的文档承诺兑现（当前零调用）、`unlock` 数据生效；代价——`TechFog` 需要 context（lit 集合/累计影响力/主干数），从"纯字典进纯字典出"变为"需注入 context"，`advance()` 签名调整（建议新增 `advance_with_context()` 保留旧签名）。
- **关系**：落 DR-031/改动 9、DR-011、ADR-0009 理由 2；与 ADR-0012（`rp_threshold` 需要 `cum_influence`）耦合，建议同批。

### ADR-0015 周结管线的收入结算与破产判定步序契约

- **状态**：新增（accepted 建议）；**修订 DR-021 B3 的契约表述**（"判定写死在收支后" → "判定写死在**全部经营收入结算之后**"）。
- **决策**：①周结步序固定为：`1 固定支出 → 2 任务结算与过账 → 3 收支 ledger 快照（含任务收入）→ 4 破产判定短路 → 5 delayed 效果 → 6 出分/SOTA → … → 11 自动存档`（或按 P3 选 (b)：任务结算保持原位、破产判定后移）；②**账期契约**：`ledger` 只统计"本次周结步 1–2 期间"的过账；非周结过账（买卡/研究/入队/事件 immediate）计入**下一周**周报，并在 `get_income_forecast()` 中作为"已知待入账"项披露；③破产短路前必须完成全部经营收入过账。
- **备选**：(a) 任务结算并入步序 1（推荐）；(b) 短路后移（备选）；(c) 双 ledger（周结账 + 实时账，**否决**：改动面大、UI 双口径易错）。
- **后果**：正向——周报闭合（GDD §6.1）、破产判定口径清晰、预告可定义；代价——周结管线图（GDD §5.2）与 ADR-0005 的"周结末步"映射需同步改、破产时已结算的任务收入会进入终局档。
- **关系**：落 DR-031/C1·B-2、GDD §5.2 步序修正段；修订 DR-021 B3；与 ADR-0005（存档时机）无冲突（末步仍为存档）。

### ADR-0016 L2 数据面契约：L3 零业务计算

- **状态**：新增（accepted 建议）。
- **决策**：①**L3 只做格式化与布局**，任何"派生数值/统计/预测"必须由 L2 提供：新增 `GameWorld.get_income_forecast()`（下周净流入预告）、`get_staff_view()`（三口径）、`get_domain_progress()`（`{lit,total}` 按域）、`get_rival_view()`（名称/差距/进度/预警等级）；②L3 **禁止**直接读 L4 数据表（删除 `tech_tree_dialog.gd:51` 的磁盘读）；③L3 **禁止**调用非契约命令（`main.gd:119–120` 的 `set_pending_decision` 收口为调试专用注入或契约化）；④`ui_snapshot` 保留全量只读语义，新增字段走"快照 + 契约命令"双通道。
- **备选**：(a) 现状（L3 自算，**否决**：`tech_tree_dialog` 已因缺数据而硬编码并显示错误值）；(b) 让 L3 依赖 L2 实体（**否决**：ADR-0002 的注入语义模糊化）。
- **后果**：正向——改动 12 可验收（"L3 只格式化"可 grep 断言）、G1–G4 缺口一次性补齐、`rival_warned` 有落地路径；代价——L2 门面方法增多（建议保持"只读查询"轻量，不进 `CONTRACT_COMMANDS`，除非 P1 决定）。
- **关系**：落 DR-031/改动 12 与 DR-015；修订 ADR-0002 的"经注入可触达 L2 数据"注释（明确"数据面=快照/只读查询，不是内部对象"）。

### 附：ADR-0008 修订建议（不新建）

- **状态**：修订 `docs/adr/0008-deterministic-domain-counter-rng.md`（追加"消费点登记表 + 第 4 点退役"）。
- **决策**：把"消费点恰 3 处"改为"**登记表机制**"：新增消费点必须在 `RngStream.REGISTERED_DOMAINS`（`rng_stream.gd:14–18`）登记并在此 ADR 追加一行；**禁止**在 `entities/` 内新建 `RandomNumberGenerator`（`game_world.gd:460–463` 现状违规，随 C1 退役）；补"读档确定性"条款（存档往返后 RNG 序列必须一致，D2/D3）。
- **关系**：落 ADR-0008 决策 3；与 ADR-0012（`cum_influence` 非 RNG）无冲突。

---

## 5. 落地 PR / issue 拆分建议（对齐纪要 §六 批 0–3）

> 每项给出：**改动面（文件清单）** / **必须随行的断言** / **ADR 同步** / **最小改动路径**。

### 批 0（立即，零行为变更）

| PR | 标题 | 改动面 | 随行断言 | ADR |
|---|---|---|---|---|
| **0a** | `chore(docs): 口径收口（分母表述/A1 表述/Q 编号）` | `docs/gdd/gdd.md:170`（D3 选项 **(b)** 与"建议改 11"冲突，须改为"显示 n/14 并注明 elsewhere 不可研"）、`:346`；`docs/discussion/decision-log.md:57`（A1 段仍写"靠 A2 调表使 P50=9 合规"，与 A2 撤销调表矛盾）；`docs/discussion/README.md` 索引 | 无（纯文档） | 无 |
| **0b** | `refactor(core): K/m/指数/节点数/死键数据化（零行为变更）` | `src/core/score_math.gd:9–18/34–35`、`src/data/benchmarks.json`、`src/entities/tech_fog.gd:18–29/33–34/320`、`src/entities/event_engine.gd:29–31/66–68/84–85/127`、`src/entities/game_clock.gd:15` + `src/entities/game_world.gd:426` + `src/data/clock.json:3`、`src/entities/economy.gd:111–112/205`、`training_project.gd:37/56/61/124`、`sota_board.gd:18/20`、`rival_track.gd:22/28/96/101`、`text_service.gd:13–24`、`game_world.gd:295` | `test_formula_data_driven_equals_hardcoded`（新：数据化前后逐值一致，扩展现有 `test_acceptance_point_1_formula_boundary_vectors`）；`test_no_numeric_defaults_in_code`（新：grep 断言 `_config.get(key, 数字)` 零命中）；`test_tech_fog.gd:20–22/190` 重写（不再断言常量） | ADR-0013 |

**最小路径**：数据化 PR **只做"迁表 + 删默认值"**，不动公式形态、不改行为；`TOTAL_NODES` 用 `techs.json` 新键 `total_nodes`（而非 `nodes.size()`）以兼容"elsewhere 不可研"的分母口径（改动 8/D3 选项 b）。

### 批 1（v1.0 P0，按拓扑序）

| PR | 标题 | 改动面 | 随行断言 | ADR | 依赖 |
|---|---|---|---|---|---|
| **1a** | `fix(economy): 收入口径改占槽结算 + 周报裂缝 + 破产步序 + 确定性修复` | `src/entities/game_world.gd:458–556`（步序）、`:143/183`（死赋值）、`:460–463/561–570`（删第 4 随机源）、`:335–394`（补 `_income_roll_seed` 恢复）、`:355–360`（修 setup/restore 顺序）、`src/entities/economy.gd:120–145`（`accrue_week` 拆"支出/结算/账"三段）、`src/data/economy.json:15–21`（`sources` 开关退役/标注）、`:5–6`（`duration_min/max` 死参数清理） | `test_weekly_ledger_includes_task_income`、`test_bankruptcy_after_task_income`、`test_pulse_source_retired`、`test_save_restore_rng_determinism`（D2/D3）、`test_economy.gd:74–101` 重写（脉冲断言退役） | ADR-0015、ADR-0008 修订 | — |
| **1b** | `feat(staff): Σeff 落地 + max_staff 上桌上限` | `src/entities/staff_roster.gd:17–20/46–65/95–96/113–119`（多人槽 + Σ）、`:144–153`（**保持存档形状**）、`src/data/model_bases.json`（加 `max_staff`）、`src/entities/training_project.gd:29–41`（上桌校验）、`src/entities/game_world.gd:580–585` | `test_research_eff_sums_slot_occupants`、`test_training_headcount_bounded_by_base`、`test_staff_multi_assign_save_roundtrip`（断言 `assigned` 形状不变） | — | 0b |
| **1c** | `feat(economy): 买卡契约命令 + 卡时每周预算（不可拆）` | `src/entities/economy.gd:72–78/149–159` + `recharge_weekly()`、`src/data/economy.json`（`weekly_supply`）、`src/entities/game_world.gd:24–36`（命令 11→12）、`:458` 起（步序加 `recharge_weekly`）、`src/entities/training_project.gd:45–65`（每周扣预算 + 余量不足拒绝）、`src/ui/main/main.gd`（资源条按钮，零 PanelStack 注册） | `test_command_and_signal_contract_accounting`（11→12）、`test_weekly_compute_supply_reset`、`test_training_cost_not_double_charged`、`test_training_rejected_when_budget_insufficient` | ADR-0011 | 1a |
| **1d** | `feat(events): 命中率门 + 冷却 + 预算闸 + 文案迁 texts + flag_set 入档` | `src/entities/event_engine.gd:97–162`（`p_week` 门 + 冷却 + 权重）、`:231–237`（`cooldowns` 入档）、`:178–208`（`flag_set` 落 flags）、`src/data/events.json`（`p_week`/`cooldown`/单卡上限重标/文案键）、`src/entities/game_world.gd:381–383`（flags 读写）、`src/entities/snapshot_codec.gd:90`、`src/data/texts.json` | `test_event_hit_rate_gate`、`test_event_cooldown_blocks_repeat`、`test_event_income_share_bound`、`test_flag_set_persists_across_save`、`test_texts.gd` 键数重标 | ADR-0016（文案通道） | 1a |
| **1e** | `chore(balance): 任务池 rp_output/income 标定 + V6 复算 + cum_influence + 饱和护栏` | `src/data/tasks.json`、`src/data/assertion_bounds.json:16`（`supply_anchor_rp` 重标）、`src/entities/game_world.gd:514` + `src/entities/economy.gd`（`cum_influence` 累加）、`src/entities/tech_fog.gd:84–126`（`advance_with_context`）、`tests/unit/test_assertion_bounds.gd:27–57`、`tests/unit/test_game_world.gd`（新增饱和用例） | `test_saturation_first99_week`、`test_v6_lit_distribution_6_7_7`、`test_domain_reachable_under_p50`（每域 ≥1）、`test_fog_advance_independent_of_balance`（点树不拖慢翻雾） | ADR-0012 | 1a |
| **1f** | `chore(balance): 竞对死表重标（N11）` | `src/data/rivals.json`（L1–L4 分数 + 预警周）、`src/entities/rival_track.gd:96/101`（预警公式数据键） | `test_rival_scores_within_jitter_band`、`test_acceptance_point_4_warning_thresholds_and_zero_false_alarm`（重标） | — | 1b/1e/批 2 |
| **1g** | `feat(ui): 呈现层（L2 数据面 + 显示分级 + 净流入预告）` | `src/entities/game_world.gd`（`get_income_forecast/get_staff_view/get_domain_progress/get_rival_view`）、`src/entities/snapshot_codec.gd:13–25`（**删死代码** `staff_list`）、`:26–54`（加字段）、`src/ui/dashboard_presenter.gd:82–113`（改为消费 L2 视图）、`src/ui/main/main.gd:448–459`（格式化）、`src/ui/modals/tech_tree_dialog.gd:36–51`（删硬编码与磁盘读） | `test_forecast_equals_actual_week_settlement`、`test_domain_progress_matches_fog`、`test_rival_view_fields_populated`、`test_l3_no_business_math`（grep） | ADR-0016 | 1a/1b |

### 批 2 / 批 3

| PR | 标题 | 改动面 | 随行断言 | ADR |
|---|---|---|---|---|
| **2** | `chore(balance): 任务池 income/固定运维联标 + V1 破产率重标` | `src/data/tasks.json`、`src/data/economy.json`（`upkeep_weekly`）、`src/entities/economy.gd:126–145`（固定运维读键）、`tests/unit/test_task_roster_integration.gd:72–99`、`test_assertion_bounds.gd:19–24` | `test_weekly_upkeep_applied`、`test_lab_weekly_expense_9k`、`test_v1_bankruptcy_rate_rebased` | ADR-0015 |
| **3** | `chore(docs+data): 域计数分母 + 口径修正 + 每域可达性` | `src/entities/tech_fog.gd:224–234`（`get_domain_progress` 返回 `{lit,total}`）、`src/ui/modals/tech_tree_dialog.gd:36–46`、`src/data/techs.json`、`tests/unit/test_tech_fog.gd:166–196`、`tests/integration/test_tech_and_staff_panels.gd:26–28`（**重写**：当前断言的是错误域名） | `test_domain_count_denominator_consistency`、`test_domain_reachable_under_p50` | ADR-0014/0016 |

**建议的 issue 归属**（对齐纪要 §十一）：1a→#1（扩）、1b→#2、1c→#3+#4（合并或强依赖）、1d→#5、1e→#6+#9（合并，避免 tasks.json 两次改）、1f→#7、1g→#8、0a/0b/3→#10（扩）。

---

## 6. 测试策略

### 6.1 新增 / 重标 GUT 用例清单

| 用例名 | 断言点（要点） | 归属 PR | 门禁 |
|---|---|---|---|
| `test_weekly_ledger_includes_task_income` | `week_settled` 报告 `money_row.income` ≥ 本周任务结算额；`Economy.get_week_ledger()` 与报告一致 | 1a | **verify** |
| `test_bankruptcy_after_task_income` | 资金 −210k + 本周 +60k 结算 → 按 P3 口径断言（不破产/破产），并断言终局档内容 | 1a | **verify** |
| `test_pulse_source_retired` | `economy.json` 脉冲参数不再产生收入；`accrue_week` 无 `_roll_income` 调用 | 1a | **verify** |
| `test_save_restore_rng_determinism` | `start(42)`→20 周→存档→读档→20 周 的 digest == 直接 40 周 digest（`snapshot_codec.gd:95–96`） | 1a | **verify** |
| `test_command_and_signal_contract_accounting`（扩） | `CONTRACT_COMMANDS.size()==12` 且含买卡名；信号数与清单一致；**并断言 11 个信号中至少 9 个在模拟中被 emit 过**（防死信号回归） | 1c | **verify** |
| `test_weekly_compute_supply_reset` | 每周期结后 `hours_remaining == weekly_supply`；买卡后 `weekly_supply` 升档 | 1c | **verify** |
| `test_training_cost_not_double_charged` | 开训扣 `base.cost` **一次**；全程 10 周后 money 变化 == `-cost`（无卡时转钱）；`training_cost()` 不产生 `apply_delta` | 1c | **verify** |
| `test_training_rejected_when_budget_insufficient` | `hours_per_week > 本周供给` → 拒绝 + 原因 | 1c | **verify** |
| `test_training_headcount_bounded_by_base` | 上桌人数 > `max_staff` 拒绝；≤ 允许；`min_staff` 行为按 P5 断言 | 1b | **verify** |
| `test_research_eff_sums_slot_occupants` | 2 人入训练槽 → `research_eff == 70+55`；空槽 → 0 | 1b | **verify** |
| `test_staff_multi_assign_save_roundtrip` | 多人同槽 → `to_save()["assigned"]` 形状仍为 `{staff→slot}` → restore 还原 | 1b | **verify** |
| `test_event_hit_rate_gate` | `p_week` 门生效（1000 seed 统计命中率 ∈ 区间） | 1d | **verify** |
| `test_event_cooldown_blocks_repeat` | 冷却期内同卡不再抽中；`cooldowns` 读档还原 | 1d | **verify** |
| `test_event_income_share_bound` | 事件累计收入 / 累计经营收入 ≤ 10%（占槽口径下） | 1d | nightly |
| `test_flag_set_persists_across_save` | `flag_set` 后存档→读档 → flag 仍可读 | 1d | **verify** |
| `test_saturation_first99_week` | 首达 99 分周次 ≥ 50（现状实算 W54） | 1e | **verify** |
| `test_v6_lit_distribution_6_7_7` | P10/P50/P90 = 6/7/7（供给标定后） | 1e | nightly |
| `test_domain_reachable_under_p50` | P50 供给下每域 ≥1 节点可达（M-2） | 1e/3 | nightly |
| `test_fog_advance_independent_of_balance` | 点树扣影响力后 `advance` 推进量不变（`cum_influence` 生效） | 1e | **verify** |
| `test_forecast_equals_actual_week_settlement` | `get_income_forecast()` == 下周实际 `week_settled` 的 net（含非周结待入账） | 1g | **verify** |
| `test_domain_count_denominator_consistency` | 分母与可研数口径一致（D3 选项 b：显示 n/14 + elsewhere 标注） | 3 | **verify** |
| `test_l3_no_business_math` | grep 断言 L3 无统计/预测计算（仅格式化） | 1g | **verify** |
| `test_formula_data_driven_equals_hardcoded` | 数据化前后逐值一致 | 0b | **verify** |
| `test_no_numeric_defaults_in_code` | grep 断言 `_config.get(key, <数字>)` 零命中 | 0b | **verify** |

**重标（既有用例）**：
- `test_assertion_bounds.gd:34`（`supply_anchor_rp==12300`）→ 改为"供给锚由任务池标定后复算"，或断言 ∈[4910,6810)；
- `test_assertion_bounds.gd:43–57`（"单调性"弱断言）→ 改为断言"lit 数随供给单调不减"（当前只比 `discovered_count`）；
- `test_economy.gd:74–101`（脉冲参数/行为）→ 退役或改为"固定支出 + 任务结算"口径；
- `test_tech_fog.gd:20–22/190`（硬编码常量）→ 改读数据键；
- `test_tech_and_staff_panels.gd:26–28`（断言"模型架构/算法演进/工程基建"）→ **必须重写**（当前锁定了错误域名）；
- `test_task_roster_integration.gd:78–92`、`test_techs_data.gd:103–120`（逐值硬断言）→ 随 C3/rp 标定同步；
- `test_main_scene_smoke.gd:40`（文本键 40）→ 事件文案迁 texts 后同步。

### 6.2 `verify.sh` 必跑 vs nightly 划分

**现状**：`scripts/verify.sh:22` 固定 `-gdir=res://tests -ginclude_subdirs -gexit` → **所有 178 用例都在必跑集**；`.github/workflows/` 只有 `ci-validate.yml` 与 `release-build.yml`，**无 schedule/nightly workflow**（`grep schedule` 零命中）。

**建议机制**（GUT 已支持，零改造）：
- 必跑集 = 现有 34 个脚本（全部纯逻辑 + 冒烟，实测 11.25s，成本可接受）；
- **nightly 集** = 新建 `tests/sim/` 目录（文件名 `test_sim_*.gd`），用 `-gtest=<显式列表>` 或 `-gselect=sim`（`addons/gut/cli/gut_cli.gd:116/126`）单独跑；内容 = 万局蒙特卡洛（V1 破产率/V6 分位/V10 空窗/事件收入占比/每域可达性/竞对 ±15% 带），单次目标 ≤10 分钟；
- 新增 `.github/workflows/nightly.yml`（`on: schedule` + `workflow_dispatch`），**与 `verify.sh` 分离**（守 DR-030"流程门禁与 verify.sh 永久分离"的同类纪律：耗时模拟门禁不拖慢 PR）；
- 性能防呆线维持"量级劣化"口径（`testing.md:67–69`、`test_game_world.gd:132–134`）。

**必跑集新增的边界**：`test_save_restore_rng_determinism`（D2/D3）必须进必跑——它是确定性红线的唯一兜底。

### 6.3 已发现的假绿 / 脆弱点

| # | 位置 | 问题 | 建议 |
|---|---|---|---|
| F1 | `tests/integration/test_playtest_loop_headless.gd:130–131` | `assign_staff("r_lin","slot_core")` 是**非法槽**（`staff_roster.gd:14` 只认 `task`/`training`）→ 返回 false；断言只查 `world.staff.has("r_lin")`（恒真）→ **假绿** | 改断言 `assign_staff` 返回值 + `get_slot_occupant` |
| F2 | `tests/unit/test_task_roster_integration.gd:159–161` | `driver.setup(_world.clock)` 传的是 `GameClock`（`GameLoopDriver.setup` 期望"有 `get_clock()` 的对象"，`game_loop_driver.gd:62–70`）→ 驱动实际未参与，真正推进靠 `:163` 直调 `clock.advance` | 传 `_world`；或用 `driver.feed_frame()` 驱动 |
| F3 | `tests/unit/test_dashboard_presenter.gd:34–36` | 只断言 `rival_view` 含 `sota_best/rival_best`，**未断言** `main.gd:456–459` 实际消费的 `rival_name/gap_text/rival_progress` → 竞对条恒 0% 的缺陷被放过 | 补三字段断言 |
| F4 | `tests/integration/test_tech_and_staff_panels.gd:26–28` | 断言域计数标签含"模型架构/算法演进/工程基建"——**这些域名在 `techs.json` 中不存在**，测试锁定了错误实现（真实 UI 恒 `(0/4)(0/5)(0/5)`） | 随批 3 重写 |
| F5 | `tests/unit/test_assertion_bounds.gd:47–57` | 用例名"点亮随供给单调不减"，实际只比 `get_discovered_count()`（非 hidden 计数，构造上单调）→ **弱断言** | 改为比较 `lit` 数 |
| F6 | `tests/unit/test_tech_fog.gd:21` | 断言 `PITY_THRESHOLD==8`——该常量**全仓零消费** → 测试在保护死代码 | 删除常量或实现消费 |
| F7 | `tests/unit/test_schema_freeze.gd:122`、`test_game_over_and_save.gd:24–37/63–65`、`test_game_world.gd:150–151` | 均写/读 `user://savegame.json`（`save_system.gd:17`）→ 用例间**共享磁盘状态**，顺序敏感；`test_schema_freeze` 直接 `settle_week()` 触发落盘 | 用临时路径参数 `save_game(data, path)`/`load_game(path)` 隔离（API 已支持 `:23/31`） |
| F8 | `tests/unit/test_event_engine.gd:31–40` | 注释称"权重分位数断言"，实际只断言 `hit_counts.size() > 2` | 改分位数/卡方 |
| F9 | `tests/unit/test_event_engine.gd:98/133–134` | 直接写 `engine._pending_card`、`tech_fog._fog_states` 私有字段 → 与实现耦合，重构即红 | 用公开 API 或新增测试专用构造 |
| F10 | `tests/unit/test_techs_data.gd:82–84` | 只断言 `synesthesia_clip.min_week >= 26`（数据值），但 `min_week` **生产零消费**（GDD §8.1 的"防穿越"未实现） | 随 ADR-0014 实现后改为行为断言 |
| F11 | `tests/unit/test_game_world.gd:62–63` | 命令/信号数 11 硬断言——设计如此（契约对账），但**未断言信号真的会被发出** → 两个死信号（§1.6）长期存在 | 补 emit 覆盖断言 |

**缺失覆盖（建议补）**：`restore()` 的字段完整性（`_income_roll_seed`/`cum_influence`/flags）、`compute_tier` 在信号/快照的同步、L3 零业务 grep 门禁、`events.pending` 文案通道往返、`rival_warned` 到 UI 的链路、**契约命令的 UI 落点核对**（`submit_model_name` 当前无 UI 路径，见 §1.6；建议 `test_all_contract_commands_have_ui_paths`：grep `src/ui/` 对 12 条命令的调用面）。

---

## 7. 附录

### 7.1 对纪要/GDD 的勘误（4 条，均有代码实证）

| # | 稿面表述 | 代码实证 | 处置 |
|---|---|---|---|
| E1 | 纪要 §八「`snapshot_codec.gd:20–24` 员工快照缺 `research` 字段（员工实体卡阻塞项）」 | `ui_snapshot["staff"]` 来自 `roster.to_snapshot()`（`snapshot_codec.gd:45`），**已含** `research/engineering/wage`（`staff_roster.gd:136–140`）；`:13–25` 的 `staff_list` 是**死代码**（构造后从未使用） | 改动 12 的验收点改为"删除死代码 + 统一 staff 形状（名册弹窗改走快照）"，而非"补字段" |
| E2 | GDD `:170`「`TOTAL_NODES=14` 硬编码 → 建议改 11」 | 纪要 §D3 第 2 条已**改选 (b)**（显示 n/14 + 注明 elsewhere 不可研） | GDD 该句须同步为选项 (b)（批 0a） |
| E3 | `decision-log.md:57` DR-031/A1「合规路径 = …靠 A2 调表使 P50=9 合规」 | 同一行 A2 已写"撤销调表"，GDD §8.1 亦为"撤销调表 + 标定供给" | decision-log 该句须改为"合规路径 = 标定任务池 rp_output"（批 0a） |
| E4 | 纪要 §八「最小改动路径：买卡 UI 挂资源条按钮…」 | 与契约面一致；但 `resources_changed` 载荷不含 `compute_tier`（`game_world.gd:11`）→ 买卡后资源栏若展示档位会读到旧值 | 随 1c 定契约（P1/§2.4） |

### 7.2 证据索引（高频引用文件）

| 文件 | 关键行 | 用途 |
|---|---|---|
| `src/entities/game_world.gd` | `:11`（信号载荷）、`:24–49`（契约清单）、`:335–394`（restore）、`:424–426`（周推进）、`:458–556`（周结管线）、`:514`（翻雾实参）、`:561–570`（第 4 随机源） | 门面/管线/契约 |
| `src/entities/economy.gd` | `:62–82`（唯一过账口）、`:105–106`（ledger）、`:126–145`（accrue）、`:149–159`（买卡）、`:204–206`（死方法） | 经济 |
| `src/entities/staff_roster.gd` | `:17–20`（单槽）、`:46–65`（分配）、`:113–119`（单人 eff）、`:144–153`（存档形状） | Σeff/max_staff |
| `src/entities/tech_fog.gd` | `:18–20`（硬编码）、`:24–29`（开局节点）、`:84–126`（advance）、`:224–234`（域计数）、`:313–331`（硬编码谓词） | 迷雾/谓词 |
| `src/entities/event_engine.gd` | `:97–162`（抽卡）、`:178–208`（效果/flag_set）、`:231–237`（存档） | 事件闸/flag |
| `src/entities/snapshot_codec.gd` | `:13–25`（死代码）、`:26–54`（快照）、`:58–91`（存档）、`:95–96`（digest） | schema |
| `src/core/score_math.gd` | `:9–18`（K/θ/k/m）、`:34–35`（指数） | 数据化 |
| `tests/unit/test_game_world.gd` | `:56–63`（契约对账）、`:123–134`（万周） | 契约/确定性 |

---

**（文档结束）**
