# v1.0 需求文档（2026-09-08 · 短单局体验）

> **性质**：**需求文档（Requirements Spec）**——设计产物，非裁决、非 issue、非代码。
> 本文把 `2026-09-08-decision-session-minutes.md`（**DR-031 裁决全文**）的"v1.0 必落"清单**逐项翻译为可实施、可测试的功能点**；不发明任何新裁决，不重开 DR-000~031。
> **唯一裁决依据**：DR-031 + 纪要 §四/§六/§八；触碰 DR 的项一律标注"复议材料齐备度"，未齐不动工。
> **范围声明（制作人最新裁决）**：**v1.0 = 短单局体验**——一局 **160 周 ≈ ~27 分钟**（`src/data/clock.json`：`tick_seconds=0.25` × `ticks_per_week=40` = **10s/周**）。
> 成功标准 = **"一局从头玩到尾有高潮、有收尾、想再开一局"**。
> **长线（10h+ / 多周目 / 18 节点扩树 / θ 阶段化数值）整体推迟 v2.0**，不纳入本次范围（见 §末·不做清单）。
> **纪律**：数值一律 `~` 占位（键名进文档、数值不进代码）；每个功能点必须有出处（DR 号 / GDD 行 / 代码路径:行号 / 试玩反馈）；验收点格式 `[T] GUT 用例名`（硬验收）/ `[P] 试玩主观验收句`（三段式）。
> **状态**：`[开发中]`（v1.0 P0 范围已由 DR-031 收口；本文为实施前的规格卡口，过主策划内容审查后方可建 issue）。

---

## 〇、卷首：v1.0 目标与范围

### 0.1 一句话目标

> **一局 160 周（~27 分钟）内，玩家从"复现论文的博导"走到"登顶后守成"，全程有 4 个可截图高潮（首出分 / 首冠 / 阶段跃迁 / 登顶封顶），并在封顶后仍有 3 条可追的线（自由期三线）撑着走完，最后一屏收尾能说清"这一局我做了什么"。**

### 0.2 短单局体验的体验曲线（W0–160 分段表）

> 时间换算：**1 周 = 10s**（`src/data/clock.json`，`tick_seconds=0.25` × `ticks_per_week=40`）；**~27 分钟 = 160 周**。
> "决策密度"= 有效决策次数 / 30s（DR-009 节奏宪法：1–3 次/30s，峰值 ≤6，同屏待决 ≤1，**每周必做 ≤1**）。
> "空窗风险"= 连续 3 真空窗（~2 分钟）无新信息即设计违约（GDD §2 真空三件套）。

| 段 | 周次 | 时长 | 玩家目标 | 情绪峰值（可截图物） | 决策密度 | 空窗风险 / 兜底 |
|---|---|---|---|---|---|---|
| **S1 开局** | W0–6 | ~1 min | 搞懂"我在干嘛"；首指派；接第一条任务 | 博导手记第 1 页 + 首任务卡（GDD §13 引导） | ~2 / 30s（DR-029 D-3） | **高**：开场占屏无任务可派 → 手记锚任务槽（DR-029 D-5） |
| **S2 首出分** | W7–24 | ~3 min | 攒钱开首训；首翻雾；首出分命名 | **首出分 + 命名仪式**（"我造出了一个模型"） | ~1.5 / 30s | **高**：首训 10 周等待段 → 真空三件套（排队预填/训练播报/迷雾照推，GDD §2） |
| **S3 跃迁** | W25–54 | ~5 min | 冲 gate 晋升；买卡升档；多人上桌 | **阶段跃迁金框头条**（"我变大了"）+ 首次霸榜（首冠）；**W25 起三线开始常显**（长线目标线，GDD §2①） | ~2.5 / 30s（双驼峰峰顶） | 中：gate 已达而内容未增 → 三线 + 图鉴（§0.3） |
| **S4 登顶** | W55–80 | ~4 min | 巩固 SOTA；压住深巷 L2/L3/L4 | **登顶封顶"已登顶·自由期"横幅**（本作最高峰） | ~2 / 30s | **中高**：分数封顶 → **三线接管**（§0.3） |
| **S5 守成** | W81–140 | ~10 min | 守榜；补树；攒影响力存量 | 连霸周数里程碑 / 树 n/14 跳变 / 竞对反超再夺回 | ~1.2 / 30s（长尾） | **最高**：本段最长 → 三线 + 假 arXiv 装饰行 + 通知层零红点（DR-029 F） |
| **S6 收尾** | W141–160 | ~4 min | 走完最后阶段；看终局三线 | **终局收尾屏**（霸榜周数 / 树 n/14 / 影响力存量 / 总资产） | ~1.5 / 30s | 低：收尾屏本身即信息峰 |

**体验曲线的形状**：**双驼峰 + 长尾**——峰值在 S3（跃迁+首冠）与 S4（登顶封顶），长尾在 S5。**这不是"内容不够"，是"峰值太靠前"**：实算显示分数在 **W54 即封顶**（纪要 §2.4），若不处理，S5 的 ~10 分钟将完全无成长。**这正是 §0.3 的存在理由。**

### 0.3 W54 封顶后如何靠"自由期三线"接管（本任务核心新增内容）

> **口径校正（务必先读）**：GDD §2 已按**制作人最新裁决（DR-031/§十二）**写入三条落地——①**自由期三线提前到 W25**；②竞对重标时 **L4 标到 ~96–98 分**（与玩家封顶 99 分差 1–3 分 → 守卫张力，**禁超玩家**）；③封顶叙事「已登顶·自由期」+ **终局 summary 扩六项**。
> **因此三线有"两个时点"，本文必须区分**：
> - **W25（阶段跃迁后）三线开始常显**——玩家一进独角兽期就看到三线在动，作为**长线目标线**；
> - **W54（分数封顶）三线正式"接管"**——横幅 + 三线升为主权重，因为此后**分数不再成长**。

**问题（实算，纪要 §2.4 / GDD §9）**：
- `score = 100/(1+exp(-(A-θ)/k))`，`θ=~95 / k=~13`；`score=99` 的 A 阈值 = `95 + 13·ln99` = **~154.74**；
- 饱和根源**不是 tb**，而是 `eff=187 × q=1.0 × m≥0.9` 三者同时成立：`tier3 + 深渊 + 3 人上桌 + tb=0` → A=**164.1 → 99.5 分**；要 A ≤ 154.74 需 `tb ≤ −0.178`（**不可能**）；
- 按供给曲线，`tb ≥ 0.374` 落在 **W54（点满 6 个节点，成本升序累计 3310）** → **玩家 W54 封顶，其后 ~106 周无分数成长**。

**裁决处置（DR-031/B1 + GDD §2「单局目标形态」）**：
1. **不掩盖封顶**——封顶是设计事实，把它**转成叙事**：呈现层显示「**已登顶 · 自由期**」横幅（`[T] test_saturation_banner_free_period`）；
2. **三线两阶段可见**（GDD §2 口径）：

| 时点 | 三线状态 | 依据 |
|---|---|---|
| **W25**（阶段跃迁） | 三线**开始常显**（作为长线目标线），但**不弹横幅**、不压过主玩法 | GDD §2"自由期三线提前到 W25" |
| **W54**（分数封顶） | 弹「已登顶 · 自由期」横幅 + 三线**升为主权重**（差距行、里程碑） | DR-031/B1② + GDD §9 饱和护栏 |
| **W55–160** | 三线接管 ~17.7 分钟；**封顶后至少 3 次三线进度变化**（否则判"后半空转"） | GDD §18 `[P]` 短单局专项 |

3. **三条线的定义与变化来源**：

| 线 | 计数器 | 变化来源 | 玩家追的是什么 | 为什么在封顶后仍有效 |
|---|---|---|---|---|
| **① 霸榜周数** | `freedom_king_weeks` | SOTA 保霸周 +1 | "守住第几名多久" | 分数封顶但**名次仍会掉**（竞对 L2/L3/L4 后续发版，L4 标到 ~96–98 分紧咬）→ 守榜=真张力 |
| **② 树已探明 n/14** | 域计数（`fog_changed` 载荷） | 翻雾推进 | "还有多少雾没拨开" | RP 供给曲线到 W151 才点第 10 个节点 → **树比分数更晚封顶** |
| **③ 影响力存量** | `resources.influence` 快照 | 任务 `rp_output` + 事件 + 榜单脉冲 | "我攒了多少声望" | 与点树同池消耗 → **攒 vs 花的取舍贯穿全程** |

4. **三条线的呈现纪律**（DR-029 C-6 原文"亮 9 后缺的是目标不是手活"）：
   - 三线**同权重并列**，禁排序、禁"推荐"标（避免伪选择，架构稿 §18.4）；
   - 三线**不新增待办**（DR-029 D-4"1 提醒只指向已存在待办"）；
   - 三线**零强制操作**——玩家不点也不罚，世界照走。
5. **终局收尾（GDD §2③"终局 summary 扩六项"）**：W160（或 Game Over）时，终局屏必须**同时**呈现三线终值 + 关键决策回溯（六项口径见 RF-03）。**收尾必须可截图**——这是"想再开一局"的钩子。

**"想再开一局"的三个来源（对齐制作人成功标准）**：
- **① 未尽的树**：160 周内最多点亮 10/11 个可研节点（实算，纪要 §2.2）→ 总有 1 个没点亮；
- **② 未破的纪录**：三线终值构成"下一局的靶子"；
- **③ 不同的配比**：`钱 vs RP` 从"互斥"变"配比"（纪要 §2.8）→ 同一局不同选择走出不同形状。

### 0.4 12 项裁决 → 模块映射（本文覆盖度骨架）

| # | DR-031 裁决 | 本文模块 | 主功能点 |
|---|---|---|---|
| 1 | 收入口径改占槽任务结算（C1 + D-11 周报裂缝 + B-2 破产步序） | §1 经济 | RE-01…RE-05 |
| 2 | 任务池参数联标（C3） | §2 任务池 | RT-01…RT-05 |
| 3 | Σeff 落地 + 多人上桌 + `max_staff`（B2/D1③） | §3 人员 | RP-01…RP-04 |
| 4 | 买卡入口 N9（D2） | §4 算力 | RC-01…RC-03 |
| 5 | 卡时消费 N10（D1②，周预算口径） | §4 算力 | RC-04…RC-07 |
| 6 | 事件命中率门 + 冷却 + 预算闸（C2） | §5 事件 | REV-01…REV-05 |
| 7 | RP 供给标定 + 翻雾供给源（§2.9） | §6 知识 | RK-01…RK-05 |
| 8 | 科技树口径收口（D3） | §7 科技树 | RK-06…RK-09 |
| 9 | 数据化硬编码（D-7/M-9） | §8 出分 | RS-01…RS-03 |
| 10 | 饱和护栏 + 呈现层（B1） | §8 + §9 | RS-04…RS-06 / RU-01…RU-04 |
| 11 | 竞对死表重标（N11） | §10 竞对 | RR-01…RR-04 |
| 12 | 短单局体验收尾（本任务新增） | §11 收尾 | RF-01…RF-04 |

---

## 模块 1：经济与收入口径（GDD §6）

### 1.1 现状实证

| # | 事实 | 证据（代码路径:行号） |
|---|---|---|
| E1-1 | 周结步序 1 调 `economy.accrue_week()`，其内部按"每周 roll 双来源"给钱 | `src/entities/game_world.gd:463`；`src/entities/economy.gd:126–145` |
| E1-2 | 双来源脉冲实参：`reproduce.amount_min/max=5000/12000`、`grant.amount_min/max=30000/80000` | `src/data/economy.json`（`reproduce`/`grant` 段） |
| E1-3 | `duration_min/duration_max` 键**从未被产品代码读取**（`_roll_income` 只读 amount）；仅 `test_economy.gd:80–87` 断言其**值**（读配置不等于消费逻辑）→ 死参数 | `src/entities/economy.gd:172–180`；`src/data/economy.json:5–6`；`tests/unit/test_economy.gd:80–87` |
| E1-4 | **周报收支裂缝（D-11）**：`ledger` 在 `:463` 抓取，任务收入在 `:484` 过账 → `report.money_row.income` **不含任务收入**，但 `cum_income`（`:485`）含 | `src/entities/game_world.gd:463` vs `:479–491` vs `:542–551` |
| E1-5 | **破产判定步序（B-2）**：步序 2 破产短路在 `:470–477`，任务结算在 `:479` **之后** → 本周有任务结算仍会被判破产冻结 | `src/entities/game_world.gd:469–491` |
| E1-6 | 无固定运维支出键：`accrue_week` 只扣 `wage_per_staff × headcount`（注释 `:123` 写"工资×人数+ upkeep"，**upkeep 无实现**） | `src/entities/economy.gd:123–131`；`src/data/economy.json` 无运维键 |
| E1-7 | `sources.reproduce/grant.enabled=true` 是脉冲开关；`opening_money` 键不存在（开局资金在 `opening.json:6`） | `src/data/economy.json:15–21`；`src/data/opening.json:6` |

### 1.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"资金"资源的产生与消耗；独占破产/警告线判定 |
| **给谁供料 / 向谁索取** | 供：工资/训练成本/买卡/科技消耗的资金；索：任务结算收入、事件 money 效果、上市期 API 常量行 |
| **复杂度预算** | ≤1 个玩家决策（接哪条任务）；≤1 屏 UI（资源栏）；数据表键 ≤3 组（economy/tasks/sources） |
| **坏了整体会怎样** | 坏=张力消失（收入无节奏）或玩家被误判破产 → **P0**（阻塞其余全部模块） |

