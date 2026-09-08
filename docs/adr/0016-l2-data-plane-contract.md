# 0016. L2 数据面契约：L3 零业务计算

日期：2026-09-08 / 状态：accepted（**补建**：本 ADR 由 issue #78 引入但文件未随 PR #90 落地，2026-09-08 依架构复审 v1.2 §ADR-0016 与代码实证补建；决策 ①②④ 已落地，决策 ③ 部分落地，见「现状核实」与「决策对账表」）/ 落 DR-031（改动 12）与 DR-015 与 issue #78

## 背景

`ADR-0002:20` 只写了 L3「依赖 L0/L1，经注入可触达 L2 数据」，**未界定"数据"是快照/只读查询，还是 L2 内部对象**。这条模糊直接导致 L3 在 #78 之前是"半业务层"，且已产生**可见的显示缺陷**（不是风格问题）：

1. **L3 自行计算派生数值**：`dashboard_presenter.gd` 自己遍历名册统计员工三口径（total/assigned/idle）；`tech_tree_dialog.gd` 自己拼域计数。
2. **L3 直接读 L4 数据表**：`tech_tree_dialog.gd:51` 曾 `DataLoader.load_json("res://src/data/techs.json")`——与 `TechFog` 自持的 `_nodes_data` 构成**双真源**，两者可不同步，且重复磁盘 IO。
3. **显示错误值（实证缺陷）**：域计数分母硬编码 `4/5/5` 且用了已废弃域名 → UI 恒显示 `模型架构 (0/4) | 算法演进 (0/5) | 工程基建 (0/5)`（G1）；竞对条因两侧字段名不匹配恒显示「深巷科技 / 追赶中 / 0%」（G3）；员工三口径在 L3 自算（G2）；下周净流入预告**完全无数据面**（G4）。四处缺口（G1–G4）全部是"L3 拿不到 L2 出数"的直接后果。
4. **L3 直写 L2 内部状态**：`main.gd` 调试驱动调用 `_world.set_pending_decision({})`——该方法**不在契约命令面**，其自述语义是"事件引擎与装配层使用；UI 不调用"。
5. **契约面无法验收**：没有边界定义，"L3 只格式化"既写不成规范，也 grep 不出违规（现有 L3 零写路径门禁 `test_playtest_loop_headless.gd:87–93` 只禁 5 种模式，拦不住上述任何一条）。

### 现状核实（2026-09-08 于 main，grep/读码证据）

**已落（现状成立）**

- **L2 只读数据面已建**（`src/entities/game_world.gd`，文件头 `:228` 已声明「只读数据面（ADR-0016：L3 零业务计算…）」）：
  - 四主面：`get_income_forecast()`（`:234`）、`get_staff_view()`（`:287`）、`get_domain_progress()`（`:303`）、`get_rival_view()`（`:366`）；
  - 四支撑面：`get_tech_list_view()`（`:343`）、`get_score_display()`（`:406`）、`get_naming_view()`（`:440`）、`get_last_ledger()`（`:449`）；
  - 既有面复用：`get_compute_upgrade_view()`（`:612`）、`get_last_report()`（`:933`，周报 UI 唯一数据源）、`get_game_over_summary()`（`:669`）。
- **`ui_snapshot()` 全量只读语义已扩**（`src/entities/snapshot_codec.gd:14–48`）：新增 `staff_view`（`:35`）、`rival_view`（`:38`）、`domain_progress`（`:39`）、`forecast`（`:40`）、`naming`（`:41`）五键；`staff_list` 死代码已删。
- **L3 禁读 L4 已成立**：`grep -rn "DataLoader\|load_json\|res://src/data" src/ui/` → **零命中**；`tech_tree_dialog.gd:35–51` 已改为经 `get_domain_progress()` + `get_tech_list_view()` 取数，`:51` 的磁盘读已删除。
- **可执行门禁已建**：`tests/unit/test_presentation_layer.gd:184–212` `test_l3_no_business_math`（L3 禁词断言 + L2 数据面方法存在性断言）；`:158–161` 锁定「命令 12 / 信号 11 / 预告不进命令面 / 不新增预告信号」。
- **`rival_warned` 有落地路径**：`game_world.gd:143` 已连接 `rival_track.rival_warned` → `_on_rival_warned`（`:164`），预警等级经 `get_rival_view()` 的 `warn_level`/`warn_weeks_left`（`:382–383`）出数，`dashboard_presenter.gd:123–124` 只透传——L3 无需自算预警。

