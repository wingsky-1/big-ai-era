# 0008. 确定性随机：分域 counter-based RNG

日期：2026-09-07 / 状态：accepted

## 背景

争点①裁定乙档收窄版（DR-001）：随机仅竞对扰动+灵感时机两处（事件抽取共用
第三域），全部在周结点消费。确定性验收（万周模拟、同 seed 双跑哈希、
分位数断言）要求随机完全可复现；Web 导出下引擎内建 RNG 状态为 uint64，
JSON 序列化有精度坑；且单一全局随机序列一旦插入新的消费点，其后全部
结果漂移（回放断裂）。

## 决策

1. **分域 counter-based RNG**（`src/systems/rng/rng_stream.gd`，L1）：
   `root_seed + 域名 + 计数器` 三元组直接派生随机数；域=字符串枚举
   （`rival_jitter` / `inspiration` / `event_roll`，未来 `recruit` 等按
   DR-029 A-6 扩展），各域计数器互不串扰。
2. **计数器入档**：`savegame.rng{}` 开放 dict——root_seed 等在册，新随机域=
   加键零迁移（计数器缺省 0）；计数器为 int，JSON 安全。
3. **消费点恰 3 处，grep 可验**：`rival_jitter` / `inspiration` /
   `event_roll`；默认名池兜底用确定性轮转（游标入 flags），不设第 4 消费点。
4. **双跑验收**：`simulate_weeks(n, policy, seed)` + 万周模拟同 seed 双跑
   哈希一致进 verify.sh（PR3 起）；万局分布统计归 nightly（PR10）。
5. **pitch 纪律**："揭示时机随机、结果成败不随机"——训练周、出分、外溢翻态
   等全部零 RNG。

## 备选方案

- **单实例 RandomNumberGenerator + seed 重放**：全局序列，任何一处插入消费
  即整体漂移；状态 uint64 过 JSON 有精度坑，拒绝。
- **状态式 PRNG（xorshift）状态整体入档**：同 uint64 精度问题；域间串扰，
  改一个域回放全断，拒绝。
- **纯触发零随机（producer B 案）**：争点①裁决否决——灵感是"随机变决策"
  的核心惊喜源；调参担忧以"仅三键 base/pity/cap+分位数断言"兜底。

## 后果

- 正向：同 seed=同世界（回放/断言/nightly 全部成立）；新域零迁移；
  分位数断言（V6/V10、竞对 ε、灵感间隔）把方差锁进区间，"防欧非撕裂"。
- 代价：grep 断言是持续纪律（第 4 消费点=验收失败，扩域必须走 ADR 复议）；
  事件池同权重 tie-break 须确定性（按表序），已入 events.json 语义。

## 相关决策映射

- DR-001（本 ADR 载体：乙档收窄版+分域 RNG 演进预留）
- DR-027④⑤（竞对 ε 分布、灵感三键 base/pity/cap 标定依赖本框架）
- DR-029 A-6（rng.recruit() 新域=加键零迁移的实例）
- DR-023（外溢翻态零 RNG 规则表）
- GDD v3 §5.3（确定性随机章）

## 修正记录

- **2026-09-08（#75 / issue #92）：`randf_domain` 派生方式修正（决策语义不变）**。
  原实现 `float(hash("seed:domain:counter") & 0x7FFFFFFF) / 2^31` 直接归一化
  `hash(String)` 的低位：GDScript 的字符串哈希对**相邻字符串**（counter 从 c 到
  c+1）输出仅差个位数，归一化后同域连续抽样差 ~5e-10 → 同一 seed 下一局的概率
  判定**退化为恒真/恒假**（实测 200 seed × 100 次 `hit(0.35)`：85 局命中 0 次、
  23 局命中 100 次）。修正为「三元组 → 重置 `RandomNumberGenerator.seed` 后取一次
  `randf()`（PCG32）」，仍满足本 ADR 决策 1 的 **counter-based 三元组派生**（不依赖
  同域前一个随机数、计数器照常入档、读档/跳步零漂移），也**不是**备选方案中被拒绝的
  「单实例全局序列」。影响：全部概率机制（事件命中率门、灵感三键、竞对 jitter）恢复
  设计意图；同 seed 序列与既有基线不同（万周哈希随之变化，属行为修正非破坏性变更，
  存档零迁移）。