### 1.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RE-01** | 收入口径改占槽任务结算 | 每周 roll 双来源（周收入期望 ~63.5k） | 实验室/独角兽期经营收入**只来自占槽任务结算**；脉冲形态退役 | DR-031/C1；GDD §6.2；架构稿 §7.3 |
| **RE-02** | 周报收支裂缝修复（D-11） | **双侧断裂**：①World 侧 `report.money_row.income` 缺任务收入（`ledger` 在 `:463` 早于 `:484` 过账）；②UI 侧 `weekly_report_dialog.gd:36` 读 `report.rows` 键，而 `main.gd:281` 传入的是 `get_resource_view()`（**无 `rows` 键**）→ 周报**永远渲染兜底文案"本周运转平稳"**，收支行根本不可见 | 收支行**必须闭合**（`income − expense = net`，且含任务收入）**且真的渲染出来** | DR-031/C1 前置①；GDD §6.1"周报对账必须闭合"；GDD §14 字段集冻结；纪要 D-11 |
| **RE-03** | 破产判定步序重排（B-2） | 破产短路（步序 2）在任务结算之前 | 任务结算并入收支步，或短路判定后移；**"收支"定义随 C1 更新** | DR-031/C1 前置②；纪要 B-2；需修订 DR-021 B3 契约表述 |
| **RE-04** | 固定运维支出（新增键） | 无（实为 0，周支出仅工资 ~6k） | 新增固定运维 `~3k/周` → lab 期周支出 **~9k**（工资 6k + 运维 3k） | DR-031/C3；GDD §6.4"lab 期 ~9k" |
| **RE-05** | 死参数清理 + 脉冲参数退役 | `duration_min/max` 零消费；`reproduce/grant` 段被 pulse 消费 | `duration_min/max` 删除或标注"死参数·C1 后退役"；`sources.reproduce/grant` 置 `enabled:false` 或删段 | 纪要 D-13；DR-031/C1 |

**关键规则（伪代码）**：

```
# 周结步序 1（改造后，RE-01 + RE-03）
func settle_week():
    week += 1
    # ① 任务结算并入收支步（先于破产判定）
    task_settle = task_queue.settle_week()
    if task_settle.completed:
        economy.apply_delta("money", task_settle.income, "task_reward")   # 过账
        cum_income += task_settle.income                                   # 累计经营收入
        economy.apply_delta("influence", task_settle.rp_output, "task_rp") # RP 入同一池
    # ② 收支聚合（工资 + 固定运维，无脉冲）
    ledger = economy.accrue_week(headcount)      # 内部：-wage*head - upkeep
    # ③ 周报收支行含任务收入（RE-02：ledger 必须已含 task_reward）
    ledger.income  = Σ(本周所有 money 收入过账，含 task_reward)
    ledger.expense = Σ(本周所有 money 支出过账，含 wage / upkeep)
    assert ledger.income - ledger.expense == ledger.net
    # ④ 破产判定（RE-03：移到任务结算之后）
    if economy.check_lines() == WARNED_BANKRUPT:
        game_over_flag = true; request_save("game_over"); game_over.emit(summary); return
    # ⑤ 步序 3–10 不变（出分/SOTA/竞对/迷雾/灵感/事件/阶段）
```

**数值口径（全 `~`）**：

| 键 | 现值 | 裁决值 | 说明 |
|---|---|---|---|
| `economy.json.sources.reproduce.enabled` | `true` | `false`（退役） | DR-031/C1 |
| `economy.json.sources.grant.enabled` | `true` | `false`（退役） | DR-031/C1 |
| 固定运维（新键，如 `upkeep_per_week`） | 无 | `~3000` | DR-031/C3 |
| `wage_per_staff` | `2000` | 维持 `2000` | DR-031/C3 |
| `bankruptcy_line` / `warn_line` | `-200000` / `-30000` | 不动 | DR-027② |

### 1.4 验收点

- `[T] test_weekly_ledger_includes_task_income`（`tests/unit/test_economy.gd` / `test_game_world.gd`）——**断言点**：构造"本周有任务结算"的周，`report.money_row.income` 的解析值 **=** 本周所有 `money` 收入过账之和（含 `task_reward`），且 `income − expense == net` 恒成立（GDD §6.1 闭合）。
- `[T] test_weekly_report_renders_money_row`（`tests/unit/test_dashboard_presenter.gd`）——**断言点**：周报载荷含 `rows` 键且**至少渲染收支行**（不再是兜底文案"本周运转平稳"）；`money_row` 的 `income/expense/net` 三值可被 UI 读到（E9-3 双侧断裂的 UI 侧回归防护）。
- `[T] test_bankruptcy_check_after_task_settlement`（`tests/unit/test_game_world.gd`）——**断言点**：money 已 ≤ 破产线、但本周任务结算为 `+~42k` → **不**触发 `game_over`，且结算后 money 回升；反向例（无结算）仍触发短路。
- `[T] test_pulse_sources_disabled_no_roll`（`tests/unit/test_economy.gd`）——**断言点**：`accrue_week` 在 `sources.reproduce/grant` 关闭后**不再调用随机源**（用 spy/计数断言 `randi_in_range` 调用次数 = 0）。
- `[T] test_weekly_upkeep_expense_bound`（`tests/unit/test_economy.gd`）——**断言点**：lab 期（3 人）周支出 = `wage×3 + upkeep` ∈ `[~8k, ~10k]`（GDD §6.4 "~9k" 带内）。
- `[T] test_economy_dead_keys_absent_or_flagged`（`tests/unit/test_data_loader.gd`）——**断言点**：`economy.json` 中不存在未被消费的 `duration_min/max`（或存在但带 `_dead` 标记），防死参数回归。
- `[P] test_playtest_economy_pressure_30s`（试玩脚本 `docs/playtest/scripts.md#RE-01`）——**步骤脚本**：新开一局，1x 速跑至 W12，全程只用"接任务/指派"两类操作；**预期感受**：能感到"钱是任务换来的、发薪日会心疼"，而不是"钱自己在涨"；**代理指标**：W12 时玩家能说出"下笔任务结算还有 N 周"（≥1 次主动查看任务进度）。

### 1.5 待裁 / 待试玩

- **固定运维键名与量级**（`upkeep_per_week` vs `fixed_ops`）——数值席定名，量级 `~3k` 已裁。
- **破产线警告时机**：任务结算并入收支后，"预警黄灯"何时亮（结算前/后）——需试玩定（DR-027② 警告线 -30k 待试玩）。

---

## 模块 2：任务池参数联标（GDD §6.2 / §7）

### 2.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E2-1 | 5 条任务（1 条 deploy 占位 `enabled:false`） | `src/data/tasks.json` |
| E2-2 | `task_grant_pilot`：`duration_weeks=4`、`income=35000`、**`rp_output=0`** | `src/data/tasks.json` |
| E2-3 | `task_reproduce_paper_0`：3 周 / 8000 / rp 50；`task_reproduce_lingxi`：4 周 / 12000 / rp 100（解锁需 `silver_leash`） | 同上 |
| E2-4 | `task_research_basic`：4 周 / **income=0** / rp 150 | 同上 |
| E2-5 | 教学链占槽：`paper_0`(3 周) + `lingxi`(4 周) = **~7 周** | 同上 + GDD §7 教学闭环 |
| E2-6 | 单任务槽串行（`tasks.active` 单条，`_active_task` + `_queue` FIFO） | `src/entities/task_queue.gd:12–14`；ST4/DR-023 |
| E2-7 | **`type` 键不存在**：`task_queue.gd:168` 读 `task_cfg.get("type","")` → 恒空串；收入字段实际键名 = **`income`**、周期键名 = **`duration_weeks`** | `src/entities/task_queue.gd:166–168`；`src/data/tasks.json:3,5,14,16,…` |

### 2.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"玩家每周的注意力与任务槽"；独占"钱 vs RP"的配比决策 |
| **给谁供料 / 向谁索取** | 供：income→经济、rp_output→RP/影响力池、任务完成→迷雾供给；索：资金（cost）、科技（unlock 谓词）、时间 |
| **复杂度预算** | ≤1 个玩家决策（三选一）；≤1 屏 UI（任务槽+列表）；数据表键 ≤3 组（tasks/unlock/教学链） |
| **坏了整体会怎样** | 坏=收入无来源（P0）或 RP 供给断裂（科技树死锁）→ **P0** |

### 2.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RT-01** | 课题类 income 标定 | `35000 / 4 周` | **`~60000 / 4 周`**（须含教学链占槽 ~7 周） | DR-031/C3；纪要 §2.5 + 对抗评审 B-3 |
| **RT-02** | 课题类 rp_output 标定 | **`0`** | **`~150`**（解"gate 与科技树在单槽下互斥"） | DR-031/C3；纪要 §2.8/§2.9 |
| **RT-03** | 复现类 income 标定 | `8000 / 3 周`（`paper_0`）；`lingxi` 12000 | **`~15000 / 3 周`**（避免"非课题任务立即致死"） | DR-031/C3 |
| **RT-04** | 复现类 rp_output 标定 | 50 / 100 | **`~100–150`**（配平 160 周供给） | DR-031/C3；纪要 §2.9 |
| **RT-05** | 任务池内容化（扩池） | 5 条（1 占位） | 扩池为"课题池/论文池/合作池"（每条带梗+独立参数）；**选择 UI = 黄** | DR-031/C1 第 3 条；架构稿 §5.4 Q-C1 |

**关键规则（gate 与供给双达标，实算口径）**：

```
# ① gate 达标（24 周内累计经营收入 ≥ ~250k）——教学链占槽不可漏算
教学链：paper_0(3 周 / 8k) → [silver_leash 点亮] → lingxi(4 周 / 12k)   占槽 ~7 周
24 − 7 = 17 周 ≈ 4 笔课题
4 × ~60k + 8k + 12k = ~260k ≥ 250k  ✓（余量 ~4%）
# 反例（否决）：课题 ~50k/4 周 → ~220k ✗

# ② RP 供给（V6 P50 合规）
单槽串行 160 周 ≈ 40 笔 × ~150 = ~6000 RP
C(7)=4910 ≤ ~6000 < C(8)=6810  →  点亮 7 个 → P50 = 7  ✓

# ③ 互斥 → 配比（结构性修复）
改造前：纯课题 24 周收入 25.2 万但 RP=0 → 科技树死锁
改造后：课题也给 rp_output → "钱 vs RP" 从互斥变配比（RT-02 的存在理由）
```

**数值口径（全 `~`）**：

| 键 | 现值 | 裁决值 |
|---|---|---|
| `task_grant_pilot.income` | `35000` | `~60000` |
| `task_grant_pilot.rp_output` | `0` | `~150` |
| `task_reproduce_paper_0.income` / `.rp_output` | `8000` / `50` | `~15000` / `~100–150` |
| `task_reproduce_lingxi.income` / `.rp_output` | `12000` / `100` | `~15000` / `~100–150` |
| `task_research_basic.rp_output` | `150` | `~150`（维持） |
| gate `250k` / lab 期 `24 周` | — | **不动**（守 DR-028 R-9 / DR-029 C-2） |

### 2.4 验收点

- `[T] test_lab_gate_reachable_within_24_weeks`（`tests/unit/test_game_world.gd`）——**断言点**：按"教学链 2 笔 + 课题 4 笔"策略模拟 24 周，`cum_income ≥ ~250k` 为真，且**教学链占槽周数被计入**（防漏算回归）。
- `[T] test_task_rp_supply_in_target_band`（`tests/integration/test_playtest_loop_headless.gd`）——**断言点**：160 周单槽串行策略跑完，`Σ rp_output ∈ [~4910, ~6810)`（V6 P50 合规带）。
- `[T] test_grant_task_yields_both_money_and_rp`（`tests/unit/test_task_queue.gd`）——**断言点**：课题完成时 `money` 与 `influence`（RP）**两者都**变化（RT-02 回归防护；改造前 RP 恒 0）。
- `[T] test_reproduce_task_not_instant_death`（`tests/unit/test_economy.gd`）——**断言点**：纯复现策略下 24 周 money 不触破产线（避免"非课题任务立即致死"）。
- `[T] test_lab_weekly_expense_matches_gdd_64`（`tests/unit/test_economy.gd`）——**断言点**：lab 期周支出 ∈ `[~8k, ~10k]`（与 RE-04 同源，GDD §6.4）。
- `[P] test_playtest_money_vs_rp_tradeoff`（`tests` 外，试玩脚本 `#RT-01`）——**步骤脚本**：在 W20 时同时存在"课题（钱多 RP 少）"与"研究（RP 多钱少）"两个可选任务；**预期感受**：玩家犹豫 ≥5 秒并说出"我缺钱还是缺 RP"；**代理指标**：单局内**至少 3 次**主动切换任务类型（不全程只接一种）。

### 2.5 待裁 / 待试玩

- **任务池扩池的具体条目数与文案**（Q-C1 倾向"是"；扩池=绿，选择 UI=黄）——文案席 + 内容席供给。
- **`rp_output` 最终落点**：`~150` vs `~100–150` 区间内取值，须与 §6 供给复算同批定（见 §6.5 待裁）。

---

## 模块 3：人员与 Σeff（GDD §7）

### 3.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E3-1 | 3 人（research 70/55/62，Σ=187；wage 2k/人·周） | `src/data/staff.json` |
| E3-2 | **`get_research_eff()` 只返回单个占用者的值**（不是 Σ）——DR-005R 求和口径未落地 | `src/entities/staff_roster.gd:113–119` |
| E3-3 | 单槽独占：`assign_staff` 会踢出原占用者 | `src/entities/staff_roster.gd:46–65` |
| E3-4 | **`min_staff` 全仓零消费**：`can_start_training` 只查 `research_eff>0` / `min_tier` / `money≥cost`；全仓 `min_staff` 仅 3 处**定义**（数据表） | `src/entities/training_project.gd:29–41`；`src/data/model_bases.json:5,14,23` |
| E3-5 | **`max_staff` 全仓不存在**（grep 零命中）；`get_slot_occupants()`（复数）亦不存在 | `src/data/model_bases.json` 键集：name/train_weeks/min_staff/hours_per_week/min_tier/quality/cost |
| E3-6 | 已有求和工具函数 `calculate_aggregate_research()`（**仅测试调用**，World 不用） | `src/entities/staff_roster.gd:122–132` |

