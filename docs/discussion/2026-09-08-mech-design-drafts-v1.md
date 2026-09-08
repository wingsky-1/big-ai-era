# 机制设计稿 v1：多任务槽 + 周目继承细节（主策划席 · 2026-09-08）

> 性质：机制空白处先行设计稿两份（均未裁不动工）；数值全部 ~ 占位 + src/data 键名；禁重开 DR；输入抽象不落具体按键。
> 编号口径：多任务槽=缺口 N6（【change】，制作人 2026-09-08-version-boundary-proposal.md §2.2）；周目继承=D-4 前置（批 3 地基）。

---

## 设计稿 1【多任务槽】（缺口 N6）——轻度复议正门材料（circuit-breaker.md §5），未裁不动工

> 针对"仅稿面裁决"的 ST4 单任务槽（DR-023/ST4）提轻度复议：试玩证据 = v0.1.3 反馈④a 原话"一个任务只能指派一个人？"（docs/playtest/2026-09-08-v013-feedback.md 分诊④a：设计如此（非 bug），机制改动走轻度复议）；一次一议、黄级流程、待圆桌裁决；规格草稿占位见 docs/discussion/2026-09-08-gap-issue-specs-v1.md §N6（双签+裁决前不建）。

### 目的

玩家视角：闲下来的研究员不再干看着——我能让几条任务线并行推进，实验室像"同时在忙好几件事"的地方，而不是所有人挤在唯一岗位上互相看。

### 规则（可验证伪代码级，数值全部 ~ 占位）

```
SLOTS    = data.tasks.max_active_slots   # ~3 占位（数值席标定；最小切片版 =1 即现状）
AUTOFILL = data.tasks.autofill_default   # true（默认开，宪法兼容关键；试玩可关）

assign_staff(staff_id, slot_idx):
  require slot_idx < SLOTS 且 active[slot_idx] == EMPTY   # 槽满/非法槽位 → 拒绝
  require staff.assigned == NONE                          # 一人一岗：已占任一槽或训练位 → 拒绝
  active[slot_idx] = {task_id: queue.pop_front(), staff_id}
  emit resources_changed                                  # 0.5s内槽与员工卡双刷新（④b 教训）

on_task_done(slot_idx):                                   # 现状=Game Over 短路后独立段结算（game_world.gd task_settle 段，经对抗评审 m10 核正）；并入第 3 步=黄级改动随圆桌裁
  结算 task.rp_output / task.income（经 apply_delta 唯一过账口）
  if AUTOFILL 且 queue 非空: active[slot_idx] = queue.pop_front()
  else: active[slot_idx] = EMPTY                          # 空槽=可见空态，不静默
```

任务槽（task slots）：1–~SLOTS 个，每槽挂 1 任务 + 1 名研究员，产出 rp/收入。**任务槽 ≠ 训练位**：训练位恒 1、独立于任务槽，挂基座 + 上桌人选，出分用 `research_eff = Σ已分配研究力`（DR-005R）；上桌训练 = 先从任务槽 unassign（一人一岗，人力稀缺张力保住）。输入抽象：指派 = 用户选中员工实体卡 → 选中目标槽（虚拟 Action：action_primary 选卡/选槽，禁落具体键位）。

### 边界

- 0 槽/未解锁：任务入口整体置灰 + 原因可查；槽满：assign 拒绝且禁止态提示；0 空闲员工：拒绝；空槽空队：保持可见空态。
- 存档：savegame.tasks.active 由单对象 `{task_id, weeks_left}` 复数化为数组 = 破坏性变更，走 SaveMigrator 单步迁移 + 单测，旧档读回进度不丢；tasks.json 加配置键属数据文件结构（schema v1 外，绿）。
- **跨槽 research_eff：任务槽不存在 eff 求和点**——eff 唯一求和点 = 训练位（DR-005R 通路 R1(a) 唯一 Σ），任务产出 = task 定值结算不乘 eff，防出现第二个求和点稀释 DR-005R 语义（与 DR-005R 口径相容的核心保证）。

### 相容性自检

