# 0022. 数据表护栏"跟键走"（内嵌 _bounds 块）与 schema 断言框架

日期：2026-09-10 / 状态：accepted

## 背景

v1.0.0 全量数值以 `src/data/*.json` 为唯一真源（AGENTS.md 红线 3），
architecture-100 §6 提出护栏存储形态决策点 D6：
**集中 assertion_bounds.json vs 各表内嵌 bound 块**。选型影响：
- "防改数不改护栏"：数值被改动时，护栏是否在同一处强制跟随；
- 表结构是否臃肿（D6 顾虑：跟键造成 JSON 结构臃肿时再收口集中表）。

## 决策

**护栏跟键走**：每张数据表内嵌 `_bounds` 块（`{"键名": [min, max], ...}`），
数值键（int/float）必须有对应护栏声明；缺失 = schema 断言失败（verify 红）。
配套实现：
- `src/systems/data/data_schema.gd` = 通用声明式断言引擎：
  `validate_table`（键存在/类型/可选 bound 区间）、`validate_inline_bounds`
  （数值键必带护栏，防改数不改护栏）、`validate_key_spelling`（真源键精确比对，
  `_` 前缀元数据键豁免）；
- `src/systems/data/data_loader.gd.load_validated()` = 读表 + 校验统一入口，
  校验不过返回空表熔断（脏数据不入玩法）+ push_error；
- 运行时读键：护栏值随表一起被读，改数值不改护栏、改护栏不改数值都会在
  断言层暴露，杜绝"改表漏改护栏"。
- 不做集中 `assertion_bounds.json`（除非单表结构超限时再收口，见后果）。

## 备选方案

- **集中 assertion_bounds.json**：所有护栏一处收口，数值表保持纯净；
  但改数值表与改护栏分处两文件=双点维护，D6 已指"防改数不改护栏"效力弱，
  且集中表随表增长会膨胀为第二本数值真源（与架构"每表 D.1/D.2 真源"冲突）。
- **无护栏（仅类型/必需键）**：数值无界漂移，联标护栏（首满 W80/树≤30% 等）
  失去运行期闸口，违反 numerics-master"护栏断言"契约，放弃。

## 后果

- 正向：数值与护栏同表同源；schema 断言框架成为后续建表 issue（#124–#154
  各数据表）的统一挂载点——每表建表即注册 schema + 护栏，verify 自动守卫。
- 代价：每表多一块 `_bounds`（结构化成本约每数值键一行）；JSON 超 300 行时
  按 D7 拆文件（键名前缀稳定），护栏随拆随走。
- 与既有 ADR 关系：本决策是 architecture-100 §6 D6 的实施落地；
  键名拼写自检真源 = texts-keys.md / numerics-master.md / 各规格 D.1/D.2。