### 3.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"研究力"这一**不可购买的稀缺资源**；不产出分数（只提供 eff 输入） |
| **给谁供料 / 向谁索取** | 供：research_eff→出分；索：工资（经济）；招聘/condition=v2.0 |
| **复杂度预算** | ≤2 个玩家决策（谁上桌 / 谁跑任务）；≤1 屏 UI（名册）；数据表键 ≤3 组（staff/model_bases/opening） |
| **坏了整体会怎样** | 坏=主玩法失去唯一稀缺约束 → **P0** |

### 3.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RP-01** | Σeff 落地 | `get_research_eff()` 返回单人值（`:113–119`） | `research_eff = Σ(已分配到训练位的员工 research)` | DR-031/D1③；DR-005R；GDD §7 |
| **RP-02** | 多人上桌 | 单槽独占（`assign_staff` 踢人） | 训练位可容纳多人；**上桌人数 ≤ 基座上限** | DR-031/D1③；DR-029 A-1"两人同时上桌" |
| **RP-03** | `max_staff` 数据键 | **不存在** | `model_bases.json` 新增 `max_staff`（**1/2/3**）；**禁借用 `min_staff`** | DR-031/B2；纪要 M-5（从零新增校验，非防歧义） |
| **RP-04** | 上桌人数校验 | 无 | `can_start_training` 增一条"上桌人数 ≤ `max_staff`"校验 + 拒绝原因 | DR-031/B2；R-5/Q11 |

**关键规则（伪代码）**：

```
# RP-01 Σeff（保留单人语义方法，新增聚合方法 → 测试改动面最小）
func get_research_eff(slot_id := SLOT_TRAINING) -> int:
    return Σ(research of all staff assigned to slot_id)     # 改：从"取第一个"改"求和"

# RP-02 多槽占用（纪要 §八"最小改动路径"）
func get_slot_occupants(slot_id) -> Array[String]   # 新增
func get_slot_occupant(slot_id) -> String           # 保留（返回首个，单人语义不破）

# RP-03/RP-04 上桌校验
func can_start_training(base_id, context) -> Dictionary:
    if context.research_eff <= 0: return {ok:false, reason:"zero_research_eff"}
    if context.compute_tier < base.min_tier: return {ok:false, reason:"tier_too_low"}
    if context.money < base.cost: return {ok:false, reason:"insufficient_money"}
    # 新增（RP-04）
    n = context.occupants.size()
    if n < 1:              return {ok:false, reason:"no_occupant"}
    if n > base.max_staff: return {ok:false, reason:"headcount_exceeds_base_limit"}
    return {ok:true}
```

**数值口径**：`max_staff`：璞石 `1` / 玄冰 `2` / 深渊 `3`（= 与 `min_staff` 同值，但**独立键**）。

> **R-5/Q11 待裁**：是否允许 `min_staff < max_staff`（如"深渊最少 3、最多 3"）——见 §11.5 待裁。

### 3.4 验收点

- `[T] test_research_eff_sums_all_assigned`（`tests/unit/test_staff_roster.gd`，**扩展既有 `test_research_eff_and_dr005r_aggregate` 的多人分支**）——**断言点**：3 人全部上桌时 `research_eff == 187`（**严格禁均值**）；1 人时 == 该人值；0 人时 == 0；既有"未分配为 0 / 单人 90"断言不破。
- `[T] test_training_headcount_bounded_by_base`（`tests/unit/test_training_and_sota.gd`）——**断言点**：璞石上桌 2 人 → `can_start_training` 返回 `reason="headcount_exceeds_base_limit"`；玄冰 2 人 / 深渊 3 人 → 通过。
- `[T] test_multi_occupant_assign_roundtrip`（`tests/unit/test_staff_roster.gd`）——**断言点**：多人指派 → `to_save()` → `restore()` 后占用者集合一致（存档往返）。
- `[T] test_min_staff_zero_consumers_grep`（`tests/unit/test_staff_roster.gd`）——**断言点**：全仓 `min_staff` 消费点 = 0（防"借用 min_staff 当上限"的回归）；`max_staff` 消费点 ≥1。
- `[P] test_playtest_headcount_decision`（`scripts.md#RP-02`）——**步骤脚本**：开训时在 1 人 / 2 人 / 3 人之间选择；**预期感受**：能感到"多人上桌=更快出分，但占掉的是任务槽的人"，且选择后立刻看到 eff 预演变化；**代理指标**：开训前玩家**主动查看 eff 数值 ≥1 次**，且 10 秒内完成上桌人选确认。

### 3.5 待裁 / 待试玩

- **R-5 / Q11**：`min_staff` 与 `max_staff` 关系（是否允许 min<max；扩编后是否放开）——主程序席，批 1 ③ 开工前。
- **多人上桌的 UI 形态**（点卡逐个上桌 vs 勾选列表）——UI 席。

---

## 模块 4：算力（买卡入口 N9 + 卡时消费 N10）

### 4.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E4-1 | `upgrade_compute(target_tier)` **已实现**（扣款+补余量+发信号），但**唯一调用方是测试** | `src/entities/economy.gd:148–159`；`tests/unit/test_economy.gd:168–179` |
| E4-2 | **无契约命令**：`CONTRACT_COMMANDS` 11 项中无买卡 | `src/entities/game_world.gd:24–36` |
| E4-3 | **无 UI 入口**：`main.gd` 资源条无买卡按钮（仅 `ComputeLabel` 文本，显示"算力: %d卡时"） | `src/ui/main/main.gd:35,430`；`src/ui/main/main.tscn:42` |
| E4-4 | 买卡价格/容量：tier1~4 = `price 0/19000/38000/77000`、`capacity 40/80/160/320` | `src/data/economy.json:9–14` |
| E4-5 | `hours_per_week`（6/14/30）**零消费**；`Economy.training_cost()` **零调用方**；无 `weekly_supply` 键 | `src/data/model_bases.json`；`src/entities/economy.gd:204–206` |
| E4-6 | **双重计费实证**：`base.cost` 精确 = `hours_per_week × train_weeks × 150`（璞石 9000=6×10×150、深渊 117000=30×26×150、玄冰 34000≈33600）；`start_training` 只扣 `cost` 资金、不扣卡时 | 纪要 D-9；`src/entities/training_project.gd:50–54` |
| E4-7 | 卡时口径：GDD §6.3 供给 `8/16/32/64` vs `capacity 40/80/160/320` = **两概念并存分键** | GDD §6.3；纪要 D-6/D-10 |

### 4.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"算力档位"与"每周卡时预算"；不产出分数（只提供 m 乘子与训练门槛） |
| **给谁供料 / 向谁索取** | 供：m(compute_tier)→出分、卡时→训练门槛；索：资金（买卡价） |
| **复杂度预算** | ≤2 个玩家决策（买不买卡 / 本周卡时怎么分）；≤1 屏 UI（资源条按钮）；数据表键 ≤3 组（economy.compute_tiers / model_bases.hours_per_week / 周供给） |
| **坏了整体会怎样** | 坏=玄冰/深渊永不可达 + 买卡=纯收益 → **P0**（成长路径断裂） |

### 4.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RC-01** | 买卡契约命令（N9） | 无命令（`upgrade_compute` 是孤儿方法） | 新增契约命令 **11→12**（如 `upgrade_compute`），同步 `CONTRACT_COMMANDS` + 契约对账测试 | DR-031/D2；DR-026 命令面修订；架构稿 §12① |
| **RC-02** | 买卡主台入口 | 无 UI（资源条**全为 Label，无 Button**） | 资源条按钮（**不新增面板，零 PanelStack 注册**） | 纪要 §八"最小改动路径"；架构稿 §12① |
| **RC-03** | 买卡反馈 | `compute_upgraded` 信号已存在 | 按钮态（可买/不可买+原因）+ 资源栏刷新 + 买后 m 档可见 | DR-015 反馈三态；架构稿 §6.4 |
| **RC-04** | 卡时**每周预算**口径（N10） | 无消费 | 每周结**重置为供给**（`weekly_supply`）；**不是"卡池扣减"** | DR-031/D1②；纪要 D-10；GDD §6.3 |
| **RC-05** | 训练占用卡时 | `hours_per_week` 零消费 | 训练每周占用 `hours_per_week` 卡时（占用=门槛，**不过账 money**） | DR-031/D1②；纪要 D-14 |
| **RC-06** | 余量不足拒绝开训 | 无校验 | `weekly_card_hours ≤ 每周供给` 才可开训；否则拒绝+原因 | GDD §6.3；架构稿 §3 E3 |
| **RC-07** | 防双重计费 | `base.cost` 已含全程卡时费 | **`base.cost` = 全程卡时费，卡时只作门槛/占用，不得再过账 money** | 纪要 D-9（唯一解）；DR-031/D1② |

**关键规则（伪代码）**：

```
# RC-04 每周预算口径（关键：不是卡池扣减）
每周结：economy.recharge_weekly()
    compute.weekly_budget = 每周卡时供给[compute_tier]        # 8/16/32/64（~）
    # 注意：不写 compute.hours_remaining 的"池"语义
开训：if base.hours_per_week > compute.weekly_budget: 拒绝("insufficient_weekly_compute")
      else: 占用 = base.hours_per_week（每周结算时按周扣减本周预算）

# RC-07 防双重计费（唯一解）
base.cost == hours_per_week × train_weeks × 150      # 已含全程卡时费
→ 卡时**不得**再过账 money（否则双重计费）
→ training_cost() 仅用于**校验/显示**，不作过账依据

# 为什么必须"周预算"而非"卡池扣减"（反例实算）
若按卡池扣减：璞石全程需 6×10 = 60 卡时 > tier1 容量 40 → 训练立刻不可行 ✗
```

**数值口径（全 `~`）**：

| 键 | 现值 | 裁决值 |
|---|---|---|
| 每周卡时供给（新键 `weekly_supply`） | 无 | `~8/16/32/64`（tier1–4） |
| 容量上限 `compute_tiers[].capacity` | `40/80/160/320` | **不动**（仅余量上限校验） |
| 买卡价 `price` | `0/19000/38000/77000` | 不动（v1.0 不调） |
| `training_cost_per_compute_hour` | `150` | 不动（仅校验用） |

### 4.4 验收点

- `[T] test_command_and_signal_contract_accounting`（`tests/unit/test_game_world.gd`，**扩展既有用例**）——**断言点**：`CONTRACT_COMMANDS.size() == 12` 且含买卡命令名；`CONTRACT_SIGNALS` 数量与清单一致（命令面 11→12 对账）。
- `[T] test_weekly_compute_supply_reset`（`tests/unit/test_economy.gd`）——**断言点**：连续 3 个周结后，每周卡时预算**每周期都重置为供给值**（不累计、不递减）。
- `[T] test_training_cost_not_double_charged`（`tests/unit/test_training_and_sota.gd`）——**断言点**：开训扣款 = `base.cost` **一次**；全程 10 周后 `money` 变化量 == `-cost`（**无**额外卡时过账）；`training_cost()` 调用不产生 `apply_delta`。
- `[T] test_training_rejected_when_weekly_compute_insufficient`（`tests/unit/test_training_and_sota.gd`）——**断言点**：周供给不足时 `start_training` 返回 `reason="insufficient_weekly_compute"`，且 money 未被扣（拒绝分支不留副作用）。
- `[T] test_compute_upgrade_command_and_entry`（`tests/integration/test_tech_and_staff_panels.gd`）——**断言点**：调买卡命令后 tier+1、`compute_upgraded` 发射、资源栏算力文本刷新；tier 已顶或钱不足时返回 false 且按钮置灰+原因可查。
- `[P] test_playtest_buy_compute_entry_10s`（`scripts.md#RC-02`）——**步骤脚本**：从主台出发，找买卡入口并完成一次升档；**预期感受**：入口"一眼可见"、买完立刻能感到 m 档变化（出分预演/算力文本）；**代理指标**：**10 秒内**完成首次升档（≤2 次点击）。

### 4.5 待裁 / 待试玩

- **每周供给 `8/16/32/64` 与 `hours_per_week` 6/14/30 的差 2 是否保留**（GDD §6.3 已定"逐档差 2，训练永远供得上"）——维持，不动。
- **超分配拒绝顺延**：明确 **v0.2**（DR-018 A15），v1.0 只做"拒绝开训"。

---

## 模块 5：事件（GDD §11）

### 5.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E5-1 | 实表 **8 卡 = 6 通知 + 2 决策**（`layer` 字段） | `src/data/events.json` |
| E5-2 | **8 卡 `predicate` 全为 `none`** → 候选永远非空 → **每周结必抽 1 张** | `src/data/events.json`；`src/entities/event_engine.gd:120–133` |
| E5-3 | 实表量级：money 15000/30000/-5000、influence 100、rp_grant 200、compute 10 | `src/data/events.json` |
| E5-4 | 无 `p_week` / `cooldown` 键；`once` 已有（3 卡 true） | 同上 |
| E5-5 | `rp_grant` 直接入 influence 池 | `src/entities/event_engine.gd:190–191` |
| E5-6 | 实算现状：money **3.1–5.6k/周**、rp_grant **16.7/周**、influence **16.7/周**（160 周 2667 影） | 纪要 §2.6 |

### 5.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"结算点的叙事注入"与"决策卡阻塞"语义；**不独占收入** |
| **给谁供料 / 向谁索取** | 供：9 效果类型→资源/任务/训练/迷雾/旗标；索：谓词上下文 + RNG 域 3（**不新增 RNG 域**） |
| **复杂度预算** | ≤1 张决策卡/周；≤3 条 toast 同屏；数据表键 ≤4 组（events/inspiration_spec/layer/效果枚举） |
| **坏了整体会怎样** | 坏=经济被击穿（现状）或节奏断档 → **P1**（现状实为 P0 级破坏） |

### 5.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **REV-01** | 命中率门 `p_week` | 无（每周必抽） | `p_week ~0.30–0.35`；未过门则**通知层静默** | DR-031/C2；纪要 §2.6 |
| **REV-02** | 单卡上限 | money 15000/30000、rp 200、influence 100 | `money ≤5k` / `rp_grant ≤60` / `influence ≤20` | DR-031/C2 |
| **REV-03** | 冷却 + once | `once` 有、**冷却无** | 同卡 N 周内不重复；`once` 卡 fired 后永久排除 | DR-031/C2；纪要 §八"新增 `cooldowns` 键，不改 `fired` 数组 → 零迁移" |
| **REV-04** | 总闸 + 收入占比 | 无 | 事件期望净效果 ≤`~0.6k/周`；事件累计收入 ≤累计经营收入 `~10%` | DR-031/C2；GDD §11 |
| **REV-05** | influence 权重占比 | influence 卡权重 20/120 ≈ 16.7% | influence 卡权重占比 **≥~25%**（与 Q2 的 300–600 影联标） | DR-031/C2；纪要 §2.6 自洽组 |