**待落 / 边界（如实登记，未粉饰）**

- **决策 ③ 未收口**：`main.gd:128–129` 仍在 `_setup_debug_shot_driver()` 内直调 `_world.set_pending_decision({})`。已限定在"仅 Web 且带 `?shot=`/`?selftest=` 参数"的调试驱动分支（`:117–124`），但**仍是 L3 对非契约方法的调用**。
- **"数据面=快照/只读查询"推论下的现存偏差**（本 ADR 界定后即成为违规，需另单收口）：
  - `main.gd:323` 读 `world.pending_decision`（快照已有同名键 `snapshot_codec.gd:42`）；
  - `main.gd:479/492/504` 读 `_world.user_paused`（快照键 `snapshot_codec.gd:43`）；
  - `staff_roster_dialog.gd:30/36` 读 `_world.roster.get_all_staff()`（直读 L2 子系统对象；L2 已提供 `get_staff_view()`）。
- **门禁覆盖不足**：`test_l3_no_business_math` 的 `l3_paths` 只覆盖 4 个文件（`src/ui/**` 实为 15 个 `.gd`），且是字符串 token 断言（可被改名绕过）。
- **L3 文案硬编码**：`tech_tree_dialog.gd:64–105`、`game_over_dialog.gd:33–35`、`staff_roster_dialog.gd:45` 仍有内联中文与 `%.2f` 精度。这属 i18n/文本外置范畴（`TextService` 通道），**不在本 ADR 决策范围**（本 ADR 只管"数值派生"边界），登记为交叉项。

## 决策

**① L3 只做格式化与布局**：任何"派生数值 / 统计 / 预测"必须由 L2 提供。新增 `GameWorld.get_income_forecast()`（下周净流入预告）、`get_staff_view()`（员工三口径）、`get_domain_progress()`（逐域 `{lit,total}`）、`get_rival_view()`（名称/差距/进度/预警等级），并随行补齐 `get_tech_list_view()` / `get_score_display()` / `get_naming_view()` / `get_last_ledger()`。
**落地状态：已落**（`game_world.gd:234/287/303/366` + 四支撑面 `:343/406/440/449`；L3 消费点 `dashboard_presenter.gd:68–98/107–113/146–207`、`tech_tree_dialog.gd:37/51`、`main.gd:471`）。

**② L3 禁止直接读 L4 数据表**（删除 `tech_tree_dialog.gd:51` 的磁盘读）：节点元数据、域分母、文案键一律经 L2 数据面下发；L2 侧文案真源为 `src/data/ui_display.json`（`game_world.gd:65/159`）。
**落地状态：已落**（`grep -rn "DataLoader\|load_json\|res://src/data" src/ui/` 零命中；`tech_tree_dialog.gd:35–51` 改走数据面）。

**③ L3 禁止调用非契约命令**（`main.gd` 的 `set_pending_decision` 收口为调试专用注入或契约化）。
**落地状态：部分落地**（已限定在 `_setup_debug_shot_driver()` 调试分支内，`main.gd:117–129`；但仍是直调非契约方法，两条收口路径待主程序席裁决——见「需裁决事项」）。

**④ `ui_snapshot` 保留全量只读语义**，新增字段走"快照 + 契约命令"双通道：**展示数据**进 `ui_snapshot()`（`snapshot_codec.gd:35/38/39/40/41`），**状态变更**走 `CONTRACT_COMMANDS`（`:29–42`，仍 12 条）；只读查询不进命令面。
**落地状态：已落**（`test_presentation_layer.gd:151–181` 断言快照含五键且命令数仍 12；`:160–161` 断言预告不进命令面、不新增预告信号）。

## 理由