- **DR-018 A15 超分配拒绝**：A15 = `weekly_card_hours ≤ tier_supply`（算力域检查），多任务槽不触碰算力模型；DR-018 演进预留"随多任务槽竞争恢复"指排期凑批非逻辑耦合，两机制不互为前置。
- **DR-009 节奏宪法（有效决策 1–3 次/30s，峰值 ≤6）**：相容关键 = autofill 默认开——被动流程 0 决策/30s（槽空自动补，玩家不干预照转）；玩家优化干预（换任务/换人）~1–2 次/30s，落在红线内；峰值场景（多槽同帧完成+出分）瞬时待办 ~3 项 < 6 峰值上限；超线时先调 SLOTS 与提示强度（数值可调、结构不改）。
- **ST5 排队预填**：由"任务完成自动顶入队首"推广为"空槽自动顶入"，语义同源不冲突；**DR-007 周结管线**：现状任务结算=Game Over 短路后、effects 消费前的独立段（紧邻第 3 步；经对抗评审 m10 修正原稿"挂第 3 步"表述）；正式并入第 3 步=插步黄级（须保 RNG 顺序稳定，随 N6 裁决一并评审），默认不动管线顺序。

### 数据表与存档增量清单

tasks.json 新增键 max_active_slots（~3，带区间注释，出处纪律 DR-029 C-4）/ autofill_default（bool）；savegame.tasks.active 复数化（SaveMigrator 单步迁移，进度字段语义不变）；员工数据结构 assigned 字段改 NONE|slot_id|training 三值（经对抗评审 m10 核正：现实现=slot_id 字符串非布尔；迁移=枚举语义收窄，同批迁移单测）。

### 切片建议（交制作人裁）

最小可试玩版本 = **2 槽**：1→2 的并行体感已成立、指派频次增量最低、试玩风险最小；3 槽等 2 槽试玩数据再上。同 PR 必带：迁移单测 + 槽/员工卡禁用态（防"指派没反应"复发）。GDD 同步预填（裁决通过后随 PR 改）：§7 "单任务槽+单训练位"（ST4）改"~SLOTS 任务槽+单训练位"、§12 schema tasks.active 结构、§15 不进清单"算力超分配"行解挂说明。

### 转 GUT 验收句草案

- 正常：assign 至空槽成功 → resources_changed 发射，槽与员工卡状态 0.5s内双刷新（test_task_slot_assign_dual_refresh）；
- 边界：槽满/无空闲员工 assign 拒绝且禁止态可辨；autofill 关时完成任务后槽保持空态（test_task_slot_reject_and_empty_state）；
- 终态：autofill 开时空槽自动顶入队首任务；旧档单对象 active 经迁移读回进度不丢（test_task_slot_autofill_and_migrate）；
- [P]：并行感——同屏至少两条线各自走进度（代理指标：10 分钟窗口主动干预 ≤~12 次，不疲于点头）。

---

## 设计稿 2【周目继承细节】——D-4 前置，v2.0 周目三件套真身的地基

> 范围红线：本稿只做批 3 地基（meta.cfg 通道字段清单 + 触发时序 + 边界）；"周目三件套真身"（开局选路线等结构性改动）= v2.0 红级专项储备（GDD §16），不越界；往年卷字段清单属开放问题 Q6，本稿只列候选不裁。

### 继承什么（meta.cfg 通道逐字段清单）

| 字段 | 类型 | 写入时机 | 读回消费方 |
|---|---|---|---|
| meta.v | int | 每次写入 | meta 自身兼容键（占位预留） |
| meta.run_count | int ≥0 | 局终态归档时 +1 | start_new_game → 教学豁免判定/开局气泡 |
| meta.tutorial_exempt | bool | 归档时置 true（=run_count≥1 显式落盘，利于测试） | 引导系统跳过 step 教学 |
| meta.dex{} | 开放容器 | 收集即时合入（图鉴先于通关成立） | 图鉴面板（N2 数据/批 2 UI） |
| meta.past_runs[] | 通关摘要数组 | 局终态归档时追加 | 博导手记·往年卷（只读） |

past_runs[] 单条候选字段（Q6 待锁）：week_total / sota_count / best_score / rival_l1_week / first_crown_week / top_hold_weeks / lit_count_end / cum_income_end。

### 不继承什么（红线）

- **savegame 全量禁跨局**：resources/techs/tasks/staff/training/rivals/events/sota/flags 一律不进 meta.cfg——meta 只收"跨局有意义"的最小集，局内态进 meta = 设计违约；
- root_seed 与 rng{} 计数器不继承（新周目新 seed，确定性验收从零起跑）；
- 员工名册不继承（招人的新鲜感是局内资产）；术语首次提示不继承（教学豁免 ≠ 术语豁免，DR-022③ 一次性文本）。