**关键规则（伪代码）**：

```
每周结事件抽取（目标形态）：
  if rng.event_roll() ≥ p_week:           # p_week ~0.30–0.35
      本周不抽 → 通知层静默
  else:
      candidates = 谓词过滤(events) ∧ 冷却未到 ∧ ¬fired
      if candidates 非空: 按权重抽 1 张
      决策卡每周 ≤1（通知不占额）
  单卡上限校验：money ≤5k / rp_grant ≤60 / influence ≤20
  冷却：同一卡 N 周内不重复（新增 cooldowns 键）
  once：fired 后永久排除（既有 fired 数组）
  总闸：Σ事件期望净效果 ≤ ~0.6k/周；事件累计收入 ≤ 累计经营收入 ~10%（V-sim）

# 自洽参数组（数值席，纪要 §2.6，全部 ~）
p_week = ~0.35, Σw = ~175
grant w25/money 4500 | sponsor w10 once/5000 | maint w10/−5000×50%
paper w50/influence 20 | advisor w35/rp 60 | rumor 20 / cloud 15 / badge 10
→ 净 money ~+175/周 ✓(≤600) | influence ~2.0/周 → 320 影 ✓(∈300–600)
  rp ~4.2/周（供给 8.1%）✓ | 事件收入占比 ~2.0% ✓(≤10%)
```

**为什么 `p_week` 不能孤立取小（联标依据）**：`p_week=0.10` 下事件仅贡献 ~53 影（Q2 下限 300 的 18%）→ **从"超标"翻成"不达标"** → `p_week` 与 influence 权重**必须同批标定**（DR-031/C2 对抗评审 B-4）。

**联标三项（DR-031/C2 必须同批）**：
1. `influence ≤20` 与 Q2 的 300–600 影**互斥**（现状权重下 160 周上限仅 256 影）→ influence 卡权重须 ≥~25%；
2. 闸的鉴别力**依赖 C1**：脉冲口径下"事件收入 ≤10%"自动合规（4.9%）→ 闸失效；占槽口径下为 **36%** → **C2 依赖 C1（§1）**；
3. `rp_grant` 现状 +16.7/周（+21.7% 供给）→ 会推高 V6 P50；压到 ≤60 后 → `~+0.5/周`（可忽略）→ **C2 与 §6 供给标定必须同批**。

### 5.4 验收点

- `[T] test_event_hit_rate_gate`（`tests/unit/test_event_engine.gd`）——**断言点**：同 seed 跑 1000 周，实际抽卡周数 / 1000 ∈ `[~0.28, ~0.38]`（`p_week` 带内）；未命中周 `pending_card` 为空且**无 toast 产出**。
- `[T] test_event_card_effect_caps`（`tests/unit/test_event_engine.gd`）——**断言点**：全表逐卡校验 `money ≤5000`、`rp_grant ≤60`、`influence ≤20`（数据表级断言，防新增卡越界）。
- `[T] test_event_cooldown_and_once`（`tests/unit/test_event_engine.gd`）——**断言点**：同一卡在冷却窗口内不重复抽中；`once` 卡 fired 后 1000 周内不再出现。
- `[T] test_event_income_share_bound`（`tests/integration/test_playtest_loop_headless.gd`）——**断言点**：160 周模拟后，事件累计收入 / 累计经营收入 ≤ `~10%`，且事件净效果周均 ≤ `~0.6k`。
- `[T] test_event_influence_weight_share`（`tests/unit/test_event_engine.gd`）——**断言点**：带 influence 效果的卡权重之和 / Σweight ≥ `~25%`（防"下限不达标"回归）。
- `[P] test_playtest_event_not_income_source`（`scripts.md#REV-01`）——**步骤脚本**：连玩 30 分钟，记录每次事件后的资金变化；**预期感受**：事件是"调味"不是"发薪"——不会因为等事件而不做任务；**代理指标**：事件贡献资金占玩家总资金增幅的**主观估计 ≤1/3**，且**没有任何一周**玩家因事件而放弃接任务。

### 5.5 待裁 / 待试玩

- **R-6 / Q12**：`p_week` 与 `inspiration base=0.10` 的密度叠加（两个 RNG 域每周叠加是否破"每周必做 ≤1"）——体验席 + 数值席，批 2 C2 开工前。
- **冷却窗口 N 的取值**（`~4–8 周`？）——数值席，需 V-sim。
- **形态 C（对齐税→影响力负向）**：触碰 B5，**v1.0 不做**，复议队列第 5 项。

---

## 模块 6：RP 供给与翻雾供给源（GDD §7 / §8.2）

### 6.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E6-1 | RP（=影响力同一池）**唯一来源** = 任务 `rp_output`（`:487`）+ 事件 `rp_grant`（`:190–191`）；**全仓无"研究力每周产 RP"通路** | `src/entities/game_world.gd:486–487`；`src/entities/event_engine.gd:190–191` |
| E6-2 | 消耗点 = 点树扣同一池 | `src/entities/tech_tree.gd:67` |
| E6-3 | **翻雾供给源是影响力余额**：`tech_fog.advance(get_influence())` → 点树花影响力会**隐式改变翻雾进度语义** | `src/entities/game_world.gd:514` |
| E6-4 | 翻雾通路 1 是**全局累计阈值**（rumored 200 / visible 600）→ 达到后所有 hidden 同时翻态 | `src/data/techs.json.fog_gate`；`src/entities/tech_fog.gd:95–103` |
| E6-5 | 无 `cum_influence` 计数器 | 全仓 grep 无命中 |

### 6.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"RP 供给"与"迷雾揭示进度"的输入；不产出分数 |
| **给谁供料 / 向谁索取** | 供：RP→点树、翻雾→可见性；索：任务 `rp_output`、事件 `rp_grant` |
| **复杂度预算** | ≤1 个玩家决策（点哪个节点）；≤1 屏 UI（迷雾面板）；数据表键 ≤3 组 |
| **坏了整体会怎样** | 坏=科技树死锁或供给破 V6 → **P1**（不阻塞主玩法，但长线塌） |

### 6.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RK-01** | 承认任务 `rp_output` 为 RP 唯一来源 | 代码实证成立，但文档口径未收口 | 写进 GDD §7 口径；`balance-preview` 连续模型**降级为参考** | DR-031/§2.9 第 1 条 |
| **RK-02** | RP 供给标定 | 现状 ~1800–2400（P50=4–5，破 V6 下限） | 目标 P50 `∈[4910, 6810)`（→ 点亮 7 个） | DR-031/§2.9 第 2 条；A1 |
| **RK-03** | RP = 影响力同一池（承认） | 代码已如此；GDD §6.1 原文"只进不出"矛盾 | 修订 GDD §6.1 为"**可消耗（点树）**" | DR-031/§2.9 第 4 条（C-B2 补裁） |
| **RK-04** | 翻雾供给源改独立计数器 `cum_influence` | 读当前余额（`:514`）→ 点树拖慢翻雾 | 新增累计计数器 `cum_influence`（不读当前余额） | DR-031/§2.9 第 4 条；D-12 |
| **RK-05** | Σrp_cost 维持实表 | 14210 | **不调表**（撤销原"→15910"方案）；调表降级为**条件项**（仅当标定后实测供给 >6.8k） | DR-031/A2 |

**关键规则（伪代码）**：

```
# RK-04 翻雾供给源（新增 advance_with_context，保留旧签名 → 测试改动面最小）
func advance_with_context(ctx) -> void:
    _reveal_by_cum_influence(ctx.cum_influence)    # 用累计计数器，不用当前余额
func advance(cumulative_rp) -> void:               # 旧签名保留（兼容）
    advance_with_context({cum_influence: cumulative_rp})

# cum_influence 维护（开放容器，零迁移）
每笔 influence/rp 收入过账时：cum_influence += amount   # 只增不减
点树消耗：不减少 cum_influence                          # 关键：点树不拖慢翻雾

# RK-02 供给标定校验（V6 合规判定）
C(n) = 成本升序累计：300/660/1040/1460/2010/3310/4910/6810/9110/11510/14210
供给 P50 ∈[4910, 6810) ⇒ C(7) ≤ P50 < C(8) ⇒ 点亮 7 个 ⇒ V6 P50=7 ✓
（P10≥5 / P90≤11 亦满足）
```

**数值口径**：目标供给 P50 `∈[4910, 6810)`；Σrp_cost `14210` **不动**。

### 6.4 验收点

- `[T] test_rp_supply_source_single_path`（`tests/unit/test_game_world.gd`）——**断言点**：全仓 grep 断言"产 RP 的通路恰 2 处"（任务 `rp_output` + 事件 `rp_grant`）；不存在"研究力每周产 RP"的路径。
- `[T] test_tech_lit_advance_not_slowed_by_spending`（`tests/unit/test_tech_fog.gd`）——**断言点**：同样 `cum_influence` 下，无论玩家是否点树（当前余额高低），翻雾进度**完全一致**（RK-04 回归防护）。
- `[T] test_acceptance_point_2_v6_tech_lit_distribution_bounds`（`tests/unit/test_assertion_bounds.gd`，**扩展既有用例**）——**断言点**：160 周模拟 `lit@160` 的 P10≥5 / P50∈[7,9] / P90≤11（V6 绝对口径）。
- `[T] test_cum_influence_monotonic_and_persisted`（`tests/unit/test_tech_fog.gd` / `test_save_migrator.gd`）——**断言点**：`cum_influence` 单调不减；读档还原后值一致（零迁移）。
- `[T] test_rp_cost_within_redline`（`tests/unit/test_techs_data.gd`，**扩展既有用例**）——**断言点**：`Σ(rp_cost + 域门槛) ∈ [~10k, ~20k]`（DR-027① 警戒带；GDD 原 `[8k,12k]` 已作废）。
- `[P] test_playtest_rp_supply_feels_scarce`（`scripts.md#RK-02`）——**步骤脚本**：全程记录每次点树所需 RP 与攒 RP 的周数；**预期感受**："点树要攒、要选"，不是"随便点"；**代理指标**：单局内点树决策**至少 3 次**出现"两个都想点但只能点一个"的犹豫。

### 6.5 待裁 / 待试玩

- **Q14**：DR-027① 的"Σ(rp_cost+域门槛) ≈ 12–16k"是**需求还是供给**——若指供给，与实现口径（~6k）差 2 倍；若指需求，与 V6 的 `[7,9]` 矛盾（供需比 1.0 意味着能点满）→ 数值席，任务池标定后复算。
- **`supply_anchor_rp = 12300` 现被测试锁定**：`assertion_bounds.json:16` + `tests/unit/test_assertion_bounds.gd:34` 断言"供给锚 12.3k RP（三阶段占比口径）"——**该锚已被代码实证推翻**（无产出通路），须随 RK-02 同批改为"任务口径供给带 `[4910, 6810)`"；**这是一处必须同批修的断言**（否则 V6 断言自相矛盾）。
- **Q13**：`balance-preview` 连续模型（lab 1244 RP）vs 任务系统离散 `rp_output`（纯研究 24 周 900 RP，差 28%）口径统一——数值席，任务池内容化标定同批。
- **M-1（同口径蒙卡复核）**：`balance-preview` 蒙卡给 9/9/9（合规），本会解析法给 10（违规）→ **A2 生效前须用同一口径蒙卡跑前后对比**（含域门槛、时序、点树扣同一池）。

---

## 模块 7：科技树口径收口（GDD §8.1）

### 7.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E7-1 | 实表 **14 节点 = 11 `enabled` + 3 `never`**（world/symbol/embodied） | `src/data/techs.json`（实测） |
| E7-2 | Σrp_cost = **14210**；Σtech_bonus = **1.4000**（实测复算） | 同上 |
| E7-3 | 域分布：深思 3 / 蒲公英 3 / 长忆 2 / 通感 **1** / 器用 **1** / 交叉 **1** / elsewhere 3 | 同上 |
| E7-4 | **`TOTAL_NODES = 14` 硬编码**，域计数分母用它，但最多亮 11 | `src/entities/tech_fog.gd:18` |
| E7-5 | 开局可研节点硬编码 4 个 | `src/entities/tech_fog.gd:24–29` |
| E7-6 | 解锁谓词未落地：只认"parents 全 lit"+`mirror_mind` 硬编码特例，`unlock` 字段被忽略 | `src/entities/tech_fog.gd:313–331` |
| E7-7 | 成本升序累计：300/660/1040/1460/2010/3310/4910/6810/9110/11510/14210 | 实测复算 |
| E7-8 | **域计数分母已排除两域**：主干点亮计数 `if domain != "elsewhere" and domain != "crossover"`；`payload["total_nodes"] = TOTAL_NODES`（14） | `src/entities/tech_fog.gd:334–343`、`:371` |
| E7-9 | 现有测试**已锁定** `playable_count == 11` 与警戒带 `[10k, 20k]` | `tests/unit/test_techs_data.gd:87–104` |

### 7.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"知识可见性"（五态）与"科技乘子"（tech_bonus）；不产分数、不产资源 |
| **给谁供料 / 向谁索取** | 供：tech_bonus→出分、tech_lit→任务解锁、域计数→图鉴；索：RP、竞对论文外溢、交叉进度 |
| **复杂度预算** | ≤2 个玩家决策（点亮顺序/域优先）；≤1 屏 UI（迷雾面板 C 方案）；数据表键 ≤3 组（nodes/fog_gate/domain_enum） |
| **坏了整体会怎样** | 坏=中长线目标消失 + 出分乘子失效 → **P1** |