1. **缺陷只有单点真源能修**：域分母曾因 L3 硬编码 `4/5/5` 恒显错值；`get_domain_progress()` 的分母真源单点为 `TechFog.get_domain_totals()`（`game_world.gd:303–305`），逐域分母之和 = `tech_fog.get_total_nodes()`（`test_presentation_layer.gd:215–232` 断言）。
2. **边界可断言才可验收**：把"数据面 = 快照 + 只读查询方法"写成契约后，违规可用 grep 断言（`test_l3_no_business_math`），而 ADR-0002 原注释无法判违规。
3. **账期契约要求预告归 L2**：`get_income_forecast()` 的逐项口径与下一周结 `ledger` 同源（ADR-0015 账期契约），若放 L3 自算必然与周结口径漂移；现由 `test_forecast_view_matches_ledger`（`test_presentation_layer.gd:32–65`）三场景（无任务 / 在途任务 / 非周结过账买卡）锁定"预告 = 实际"。
4. **显示分级是业务判定，不是排版**：`score < 阈值 → 只显档位标签、周报留真值`（RU-01）是口径决策，阈值属 `ui_display.json.score_tiers`；判定归 L2 `get_score_display()`（`game_world.gd:406–436`），L3 只按 `reveal_truth` 决定是否拼真值（`dashboard_presenter.gd:107–113`）。
5. **信号与数据面分工**：`rival_warned` 由 L2 连接并转成数据面字段后，预警灯（DR-027④）有落地路径，L3 不碰 `RivalTrack`。

## 备选方案

- **维持现状（L3 自算，否决）**：`tech_tree_dialog` 已因缺数据而硬编码并**显示错误值**（`4/5/5` + 废弃域名），竞对条恒 0%；且"L3 只格式化"无边界可验收。现状不是可接受的技术债，是已发生的玩家可见缺陷。
- **让 L3 依赖 L2 实体（否决）**：允许 L3 直接持有/调用 `GameWorld` 的子系统（`tech_fog` / `roster` / `economy`…）会**使 ADR-0002 的注入语义彻底模糊化**——L3 可绕过 `SnapshotCodec` 读写内部状态，存档/快照/呈现三方口径将无单一映射点，`SnapshotCodec` 作为"GameWorld ↔ 字典唯一映射点"（`snapshot_codec.gd:4`）也随之失效。

## 后果

**正向**

- 改动 12 可验收：**"L3 只格式化"可 grep 断言**（`test_l3_no_business_math` 已落；禁词含 `DataLoader.load_json(` / `ui_display.json` / `score_tiers` / `get_domain_counts(` / `get_week_ledger(` / `economy.json` / `techs.json`）。
- G1–G4 四处缺口一次性补齐：域 `{lit,total}`、员工三口径、竞对条四字段、净流入预告。
- `rival_warned` 有落地路径（L2 连接 + 数据面字段 + L3 透传）。
- 快照成为"L3 首渲染唯一来源"（`snapshot_codec.gd:5` 的既有承诺）名副其实，读档后呈现不再退化（`flags.scored` / `player_best_score` 入档，`snapshot_codec.gd:88–91`）。

**代价**

- **L2 门面方法增多**：`game_world.gd` 已因"契约面 + 数据面聚合"豁免 `max-public-methods` 与 `max-file-lines`（`:1–5`）。约束：新增数据面必须**只读、轻量、无副作用**，不得把周结/结算逻辑塞进门面。
- **是否进 `CONTRACT_COMMANDS` 的边界需长期守住**：DR-031/P1 已裁"净流入预告不进命令面（并入快照/周报载荷）"，`CONTRACT_COMMANDS` 内含 `get_ui_snapshot` 是**历史既成例外**（首渲染唯一入口，v1.1 §B）。后续新增只读查询一律不进命令面；反过来说，**带副作用的方法不得伪装成 `get_*` 塞进数据面**。
- **"数据面"边界一旦收紧，存量偏差要还债**：`main.gd:323/479/492/504`、`staff_roster_dialog.gd:30/36` 需改走快照/数据面（见对账表）。
- L3 无法在本地做"临时补算"救急：任何缺字段都必须回 L2 补数据面，短期改动面变大（这是刻意的摩擦）。

## 可执行契约（本 ADR 的验收面）

以下规则必须可被审查/断言。判据落在**现有 GUT 门禁 + grep**，不引入新工具。

- **R1｜L3 禁读 L4**：`src/ui/**` 不得出现 `DataLoader` / `load_json` / `res://src/data`。
  现状：零命中（2026-09-08 实测）。**豁免清单：无**（`test_presentation_layer.gd` 的 `l3_paths` 内不含任何 L4 读取；测试文件自身读表不属 L3）。