### 触发时序（通关 → 归档 → 新周目注入）

局终态两条通路**都归档**（否则"不破产就永无往年卷"）：

1. game_over 短路（破产）→ 终局档 → 归档 meta（run_count+1、past_runs 追加、dex 合入）；
2. 玩家主动重开（暂停菜单重开）→ 归档同上 → start_new_game 注入。**归档资格口径（经对抗评审 M5 补，待拍板）**：主动重开无 game_over summary——归档收窄为 dex 合入+run_count+1，past_runs 不追加完整摘要（或仅记 abandoned 占位行），防"差局反复重开刷往年卷"；该口径扩展 DR-020 暂停菜单重开语义，随开放问题裁决。

新周目：start_new_game 读 meta → 置 run_count/tutorial_exempt 全局态；past_runs 不进局内档，UI 层只读加载——往年卷是"手记"不是存档。

### meta 写入与兼容协议

写入走 SaveSystem 同级双缓冲（tmp→校验→换名+.bak），meta 与 savegame 是两个独立文件互不嵌套；meta.v 占位 = 兼容键，字段集冻结前不锁 schema（图鉴容器开放键零迁移）；归档幂等 = 同一局终态重复触发只计一次（run_count 防重入断言）。

### 边界

- 首局：run_count=0 → past_runs=[]，往年卷入口置灰/隐藏（UI 席定），教学不豁免；
- meta.cfg 损坏：双缓冲同级处理，.bak 亦坏 → 重置空 meta 不崩（参照 SaveMigrator 坏档回退单测模式）；meta 损坏重置只清 meta 不碰 savegame——局内进度永不因 meta 问题丢失（单向隔离红线）；
- 图鉴半解锁跨版本兼容：meta.dex 开放容器新条目加键零迁移，旧 meta 缺键 = 按未收集处理（shell fill）；
- 归档失败不阻断局终态主流程（game_over 照走，归档可重试并提示）。

### 与 DR-029 相容性

D-4"二周目送'博导手记·往年卷'（meta.cfg 承载）" = 本稿直接细化，无改判；E-1 猫 = 零状态版 → meta 不承载猫状态；收集图鉴专项"meta.cfg+flags 容器 = 绿" = meta.dex 依据；玄冬年报"周目继承"（F-5）消费本通道，归档字段另议不在此裁。GDD 同步预填（落地 PR 时改）：§12 存档增 meta.cfg 文件级条目、§13 归来摘要行挂"往年卷只读"注、Q6 关闭路径 = 往年卷字段候选清单移交本表。

### 验收句草案（GUT 可翻）

- 正常：game_over 后 meta.run_count 增 1、past_runs 追加含 week_total 摘要、已收集图鉴键不丢（test_meta_archive_on_run_end）；
- 边界：坏 meta 注入 → .bak 回退 → 空 meta 兜底全程不崩（test_meta_corrupt_fallback）；首局 tutorial_exempt=false（test_first_run_no_exempt）；
- 终态：二周目 start_new_game 后 tutorial_exempt=true、往年卷条目可读、局内态全新 seed 重掷（test_new_run_injects_exempt_and_fresh_state）；
- [P]：二周目开局 10 秒内"这是第二局"可感知且无重复教学（代理指标：开局到首次指派 ≤~10s，零 step 教学弹泡）。

### 开放问题登记

遵守 GDD §17"新增未决项必须登记"：本稿新增 2 项待登记（GDD §17）——①"主动重开是否先经暂停菜单确认弹层"（主程序/UI 联合确认；倾向：确认弹层属暂停菜单既有交互不算新阻塞，与 DR-020 z2 白名单相容）；②"主动重开归档资格口径"（经对抗评审 M5 新增：仅 dex+run_count，past_runs 不追加完整摘要；与①同场裁决）。

## 【下游省工自问】

数值席：SLOTS/AUTOFILL 两键带区间标定即可开工，无需等全参数表；主程序：稿 1 已预判 SaveMigrator 迁移点与信号断言点、稿 2 已给字段表/写入协议/双通路归档时序，实施不必重推时序争议；UI 席：槽禁用态/空态/员工卡高亮已挂进验收句，输入抽象已给（选卡→选槽），映射表行可在规格评审时同步产出；制作人：稿 1（N6）裁决只需答"2 槽切片要不要双签进批 1"一个二选一，稿 2 只需在 Q6 锁字段清单——决策面已压到最小。