### 7.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RK-06** | 14 节点口径收口 | 实表 14 = 11 可研 + 3 elsewhere；DR-023 表述"elsewhere 余 2" | 以 **3** 为准；GDD §8.1 同步 | DR-031/D-1；DR-003 |
| **RK-07** | 域计数分母收口（选项 b） | `TOTAL_NODES=14` 硬编码；主干点亮计数**已排除 elsewhere/crossover**；分母 14 但最多亮 11 | **显示 `n/14` 但注明 elsewhere 不可研**（选项 b）；**`TOTAL_NODES` 数据键化** | DR-031/D3 第 2 条（M-11 修正）；`tech_fog.gd:334–343` |
| **RK-08** | 每域 ≥1 个可达节点 | 通感（`synesthesia_clip`）、交叉（`mirror_mind`）在多数局面不可达 | **硬约束**：P50 供给下每域 ≥1 节点可达；不可达则调 `rp_cost` 或（v0.2）增设域内廉价节点 | DR-031/A2 第 6 条（M-2） |
| **RK-09** | 单节点 tb 区间 | 实表 0.05–0.25 | `tb ∈ [0.02, 0.10]`（**v1.0 不调表**——冻结现状，登记 v0.2 复议） | DR-031/B3 |

> **RK-09 说明**：DR-031/B3 裁决"单节点 tb∈[0.02,0.10] 采纳、Σtb 冻结 1.40"。**实表当前单节点最大 0.25 > 0.10** → 本项在 v1.0 是**记录性约束**（不做改表），改表归 v0.2 复议（见 §末不做清单）。**Σtb 冻结 1.40 已成立**（实测 1.4000）。

**关键规则（域计数选项 b）**：

```
域计数显示：n / TOTAL_NODES       # n = 已探明（rumored 及以上）节点数
  - TOTAL_NODES 由数据键提供（不再硬编码 14）
  - 3 个 elsewhere 节点在迷雾列表中显示为「??? · 传闻未探明」行（DR-003）
  - 分母 14 + 列表 14 行 ⇒ 一致（选 b 的理由：选 a 分母 11 + 列表 14 行会不一致）
每域可达性校验（RK-08）：
  for domain in [deep_thought, dandelion, long_memory, synesthesia, tool_use, crossover]:
      assert ∃ node in domain: cost(node) ≤ P50 供给 ∧ min_week 已过
```

### 7.4 验收点

- `[T] test_domain_count_denominator_consistency`（`tests/unit/test_tech_fog.gd`）——**断言点**：域计数分母 == 数据键 `TOTAL_NODES` == 实表节点数（三处一致）；elsewhere 节点显示为"??? · 传闻未探明"且**不可研**。
- `[T] test_every_domain_has_reachable_node`（`tests/unit/test_techs_data.gd`）——**断言点**：P50 供给下，6 个域（深思/蒲公英/长忆/通感/器用/交叉）**各至少 1 个**节点满足"成本 ≤ 供给 ∧ `min_week` 已过"（RK-08 硬约束）。
- `[T] test_total_nodes_key_not_hardcoded`（`tests/unit/test_tech_fog.gd`）——**断言点**：`tech_fog.gd` 无 `TOTAL_NODES` 字面量常量（改读数据键）；grep 断言硬编码零命中。
- `[T] test_tech_table_integrity_and_schema`（`tests/unit/test_techs_data.gd`，**扩展既有用例**）——**断言点**：14 节点 / 11 enabled / 3 never / Σrp_cost=14210 / Σtb=1.4000 与文档口径一致。
- `[P] test_playtest_fog_exploration_feel`（`scripts.md#RK-07`）——**步骤脚本**：从 W0 玩到 W54，观察迷雾面板；**预期感受**："树是这样长的"——每次翻雾都能看到"还有一大片没拨开"；**代理指标**：单局内玩家**主动打开迷雾面板 ≥5 次**，且能说出"我最想点哪个域"。

### 7.5 待裁 / 待试玩

- **Q4**：长忆/器用 4 节点命名与定稿（窗口已过，归 v0.2 前复核）——主策划 + 文案席。
- **Q3**：灵感触发 > 可研节点数时的兜底行为——主策划（本席），PR5 后复核。
- **N15 扩树触发条件**：v1.0 只写**可判定硬约束**（①试玩"点亮到顶太早" ②V10 空窗频繁触顶 ③周目三件套需要开局选路线）；**扩树本身 v0.2**。

---

## 模块 8：出分与饱和护栏（GDD §9）

### 8.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E8-1 | `K=4.0` 与 `m` 乘子表 **硬编码** | `src/core/score_math.gd:9–18` |
| E8-2 | `θ=95 / k=13` 亦硬编码为默认参数（`DEFAULT_THETA` / `DEFAULT_K_SIGMOID`） | `src/core/score_math.gd:10–11` |
| E8-3 | `benchmarks.json` 只有 `bench_gkp`（theta/k/baseline/rival_model），**无 K / m / 节点数键** | `src/data/benchmarks.json` |
| E8-4 | 出分链：`A = K·(1+eff)^0.7·(1+tb)^0.3·m·q`；`score = 100/(1+exp(-(A-θ)/k))` | `src/core/score_math.gd:27–52` |
| E8-5 | 饱和实算：`score=99` 阈值 A=154.74；`tier3+深渊+3人+tb=0` → 99.5 分；**W54 封顶** | 纪要 §2.4 |

### 8.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"分数"这一社交货币与"截图时刻" |
| **给谁供料 / 向谁索取** | 供：score→SOTA/霸榜/三线①；索：eff（人）、tb（知识）、m（算力）、q（基座） |
| **复杂度预算** | ≤1 个玩家决策（训哪个基座）；≤1 屏 UI（出分宣发）；数据表键 ≤3 组 |
| **坏了整体会怎样** | 坏=主玩法失去反馈 → **P0** |

### 8.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RS-01** | `K` 数据化 | 硬编码 `4.0` | 迁 `benchmarks.json`（键如 `k`） | DR-031/D-7；红线 3（数值禁硬编码） |
| **RS-02** | `m` 乘子表数据化 | 硬编码 `{1:0.6,2:0.75,3:0.9,4:1.05}` | 迁 `benchmarks.json` / 新键 `compute_multipliers` | DR-031/D-7 |
| **RS-03** | `TOTAL_NODES` 数据化 | 硬编码 `tech_fog.gd:18` | 迁数据键（与 RK-07 同批） | DR-031/D-7·D3 |
| **RS-04** | θ/k 参数通路（零数值） | 已是函数默认参数 | **通路可注入**（从数据表读），但**数值维持 θ95/k13 不动** | DR-031/D1④修正；A3/B1 |
| **RS-05** | 饱和断言 | 无 | `[T] test_saturation_first99_week`：**首达 99 分周次 ≥~50** | DR-031/B1；GDD §18 |
| **RS-06** | 饱和触发器透明化 | 无 | `benchmarks.json` 或数值稿注明"**tier2 永不饱和**"、"玄冰 q=0.8 永不饱和" | DR-031/B1 第 3 条 |

**关键规则**：

```
# RS-01/02/03 数据化（红线 3 兑现）
benchmarks.json:
  bench_gkp: { theta, k, baseline, rival_model }        # 既有
  k: ~4.0                                                # 新增（RS-01）
  compute_multipliers: { 1: 0.6, 2: 0.75, 3: 0.9, 4: 1.05 }  # 新增（RS-02）
  total_nodes: 14                                        # 新增（RS-03）
  saturation: { first99_week_min: ~50, tier2_never_saturates: true }  # 新增（RS-05/06）

# RS-04 θ/k 通路（零数值变更）
score_math 函数签名已支持 theta/k 注入 → 只需把"读数据表"接上；v1.0 值仍 θ95/k13

# RS-05 饱和护栏判定（实算依据）
score=99 ⇔ A ≥ 95 + 13·ln99 = ~154.74
实算：tier3 + 深渊 + 3 人上桌 + tb=0 → A=164.1 → 99.5 分
      tb ≥ ~0.374（= 成本升序第 6 个节点，累计 3310）落在 W54
⇒ 断言"首达 99 分周次 ≥ ~50"（现状 ~54）
```

### 8.4 验收点

- `[T] test_saturation_first99_week`（`tests/integration/test_playtest_loop_headless.gd`）——**断言点**：按标准策略（3 人上桌 + 深渊 + tier3+ + 成本升序点树）模拟 160 周，**首达 score ≥ 99.0 的周次 ≥ ~50**；且记录该周次供 §11 收尾屏消费。
- `[T] test_acceptance_point_1_formula_boundary_vectors`（`tests/unit/test_training_and_sota.gd`，**扩展既有用例**）——**断言点**：K/m 由数据表驱动后，公式边界向量（eff=0 / tb=0 / tier 越界 / q 极值）输出与硬编码版本**逐值一致**（数据化零行为变更）。
- `[T] test_score_math_no_numeric_literals_grep`（`tests/unit/test_training_and_sota.gd`）——**断言点**：`src/core/score_math.gd` 中不存在 `4.0`/`0.6`/`0.75`/`0.9`/`1.05`/`95.0`/`13.0` 作为**业务数值字面量**（grep 断言，红线 3 回归防护）。
- `[T] test_saturation_trigger_metadata_present`（`tests/unit/test_assertion_bounds.gd`）——**断言点**：`benchmarks.json` 含 `saturation` 键且 `tier2_never_saturates == true`（透明化断言）。
- `[P] test_playtest_first99_feels_like_peak`（`scripts.md#RS-05`）——**步骤脚本**：玩到分数首达 99 分那周；**预期感受**：这是本局最爽的一刻，且**紧接着**出现"已登顶·自由期"提示（不是"然后什么都没了"）；**代理指标**：该周后玩家**继续游玩 ≥5 分钟**（不退出）。

### 8.5 待裁 / 待试玩

- **`benchmarks.json` 新键的命名与结构**（`k` vs `cobb_k`；`compute_multipliers` 是否嵌在 `bench_gkp` 内）——主程序 + 数值席。
- **饱和阈值是否改为"99.0"还是"99.5"**——数值席（现状 W54 达 99.06）。

---

## 模块 9：呈现层（分级 + 净流入预告 + 封顶叙事）（GDD §13）

### 9.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E9-1 | 资源栏节点**全为 `Label`（无 Button）**：`MoneyLabel` / `ComputeLabel` / `InfluenceLabel` + 副行 `ResearchEffLabel` / `TechBonusLabel` | `src/ui/main/main.tscn:37/42/47/57/62`；`src/ui/main/main.gd:33–39` |
| E9-2 | 资源视图 `_resource_view` 由 presenter 维护，仅含 `week/money/compute_hours/compute_tier/influence/research_eff/tech_bonus` | `src/ui/dashboard_presenter.gd:72–80`、`:116–120`、`:131–133` |
| E9-3 | **周报渲染断裂**：`weekly_report_dialog.gd:36` 读 `rows` 键 → 载荷无此键 → 恒走兜底文案；`money_row` 无任何 UI 消费点 | `src/ui/modals/weekly_report_dialog.gd:36–45`；`src/ui/main/main.gd:280–286`；`src/entities/game_world.gd:542–554` |
| E9-4 | **无分数分级显示**；无净流入预告；无封顶横幅（presenter 无相关函数） | 全仓 grep 无相关键 |
| E9-5 | 周报自动弹每周无条件 push（R3 结构落差，属 v0.1.x 债） | `src/ui/dashboard_presenter.gd:131–137` |

### 9.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"信息呈现"（不产数值、不改规则） |
| **给谁供料 / 向谁索取** | 供：玩家对世界的可读性；索：所有子系统的状态 |
| **复杂度预算** | ≤1 屏改动（资源栏 + 周报）；数据表键 ≤2 组（texts/benchmarks 分级阈值） |
| **坏了整体会怎样** | 坏=玩家看不懂（可玩性受损，但不破坏数值）→ **P1** |

### 9.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RU-01** | 分数分级显示 | 无 | `score < ~10` 主台只显分档标签（如"起步档·榜外"），周报留真值 | 架构稿 §6.3 ④ |
| **RU-02** | 净流入预告 | 无 | 资源栏副行常显"下周净流入预告" | 架构稿 §6.3 ⑤；DR-031/D1⑥ |
| **RU-03** | 封顶叙事 | 无 | 出分封顶时显示「**已登顶 · 自由期**」 | DR-031/B1 第 2 条；衔接 DR-029 C-6 |
| **RU-04** | 三线常显 | 无 | 自由期三线计数器可见（§11） | DR-029 C-6；GDD §3 |

**关键规则（状态-视觉映射，`docs/standards/ui-state-visual-mapping.md` 口径）**：

| 状态 | 触发条件 | 视觉 | 断言 |
|---|---|---|---|
| 起步档·榜外 | `score < ~10` | 分档标签（灰） | 主台不显裸分数 |
| 榜内 | `score ≥ ~10` | 显示分数 + 名次 | 分数与 `sota_board` 一致 |
| 已登顶·自由期 | `score ≥ 99.0` 首次达成 | 横幅（金框）+ 三线并排 | 横幅仅出现 1 次（`once` 语义） |
| 净流入预告 | 每周期 | 副行"下周净流入 ~-¥3万" | 预告值 == 下周实际 `net`（±0 误差） |

### 9.4 验收点

- `[T] test_net_inflow_forecast_matches_actual`（`tests/unit/test_dashboard_presenter.gd`）——**断言点**：预告值 == 下一周实际 `report.money_row.net`（**误差 0**，预告必须是"算出来的"不是"猜的"）。
- `[T] test_score_grade_display_mapping`（`tests/unit/test_dashboard_presenter.gd`）——**断言点**：`score < ~10` → 分档标签且**不含裸数字**；`score ≥ ~10` → 显示真值；阈值由数据键驱动。
- `[T] test_saturation_banner_free_period`（`tests/unit/test_dashboard_presenter.gd`）——**断言点**：首达 99 分那周 push 横幅"已登顶·自由期"；**仅 1 次**（重复周不重弹）；横幅文案走 texts 键。
- `[T] test_resource_subrow_no_overflow`（`tests/unit/test_responsive_and_polish.gd`）——**断言点**：竖屏第一折（副行）内新增的预告文本不溢出、字号不缩到可读下限以下（DR-015 竖屏折叠纪律）。
- `[P] test_playtest_economy_readable_5min`（`scripts.md#RU-02`）——**步骤脚本**：新玩家 5 分钟试玩后，被问"下周大概会赚还是亏"；**预期感受**：不需要打开任何面板就能答出来；**代理指标**：**≥80%** 的新玩家能正确回答（预演/试玩样本），且回答耗时 ≤10 秒。

