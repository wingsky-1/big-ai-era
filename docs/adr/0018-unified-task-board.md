# 0018. 统一任务槽容器（TaskBoard 4 槽 × Project 抽象基类）

日期：2026-09-10 / 状态：accepted

## 背景

v0.1.x 时代任务以 task_queue 三处消费点分治（不同类型任务各自推进/结算），
ADR-0015 背景已实证"结算口径分散导致周报收支裂缝与确定性真源受损"。
v1.0.0 规格全局骨架：任务槽恒 4（numerics-master §四），论文/模型/算力三类
项目共用同一批槽位；指派语义统一（"谁上桌"不因项目类型而异）；结算统一在周结
推进。若沿用"三类队列分治"，槽位互斥、指派、结算各写一份 → 三份漂移。

## 决策

**统一任务槽容器 TaskBoard（恒 4 槽）+ Project 抽象基类（三型同接口）**：

- 槽位 slot[0..3] 各持 0..1 个 Project + 0..N 上桌员工 id（weakref 语义序列化为 id）；
- ProjectState enum：EMPTY / IN_PROGRESS / FINISHED_PENDING（QUEUED 留 P2，
  加枚举=纯扩展，enum 值不入档）；
- Project 基类：project_type（enum）/ 工期周定值 / 进度（周内刻级）/ 剩余周 /
  周耗卡时 / 上桌上限 / 协作系数 / 状态；统一钩子 week_tick() 由 TaskBoard
  周结驱动；子类覆写 _on_week_tick/_on_finished；
- 命令面：assign_staff / unassign_staff / start_paper / start_training /
  cancel_project（P0 直接入空槽，槽满即拒 + 单一原因源 *_disabled_reason）；
- 指派写点唯一化：槽成员 id 列表=唯一写点；Staff/Roster 不写"在岗项目"字段，
  只出 is_idle()/is_assignable() 谓词（防双真源漂移）；
- 数据面：get_task_view() → Array[槽 view]（深拷贝字典，L3 只画）。

## 备选方案

- **三类队列分治**（旧 task_queue 形状）：槽位互斥/指派/结算各写一份，漂移风险
  三倍，违反架构 §4.1"为什么收进一个容器"的 ADR-0015 教训，放弃。
- **槽位=队列（QUEUED 预实现）**：P0 无深队列需求，预写=死代码（架构 §7 预留
  判据 C），枚举留到 P2 加。

## 后果

- 正向：槽/结算语义单点；三类项目同接口同指派同结算；L3 只画数据面；
  上桌员工与名册一致性由 GUT 断言（每员工至多一槽、槽成员均存在）。
- 代价：TaskBoard 为 L2 核心类需严控 ≤500 行（架构 §8 预算）；抽象基类
  需要三类项目都真实落地后才显收益（#131/#133/#140 分批验证）。
