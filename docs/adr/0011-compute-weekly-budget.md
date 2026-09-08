# 0011. 算力供给模型：每周预算（weekly budget）而非卡池余量

日期：2026-09-08 / 状态：accepted / 落 DR-031（D1②、D-6、D-9、D-10）与 issue #74（批 1c）

## 背景

GDD §6.3 定义算力档位供给 `8/16/32/64`，而 `economy.json.compute_tiers[].capacity` 是
`40/80/160/320`——**两个概念并存却无消费通路**：`hours_per_week`（6/14/30）零消费、
`Economy.training_cost()` 零调用方、无 `weekly_supply` 键，训练启动只扣 `base.cost` 资金。

两个口径的实算差异是**否决性**的：

- 若按**卡池扣减**：璞石全程需 `6 卡时/周 × 10 周 = 60` 卡时 > tier1 容量 40
  → **训练立刻不可行**（D-10 实算）；
- 且 `base.cost` 精确等于 `hours_per_week × train_weeks × 150`
  （璞石 `9000 = 6×10×150`、深渊 `117000 = 30×26×150`）——卡时若再过账 money 即
  **双重计费**（D-9）。

## 决策

**① `compute_hours_remaining` 的语义 = 本周可用预算**，不是卡池余量。
每周期结（步序 1）由 `Economy.recharge_weekly()` 重置为 `compute_tiers[].weekly_supply`
（`8/16/32/64`）；**不累计、不递减**。

**② `capacity`（40/80/160/320）只作 `apply_delta("compute")` 的上限校验**，
不参与每周重置——供给与容量分键（D-6）。

**③ 训练按 `model_bases.hours_per_week` 逐周占用本周预算**；`base.cost` 是
**全程卡时费**，卡时只作门槛/占用，**不得再过账 money**。`training_cost()` 降级为
纯校验/显示函数（不产生 `apply_delta`）。

**④ 买卡（N9）**：新增契约命令 `upgrade_compute(target_tier)`（命令面 11→12）；
升档后本周预算重置为新档供给；主台资源栏按钮三态（可买/置灰/顶档）由
`Economy.get_upgrade_view()` 提供，**不新增面板、不注册 PanelStack**。

**⑤ 周供给不足拒绝开训**：`hours_per_week > 本周供给` → `reason="insufficient_weekly_compute"`，
拒绝分支不留副作用（不扣款、不建训练态）。

## 理由

1. **训练永远供得上**：周预算下璞石的 6 卡时/周永远 ≤ tier1 的 8 卡时/周；
   卡池口径会死锁（见背景）。
2. **买卡动机清晰**：升档 = 提高每周供给（8→16→32→64），同时抬高 `m(tier)` 乘子。
3. **防双重计费有唯一解**：`base.cost` 一次性扣 money，卡时纯占用——不存在
   "扣了钱又扣卡时折算的钱"的路径。
4. **零迁移**：`resources.compute.hours_remaining` 的键与类型不变，仅**语义**从
   "卡池余量"变为"周预算余额"；老档读入后下一周即被重置（无需 `SaveMigrator`）。

## 备选方案

- **卡池扣减（否决）**：璞石全程 60 > tier1 容量 40，训练不可行（D-10）。
- **供给与容量合并为一个键（否决）**：两者是不同概念（周供给 vs 瞬时上限），
  D-6 已判分键。
- **超分配拒绝顺延（否决，归 v0.2）**：DR-018 A15 明确 v1.0 只做"拒绝开训"。

## 后果

**正向**：训练可达性有保障、买卡入口与动机闭环、防双重计费单点成立、
`hours_per_week` 从死键变为真源。

**代价**：
- `hours_remaining` 存档语义变更（零迁移但需本文记录）；读档后首周预算由
  `recharge_weekly()` 决定；
- `opening.json` 的 `compute.hours_remaining=0` 需在 `start_new_game` 后立即
  `recharge_weekly()` 补齐（Q-R2/P6）；
- 买卡后本周预算跳到新档供给（旧档已消耗的额度不找回），属设计选择。

## 关系

- 落 DR-031/D1②·D-9·D-10 与 GDD §6.3；修订 DR-018 的"卡池规模档"表述。
- 与 ADR-0015（周结步序）协同：`recharge_weekly()` 是步序 1 的第一个动作。
- 与 ADR-0013（零默认值纪律）一致：`weekly_supply` 缺键即 `require_key` 报错。
- 不触碰 ADR-0008（本次无 RNG 消费点变更）。