### 9.5 待裁 / 待试玩

- **分档阈值 `~10` 与档名**（"起步档·榜外"等）——文案席 + 数值席，等试玩。
- **净流入预告的口径**（含不含"未来 N 周"预测 vs 仅下周）——本席倾向**仅下周**（避免过度设计），待拍板。

---

## 模块 10：竞对死表重标（GDD §10 / N11）

### 10.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E10-1 | 深巷 8 动作时间线；L1@~12 周 **35** 分、L2@~54 周 **58**、L3@~68 周 **75**、L4@~82 周 **92** | `src/data/rivals.json` |
| E10-2 | W0 基线（灵犀 Chat）**24** 分 | `src/data/opening.json` rival_best / `benchmarks.json` baseline |
| E10-3 | ±15% 扰动（RNG 域 1）；黄灯 ⌈0.15t⌉ 周、红灯 2 周零误报 | `src/entities/rival_track.gd`；DR-027④ |
| E10-4 | 玩家早期（单人 eff=70 / tier1 / 璞石 / tb=0）→ A=26.1 → **0.50 分** vs 竞对 L1 35 分 → **早期不可能反超** | 架构稿 §2.1 |

### 10.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"时限与参照系"；**玩家无直接决策**（守 B1 永不博弈 AI） |
| **给谁供料 / 向谁索取** | 供：分数压力、论文外溢→翻雾、预警→节奏；索：无（脚本 + ±15% 扰动） |
| **复杂度预算** | 0 个玩家决策；≤1 屏 UI（竞对条）；数据表键 ≤2 组（rivals/opening） |
| **坏了整体会怎样** | 坏=霸榜不可达、三线①失效 → **P1** |

### 10.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RR-01** | 竞对死表重标 | 35/58/75/92 vs 玩家成长曲线系统性偏离 | 离线一次性标定，与玩家成长曲线匹配；**L4 标到 ~96–98 分**（与玩家封顶 99 分差 1–3 分，**禁超玩家**） | DR-031/D2（N11 升 v1.0 P0）；架构稿 §12⑤；**GDD §2①/②** |
| **RR-02** | 标定前提 | 玩家 eff=单人 70（W12 仅 0.89 分） | **前提 = Σeff（§3）+ 供给标定（§6）收敛** | 纪要 §三依赖图；架构稿 A-B4 |
| **RR-03** | 扰动带口径 | ±15% 已实现 | 反解须按扰动后区间计算（"追 L1 35 分"实为追 `[~29.75, ~40.25]`） | 架构稿 A-M8 |
| **RR-04** | 预警断言 | 红灯零误报已实现 | 重标后**红灯零误报断言仍成立**（重标不得破预警） | DR-027④；GDD §18 |

**关键规则**：

```
# RR-01 标定口径（离线一次性，不改引擎）
输入：玩家成长曲线（Σeff 落地 + 供给标定后的 A 曲线）
输出：rivals.json 各动作的 score（死表，±15% 扰动带内）
约束：
  ① 霸榜可达：玩家 A 上限（~213.4）≥ 竞对最高分所需 A（L4 92 分 → A=126.8）✓
  ② 早期不绝望：W12 玩家分 ≥ 竞对 L1 的 ~1/3（体验席"首分可见锚"）
  ③ 死表纪律：竞对=固定死表 + ±15% 扰动，永不引入博弈 AI（B1）
  ④ 重标**不改时间线周次**（L1=~12 周维持，守 DR-027④ 先发率 49.4%）
  ⑤ **L4 上限 ~96–98 分**（GDD §2②：与玩家封顶 99 分差 1–3 分 → 守卫张力；**禁超玩家**）
```

### 10.4 验收点

- `[T] test_rival_scores_within_jitter_band`（`tests/unit/test_rival_track.gd`，**扩展既有用例**）——**断言点**：重标后每个动作的实得分 ∈ 死表值 × `[0.85, 1.15]`；且**死表值本身**在标定稿给出的目标带内；**L4 死表分 ∈ `[~96, ~98]` 且 < 玩家封顶 99 分**（禁超玩家）。
- `[T] test_acceptance_point_4_warning_thresholds_and_zero_false_alarm`（`tests/unit/test_rival_track.gd`，**扩展既有用例**）——**断言点**：重标后黄灯/红灯阈值不变，红灯误报率 == 0（回归防护）。
- `[T] test_player_can_top_rival_at_reachable_config`（`tests/integration/test_playtest_loop_headless.gd`）——**断言点**：在"Σeff + max_staff 上限 + tier3+ + 满树 tb"的可达配置下，玩家最高分 **>** 竞对 L4 死表分（霸榜可达性硬约束）。
- `[T] test_rival_timeline_weeks_unchanged`（`tests/unit/test_rival_track.gd`）——**断言点**：重标只改 score 不改 `week`（L1=~12 周维持）。
- `[P] test_playtest_rival_pressure_curve`（`scripts.md#RR-01`）——**步骤脚本**：全程观察竞对条；**预期感受**：W12 前后"被压住但看得见希望"，W54 后"我压住了它但它在追"；**代理指标**：单局内玩家**主动查看竞对条 ≥8 次**，且能说出"下一个威胁在第 N 周"。

### 10.5 待裁 / 待试玩

- **标定稿的目标带**（各动作目标分区间）——数值席产出，须在 §3/§6 落地后。
- **复议队列第 8 项**：竞对时间线对齐真实史（T2/T4）——**v1.0 不做**，待试玩。
- **N12（W47 ChatGPT 时刻 + 2022-10 算力红线）**：**v1.0 只按纯文案/通知层落地**，**不改竞对时间线**（DR-031 补裁）。

---

## 模块 11：短单局体验收尾（本任务新增）

### 11.1 现状实证

| # | 事实 | 证据 |
|---|---|---|
| E11-1 | 周数换算：0.25s × 40 = **10s/周** → 160 周 ≈ **~27 分钟** | `src/data/clock.json` |
| E11-2 | 分数 **W54 封顶**（99 分），其后 ~106 周无分数成长 | 纪要 §2.4/E5 |
| E11-3 | 自由期三线**尚无计数器**（`freedom_*` 键不存在） | 全仓 grep 无命中；GDD §3 有表述 |
| E11-4 | Game Over summary = `week/best_score/rival_best/model_name/cum_income/reason`，**无三线终值、无 SOTA 次数** | `src/entities/game_world.gd:315–323`；S2-08 |
| E11-5 | 终局只有 Game Over 卡（破产）；**正常走完 160 周无终局屏** | `src/ui/modals/game_over_dialog.gd` |

### 11.2 边界卡四问

| 问 | 答 |
|---|---|
| **独占什么** | 独占"一局的形状"——高潮点排布与收尾 |
| **给谁供料 / 向谁索取** | 供：三线目标、"想再开一局"的钩子；索：所有子系统的状态（分数/树/影响力/竞对） |
| **复杂度预算** | ≤1 屏（终局屏）；数据表键 ≤2 组（flags 计数器 + texts） |
| **坏了整体会怎样** | 坏=一局"有高潮无收尾"→ 制作人成功标准不成立 → **P0**（本任务的验收核心） |

### 11.3 功能点

| 编号 | 功能点 | 现状 | 目标 | 出处 |
|---|---|---|---|---|
| **RF-01** | 自由期三线计数器 | 无 | `freedom_king_weeks` / 树已探明 n / `influence` 存量，入 flags 开放容器（零迁移） | DR-029 C-6；GDD §3；D1-05-02 |
| **RF-02** | 三线两阶段可见 + 封顶接管 | 无 | **W25 起常显**（长线目标线）；**W54 封顶弹横幅 + 三线升主权重** | DR-031/B1②；**GDD §2①**；本任务新增 |
| **RF-03** | 终局收尾屏 | 无（仅破产 Game Over） | 走完 160 周（或破产）时，终局屏呈现三线终值 + 关键决策回溯（**summary 扩六项**） | **GDD §2③**；本任务细化（Q-R3 待裁） |
| **RF-04** | 单局时长守卫 + 后半不空转 | 无 | 断言"160 周 × 10s ≈ ~27 分钟"；**封顶后 ≥3 次三线进度变化** | DR-009；**GDD §18 `[P]` 短单局专项** |

**关键规则（三线接管与收尾）**：

```
# RF-01 三线计数器（flags 开放容器，键名 freedom_*）
freedom_king_weeks  : SOTA 保霸周 +1（每周结：我方仍为霸主则 +1）
freedom_tree_n      : 消费 fog_changed 域计数（不新增计数器，读现成）
freedom_influence   : resources.influence 快照（不新增计数器）

# RF-02 三线两阶段可见（GDD §2① 口径）
if week >= 25:                       # 阶段跃迁后
    enable_three_line_display()      # 三线常显（长线目标线），不弹横幅
if first99_week reached:             # 实算 ~W54
    push_banner_once("已登顶 · 自由期")     # RU-03
    promote_three_line_to_primary()         # 三线升主权重（差距行/里程碑）
    # 优先级压过摆弄层（DR-029 C-6）
    # 此后每周报固定带三线行；封顶后须 ≥3 次三线进度变化（RF-04）

# RF-03 终局收尾屏（走完 160 周或破产；summary 扩六项，GDD §2③）
终局屏必须含（六项）：
  ① 周数 / ② SOTA 次数 / ③ 最高分 / ④ 三线终值（霸榜 ~N 周 / 树 ~n/14 / 影响力 ~M）
  ⑤ 关键决策回溯（3 条）：最贵的训练 / 最晚的一次点树 / 最险的一次破产边缘
  ⑥ 一句话评价（如"你守住了 ~34 周榜首"）
  + 可截图（一屏内、无滚动）
边界：
  - 破产终局：三线终值 + "在第 N 周倒下"（不清档语义 v1.0 维持，N14=v0.2）
  - 0 霸榜（从未夺冠）：三线①显 0，不 NaN、不空行
  - 树 0 探明：显 0/14
```

### 11.4 验收点

- `[T] test_freedom_three_counters_accumulate`（`tests/unit/test_game_world.gd`）——**断言点**：构造"连续 5 周霸榜 + 3 个节点探明 + 影响力 500"的局面，三线值分别 == 5 / 3 / 500。
- `[T] test_freedom_counters_zero_state`（`tests/unit/test_game_world.gd`）——**断言点**：全 0 局面（首周、零霸榜、零探明）三线显示 `0 / 0/14 / 0`，**不 NaN、不空指针、不进差距行**。
- `[T] test_endgame_screen_three_lines_present`（`tests/unit/test_dashboard_presenter.gd`）——**断言点**：走完 160 周后终局屏含**六项**（周数/SOTA 次数/最高分/三线终值/≥3 条决策回溯/一句话评价）；一屏内可渲染（无滚动）。
- `[T] test_single_run_duration_guard`（`tests/unit/test_clock_math.gd`）——**断言点**：`tick_seconds × ticks_per_week × 160 == ~1600s`（≈~27 分钟）；变速系数不改变"周数→决策数"映射。
- `[T] test_three_line_visible_from_week25`（`tests/unit/test_dashboard_presenter.gd`）——**断言点**：W25 起三线常显（不弹横幅）；W54 封顶弹横幅且三线升主权重（**两时点分离**，GDD §2① 口径）。
- `[T] test_three_line_takes_over_after_saturation`（`tests/integration/test_playtest_loop_headless.gd`）——**断言点**：首达 99 分的那一周起，周报/主台**开始**携带三线差距行；**封顶后 ≥3 次三线进度变化**（否则断言失败 = "后半空转"，GDD §18）。
- `[P] test_playtest_oneshot_end_to_end`（`scripts.md#RF-03`）——**步骤脚本**：完整玩完一局（~27 分钟），从开局到终局屏；**预期感受**：**①有高潮**（至少 2 次"想截图"的瞬间）；**②有收尾**（终局屏能说清"我这一局干了什么"）；**③想再开一局**（结束后主动点"重新开局"或讨论"下次我要怎么玩"）；**代理指标**：终局后 **≤30 秒**内触发重开或明确表达重开意愿；能说出 ≥2 个"下次想改的决策"；且能自主说出「我封顶了 / 我在守成 / 我想再开一局」三句中至少两句（GDD §18 `[P]` 短单局专项原文）。

### 11.5 待裁 / 待试玩

- **Q-R3（本任务新发现）**：终局收尾屏的**触发时点与形态**——走完 160 周自动弹？还是玩家手动点"结算"？终局屏是否替代/并存破产 Game Over 卡？**需制作人拍板**（见 §末·三问）。
- **三线"差距行"的具体文案与里程碑刻度**（如"再守 ~10 周就破纪录"）——文案席 + 数值席。
- **三线优先级是否"压过摆弄层"的落地形态**（DR-029 C-6 原文"优先级压过摆弄层"）——UI 席。

---

## 末、依赖拓扑与落地批次（对齐纪要 §六 批 0–3）

### 依赖拓扑