- **R2｜L3 禁自算业务派生**：不得调用 L2 子系统（`tech_fog` / `economy` / `roster` / `rival_track` / `task_queue` / `training` / `sota_board` / `event_engine`）、不得做阈值定档、累加/均值/极值等统计、不得读 `score_tiers`。
  **允许的纯格式化（白名单，穷举）**：①单位/货币/符号换算 → `Formatter.format_money()` / `format_delta()` / `format_stat_line()`（L1 服务，`src/systems/text/formatter.gd`）；②百分比换算 → `* 100.0` 且行尾标 `# num-ok: 百分比换算`（`main.gd:561/585/600`）；③文本拼接与分隔符拼接（分隔符取自数据面 `display.*_separator`，如 `dashboard_presenter.gd:146–190`）；④排序/过滤（排序键由 L2 提供）；⑤本地化取词 → `TextService.text()`；⑥布局常量与触控热区 → 标 `# num-ok: <理由>（表现层）`（`# num-ok:` 机制见 ADR-0013 与 `test_numeric_data_migration.gd:11/176`）。
- **R3｜新增 L3 展示字段必须由 L2 提供**：走 `ui_snapshot()` 新键，或走 L2 只读查询方法；**L3 不得新增对 L2 内部字段/子系统对象的读取**。数据面返回结构里应自带文案键与精度（例：`forecast.display`，`game_world.gd:261/272–283`），L3 不查表。
- **R4｜只读查询不进 `CONTRACT_COMMANDS`**：命令 = 有副作用的状态变更（`CONTRACT_COMMANDS`，`:29–42`，12 条）；数据面 = 纯读（`get_*` 查询 + `ui_snapshot` 载荷）。断言：命令数 12、信号数 11、`get_income_forecast` 不在命令面、无新增预告信号（`test_presentation_layer.gd:158–161`）；例外仅 `get_ui_snapshot`（历史既成，首渲染入口）。
- **R5｜L3 零写路径**（既有门禁，本 ADR 不改）：`test_playtest_loop_headless.gd:87–93` 禁 `SaveSystem.save_game` / `FileAccess.open` / `.money +=` / `.money -=` / `.apply_delta`。
- **R6｜门禁覆盖待扩（待落）**：`test_l3_no_business_math` 的 `l3_paths` 应从 4 个文件扩到 `src/ui/**` 全量（15 个 `.gd`），并把 R2 的子系统调用、R3 的内部字段读取纳入禁词；`test_playtest_loop_headless.gd` 的 L3 门禁同步扩。

## 附：决策对账表

| 决策 | 落地状态 | 证据（文件:行 / 方法名） |
|---|---|---|
| ① L3 只格式化，派生数值由 L2 出数 | **已落** | `game_world.gd:234 get_income_forecast` / `:287 get_staff_view` / `:303 get_domain_progress` / `:366 get_rival_view`；支撑面 `:343/:406/:440/:449`；消费点 `dashboard_presenter.gd:68–98/145–207`、`tech_tree_dialog.gd:37/51`、`main.gd:471`；断言 `test_presentation_layer.gd:207–212` |
| ② L3 禁读 L4 数据表 | **已落** | grep 断言 `DataLoader` / `load_json` / `res://src/data` 在 `src/ui/` 零命中；`tech_tree_dialog.gd:35–51`（原 `:51` 磁盘读已删）；文案真源 `ui_display.json` 由 L2 读（`game_world.gd:65/159`）；禁词断言 `test_presentation_layer.gd:192–205` |
| ③ L3 禁调非契约命令（`set_pending_decision` 收口） | **部分落地** | 已限定调试分支：`main.gd:117–129`（`_setup_debug_shot_driver`，仅 Web + `?shot=`/`?selftest=`）；`set_pending_decision` 仍在命令面外（`game_world.gd:29–42` vs `:802`）；**收口路径待裁决** |
| ④ `ui_snapshot` 全量只读 + 双通道 | **已落** | `snapshot_codec.gd:14–48`（新键 `:35/38/39/40/41`，`staff_list` 已删）；命令仍 12 / 信号仍 11（`game_world.gd:29–55`）；断言 `test_presentation_layer.gd:151–181` |
| 契约推论：数据面 = 快照/只读查询（非内部对象） | **待落** | 存量偏差：`main.gd:323`（`world.pending_decision`，快照键 `snapshot_codec.gd:42`）、`main.gd:479/492/504`（`_world.user_paused`，快照键 `:43`）、`staff_roster_dialog.gd:30/36`（`_world.roster.get_all_staff()`） |
| 门禁覆盖（R6） | **待落** | `test_presentation_layer.gd:186–191` 仅 4 文件 vs `src/ui/**` 15 文件 |

