# 0014. 谓词单点真源：PredicateRegistry 唯一求值口

日期：2026-09-08 / 状态：accepted（决策登记；决策 ②–⑤ 的实施归 v0.2 #35，见「现状核实」）/ 落 DR-031（改动 9）、DR-011 与 issue #81

## 背景

GDD §8.2 与 DR-011 规定"谓词枚举注册表：枚举 + params + 一层 any_of，禁 DSL"，
`tech_tree.gd:5` 亦声明"依赖 TechFog（迷雾态）与 PredicateRegistry（前置谓词校验）"。
但架构复审 v1.2 实测：**`{predicate, params}` 的求值散落在多处**，注册表只覆盖其中一条通路。

### 现状核实（grep 证据，2026-09-08 于 main@fc123d0 + 本单 #81）

**已落（现状成立）**

- `PredicateRegistry`（`src/systems/data/predicate_registry.gd`）是**事件/阶段通路**的唯一求值口：
  - `grep -rn "PredicateRegistry.evaluate" src/` → 仅 2 处调用方：`stages.gd:45`（阶段 gate 隐式 AND）、
    `event_engine.gd:179`（事件 trigger 谓词门）；
  - 注册表内为单点实现：单层 `any_of` 递归（`:15–24`）+ 6 个谓词
    `none/never/tech_lit/rp_threshold/min_money/crossover_count`（`:30–66`）；
  - `grep -rn "match predicate" src/` 仅 2 命中：注册表 `:30` 与 `task_queue.gd:127`（后者属待落项）。
- `tech_fog` 的 `mirror_mind` **字面特例已数据化**：
  `git log -S "mirror_mind" -- src/entities/tech_fog.gd` → 2af42fe（#71）删除该字面量；
  现行判定读节点级 `unlock.predicate == "crossover_count"`（`tech_fog.gd:362`），
  `grep -n "node_id ==" src/entities/tech_fog.gd` 零命中。

**待落（不在本单范围，归 v0.2 #35 新谓词注册批）**

- `tech_fog._can_become_researchable()`（`tech_fog.gd:357–378`）**自实现**求值：
  `crossover_count` 分支 + "parents 全 lit"闭包，**不经注册表**
  （`grep -n "PredicateRegistry" src/entities/tech_fog.gd` 零命中）。
- `task_queue._check_unlock()`（`task_queue.gd:120–145`）**自实现 `match predicate`**
  （`none/min_money/tech_lit/never`），与注册表语义并行
  （`grep -n "PredicateRegistry" src/entities/task_queue.gd` 零命中）。
- `techs.json` 的 `unlock.predicate == "rp_threshold"`（`long_scroll:163`、`arm_will:205`）
  **零消费**：`TechFog` 只识别 `crossover_count`，其余回退 parents 闭包 → 该门形同不存在。
- `min_week`（`techs.json` 13 处）**零消费**：`grep -rn "min_week" src/` 仅命中数据表本身，
  全仓唯一代码引用是 `tests/unit/test_techs_data.gd:86` 的数据值断言
  （GDD §8.1 的"防穿越"未实现；该断言不得升级为行为断言，属本 ADR 范围）。
- `tech_tree.gd:5` 的文档承诺**零调用**：该文件无 `PredicateRegistry` 命中。

## 决策

**① 一切 `{predicate, params}` / `{any_of}` 结构必须经 `PredicateRegistry.evaluate()` 求值**，
禁止任何调用方自实现 `match predicate` 分支。
（事件/阶段通路**已落**；`tech_fog` / `task_queue` **待落**。）

**② `tech_fog` 的可研判定改为谓词化**：`parents` 全 lit ⇒ `tech_lit{tech_ids}` 谓词 +
`crossover_count` 谓词 + 节点级 `unlock` 字段统一求值。`mirror_mind` 字面特例已于 #71 删除，
剩余工作是把自实现分支替换为注册表调用。**待落（v0.2 #35）**。

**③ `task_queue._check_unlock` 改为薄封装**：构造 context 后调用注册表，删除自实现 `match`。
**待落（v0.2 #35）**。

**④ `techs.json` 的 `unlock` 字段必须被消费**（当前 `rp_threshold` 在 `long_scroll`/`arm_will`
上完全无效）。**待落（v0.2 #35）**。

**⑤ `min_week` 若保留为硬门，必须实现**（当前零消费）。**待落（v0.2 #35）**。

## 理由

1. **谓词扩展单点**：新增谓词只需改注册表一处，不必同步三处 `match` 分支
   （现状加一个谓词要改注册表 + `tech_fog` + `task_queue`，且三处行为易漂移）。
2. **行为一致性**：同名字面谓词在三处必须同义——自实现分支已出现语义分叉：
   注册表的 `tech_lit` 同时支持 `tech_id` 与 `tech_ids` 两种 params（`:37–48`），
   而 `task_queue._check_unlock` 只认 `tech_id`（`:136–141`）。
3. **文档承诺兑现**：`tech_tree.gd:5` 声明依赖注册表但零调用；GDD §8.2
   「4 类解锁谓词（谓词枚举注册表…）」在科技树通路未落地。
4. **数据生效**：`unlock` / `min_week` 是已录表的设计字段，零消费等于"数据表说谎"——
   策划改表不生效、玩家看不到任何效果（ADR-0013 零默认值纪律的镜像问题：**有键无消费**）。

## 备选方案

- **保留三处分叉（否决）**：新谓词要改三处、行为不一致、ADR-0009 已声明"共用注册表"。
- **做表达式引擎 / DSL（否决）**：DR-011 明确 YAGNI；`{predicate, params}` + 单层 `any_of`
  已覆盖全部已知需求。

## 后果

**正向**：谓词扩展单点、`tech_tree.gd` 的文档承诺兑现、`unlock`/`min_week` 数据生效、
三处行为可对账（可用 grep 断言"零自实现 match"）。

**代价**：

- `TechFog` 需要 context（lit 集合 / 累计影响力 / 主干数），从"纯字典进纯字典出"变为
  "需注入 context"；`advance_with_context()` 已先行落地（ADR-0012），本决策复用该通路，
  `advance()` 旧签名继续转调（零迁移）。
- `task_queue` 的拒绝原因（`reason`）需在薄封装层保留（注册表只返回 bool，不返回 reason）。

**范围**：本 ADR 随 issue #81（科技树口径收口）创建，**只登记决策与现状核实**；
②–⑤ 的实现归 v0.2「#35 新谓词注册批」，与 `techs.json.unlock` 消费、`min_week` 硬门同批——
避免在 v1.0 冻结期改动可研判定语义（会动 V6/V10 分布与 `fog_states` 存档行为）。

## 关系

- 落 DR-031「改动 9」与 DR-011（禁 DSL、枚举注册表）、GDD §8.2 谓词表。
- **修订 ADR-0009** 的"tech_fog 消费同一注册表"条款：落地路径改为
  "经 `advance_with_context()` 注入 context 后求值"。
- 与 ADR-0012（RP 供给真源）耦合：`rp_threshold` 谓词需要 `cum_influence`，两者应同批落地。
- 与 ADR-0013（数值数据化 / 零默认值）互补：ADR-0013 解决"有值双真源"，
  本决策解决"有键无消费"。
- 与 ADR-0016（L2 数据面契约）无冲突：谓词求值仍在 L1/L2，不涉及 L3。
- 与 ADR-0008（确定性 RNG）无冲突：本单无 RNG 消费点变更。