```
批 0（立即，零依赖）
  ├─ 真源同步：GDD §6.2/§6.3/§6.4/§7/§8.1/§8.2/§9/§11/§17 + DR-031 追加
  └─ K/m/TOTAL_NODES 数据化（RS-01/02/03）          ← 红线 3，独立可做

批 1（v1.0 P0 · 按依赖拓扑）
  1a RE-01 占槽口径 ──┬─→ RE-02 周报裂缝修复（同批）
                     ├─→ RE-03 破产步序重排（同批）
                     └─→ RE-04 固定运维（同批）
      │
      ├─→ 1d REV-01…05 事件闸（**依赖 1a**：闸的鉴别力依赖 C1）
      ├─→ 1g RU-01…04 呈现层（依赖 1a + 1c）
      │
  1b RP-01 Σeff ──┬─→ RP-02 多人上桌
                  └─→ RP-03/RP-04 max_staff（同批）
      │
      └─→ 1f RR-01…04 竞对死表重标（**等 1b + 1e + 批 2 收入曲线收敛**）

  1c RC-01 买卡命令 ──→ RC-02 买卡入口
     RC-04…07 卡时周预算（**与 1c 同批不可拆**）

  1e RT-02/RT-04 任务池 rp_output 标定 ──→ RK-02 供给标定 + V6 复算
     RS-04 θ/k 通路（零数值） / RS-05/06 饱和护栏
     RK-04 翻雾供给源 cum_influence / RK-03 RP=影响力口径
     RK-06…09 科技树口径收口（D-1/D-3 + 每域可达）
     **1e 的供给标定是 A1 合规的硬前提**

批 2（v1.0 经济）
  RT-01/RT-03 任务收益 + RE-04 固定运维联标 + V1 破产率重标
  **与 1e 互为输入**（任务池参数同时定 income 与 rp_output）

批 3（v1.0 科技树）
  A2 撤销调表（已裁）→ 仅做域计数分母收口（RK-07）+ D-1/D-6 口径修正 + 每域可达校验（RK-08）
  V6/V10 复算 + 同口径蒙卡（M-1）

批 3.5（v1.0 收尾，本任务新增）
  RF-01…04 短单局收尾（依赖 1g + 批 3；**与 RS-05 饱和断言同批**）
```

### 批次表

| 批次 | 内容 | 依赖 | 门禁 | 程序评级 |
|---|---|---|---|---|
| **批 0** | 真源同步 + K/m/TOTAL_NODES 数据化 | — | `verify.sh` 全绿 | 绿 |
| **批 1a** | RE-01…05（收入口径 + 两前置 + 固定运维 + 死参数） | — | GUT + 契约 | **黄** |
| **批 1b** | RP-01…04（Σeff + 多人上桌 + `max_staff`） | — | GUT + 存档往返 | **黄** |
| **批 1c** | RC-01…07（买卡命令 + 卡时周预算，**不可拆**） | — | 契约命令 11→12 | **黄+**（命令面追加） |
| **批 1d** | REV-01…05（事件闸） | 1a | V-sim | **黄** |
| **批 1e** | RK-01…09 + RS-04…06（供给标定 + 口径收口 + 饱和护栏） | 1a | V6/V10 复算 | **黄** |
| **批 1f** | RR-01…04（竞对死表重标） | 1b + 1e + 批 2 | ±15% 带 + 红灯零误报 | **黄**（数值稿） |
| **批 1g** | RU-01…04（呈现层） | 1a + 1c | GUT | **黄** |
| **批 2** | RT-01…05 + V1 破产率重标 | 1a；与 1e 互为输入 | V-sim 复算 | 绿 + 黄 |
| **批 3** | RK-06…08（科技树收口 + 每域可达） | 1e/批 2 | V6/V10 + 蒙卡 | 绿/黄 |
| **批 3.5** | RF-01…04（短单局收尾） | 1g + 批 3 | GUT + `[P]` 试玩 | **黄** |

**门禁说明**：上表"门禁"列最终都落在 `bash scripts/verify.sh`（与 CI 同一命令）——四道：①`gdformat --check` + `gdlint`；②字体二进制门禁（防 LFS 指针）；③`godot --headless --import`（脚本/UID 破损）；④GUT 全量（三重防假绿：退出码 0 + `All tests passed` + `Tests ≥1`）。**流程检查（issue_lint / issue-gate）永不并入 verify.sh**（DR-030 门禁分离原则）。

### 工程动作随行（对齐纪要 §八）

| 变更 | schema | 断言 | GDD 同步 | ADR | 迁移 |
|---|---|---|---|---|---|
| 占槽口径（RE-01） | 无 | V1 破产率重标 + 收入形态断言 | §6.2 | — | 无 |
| 破产步序（RE-03） | 无 | 破产判定含任务收入 | §5.2 管线 + DR-021 B3 修订 | ADR 修订 | 无 |
| 固定运维（RE-04） | `economy.json` 加键 | 周支出断言 | §6.4 | — | 无 |
| 买卡命令（RC-01） | 无（tier 已在档） | 契约命令 11→12 对账 | §6.3 | 修订 DR-026 命令面 | 无 |
| 卡时消费（RC-04） | `economy.json` 加 `weekly_supply` | 周预算重置 + 防双重计费 | §6.3/§9 | — | 无 |
| Σeff + `max_staff`（RP-01/03） | `model_bases.max_staff` 新键（数据表） | Σ 组合断言 + 上桌断言 + 读档还原 | §7 | — | 无（数据表） |
| 事件闸（REV-01/03） | `events.json` 加 `p_week`/`cooldown`/`cooldowns` | 抽卡率 + 收入占比 + 冷却 | §11 | — | 无 |
| 翻雾供给源（RK-04） | 新增累计计数器（开放容器） | 点树不拖慢翻雾 | §8.2 | — | 零迁移 |
| K/m/节点数（RS-01…03） | `benchmarks.json` 新键 | 公式边界向量断言 | §9 | — | 无 |
| 饱和护栏（RS-05/06） | 无 | `test_saturation_first99_week`（新） | §9 | — | 无 |
| 域计数分母（RK-07） | 无 | `test_domain_count_denominator_consistency` | §8.2 | — | 无 |
| 三线计数器（RF-01） | flags 开放容器（`freedom_*`） | 三线累计 + 零态 | §3 | — | 零迁移 |

---

## 附 A：DR 清点矩阵（功能点 → DR 号 → 验收点）

| 功能点 | DR 依据 | 验收点（[T] / [P]） | 程序 | 依赖 |
|---|---|---|---|---|
| **RE-01** 占槽口径 | DR-031/C1 | `test_pulse_sources_disabled_no_roll` / `[P]` 经济压力 | 黄 | — |
| **RE-02** 周报裂缝 | DR-031/C1① + D-11 | `test_weekly_ledger_includes_task_income` | 黄 | 1a |
| **RE-03** 破产步序 | DR-031/C1② + B-2 | `test_bankruptcy_check_after_task_settlement` | 黄 | 1a |
| **RE-04** 固定运维 | DR-031/C3 + GDD §6.4 | `test_weekly_upkeep_expense_bound` | 黄 | 1a |
| **RE-05** 死参数清理 | DR-031/C1 + D-13 | `test_economy_dead_keys_absent_or_flagged` | 绿 | 1a |
| **RT-01** 课题 income | DR-031/C3 | `test_lab_gate_reachable_within_24_weeks` | 绿 | 批 2 |
| **RT-02** 课题 rp_output | DR-031/C3 + §2.8 | `test_grant_task_yields_both_money_and_rp` | 绿 | 1e |
| **RT-03** 复现 income | DR-031/C3 | `test_reproduce_task_not_instant_death` | 绿 | 批 2 |
| **RT-04** 复现 rp_output | DR-031/C3 + §2.9 | `test_task_rp_supply_in_target_band` | 绿 | 1e |
| **RT-05** 任务池内容化 | DR-031/C1③ | `[P]` 钱 vs RP 配比 | 绿/黄 | 批 2 |
| **RP-01** Σeff | DR-031/D1③ + DR-005R | `test_research_eff_sums_all_assigned` | 黄 | 1b |
| **RP-02** 多人上桌 | DR-031/D1③ + DR-029 A-1 | `test_multi_occupant_assign_roundtrip` | 黄 | 1b |
| **RP-03** `max_staff` | DR-031/B2 | `test_training_headcount_bounded_by_base` | 黄 | 1b |
| **RP-04** 上桌校验 | DR-031/B2 + R-5 | `test_min_staff_zero_consumers_grep` | 黄 | 1b |
| **RC-01** 买卡命令 | DR-031/D2 + DR-026 | `test_command_and_signal_contract_accounting` | 黄+ | 1c |
| **RC-02** 买卡入口 | DR-031/D2 + 纪要 §八 | `test_compute_upgrade_command_and_entry` / `[P]` 10 秒可达 | 黄 | 1c |
| **RC-03** 买卡反馈 | DR-015 + 架构稿 §6.4 | 同上 | 黄 | 1c |
| **RC-04** 卡时周预算 | DR-031/D1② + D-10 | `test_weekly_compute_supply_reset` | 黄 | 1c |
| **RC-05** 训练占卡时 | DR-031/D1② + D-14 | `test_training_cost_not_double_charged` | 黄 | 1c |
| **RC-06** 余量不足拒绝 | GDD §6.3 | `test_training_rejected_when_weekly_compute_insufficient` | 黄 | 1c |
| **RC-07** 防双重计费 | DR-031/D1② + D-9 | `test_training_cost_not_double_charged` | 黄 | 1c |
| **REV-01** 命中率门 | DR-031/C2 | `test_event_hit_rate_gate` | 黄 | 1a |
| **REV-02** 单卡上限 | DR-031/C2 | `test_event_card_effect_caps` | 黄 | 1d |
| **REV-03** 冷却/once | DR-031/C2 | `test_event_cooldown_and_once` | 黄 | 1d |
| **REV-04** 总闸/占比 | DR-031/C2 | `test_event_income_share_bound` | 黄 | 1a |
| **REV-05** influence 权重 | DR-031/C2 + B-4 | `test_event_influence_weight_share` | 黄 | 1d |
| **RK-01** RP 唯一来源 | DR-031/§2.9① | `test_rp_supply_source_single_path` | 绿 | 1e |
| **RK-02** 供给标定 | DR-031/§2.9② + A1 | `test_acceptance_point_2_v6_tech_lit_distribution_bounds` | 黄 | 1e |
| **RK-03** RP=影响力 | DR-031/§2.9④ + C-B2 | `test_cum_influence_monotonic_and_persisted` | 绿 | 1e |
| **RK-04** `cum_influence` | DR-031/§2.9④ + D-12 | `test_tech_lit_advance_not_slowed_by_spending` | 黄 | 1e |
| **RK-05** Σrp_cost 不动 | DR-031/A2 | `test_rp_cost_within_redline` | 绿 | 批 3 |
| **RK-05b** 供给锚断言改口径 | DR-031/§2.9（代码实证推翻 12.3k 锚） | `test_acceptance_point_2_v6_tech_lit_distribution_bounds`（改断言） | 绿 | 1e |
| **RK-06** 14 节点口径 | DR-031/D-1 + DR-003 | `test_tech_table_integrity_and_schema` | 绿 | 批 3 |
| **RK-07** 域计数分母 (b) | DR-031/D3② | `test_domain_count_denominator_consistency` | 绿 | 批 3 |
| **RK-08** 每域 ≥1 可达 | DR-031/A2⑥ + M-2 | `test_every_domain_has_reachable_node` | 绿/黄 | 批 3 |
| **RK-09** 单节点 tb 区间 | DR-031/B3 | `test_tech_table_integrity_and_schema` | 记录性（v0.2 复议） | — |
| **RS-01** K 数据化 | DR-031/D-7 + 红线 3 | `test_score_math_no_numeric_literals_grep` | 绿 | 批 0 |
| **RS-02** m 数据化 | DR-031/D-7 | `test_acceptance_point_1_formula_boundary_vectors` | 绿 | 批 0 |
| **RS-03** 节点数数据化 | DR-031/D-7 + D3 | `test_total_nodes_key_not_hardcoded` | 绿 | 批 0 |
| **RS-04** θ/k 通路 | DR-031/D1④ + A3/B1 | `test_acceptance_point_1_formula_boundary_vectors` | 绿 | 1e |
| **RS-05** 饱和断言 | DR-031/B1① | `test_saturation_first99_week` | 黄 | 1e |
| **RS-06** 触发器透明化 | DR-031/B1③ | `test_saturation_trigger_metadata_present` | 绿 | 1e |
| **RU-01** 分级显示 | 架构稿 §6.3④ | `test_score_grade_display_mapping` | 黄 | 1g |
| **RU-02** 净流入预告 | DR-031/D1⑥ | `test_net_inflow_forecast_matches_actual` / `[P]` 5 分钟读懂 | 黄 | 1g |
| **RU-03** 封顶叙事 | DR-031/B1② | `test_saturation_banner_free_period` | 黄 | 1g |
| **RU-04** 三线常显 | DR-029 C-6 | `test_three_line_takes_over_after_saturation` | 黄 | 1g |
| **RR-01** 竞对重标 | DR-031/D2（N11） | `test_rival_scores_within_jitter_band` | 黄 | 1f |
| **RR-02** 标定前提 | 纪要 §三依赖图 | `test_player_can_top_rival_at_reachable_config` | 黄 | 1b+1e+批 2 |
| **RR-03** 扰动带口径 | 架构稿 A-M8 | `test_rival_scores_within_jitter_band` | 绿 | 1f |
| **RR-04** 预警断言 | DR-027④ | `test_acceptance_point_4_warning_thresholds_and_zero_false_alarm` | 绿 | 1f |
| **RF-01** 三线计数器 | DR-029 C-6 + GDD §3 | `test_freedom_three_counters_accumulate` | 黄 | 批 3.5 |
| **RF-02** 三线两阶段可见 | DR-031/B1② + **GDD §2①** | `test_three_line_visible_from_week25` / `test_three_line_takes_over_after_saturation` | 黄 | 批 3.5 |
| **RF-03** 终局收尾屏（六项） | **GDD §2③** + 本任务细化（Q-R3） | `test_endgame_screen_three_lines_present` / `[P]` 一局到底 | 黄 | 批 3.5 |
| **RF-04** 时长守卫 + 后半不空转 | DR-009 + **GDD §18 `[P]`** | `test_single_run_duration_guard` | 绿 | 批 3.5 |

### 覆盖度自查（12 项裁决 → 功能点）

