# 0013. 数值数据化边界与"零默认值"纪律

日期：2026-09-08 / 状态：accepted / 落 DR-031（D-7、D3、B1）与 issue #71（批 0）

## 背景

红线 3 要求"数值禁止硬编码；一切进 `src/data/`"，但架构复审 v1.2 §1.4 全仓扫描
实测**19 处违规**（远超纪要点名的 `score_math` / `tech_fog` 两处），其中 9 处是
"代码默认值 vs 数据表"双真源，另有 3 类结构性缺陷：

1. **公式系数留在代码**：`score_math.gd` 的 `K=4.0`、`θ=95.0`、`k=13.0`、
   `m={0.6,0.75,0.9,1.05}`，以及**纪要漏掉的 Cobb-Douglas 指数 `0.7`/`0.3`**——
   调权重必须改码。
2. **双真源（代码默认值兜底）**：`_config.get(key, <字面量>)` 形态遍布
   `economy.gd` / `training_project.gd` / `sota_board.gd` / `rival_track.gd` /
   `tech_fog.gd` / `event_engine.gd`——改数据表不生效。
3. **死键与第二副本**：`clock.json.ticks_per_week` 零读取（`game_world.gd` 用常量
   绕过注入）；`TOTAL_NODES=14` 在 `tech_fog.gd` 与 `event_engine.gd` 各一份。

后续 #72/#73/#76/#77/#80 全部建立在"K/m/节点数由数据驱动"之上；先做断言后做
数据化 = 断言重写一遍（架构复审 §3.2 第 4 条）。

## 决策

**① 一切可调数值必须来自 `src/data/*.json`；代码内不得留数值默认值。**
`_config.get(key, <字面量>)` 一律改为 `DataLoader.require_key(config, key, source)`：
缺键即 `push_error` 并熔断返回 `null`，由调用方显式降级——**禁止用字面量兜底**。

**② 明确"公式形态 vs 数值"边界。**
- **留代码**：公式结构（Cobb-Douglas 乘积形态、sigmoid 形态）、纯逻辑索引/枚举、
  格式化系数（万元缩写阈值，须标 `# num-ok:` 理由）。
- **进数据表**：一切系数/指数/阈值/权重/时长/上限。

**③ 数据表键位（本次落地）**：

| 表 | 新增/收口键 | 消费点 |
|---|---|---|
| `benchmarks.json` | `ability_scale`、`ability_exponents{research_eff,tech_bonus}`、`compute_multipliers`、`sigmoid_clamp_exponent`、`score_max`、`score_precision`（原有 `theta`/`k`/`baseline`） | `ScoreMath.normalize_params` → `TrainingProject` 注入 |
| `techs.json` | `total_nodes`、`pity{threshold,cap}`、`domain_flags{researchable,counts_mainline}`、节点级 `opening_researchable` | `TechFog`（`event_engine` 经 `fog.get_total_nodes()` 取值） |
| `clock.json` | `ticks_per_week`（由死键转为真源） | `GameClock.setup` → `clock.ticks_per_week` |
| `rivals.json` | `jitter_span`、`warn_red_weeks`、`warn_yellow_factor` | `RivalTrack`（DR-027④ 预警公式数据键化） |
| `events.json` | `inspiration_spec.pity_boost_factor`、`pity_skip_step` | `EventEngine` |
| `naming.json`（新） | `min_chars`、`max_chars` | `TextService.name_max_chars()` → 命名校验（收口 20/12/12 三处不一致） |

**④ 表现层常量的豁免必须显式化。**
`src/ui/**` 的布局尺寸/热区/透明度等经架构复审 §1.4 判定"不构成红线 3 违规"，
但其字面量必须在行尾标注 `# num-ok: <理由>`，由
`test_no_hardcoded_numbers_outside_data` 逐行校验——**未标注即门禁失败**。

**⑤ 门禁**：`tests/unit/test_numeric_data_migration.gd` 四个用例进 `verify.sh` 必跑集
（`test_no_hardcoded_numbers_outside_data` / `test_formula_constants_driven_by_data` /
`test_single_source_of_truth_node_count_and_clock` /
`test_same_seed_hash_stable_after_data_migration`）。

## 理由

1. **改表即改行为**：`test_formula_constants_driven_by_data` 逐个改 `ability_scale` /
   指数 / `m(tier)` / `θ` / `k` 并断言输出随之变化，把"数据驱动"从口号变成可执行断言。
2. **防双真源复发**：`require_key` 把"缺键"从静默兜底改为显式报错——数据表与代码
   不可能再各持一份真相（缺键测试会红）。
3. **grep 可审计**：`test_no_hardcoded_numbers_outside_data` 遍历 `src/**/*.gd`，
   去注释/字符串后提取数字字面量，白名单仅 `0/1/-1`——红线 3 从"人工 review"
   升级为"CI 门禁"。
4. **零行为变更可证**：批 0 改造前后同 seed 万周 `SnapshotCodec.state_digest`
   逐字节一致（seed 42/7/12345/999：`a64b4625…` / `074366c0…` / `79948663…` / `c263108b…`）。

## 备选方案

- **只迁纪要点名的 K/m/节点数（否决）**：指数 `0.7/0.3`、`event_engine.gd` 的第二处
  `14`、`clock.json` 死键会留下新的双真源，下一轮调参仍要改码。
- **全量迁 JSON 含公式结构（否决）**：把 Cobb-Douglas 乘积形态做成 DSL 属过度设计
  （DR-011 YAGNI），且失去编译器类型检查。
- **给 `require_key` 保留默认值参数（否决）**：默认值参数等于把双真源换了个名字。

## 后果

**正向**：改数值不改码、grep 可审计、双真源从机制上被阻断；#72/#73/#76/#77/#80 的
数值标定有了稳定地基（改表即生效）。

**代价**：
- 数据表键增多（每键都有"缺键即报错"的测试兜底）；
- `ScoreMath` API 从"带默认参数"改为"必须注入 params"，调用方（`TrainingProject`）
  与测试同步改造；
- `TechFog.setup()` 由"部分键 + 默认值"改为"全量键"，测试夹具传残缺字典会熔断
  （`test_game_clock.gd` 已同步改为加载 `clock.json`）；
- 迁移风险为零（数据表非存档 schema，无 `SaveMigrator` 变更）。

## 关系

- **修订 ADR-0009**：`TechFog` 的 `TOTAL_NODES` / `PITY_*` / 开局可研节点列表
  由代码常量改为 `techs.json` 数据键（`total_nodes` / `pity` / 节点级
  `opening_researchable`），并新增 `domain_flags` 取代 `domain == "elsewhere"`
  的 stringly-typed 判断。
- 与 ADR-0002（分层）一致：`ScoreMath` 保持 L0 零依赖，参数由 L2 经
  `ScoreMath.normalize_params()` 注入，**L0 不读磁盘**。
- 与 ADR-0008（确定性 RNG）无冲突：本次不含任何 RNG 消费点变更。
- 落 AGENTS.md 红线 3 与 issue #71 验收点 1/2/3。