## 关系

- 落 **DR-031「改动 12」（呈现层：显示分级 + 净流入预告）** 与 **DR-015**（UI 方向：MVP 工作台骨架 + 周报流；迷雾界面 C 方案），验收点见 issue #78。
- **修订 ADR-0002 的「经注入可触达 L2 数据」注释**：明确「数据面 = **快照（`SnapshotCodec.ui_snapshot`）+ 只读查询方法**，**不是** L2 内部对象/子系统」；L3 不得直读 `world.pending_decision` / `world.user_paused` / `world.roster` 等内部字段。（本文件不改动 `0002-directory-layering.md` 正文；该注释的正文补注归后续文档 PR。）
- 与 **ADR-0015**（周结步序与账期契约）强耦合：`get_income_forecast()` 的逐项口径 = 下一周结 `ledger` 同口径（含非周结过账计入下一账期），"预告 = 实际"是 ADR-0015 账期契约的呈现侧验收。
- 与 **ADR-0012**（RP 供给真源与翻雾累计计数器）的关系：数据面只读透出 `economy.get_cum_influence()` 等真源，不改变供给语义；预告的 `influence_delta` 与周结同源（`game_world.gd:257`）。
- 与 **ADR-0013**（数值数据化 / 零默认值）互补：ADR-0013 管"数值进表 + `# num-ok:` 豁免"，本 ADR 管"L3 不得把表值再算一遍"；L3 的展示常量一律走 `# num-ok:` 标注。
- 与 **ADR-0014**（谓词单点真源）无冲突：谓词求值在 L1/L2，L3 只消费结果。
- 与 **ADR-0008**（确定性 RNG）无冲突：数据面为纯读，不引入随机消费点。
- 与 **ADR-0001**（引擎版本与工具链）无版本变更，但本 ADR 的可执行契约依赖 ADR-0001 锁定的 GUT 9.7.1 + gdtoolkit 4.3.x 门禁（grep 断言、`# num-ok:` 豁免、`gdlint` 上限豁免注释）。
- 与 **#82**（短单局收尾：终局屏 + summary 六项）的关系：`get_game_over_summary()`（`game_world.gd:669`）扩六项须**延续本契约**——三线计数器（霸榜周数 / 树 n/14 / 影响力存量）由 L2 出数并入快照或终局数据面，L3 只格式化；`game_over_dialog.gd:33–35` 现存的 `%.2f` 精度与内联文案应一并收口。

## 遗留与收口归属（主程序席裁定，2026-09-08）

三条遗留**不在 v0.1.5 收尾批内还债**（改动面涉及命令面/契约断言，属结构性变更），统一归 **issue #103**（v0.2）：

| 遗留 | 裁定 | 归属 |
| :--- | :--- | :--- |
| 决策 ③ 未收口（`main.gd:128–129` 调 `set_pending_decision`） | 走 **(a) 调用移出 L3**（独立调试模块 + L2 侧"仅调试"入口）；**不采 (b) 契约化**——命令 12/信号 11 是 v1.1 §B 冻结契约，`test_game_world.gd` / `test_presentation_layer.gd` 双处断言锁定，为调试分支加一条命令得不偿失 | issue #103 |
| "数据面 = 快照/只读查询"存量偏差（`main.gd:323/479/492/504`、`staff_roster_dialog.gd:36`） | **另单还债**，不混入收尾批；本 ADR 先界定边界，存量偏差登记为待收口 | issue #103 |
| R6 门禁覆盖（`test_l3_no_business_math` 仅 4/15 文件） | **随还债同批扩展**（先改调用面、再扩门禁，避免门禁先亮红导致 main 不可合） | issue #103 |

**边界澄清（本 ADR 生效即适用）**：新增 L3 展示字段必须由 L2 数据面提供；存量偏差在 issue #103 收口前**不得再新增同类写法**（新代码按 R1–R5 执行）。