| # | 裁决 | 覆盖功能点 | 状态 |
|---|---|---|---|
| 1 | 收入口径改占槽任务结算（C1 + D-11 + B-2） | RE-01/02/03/04/05 | ✅ |
| 2 | 任务池参数联标（C3） | RT-01/02/03/04/05 + RE-04 | ✅ |
| 3 | Σeff + 多人上桌 + `max_staff`（B2/D1③） | RP-01/02/03/04 | ✅ |
| 4 | 买卡入口 N9（D2） | RC-01/02/03 | ✅ |
| 5 | 卡时消费 N10（D1②） | RC-04/05/06/07 | ✅ |
| 6 | 事件命中率门 + 冷却 + 预算闸（C2） | REV-01/02/03/04/05 | ✅ |
| 7 | RP 供给标定 + 翻雾供给源（§2.9） | RK-01/02/03/04/05 | ✅ |
| 8 | 科技树口径收口（D3） | RK-06/07/08/09 | ✅ |
| 9 | 数据化硬编码（D-7/M-9） | RS-01/02/03 | ✅ |
| 10 | 饱和护栏 + 呈现层（B1） | RS-04/05/06 + RU-01/02/03/04 | ✅ |
| 11 | 竞对死表重标（N11） | RR-01/02/03/04 | ✅ |
| 12 | 短单局体验收尾（本任务新增） | RF-01/02/03/04 + §0.2/§0.3 | ✅ |

---

## 附 B：v1.0 **不做清单**（对齐纪要 D1"明确移出"+ 复议队列 9 项）

### B.1 纪要 D1"明确移出"（11 项，**v1.0 不做**）

| # | 项 | 移出理由 | 归属 |
|---|---|---|---|
| 1 | 轨 3 供料链（任务→训练配方语料） | 依赖 E1（任务槽挂人），而 E1 = N6 待双签 | v0.2 |
| 2 | 形态 A–D（炼丹火候/开源闭源/对齐税/拒稿） | 与死表纪律冲突或触碰 B5 | v0.2 / 复议 |
| 3 | 命名权 ①②④（竞对点名/押名造势/谱系图鉴） | 非核心闭环 | v0.2 |
| 4 | 世界时钟条 | 与 V1-04 并案，[提案·待拍板] | 待拍板 |
| 5 | 员工实体卡 | V1-03，PR-γ 承载（本任务不纳入 v1.0 必落） | v0.1.x 修复链 |
| 6 | 图鉴解锁格 | N13：v1.0 只留**零数值收益最小一格**（成就/称谓） | v1.0 最小 / v0.2 深化 |
| 7 | 破产软着陆 | N14：v0.2 候选；v1.0 维持 Game Over 短路 | v0.2 |
| 8 | 决策卡超时 | 复议队列第 6 项 | 待试玩 |
| 9 | 迷雾扩树触发器（**扩树本身**） | N15：v1.0 只写**可判定触发条件**，扩树 v0.2 | v0.2 |
| 10 | 假 arXiv 句式扩容 | 复议队列第 7 项 | 待试玩 |
| 11 | **θ/k 阶段化数值** | DR-031/A3·B1：v1.0 只落阶段 1（θ95/k13 不动） | v0.2 |

### B.2 复议队列（纪要 §五，9 项，**未齐材料不动工**）

| 序 | 复议项 | 触碰裁决 | 阻塞什么 | v1.0 处置 |
|---|---|---|---|---|
| 1 | N6 多任务槽（**[change] 双签**） | DR-023 / ST4 | E1 / 规划决策空心 | **不动**（材料已齐，待双签） |
| 2 | Σeff 落地 + 多人上桌 | DR-005R 实现落差 | ①⑤ 前提 | **已裁为 v1.0 P0**（§3） |
| 3 | θ/k 阶段化 + A 上限 | DR-027③ | C1 参数组 | v0.2（A 上限已由 `max_staff` 落 v1.0） |
| 4 | V6 口径切换（绝对→占比） | DR-027⑤ | v0.2 扩树 | v0.2 |
| 5 | 影响力出口（形态 C 等） | DR-006 / DR-022⑩ | 内容形态 C | 待试玩 |
| 6 | 决策卡超时默认 | DR-012 / DR-022① | 碎片体验 | 待试玩 |
| 7 | 术语/展示名（GKP/璞石·洗尘/权重流出/假 arXiv 句式） | DR-022④ / DR-029 F | 文案批 | 待试玩 |
| 8 | 竞对时间线对齐真实史（T2/T4） | DR-027④ | N12 | 待试玩 |
| 9 | DR-005R 的"31k 供需上限"是否上调 | DR-005R | A2 的 v0.2 部分 | v0.2 |

### B.3 长线推迟 v2.0（制作人本次裁决）

| 项 | 说明 |
|---|---|
| **10h+ 长线体验** | 现状 ~27 分钟 vs 目标 600 分钟 = **22 倍差距**（纪要 E5）→ v2.0 |
| **多周目 / 周目三件套** | 开罗老炮画像"继承只继承知道不继承能"；开局选路线=红级 | v2.0 |
| **18 节点扩树** | 需先定 7 节点清单（Q9）；Σrp_cost 与 31k 上限关系（Q10） | v0.2/v2.0 |
| **远期 22 节点** | 不承诺（科技树稿自评"性价比骤降"） | — |
| **Σtb 上限调整（≤0.92）** | DR-031/B3 明确否决；Σtb 冻结 1.40 | — |
| **m×q 档差压缩（MJ-8）** | v0.2 数值候选，与 θ/k 阶段化同批复议 | v0.2 |
| **知识轴边际收益（R-1）** | 未裁；候选解法 C（知识给非分数收益） | v0.2 |

---

## 附 C：待制作人拍板的四个新问题（本任务发现）

> 以下四项均为**本文撰写过程中实证发现、DR-031 未覆盖、且阻塞 v1.0 收尾**的问题。按"未裁不开工"纪律，需制作人拍板后方可建 issue。

### Q-R1：**任务结算与破产判定的"顺序"是否允许"先结算再判破产"的语义反转？**

- **背景**：RE-03 的修法有两条路——(a) 把任务结算**并入收支步**（步序 1）；(b) 把破产短路**后移**到任务结算之后。两条路在"周报收支行闭合"上等价，但**语义不同**：(a) 意味着"收支"的定义从"工资+脉冲"扩展为"工资+运维+任务结算"； (b) 意味着"破产判定"不再"写死在收支后"（**修订 DR-021 B3 契约**）。
- **为什么要拍板**：DR-021 B3 是**已裁契约**（"判定写死在收支后"），改它属于**契约修订**，不是纯实现选择。
- **选项**：(a) 改"收支"定义（保守，DR-021 B3 字面保留）/ (b) 后移判定（更贴直觉，需修订 DR-021 B3）/ (c) 两者都做。
- **本席倾向**：**(a)**——"收支"本来就是"本周所有 money 过账"，任务结算本就是收支的一部分；这样 DR-021 B3 字面不变，只需在 GDD §5.2 补一句"收支含占槽任务结算"。

### Q-R2：**卡时"每周预算"与"容量上限"在 UI 上如何共处？玩家会不会困惑？**

- **背景**：GDD §6.3 明确两概念并存分键：①**每周供给 `~8/16/32/64`**（训练门槛）②**容量上限 `~40/80/160/320`**（余量上限）。现状 `ComputeLabel` 只显示"算力: N卡时"（`main.gd:430`），**玩家无法区分这是预算还是容量**。
- **为什么要拍板**：C1（占槽口径）+ N10（卡时消费）落地后，"算力"这一资源栏数字的含义**会变**（从"余额"变"本周预算"），这直接影响玩家对"买卡值不值"的判断。若呈现不清，N9（买卡入口）的价值会被误解。
- **选项**：(a) 资源栏只显**每周预算**（"本周卡时 ~16/16"），容量移到 tooltip / (b) 双值并列（"~16/16 · 上限 ~80"）/ (c) 保持单值但加图标区分。
- **本席倾向**：**(a)**——玩家关心的是"这周够不够训练"，容量是隐性上限；竖屏空间也不允许双值。

### Q-R3：**终局收尾屏（RF-03）的触发与形态——它是否替代破产 Game Over 卡？**

- **背景**：现状**只有破产 Game Over**（`game_over_dialog.gd`），**正常走完 160 周没有任何终局屏**——玩家会在 W160 后"继续玩"或"不知道结束了"。而制作人本次的成功标准明确要求"**有收尾**"。
- **为什么要拍板**：这涉及三处未裁边界——①**触发**：W160 自动弹？玩家手动点"结算"？还是"到 W160 显示提示，玩家随时可结算"？②**形态**：终局屏是否替代破产 Game Over 卡，还是两套并存（破产=灰屏+年报，DR-029 §9.6；正常终局=金框三线）？③**走完 160 周后**：游戏是"冻结"（不能再玩）还是"自由期无限延续"（可继续刷三线）？
- **本席倾向**：**①W160 自动弹 + 玩家可"继续自由期"**（不强制结束，尊重"想再玩一会"）；**②两套并存**（破产=灰屏+年报；正常终局=金框三线+关键决策回溯）；**③自由期无限延续**（三线可继续刷，但不新增系统——"守住"本身就是目标）。

### Q-R4：**三线的两个时点（W25 常显 vs W54 接管）是否会造成"目标提前泄压"？**

- **背景**：GDD §2① 明确"自由期三线**提前到 W25**"，而 DR-031/B1② 的封顶叙事发生在 **W54**。两者并存意味着：**W25–W54 这 ~5 分钟里，三线已经在动，但分数还在涨**。玩家可能产生两种反应——(a) "我知道后面还有东西可追"（正向）；(b) "既然三线才是真目标，分数就不重要了"（泄压，伤害 W25–W54 的冲刺快感）。
- **为什么要拍板**：这决定 W25–W54 段的**情绪峰值是否被稀释**（§0.2 分段表里 S3 跃迁段的峰顶）。若泄压成立，S3 的"首次霸榜"高潮会被三线分走注意力。
- **选项**：(a) 维持 GDD 现状（W25 三线常显，但**弱化呈现**——只在小字区，不进入主视觉）；(b) W25 只显示"三线已就绪"的**一次提示**，实际常显仍从 W54 开始（与 DR-031/B1 一致）；(c) 完全按 W25 常显（接受泄压）。
- **本席倾向**：**(a)**——W25 三线常显但**放在资源栏副行小字区**（与"净流入预告"同区），**不占主视觉**；W54 封顶后才升到主权重。这样既兑现 GDD §2① 的"提前"，又保住 S3 的冲刺快感。**需制作人确认这是否算"兑现了提前到 W25"**。

---

## 附 D：本文自检表

| 自检项 | 结果 | 说明 |
|---|---|---|
| **12 项裁决是否全覆盖** | ✅ | 见附 A 覆盖度自查表，12/12 均有功能点承载 |
| **验收点是否 ≥3 / 模块** | ✅ | 11 个模块，每模块 `[T]` ≥4 + `[P]` ≥1（最低为 §3：4 [T] + 1 [P]） |
| **每个功能点是否有出处** | ✅ | 附 A 逐行标注 DR 号 / GDD 行 / 代码路径:行号 / 试玩反馈 |
| **是否有未标 `~` 的硬数值** | ✅ | 唯一"实数"均为**实算证据**（如 Σrp_cost=14210、Σtb=1.4000、成本累计 300/660/…）与**已裁不动值**（如破产线 -200k、买卡价、gate 250k）；全部**目标值/新值**均为 `~` 占位 |
| **[T] 是否真实可写** | ✅ | 全部对照 `tests/` 现有命名风格（`test_<module>_<behavior>` / `test_acceptance_point_N_<desc>`）；DR-031 点名的 8 个新用例名**逐字沿用**（见下） |
| **[P] 是否三段式** | ✅ | 每条含"步骤脚本 + 预期感受 + 代理指标" |
| **是否只产出文档** | ✅ | 本文为唯一产出；未改代码、未建 issue、未改 GDD/decision-log。**注**：`docs/gdd/gdd.md` / `decision-log.md` / `README.md` 在本任务期间被**并发会话**更新（GDD §2 已写入"单局目标形态 DR-031/§十二"），本文已按其口径对齐（§0.3 两时点、RR-01 的 L4 ~96–98 分、RF-03 六项 summary） |

**DR-031 点名断言（逐字沿用，不得重命名）**：
`test_saturation_first99_week` / `test_training_headcount_bounded_by_base` / `test_training_cost_not_double_charged` / `test_weekly_compute_supply_reset` / `test_weekly_ledger_includes_task_income` / `test_event_hit_rate_gate` / `test_event_income_share_bound` / `test_rp_cost_within_redline` / `test_domain_count_denominator_consistency`（GDD §18 冻结清单）。

**已存在可复用的用例（扩展不新建）**：
`test_command_and_signal_contract_accounting` / `test_acceptance_point_1_formula_boundary_vectors` / `test_acceptance_point_2_v6_tech_lit_distribution_bounds` / `test_acceptance_point_4_warning_thresholds_and_zero_false_alarm` / `test_tech_table_integrity_and_schema` / `test_rp_cost_and_threshold_alert_band` / `test_research_eff_and_dr005r_aggregate` / `test_compute_upgrade_and_capacity_refusal`（均在 `tests/unit/` 实测存在）。

**必须在同批改动的既有断言（否则新裁决与旧断言互斥）**：
`tests/unit/test_assertion_bounds.gd:34` 的 `supply_anchor_rp == 12300`（"三阶段占比口径"）——该供给锚已被代码实证推翻（无产出通路）→ 随 RK-02 改为任务口径供给带 `[4910, 6810)`。
`tests/unit/test_economy.gd:80–87` 的 `duration_min/max` 断言——随 RE-05 一并处置（死参数退役）。

**核验结论（代码实证，子代理独立采集）**：DR-031/GDD §18 点名的 **8 个新断言在 `tests/` 中全部不存在**（`test_saturation_first99_week` / `test_training_headcount_bounded_by_base` / `test_training_cost_not_double_charged` / `test_weekly_compute_supply_reset` / `test_weekly_ledger_includes_task_income` / `test_event_hit_rate_gate` / `test_event_income_share_bound` / `test_rp_cost_within_redline` / `test_domain_count_denominator_consistency` 均零命中）；现有测试函数总数 **178**。
