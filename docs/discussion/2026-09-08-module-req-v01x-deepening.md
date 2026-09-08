# 卷一：v0.1.x 深化模块需求文档（主策划席 · 2026-09-08）

> **性质**：模块化需求文档（设计产物，非裁决）。按模块聚合 **v0.1.x 深化闭环**内容并细化到实施零猜测；姊妹卷 `docs/discussion/2026-09-08-module-req-v020-batches.md`（v0.2 批次卷，21 条）已交付，两卷引用同一批规格真源（缺口规格 N1–N8 / UI 规格 V1-01…V1-17 / 映射表行 / 修复链 PR-α/β/γ/δ），不重写不实锁，防分叉。
> **纪律**：不发明任何新裁决、不重开 DR、不改范围；数值全部 `~` 占位照抄禁实锁；已有 [T]/[P] 验收**直接带 GUT 用例名/scripts 锚原样引用，不重命名**；功能点全部有出处（试玩反馈①②③④ / 缺口 N / PR 修复链 / 闭单缺项 / DR 演进预留 / 代码内演进注释），无出处宁可不写并列入【疑点上报】。
> **真源边界（已定稿口径，两轮对抗评审修订，本卷全文遵守）**：
> 1. V1-13 危机卡：**无倒计时条/无"已错过"态**（DR-012 周结前强制选择）；"危机 30 秒"=DR-028 三刀①试玩代理指标，仅存于 [P] 项；
> 2. V1-04 常显标识"层级高于遮罩"=**增强非冲突**，标 [提案·待拍板]；
> 3. 多任务槽=缺口 N6【change】未双签：**只标占位引用设计稿 1**（docs/discussion/2026-09-08-mech-design-drafts-v1.md 设计稿 1），不写规格不实锁；任务槽结算现状=**Game Over 短路后独立段**（game_world.gd 实证），"并入周结第 3 步"=黄级改动随圆桌裁；
> 4. 设计稿 2 主动重开归档口径=**仅 dex 合入+run_count+1，past_runs 不追加完整摘要**（待拍板开放问题②【设计稿 2 登记】）；
> 5. 文档类产出验收标注=**"校验脚本名"非"GUT 用例名"**；
> 6. N 编号：N1 归来摘要+引导气泡 / N2 图鉴清单+IA / N3 C-6 三线计数器 / N4 吐槽键 / N5 G-2 抢发文案 / N6 多任务槽【change】/ N7 常显态+员工实体卡 / N8 scripts.md；
> 7. PR-α（对账断言+键名常量化）/ PR-β（issue_lint，先于建号）/ PR-γ（selftest+信标+常显态，承载 N7）/ PR-δ（#67）；
> 8. [P] 锚占位沿用各稿现状（`docs/playtest/scripts.md` 未建，N8 建档时统一映射替换）。

## 〇、卷首

### 0.1 版本定位

**本卷 = v0.1.x 深化闭环**：修复链 PR-α/β/γ/δ + 表达层补齐 N3/N4/N7 + 漏译缺口 N1/N2/N5/N8——引版本边界提案 §1.2"把 v0.2 三批全部承诺项 + 绿/黄级储备项 + 规格漏译缺口补齐（N1–N8）收拢进同一个发布里程碑，以'可发布、可玩、好玩'为门槛正式对外"与 §二"修复链是门槛件而非内容件；N7/N8 借修复链顺路落位"。**叠加卷二（v0.2 三批 21 条）后达 v1.0 门槛**（DR-016 总纲 + 三刀 + 5 分钟试玩 + 四画像真人对标 + verify 全绿，边界提案 §1.2 门槛表）。两卷分工：卷一管 **v0.1.x 存量（已发 v0.1.0→v0.1.3）的修复与表达补齐**，卷二管 **v0.2 三批已裁内容**；N6 多任务槽【change】未双签，两卷均只占位不写规格。

**修复链归属说明**：PR-β（issue-gate check + issue_lint.sh）为流程硬件（CI 独立 check，DR-030"流程门禁与 verify.sh 永久分离"），不落任何游戏模块，归卷首统一登记；其时序硬约束=**先于 N1–N5/N7/N8 建号上线**（边界提案 §2.3"时序细节：lint 卡口先行"，动作序列尾注 ⓪①②）。

### 0.2 模块总览表

| 模块 | GDD 章 | 代码落点（实证） | 深化点数 | 承载编号 |
|---|---|---|---|---|
| 1 时间与驱动 | §5 | src/entities/game_clock.gd、src/ui/game_loop_driver.gd、src/systems/rng/rng_stream.gd、game_world.gd settle_week 段 | 2 | PR-α（拆点）；疑点 S2-01 |
| 2 经济与算力 | §6 | src/entities/economy.gd、src/data/economy.json、assertion_bounds.json、assertion_ranges.json、opening.json | 2 | PR-α 同批（债收口，工程裁量） |
| 3 人员与任务 | §7 | src/entities/staff_roster.gd、task_queue.gd、training_project.gd、src/data/tasks.json、staff.json、game_world.gd 任务结算段 | 2 | N6【change】占位 + PR-α（拆点） |
| 4 科技树与迷雾 | §8 | src/entities/tech_fog.gd、tech_tree.gd、src/data/techs.json、src/systems/data/predicate_registry.gd | 3 | Q3/Q4 复核（登记册引用，不代裁）+扩树触发器监控（DR-027①）；疑点 S2-02 |
| 5 训练与 SOTA | §9 | src/entities/training_project.gd、sota_board.gd、src/core/score_math.gd、src/data/model_bases.json、benchmarks.json | 3 | 命名仪式闭单缺项（随 PR-α 暴露→修复单）；SOTA 次数闭单缺项；N3（数据侧拆点） |
| 6 竞对 | §10 | src/entities/rival_track.gd、src/data/rivals.json、event_engine.gd 外溢段 | 1 | N5（整卡承载） |
| 7 事件 | §11 | src/entities/event_engine.gd、src/data/events.json、panel_stack.gd toast 段 | 2 | PR-α（拆点）+周报字段集兑现；疑点 S2-04/S2-07 |
| 8 存档 | §12 | src/systems/save/save_system.gd、save_migrator.gd、src/entities/snapshot_codec.gd | 2 | #16 闭单缺项（第二保险挂点）；N1（数据侧拆点） |
| 9 界面与交互 | §13 | src/ui/panel_stack.gd、main.gd、main.tscn、dashboard_presenter.gd、game_loop_driver.gd、responsive_layout_manager.gd | 5 | PR-δ（#67）+ PR-γ（N7+selftest 信标）+ R3 拆点 |
| 10 引导与文案 | §14 | src/systems/text/text_service.gd、formatter.gd、src/data/texts.json、sensitive_words.json、main.gd INTRO | 5 | N1 + N4 + N8 + 反馈①复议登记 + 术语提示机制点 |

**合计 27 个功能点**（D1-01-01…D1-10-05）；PR-β 为流程件不入模块（§0.1 说明）。

### 0.3 两卷编号衔接（防混用）

| 事项 | 卷一（本卷）落位 | 卷二落位 | 口径一致性 |
|---|---|---|---|
| N1 归来摘要+引导气泡 | 模块 10（GDD §13 引导节/§14 文案管线归属） | 其模块 5（D 组同源聚合层安排，其模块 5 节首有落位说明） | **引用同一规格 §N1 与同一红线真源 DR-029 D-2，零分叉**；落位差异=各自模块方案的聚合层安排，对账表双标注 |
| N2 图鉴内容清单+IA | 卷一不重复展开（N2 是 #37/#42 的前置稿，属 v0.2 批次内容，卷二 D2-05-01 整卡承载） | 其模块 5 | 卷一仅在模块 10 文案管线行提及依赖，不复制内容 |
| N5 抢发文案+传闻窗口 | 模块 6（GDD §10 竞对归属）整卡承载 | 其模块 3（#40 实现主体引用 N5） | 同一规格 §N5 + m9 同源互引禁双写纪律一致 |
| N6 多任务槽 | 模块 3 占位（【change】） | 零功能点（其脚注 1） | 一致：双签前不出现在任何批次 |
| #34/#39/#43 等 v0.2 批次项 | 卷一不含（非 v0.1.x 深化范围） | 卷二承载 | 版本边界提案 §2.1 收拢表为准 |

### 0.4 已定稿口径遵守速查（真源边界 1–8 → 本卷落点，写作自检留痕）

| # | 已定稿口径 | 本卷落点（功能点/节） | 遵守方式 |
|---|---|---|---|
| 1 | V1-13 无倒计时/无"已错过"态；"危机 30 秒"=三刀①代理指标仅存 [P] | 本卷无危机卡载体（属卷二 #31/D2-01-05） | 不在边界态复述倒计时语义；对账表标注"两卷口径一致" |
| 2 | V1-04"层级高于遮罩"=增强非冲突，[提案·待拍板] | D1-09-02 规则细化行 | 原样标注 [提案·待拍板] 不代裁，拍板权制作人/UI 席 |
| 3 | N6 只占位引用设计稿 1；结算现状=短路后独立段，"并入第 3 步"=黄级随圆桌裁 | D1-03-01 | 零规格零槽数实锁；独立段现状实证（game_world.gd :479–491）写入现状行 |
| 4 | 设计稿 2 主动重开归档=仅 dex+run_count，past_runs 不追加 | D1-09-01 规则细化行 | 粗体引原文+标注待拍板开放问题②【设计稿 2 登记】；meta 通道未建前重开暂不归档 |
| 5 | 文档类验收标注="校验脚本名" | D1-10-03 规格行 | N8 三条全部标"校验脚本名"，CI 独立 check 口径 |
| 6 | N 编号固定（N1–N8） | 全文 | 编号与边界提案 §2.2 逐一对齐，无自造编号 |
| 7 | PR-α/β/γ/δ 内容口径 | §0.1+D1-01-01/03-02/07-01/08-01/09-01…05 | 四单内容照圆桌纪要 §四原文，不扩范围 |
| 8 | [P] 锚占位沿用各稿现状（scripts.md 未建） | D1-10-03+全部 N 系引用行 | 保留 docs/playtest/scripts.md#N* 占位，不发明 slug，N8 建档统一映射 |

---

## 模块 1：时间与驱动（GDD §5 ｜ 代码落点 src/entities/game_clock.gd · src/ui/game_loop_driver.gd · src/systems/rng/rng_stream.gd · game_world.gd settle_week 段）

**v0.1.x 现状**：已实现——模拟/视图驱动分离（Δt→clock_math 累积满刻 tick）、暂停双源（user_paused OR blocked_by_card）、变速 1x/2x/4x（View 系数）、只在场才流淌（visible_gate 停喂）、带卡不结周、周结管线 11 步全序（Game Over 短路写死收支后）、RNG 三域分域计数器入档、万周模拟同 seed 哈希一致断言（test_game_world.gd）。已知缺陷/体验债——①收入脉冲随机源内联于 settle_week（`RandomNumberGenerator.new()`+`_income_roll_seed` 播种，代码注释自认"PR7 换 rng_stream"未兑现，见疑点 S2-01）；②指令/信号面无对账常量基线（get_clock/set_speed 等游离方法未入 COMMANDS 封闭集合核查清单，DR-030 对账断言无锚可挂）。

### D1-01-01 时域指令/信号面对账常量化（PR-α 拆点）
- **功能点**：把时钟域公开方法（start_new_game/set_paused/set_speed/get_clock/simulate_weeks/request_save 等）与信号面对齐进 COMMANDS 单点常量，给 PR-α 对账断言提供封闭基线。
- **规则细化**：以 game_world.gd 现有 COMMANDS 常量为唯一清单源，差额以 grep 实测为准补录（本卷不猜差额清单）；常量单点后 presenter/main 引用一律走常量（禁裸字符串，DR-030 m3 口径）；零行为变更（纯对账基建）。
- **边界态**：清单核对期发现的游离方法不删除不改名，只进清单或显式标注"内部方法不进契约"。
- **验收锚**：DR-030②"实施对账（三方对账断言+共享键单点常量化）"+圆桌纪要§四"PR-α 对账断言+键名常量化"原文。
- **规格与切片**：PR-α 修复单（待建 issue，边界提案 §2.3）；GUT 用例名沿用 v013 验收点原锚 `test_view_contract`（presenter↔view 共享键全量契约），不重命名。
- **依赖**：PR-α issue 待建（1.0 收拢第一波前置）；无 [change]。

### D1-01-02 收入脉冲随机源收口（代码内演进预留兑现）
- **功能点**：把 settle_week 内联的收入脉冲 roll 迁入 rng_stream 分域体系或改确定性查表，兑现"PR7 换 rng_stream"代码内演进预留。
- **规则细化**：两形态候选（a 迁 rng_stream 既有域结构；b 按 DR-001 判定收入脉冲本属确定性域→改确定性查表）——**形态依主程序评审裁量，本卷不实锁**；硬约束：不新增第 4 RNG 消费点（grep 断言维持 3 处，DR-001/ADR-0008）、不改管线顺序（DR-007 黄级红线）、同 seed 双跑哈希一致不破。
- **边界态**：`_income_roll_seed` 在 start_new_game（:143 与 :183 双处赋值）与 restore 路径的口径差一并在收口单内对平（restore 不回读该字段的实证见疑点 S2-01）。
- **验收锚**：game_world.gd:143 注释原文"收入脉冲随机源种子（PR7 换 rng_stream）"+DR-021 M2（RNG 三消费点 grep 可验）+ADR-0008 分域纪律。
- **规格与切片**：工程债收口单（建号随 PR-α 同批或独立小单，工程裁量）；万周确定性回归=tests/unit/test_game_world.gd 既有断言复用。
- **依赖**：疑点 S2-01 转正；PR-α 对账先行暴露；无 [change]（不触 DR 本体）。

---

## 模块 2：经济与算力（GDD §6 ｜ 代码落点 src/entities/economy.gd · src/data/economy.json · assertion_bounds.json · assertion_ranges.json · opening.json）

**v0.1.x 现状**：已实现——三资源 apply_delta 唯一过账口（原子+resources_changed）、双来源收入（课题脉冲 task_grant_pilot + 复现小额，economy.json/tasks.json 落表）、破产线/警告线双线判定（WARNED_NONE/SOFT/BANKRUPT+warned 信号）、买卡升档（compute_upgraded）、基座质量乘子 q(base) 落表（model_bases.json quality 键：0.55/0.8/1.0 实证）、V1 现金流双断言与 V6/V10 区间入 JSON。已知缺陷/体验债——①断言区间**双文件双写**：assertion_bounds.json v1_cash_flow 与 assertion_ranges.json V1_bankruptcy 同带两份（grep 实证测试仅消费 bounds，ranges 无消费点）；②opening.json 起步集双真源：`_meta.note` 自认"W0 开局态（GW8）…staff 种子表 PR4 ST1 扩展"，与 texts.json（40 键内含 opening_line_* 四句+sys_* 系）形成数据/文案混装。

### D1-02-01 经济断言区间 JSON 合并收口
- **功能点**：把 V1/V6/V10/灵感四组断言区间收敛进单一真源文件，消除 bounds/ranges 同带双写。
- **规则细化**：保留消费点所在的 assertion_bounds.json 为真源（tests/unit/test_assertion_bounds.gd 既有消费不断链），assertion_ranges.json 退役或转薄壳（形态依主程序评审裁量）；合并窗口内 lint 挡新增对旧文件的引用；四组区间值逐键照抄（v1 破 30 周率 <1%+扩张剧本 ∈[0.5%,8%] / V6 lit@160 P10≥5·P50∈[7,9]·P90≤11 / V10 空窗 ≤40 / 灵感 40 周 6–9 次）——**数值零改动**。
- **边界态**：万周模拟与断言收窄（PR10 冻结 v1.0-frozen 口径）不因合并受扰——合并单须带同 seed 回归。
- **验收锚**：DR-027（V 断言区间 JSON 初值随预演入 PR3）+GDD §15"断言区间 JSON"+PR10"断言收窄+nightly"冻结标注（assertion_bounds.json `_meta.version="v1.0-frozen"` 实证）。
- **规格与切片**：债收口单（PR-α 同批评审，工程裁量）；回归复用 test_assertion_bounds.gd 与 test_game_world.gd 万周断言。
- **依赖**：PR-α 同批；无 [change]。

### D1-02-02 opening.json 起步集双真源合并
- **功能点**：opening.json 降级为纯开局态数值（W0 资源/竞对基线/staff_ids），文案与命名类键归 texts.json 单一真源。
- **规则细化**：现状 opening.json 实证仅承载开局态数值（money/influence/compute/rival_best/staff_ids/rival_model_name），`_meta.note` 中"staff 种子表 PR4 ST1 扩展"为未兑现演进预留——**本卷不发明种子表扩展内容**，只做真源归属收口：rival_model_name 类展示串迁 texts.json（键名随文案批实录）；staff 种子形态维持 staff.json+staff_ids 现状，扩展承诺归疑点登记不实施。
- **边界态**：迁移窗口内 TextService 三断言（断链/死键/长度）把守；game_world.gd 两处消费点（:160 建档/:362 restore）同单切换。
- **验收锚**：DR-010"texts.json 单一真源…items.json 迁键退役"先例+opening.json `_meta.note` 原文。
- **规格与切片**：文案批增量单（随批1 文案管线，卷二口径衔接）；回归复用 test_texts.gd 三断言。
- **依赖**：文案席文本批；PR-α 键名常量化同批；无 [change]。

---

## 模块 3：人员与任务（GDD §7 ｜ 代码落点 src/entities/staff_roster.gd · task_queue.gd · training_project.gd · src/data/tasks.json · staff.json · game_world.gd 任务结算段）

**v0.1.x 现状**：已实现——3 研究员名册（staff.json+opening.json 种子）、五类任务矩阵（复现/研究/课题实配+deploy 占位行 enabled:false，tasks.json 实证）、单任务槽+单训练位 assign/unassign（ST4）、教学闭环任务链 4 任务（task_reproduce_paper_0→silver_leash 门→task_reproduce_lingxi）、research_eff=Σ 已分配（空槽重算）、训练周定值不随机、assign/unassign 广播 resources_changed（v0.1.3 修复）。已知缺陷/体验债——①反馈④b"指派了没反应"双层根因已修码但**零断言锁定，回归裸奔**（v013 分诊原文）；②反馈④a"一个任务只能指派一个人？"=设计期待错位（设计如此非 bug，圆桌裁决项悬置）；③任务槽结算现状=**Game Over 短路后独立段**（game_world.gd :479–491，紧邻第 3 步之前），与 GDD §7"排队预填"语义同源但不在管线第 3 步内。

### D1-03-01 【N6 占位】多任务槽（【change】未双签——只占位不写规格）
- **功能点**：占位登记多任务槽深化需求（玩家视角：闲下来的研究员不再干看着，几条任务线并行推进），设计真源=**设计稿 1**（docs/discussion/2026-09-08-mech-design-drafts-v1.md 设计稿 1），未裁不动工。
- **规则细化**：**本卷不写规格不实锁**——槽数/autofill/竞争规则/存档复数化（tasks.active 单对象→数组=SaveMigrator 破坏性变更走迁移链+单测）/staff.assigned 三值化（现实现=slot_id 字符串，staff_roster.gd :143 实证，迁移=枚举语义收窄）全部引用设计稿 1 原文；**任务槽结算现状=Game Over 短路后独立段，"并入周结第 3 步"=插步黄级改动随圆桌裁**（设计稿 1 相容性自检段原文"默认不动管线顺序"）；映射表规划行 V1-05 沿用（其口径=依设计稿 1，未双签不排期）。
- **边界态**：未双签则本项不出现在任何批次（边界提案 §6.1 原文）；双签前 #30 reserved 卡时拒绝口径与 #31"占任务槽机会成本"四闸依赖槽数前提=批1 开工前须闭环（否则批后返工）。
- **验收锚**：v013 反馈④a 分诊行原文"设计如此（非 bug）…如需多任务并行属机制改动→走轻度复议/待 v0.2 任务槽深化（DR-018 A15 相关）"+DR-018 演进预留"v0.2 随多任务槽竞争恢复"+DR-023/ST4 单任务槽现裁。
- **规格与切片**：设计稿 1 全文（含转 GUT 验收句草案 4 条：test_task_slot_assign_dual_refresh / test_task_slot_reject_and_empty_state / test_task_slot_autofill_and_migrate + [P] 并行感——**引用不重命名**，双签后由本席按裁决结论补规格草稿再进双签流程）；缺口规格 §N6 占位段；UI 规格 V1-05（预写形态）。
- **依赖**：**[change] 双签+圆桌裁决**（槽数与竞争规则）→主策划补规格→批1；与 v013 反馈①同场裁决建议（圆桌议程合并）。

### D1-03-02 指派链路对账断言（PR-α 拆点——反馈④b 验收锁定）
- **功能点**：把 v0.1.3 已修码的指派链路用断言锁死，消除"回归裸奔"。
- **规则细化**：断言三件套（沿 v013 验收点原锚，不重命名）——①assign_staff 成功后 resources_changed 发射且主台计数 0.5 帧内刷新（`test_staff_assign_signals`）；②presenter↔view 共享键全量契约：键集合读⊆写、常量源单点（`test_view_contract`）；③0 空闲员工拒绝路径同步进断言（防只测 happy path，对齐验收点三要素"边界空态"）。契约基线=staff.assigned 为 slot_id 字符串（staff_roster.gd 实证），N6 若双签改三值枚举属同批迁移单测范围（设计稿 1 原文）。
- **边界态**：unassign 至空槽（assigned=""）与 game_over_flag 短路期拒绝路径各 1 断言；键名失配（staff vs staff_assigned 历史根因）以常量单点封堵。
- **验收锚**：v013 反馈④b 分诊行原文"双层根因已修…但零断言锁定，回归裸奔→PR-α（键名契约+信号断言+共享键常量化）"。
- **规格与切片**：PR-α 修复单（待建 issue）；GUT 用例名沿用 v013 验收点两条原锚。
- **依赖**：PR-α issue 待建（1.0 收拢第一波前置，先于批1 实现单）；无 [change]。

---

## 模块 4：科技树与迷雾（GDD §8 ｜ 代码落点 src/entities/tech_fog.gd · tech_tree.gd · src/data/techs.json · src/systems/data/predicate_registry.gd）

**v0.1.x 现状**：已实现——14 节点 v2.1 全表落 data/techs.json（深思三节点链 silver_leash→cot_sketch→silent_chain 挂 lit 门实证）、五态数据层状态机（TechFog 独立纯函数，ADR-0009）、4 类解锁谓词+crossover 转移增则、翻雾三通路（RP 揭示/竞对论文外溢/交叉进度）、域计数随 fog_changed 载荷（tech_fog.gd `get_domain_counts()` 实证）、灵感卡 pity/cap、谓词注册表（枚举+params）。已知缺陷/体验债——①**14 节点缺 1 节点**：实表 13 节点，器用域（tool_use）仅 arm_will 1 节点 vs GDD §8.1"器用 2 节点（ReAct→Toolformer→agent）"（见疑点 S2-02）；②长忆/器用 4 节点名未定稿（Q4 开放）与器用缺节点两项在录表口径上互为纠缠——Q4 截止窗（PR5 录表前）已过，须归档处置；③灵感触发 >可研节点数时兜底行为"跳过并顺延 pity 减 2"待复核（Q3 已登记）。

### D1-04-01 【Q4 复核引用】长忆/器用节点定稿窗口过期处置（登记册引用，不代裁）
- **功能点**：把 Q4（长忆 2 节点/器用 2 节点命名与定稿）从"PR5 录表前须定"的已过期窗口归档为"v0.2 前复核项"，并消解实表 13 vs 稿面 14 的口径差。
- **规则细化**：**本卷不代裁节点名与结构**（改结构=黄级评审，DR-023 演进预留）；登记册 Q4 行状态更新为"窗口已过·实表 13 节点在跑（techs.json 实证），v0.2 前复核：补第 14 节点或修订 GDD §8.1 表述，二选一须留痕"；复核结论无论哪向，逐节点 rp_cost Σ≈~10.4k 红线带 [~8k,~12k] 与 V6 分位断言不破（PR10 冻结值）。
- **边界态**：复核期间实表 13 节点维持可玩现状；他者道路 3 占位（world/symbol/embodied 实证在表）不动；若裁"补节点"，min_week 锚后纪律（防穿越）与域门槛一并过 V6 断言。
- **验收锚**：GDD §17 Q4 行原文"PR5 录表前（黄级结构改动窗口）；过窗走 v0.2"+GDD §8.1 器用行"2 节点"+techs.json 实表 13 节点实证。
- **规格与切片**：登记册更新单（S 规模，主策划+数值席各半）；V6 断言=assertion_bounds.json 既有键消费。
- **依赖**：**Q4 开放问题（引用不代裁）**；无 [change]（登记册维护非机制改动）。

### D1-04-02 【Q3 复核引用】灵感兜底行为复核（登记册引用，不代裁）
- **功能点**：复核"灵感触发 >可研节点数时跳过并顺延 pity 减 2"兜底的行为定义（是否改注入"任意可翻雾节点 RP"等形态）。
- **规则细化**：**本卷不代裁兜底形态**——v0.1.0 兜底已生效（event_engine.gd evaluate_inspiration 现行为）；复核输入=V6/V10 分位断言运行数据+万周模拟灵感触发分布（inspiration_triggers_per_40w ∈[6,9] 带内检查）；cap=12 硬保底语义不动（DR-027⑤ 否决概率上限语义维持）；复核结论若改形态=纯逻辑改动零存档迁移（pity 字段语义不变），属绿级。
- **边界态**：0 可研节点+灵感命中=不崩不卡（现行为继续，复核单补此边界显式断言）；灵感与事件同周且事件抽中决策卡→顺延 week_due 规则不受复核影响（EV4 现裁）。
- **验收锚**：GDD §17 Q3 行原文"兜底已生效待复核（是否改注入'任意可翻雾节点 RP'等形态）"+DR-027⑤"cap=硬保底语义（概率上限语义否决）"。
- **规格与切片**：登记册复核单（S 规模，主策划+数值席）；回归=test_rng_stream.gd/test_tech_fog.gd 既有断言。
- **依赖**：**Q3 开放问题（引用不代裁）**；无 [change]。

### D1-04-03 扩树信号触发器监控口径（DR-027① 演进预留——监控项非扩树项）
- **功能点**：把"扩树信号触发器"的监控口径落进 v0.1.x 试玩反馈闭环：试玩池数据按触发器三信号采集，**本卷不扩树**（触发未成立，DR-027①"维持 14 不动，扩树走 §5.4 信号触发器"）。
- **规则细化**：三信号照 GDD §8.1 触发器行原文采集——①试玩"点亮到顶太早"+V10 空窗断言频繁触顶（V10 断言=assertion_bounds.json v10_window max_gap_weeks=40，越带即触）；②周目三件套需要开局选路线（v2.0 红级评审输入，非本卷窗口）；③长忆/器用定稿装不下（走分支对结构，黄级）——前两信号归试玩池采集口径，第三信号并入 D1-04-01 Q4 复核；触发器口径与 tech-tree 全景分析 §5.4/§三 结论一致（"11 可玩节点是供需 1.0–1.3:1 精确配平的结果；'少'的体感来自他者 3 占位+P50 留白——都是钩子不是缺口"）。
- **边界态**：任一信号触发不直接开工扩树——先走主策划复核（触发器=立项评审门槛非自动开工键）；V10 越带但试玩无"点亮到顶"反馈=单信号不成立（双条件信号，DR-027① 原文用"+"连接）。
- **验收锚**：DR-027①"RP 供需重标…扩树信号触发器（§5.4 of tech-tree 全景）：试玩'点亮到顶太早'+V10 空窗频繁触顶"+tech-tree 全景分析原文"维持 14 不动，扩树走 §5.4 信号触发器"。
- **规格与切片**：试玩反馈表单采集口径增补（随 N8 scripts.md 建档同批，一列入采集字段）；V10 断言消费=test_assertion_bounds.gd 既有键。
- **依赖**：N8（采集口径载体）；Q4 复核（第三信号归属）；无 [change]（监控项零机制改动）。

---

## 模块 5：训练与 SOTA（GDD §9 ｜ 代码落点 src/entities/training_project.gd · sota_board.gd · src/core/score_math.gd · src/data/model_bases.json · benchmarks.json）

**v0.1.x 现状**：已实现——出分公式全通路（A=K·(1+eff)^0.7·(1+tech_bonus)^0.3×m×q(base)，score_math.gd 量纲写死，θ=95/k=13 真值表，DR-027③ 冻结）、三基座落表（model_bases.json 训练周/人数/卡时/成本/quality 实证）、SOTA 严格大于/平局归霸主/仅周结判定、训练计时 weeks_left 入档+progress_ticked 刻级信号（值变才发）、命名通路数据层（submit_model_name 长度/敏感词/插值转义+默认名池 10 键确定性轮转，tests 全绿）。已知缺陷/体验债——①**命名仪式 UI 三缺（闭单缺项）**：PanelStack.NAMING_DIALOG 在 z2 阻塞集合+dashboard_presenter.open_naming_dialog() push 方法+texts.json 13 个 naming_* 键+模型命名提示触发（训练完成→超阈值）俱全，但 src/ui/modals/ 无命名场景、main.gd `_on_panel_pushed` 无 NAMING_DIALOG 分支、push 方法无触发调用方——push 后遮罩出现无面板，与 #67 同构（见疑点 S2-03）；②周报 report 载荷无 SOTA 名次行（GDD §9"落后为什么一行进周报"属 DR-029 B-6=卷二 #34，本卷不展开）；③sota.by_key{} 多键容器预埋未实装（DR-029 B-6 影子榜前置，卷二 #39 范围）。

### D1-05-01 命名仪式 UI 落地（闭单缺项——#18 自检"信号渲染完整"与实证差口）
- **功能点**：补齐命名仪式 z2 弹层实体（出分命名=截图时刻的仪式承载体），消除"push 遮罩出现但无面板"的三缺状态。
- **规则细化**：场景命名框=标题（naming_title）/提示（naming_input_hint）/输入框/提交（naming_button_submit）/跳过（naming_button_skip）五件套，**键名全部沿用 texts.json 现存 13 个 naming_* 键不新增不重命名**；main.gd `_on_panel_pushed` 补 NAMING_DIALOG 分支（挂载语义与既有 z2 阻塞面板同构：遮罩不关、pop 后焦点归还）；触发链接线=训练出分周（sota_updated 或 week_settled 载荷）经 presenter 调既有 open_naming_dialog()——**触发时机与 GDD §9"立项命名（可跳过→默认名池兜底）+出分宣发展示峰值"的对应关系依主程序评审裁量接线**，本卷不实锁时点；敏感词拒绝走既有 naming_sensitive_toast 键（submit_model_name 现行为零改动）。
- **边界态**：空输入=naming_empty_toast（现行为）；超长=naming_too_long_toast；跳过=默认名池轮转+naming_fallback_toast（游标入 flags 零 RNG）；命名后 banner 键（naming_banner）进周报头条区渲染位；z2 阻塞期间 set_paused(false) 被拒（game_world 现行为）不受弹层影响。
- **验收锚**：#18 闭单验收点原文"[T] 信号渲染完整断言（11 信号→…命名框/Game Over 卡逐一有落点）"（自检勾选与实证差口=闭单缺项）+"[P] 命名仪式'署名仪式感'（出分=截图时刻）"（试玩主观，未勾选悬置）+GDD §9 命名仪式段+DR-002。
- **规格与切片**：修复单（随 PR-α 评审暴露后建号，M~S 规模，主程序裁量归属）；GUT：分支接线断言沿 test_panel_stack.gd 既有 NAMING_DIALOG 白名单用例扩展（push→弹层可见→pop→焦点归还，不重命名既有用例）；texts 三断言回归=test_texts.gd。
- **依赖**：**无 DR 改判**（DR-002 命名时机现裁适用）；命名框触发时点若须偏离 GDD §9 表述，走黄级评审而非本卷代裁；无 [change]。

### D1-05-02 自由期三线计数器（N3 数据侧拆点——霸榜周数计数落点）
- **功能点**：三线计数器的数据侧落位：霸榜周数在 SOTA 保霸周 +1、探明数消费 fog_changed 域计数、影响力存量取 resources.influence 快照，全部入 flags 开放容器（键名 freedom_*）。
- **规则细化**：**本模块只落数据侧**（sota_board 霸霸周 +1 计数点与 fog 域计数消费点在其代码落点）；周报差距行渲染（PR9b 侧）与周报固定槽位=界面侧，整卡规格引用 §N3 不重写；计数器入 flags 开放容器（PR5R 冻结包窗口预埋纪律）；freedom_counters_changed 待建信号命名沿 §N3/UI 规格 V1-16 现稿，不重命名。
- **边界态**：三线全 0/未开始（首周、零霸榜、零探明）计数器归零展示不 NaN 不空指针，且不进周报差距行（§N3 验收点 2 原文）。
- **验收锚**：DR-029 C-6"自由期三线…优先级压过摆弄层——'亮 9 后缺的是目标不是手活'。计数器+差距行随 PR5/PR9b 顺手入"+GDD §3 自由期三线段。
- **规格与切片**：**缺口规格 §N3 整卡引用**（3 [T]+1 [P]：test_freedom_three_counters_accumulate / test_freedom_counters_zero_state / test_freedom_gap_row_matches_counters + [P] scripts.md#N3——原样引用）；UI 规格 V1-16+映射表行 V1-16；本卷不立规格不改用例名。
- **依赖**：N3 issue 待建（1.0 前置，边界提案 §2.2"N3=1.0 前置（原裁窗口已关闭，随 1.0 重开）"）；#45/#28 目标带标定=卷二拆点（目标带未收口期 [P] 验收降级条款沿 §N3）；无 [change]。

### D1-05-03 SOTA 次数计数入终局档（#16 闭单缺项——summary 字段集与验收点原文差口）
- **功能点**：补齐 Game Over summary 的 SOTA 次数字段（sota_count），对齐 #16 验收点原文字段集"周数/SOTA 次数/最高分"。
- **规则细化**：计数口径=每周结第 5 步 sota.submit **我方刷新霸主（严格大于分支）时 +1**——竞对发版/平局归霸主（竞对保霸）不增计数（DR-005 严格大于口径自然导出）；字段随 summary 进终局档（flags 开放容器或实时计算依主程序裁量，本卷不实锁实现位）；Game Over 卡渲染消费对齐（game_over_dialog 现渲字段集同步补该行）。
- **边界态**：0 次出分破产=sota_count=0 显式入档（不缺键不 NaN）；读档还原后计数与局史一致（flags 持久化路径）。
- **验收锚**：#16 闭单验收点 4 原文"[T] summary 字典字段断言（周数/SOTA 次数/最高分）"（实测 summary=week/best_score/rival_best/model_name/cum_income/reason，无次数字段）+GDD §12 Game Over 短路行原文"game_over 信号+summary（周数/SOTA 次数/最高分）"。
- **规格与切片**：修复单（S 规模，PR-α 批评审时暴露建号）；GUT：test_game_over_and_save.gd 验收点 4 用例扩字段断言（沿用既有文件不重命名）。
- **依赖**：PR-α 批；无 [change]（闭单验收点兑现）。

---

## 模块 6：竞对（GDD §10 ｜ 代码落点 src/entities/rival_track.gd · src/data/rivals.json · event_engine.gd 外溢段）

**v0.1.x 现状**：已实现——深巷 8 动作时间线（rivals.json）、±15% 扰动（RNG 域 1 rival_jitter，rival_track.gd `randf_domain(DOMAIN_RIVAL_JITTER)` 实证）、黄灯/红灯预警（rival_warned 信号 WARN_YELLOW/RED+weeks_left，tests 实证红灯 2 周零误报）、论文外溢翻态零 RNG（rival_spill_triggered+确定性规则表）、rival_launched 发版播报。已知缺陷/体验债——①**同周双发（撞车周）文案键无落点**：G-2"叙事='independent work 撞车'禁'你抢到了'"已裁（DR-029 G），texts.json 40 键无 scoop_* 系（grep 实证），#14（PR7 竞对）闭单验收点无抢发文案条目（边界提案 §2.2 查证列原文）；②传闻池 6 条 ±2 周窗口显式验收点缺失（G-3 实现主体在卷二 #40，本卷只锁键与口径）。

### D1-06-01 G-2 抢发文案键+G-3 传闻窗口口径锁定（N5 整卡承载）
- **功能点**：补齐竞对叙事红线落点——G-2 同周双发文案键"independent work 撞车"（禁"你抢到了"）入库+G-3 传闻池 6 条 ±2 周窗口验收口径显式化。
- **规则细化**：**整卡规格引用 §N5 不重写**——3 [T]+1 [P]（test_scoop_copy_collision_key / test_rumor_pool_two_week_window / test_rumor_determinism_same_seed + [P] scripts.md#N5 撞车周复述措辞代理指标）原样引用；文案进 texts.json（scoop_*、rumor_*，周报条目 ≤30 预算）；窗口投放挂 rivals.json 时间线锚点（确定性规则表，零 RNG——禁开 rng 第 4 域，DR-001）；抢发判定不触碰 SOTA 严格大于/平局归霸主判定（DR-005 不动）；**同源纪律（m9）：N5（批1 前置锁键与口径）先于 #40（卷二批2 实现）建号，#40 认领以 N5 已建为前置，两单验收互引同一 GUT 用例名禁双写**。
- **边界态**：玩家先发+竞对同周发版=撞车键（单向触发口径沿 §N5 验收点 1：不同周玩家先发不出现"你抢到了"类表述）；窗口边界（-2/0/+2）各投放一次成功且不入档永占（toast 语义，DR-012）；同 seed 双跑逐周报告哈希一致。
- **验收锚**：DR-029 G"抢发判定（叙事='independent work 撞车'禁'你抢到了'）+传闻池 6 条（±2 周窗口）"+DR-027④"L1=12 周维持（先发率 49.4% 设计正中首训窗口）"。
- **规格与切片**：**缺口规格 §N5 整卡引用**（不重写不重命名）；UI 规格 V1-11（传闻 toast/周报行双形态）+映射表行 V1-11；实现主体=卷二 #40（其模块 3 D2-03-05）。
- **依赖**：N5 issue 待建（1.0 前置）；#40 已建（卷二 21 条内，open）；无 [change]。

---

## 模块 7：事件（GDD §11 ｜ 代码落点 src/entities/event_engine.gd · src/data/events.json · panel_stack.gd toast 段）

**v0.1.x 现状**：已实现——事件只在结算点产出（evaluate_events 周结消费）、决策卡阻塞=blocked_by_card+pending 入档（单周 ≤1 张决策卡，双卡 week_due 顺延实证）、效果注册表 9 类型+timing 字段（delayed 至下周结第 3 步 consume_delayed_effects 实证）、toast 队列同屏 ≤3 顶最旧（panel_stack.gd push_toast :207–212 实证）、灵感卡同管线消费（RNG 域 2）、稍后处理=UI 收起阻塞不变（周结前强制选择）。已知缺陷/体验债——①**toast 倒计时驱动链缺失**：PanelStack.update_toasts(delta) 无任何调用点（grep 实证零引用），toast 计时绑游戏时间（DR-012 现裁）实际依赖上层每帧喂 Δt——现在 toast 可能永不消散或计时源不明（见疑点 S2-04）；②事件池仅 MVP 8 张（3 决策+5 通知），三层池扩容=卷二 #41 范围不展开。

### D1-07-01 toast 计时链路收口（PR-α 拆点）
- **功能点**：把 toast 倒计时驱动链接进唯一帧循环，兑现"计时绑游戏时间"现裁，消除"计时源不明"债。
- **规则细化**：驱动链候选二选一（a main.gd `_process` 把驱动帧 Δt 同喂 panel_stack.update_toasts；b 停喂期由 tick_feeding_gate 门控信号喂 0——**形态依主程序评审裁量**）；硬约束：暂停/停喂期 toast 不耗时长（绑游戏时间=DR-012 原文"toast 不入档、同屏≤3、计时绑游戏时间"）；同屏 ≤3 顶最旧现状行为锁定（既有实现已是，断言固化）；零新信号零新面板。
- **边界态**：同帧 4 条 toast 入队→顶最旧（现行为）；z2 阻塞期 toast 冻结不消散；读档后 toast 不还原（不入档现裁，DRAM-012 口径）——三种边界各 1 断言。
- **验收锚**：DR-012"toast 不入档、同屏≤3、计时绑游戏时间"原文+panel_stack.gd :207–212 既有实现注释。
- **规格与切片**：PR-α 同批债收口单（工程裁量归属）；GUT：test_panel_stack.gd toast 段既有用例扩展（计时边界三条，命名沿既有段落风格由测试席定，本卷不发明用例名）。
- **依赖**：PR-α issue 待建；疑点 S2-04 转正；无 [change]。

### D1-07-02 周报载荷字段集接线（GDD §14 字段集冻结的兑现缺口）
- **功能点**：把周报 report 载荷从"收支行孤行"补齐到 GDD §14 冻结字段集，并打通 texts 现存 6 个 report_* 键的消费。
- **规则细化**：现状实证——settle_week 的 report 仅含 week/money_row/line_state 三键（game_world.gd :543–553），weekly_report_dialog 读 `report.get("rows", [])` 而**载荷无 rows 键**（周报弹层恒走"本周运转平稳"兜底文案，weekly_report_dialog.gd :37–40 实证）；标题为代码硬编码字符串"第 %d 周 周报"（违反"文本一律键名引用"通用纪律）；texts.json 现存 6 个 report_* 键（report_headline/money_row/reputation_row/event_row/fog_row/training_row）中仅 report_money_row/reputation_row 进 TEXT_STAT_LINE_KEYS 常量，全部零渲染消费。补齐口径=**字段集照 GDD §14 冻结行原文（收支行/声誉行/事件行/迷雾行/训练行，对齐 texts 40 键周报模板），渲染走 presenter 键重构（rows 键名对齐 dialog 读取侧，形态依主程序裁量），零新增键**；数据源全部为既有入档字段（事件行=events fired 当周、迷雾行=fog_changed 域计数、训练行=training 状态、声誉行=influence 现值）；标题改 report_headline 键插值。
- **边界态**：某行无数据=整行不渲染（静默空态，沿 V1-06"首周未出分整行不渲染"同纪律）；格式化全部经 Formatter（结构化数值行不计字数，DR-010）；周报模板键变更=文案批增量（绿），不动字段集结构。
- **验收锚**：GDD §14"周报 report 字段集冻结（Q6 裁定）：收支行/声誉行/事件行/迷雾行/训练行（对齐 texts 40 键周报模板）"原文+GDD §13 心跳时刻行"周报时刻——玩家据此做下一轮规划"（载荷空壳直接打击心跳时刻）。
- **规格与切片**：修复/补齐单（M 规模，PR-γ 批或独立，归属工程裁量）；GUT：test_dashboard_presenter.gd `_on_week_settled` 段扩展（五行渲染断言，用例名测试席沿既有文件定）；回归=test_formatter.gd/test_texts.gd。
- **依赖**：PR-α 键名常量化（rows 等共享键进契约）；周报流槽位分配对账（UI 规格跨节备忘"presenter 布局表实施时统一对账"）；无 [change]（GDD §14 已裁字段集兑现）。

---

## 模块 8：存档（GDD §12 ｜ 代码落点 src/systems/save/save_system.gd · save_migrator.gd · src/entities/snapshot_codec.gd）

**v0.1.x 现状**：已实现——周界自动存（管线第 11 步 request_save("weekly_auto")）+手动 request_save(reason)、文件级双缓冲（tmp 写→校验→换名+.bak，SaveSystem 实证）、损坏回退 .bak、Game Over 终局档+summary 字典（week/best_score/rival_best/cum_income/reason）、SaveMigrator 迁移链+schema v1 全量字段（test_schema_freeze.gd 冻结断言）。已知缺陷/体验债——①**第二/三保险无真实挂点（闭单缺项）**：#16 闭单验收"[T] 三路径触发断言（周界/退出切后台/手动各一）"自检通过，但路径 2 的测试是直调 `_world.request_save("suspend")`（test_game_over_and_save.gd :26–31 实证），src/ 全域无 NOTIFICATION_APPLICATION_FOCUS_OUT / NOTIFICATION_WM_CLOSE_REQUEST 监听（main.gd 仅 NOTIFICATION_RESIZED 实证）——"退出/切后台"保险只有能力没有触发挂点；②N1 归来摘要的触发源（存档时间戳差判定）所需时间戳字段缺位（SaveSystem 无 session/timestamp 键，grep 实证）。

### D1-08-01 退出/切后台存档真实挂点补齐（#16 闭单缺项）
- **功能点**：把"退出/切后台"保险从能力补成真实挂点，三保险语义闭环。
- **规则细化**：main.gd 补系统通知监听（WM_CLOSE_REQUEST / APPLICATION_FOCUS_OUT → request_save("suspend")，reason 键沿用测试既有 "suspend" 口径）；测试从"直调 request_save"升级为挂点触发级断言（模拟通知→落盘→save_reason=suspend 可还原）；**Web 平台边界**：Pages 秒玩形态下切后台是否发 APPLICATION_FOCUS_OUT 须实测确认（JS visibilitychange 桥接为候选形态，是否需要依主程序实测裁量，本卷不发明方案，见疑点 S2-05）；零 schema 变更（save_reason 已在档）。
- **边界态**：Game Over 短路期切后台重复存档=幂等无害（request_save 已幂等）；z2 阻塞期切后台存档不解除阻塞（存档不动 paused 态）。
- **验收锚**：#16 闭单验收点原文"[T] 三路径触发断言（周界/退出切后台/手动各一）"+GDD §12 三保险时机行（GW5/DR-008）。
- **规格与切片**：修复单（S 规模，随 PR-α 同批评审归属）；GUT：test_game_over_and_save.gd 路径 2 用例升级（挂点级，沿用既有文件不重命名）。
- **依赖**：PR-α 同批；疑点 S2-05（Web 可见性行为实测）；无 [change]。

### D1-08-02 存档时间戳字段（N1 数据侧拆点）
- **功能点**：为归来摘要触发判定提供数据基础：存档载荷与 SaveSystem 侧补时间戳记录（last_saved_at 类字段），供 session_resumed 的"存档时间戳差 ≥~阈值"判定消费。
- **规则细化**：字段进 schema v1 的方式=**开放容器或最小新增键依 PR5R 冻结包纪律与主程序裁量**（本卷不实锁键名与位置）；阈值 ~ 占位沿 §N1（阈值与摘要条数上限=等试玩池悬置项）；信号名 session_resumed 沿 §N1/V1-01 现稿不重命名；时间戳为存档元数据不入 flags 玩家语义域。
- **边界态**：旧档缺时间戳键=按"刚回来"或"不触发摘要"的缺省语义（缺键容错，选向随 N1 建号裁）；时钟回拨/同帧双存取 max 不取 min（防负差）。
- **验收锚**：缺口规格 §N1 实施提示原文"触发=session_resumed 待建信号（存档时间戳差 ≥~阈值判定，V1-01 口径）"+GDD §12 schema v1 开放容器纪律。
- **规格与切片**：N1 的前置数据点（建号可并入 N1 或独立 S 单，边界提案 §2.2 N1 行"随批1"）；回归=test_schema_freeze.gd 既有冻结断言扩展。
- **依赖**：N1（模块 10 D1-10-01）整卡为消费方；PR5R 冻结包纪律；无 [change]。

---

## 模块 9：界面与交互（GDD §13 ｜ 代码落点 src/ui/panel_stack.gd · main.gd · main.tscn · dashboard_presenter.gd · responsive_layout_manager.gd）

**v0.1.x 现状**：已实现——PanelStack 四层栈+PanelId/Layer 枚举封闭集合（v0.1.3 随案重构）、z2 阻塞白名单（is_blocking）+遮罩规则（仅 PAUSE_MENU 遮罩可关）+pop 动画锁+push 排队、周报双挂载双态（自动 z2 停喂/重看 z1 不停喂，#18 自检通过）、Dock 三键（Tech/Report/Pause）、INTRO z1 弹层、ToastLabel 同屏 ≤3、竖屏折叠框架（responsive_layout_manager）。已知缺陷/体验债——①#67：PAUSE_MENU 入栈但 main.gd 无渲染分支（push 后遮罩出现无面板，可点遮罩退出无死锁）=z2 白名单成员缺实体；②反馈②"流速和暂停不是常亮状态，失焦之后就不知道现在什么状态了"（表达缺失，PR-γ 承载）；③反馈③"界面还是不展示员工 点 0/3 才出来指派界面"（DR-015"点卡进详情"因无卡可点而变形，PR-γ 承载）；④GDD §13 R3 周报自动弹结构落差：presenter `_on_week_settled` 无条件每周 push AUTO_REPORT（:131–138 实证），无"≥~5% 显著变化才自动弹+其余 Dock 角标+4x 不弹"结构（#18 闭单双态断言不覆盖自动弹频率）。

### D1-09-01 暂停菜单面板落地（PR-δ / #67 整卡承载）
- **功能点**：补齐 PAUSE_MENU 的 z2 弹层实体（继续/重开/速率三入口），修复"入栈无面板"的可玩性断裂。
- **规则细化**：五件套=面板场景（新 tscn，或复用弹层基座）+main.gd `_on_panel_pushed` 补 PAUSE_MENU 分支+三入口（继续/重新开局/速率选择）+Esc 可关+遮罩可关；**键名沿用 texts.json 现存 sys_menu_continue / sys_menu_new_game / sys_save_hint 不新增不重命名**（速率档文案随常显态批对齐 V1-04 键名）；遮罩可关+Esc 可关语义=panel_stack.gd 既有 dismissable 实现（:163 :197 实证），零栈语义改动；重开链路复用 Game Over 卡既有 restart_requested→start_new_game() 接线（main.gd :301–306 实证先例）；**主动重开归档语义=仅 dex 合入+run_count+1，past_runs 不追加完整摘要（待拍板开放问题②【设计稿 2 登记】）——meta.cfg 通道未建前（#37/#44）重开暂不归档，#44 落地后接线**。
- **边界态**：决策卡阻塞期打开暂停菜单=允许（paused 双源独立，blocked_by_card 不受 user_paused 影响）；重开确认弹层归属=设计稿 2 开放问题①（"主动重开是否先经暂停菜单确认弹层"待拍板，未拍板前 PR-δ 不加确认弹层维持 #67 建议最小形态）；Game Over 弹层在场时暂停键置灰或被吞（两 z2 同帧串行既有规则）。
- **验收锚**：#67 issue 原文"建议：补一个轻量 PauseMenuDialog（继续/重新开局/速率选择），z2 层 dismissable 语义与 PanelStack 现有约定对齐"+映射表 §2 既有行"PAUSE_MENU 开｜dock 暂停键｜面板实例化可见（继续/重开/速率），Esc 可关"。
- **规格与切片**：PR-δ=已立 issue #67（open，唯一已立修复单）；GUT：test_panel_stack.gd 既有 PAUSE_MENU 白名单/遮罩用例扩展分支接线断言（push→面板可见→Esc/遮罩可关→pop，不重命名既有用例）；信标=main.gd 面板栈信标既有机制扩 PAUSE_MENU 态。
- **依赖**：#67 已立（open）；重开归档语义待 #37/#44；确认弹层=开放问题①（设计稿 2 登记）；无 [change]（#67 修复属闭单缺项补齐非机制新增）。

### D1-09-02 流速/暂停常显态（PR-γ · N7 前半）
- **功能点**：主台常显流速档位与暂停态标识，消除"失焦之后不知道现在什么状态"（反馈②）。
- **规则细化**：**整卡规格引用 §N7 不重写**——验收点 1/2 原样引用（`test_speed_pause_always_visible`：user_paused=false 常显 1x/2x/4x 档位、set_paused(true) 后常显"已暂停"文本+图形双通道色盲安全、读档/回菜单重进还原一致；`test_z2_auto_pause_distinct`：z2 自动暂停显示"自动暂停"标识且与用户暂停可区分、遮罩之上仍可辨识）；UI 细节唯一真源=UI 规格 V1-04（挂 %ResourceSubrow 常驻、四既有键复用零新键、decision_wait_reason 置灰原因）；映射表行=V1-04 规划行+§2 既有 user_paused 三行（并存不互斥，PR-γ 落地后维护纪律收敛）；**常显标识"层级高于遮罩"=增强非冲突，标 [提案·待拍板]（落 PR 前须制作人/UI 席确认）**。
- **边界态**：z2 阻塞期间流速档键置灰+原因可查（decision_wait_reason）；BOOT 未进 GAME 前不渲染；4x 与暂停互斥态的标识优先级沿 V1-04 三态矩阵（附录 B 行 V1-04）。
- **验收锚**：v013 反馈②分诊行原文"流速/暂停非常亮态=表达缺失（反馈三态缺结果态）→PR-γ"+DR-020 常显相关遮罩规则。
- **规格与切片**：PR-γ 修复单（待建 issue，承载 N7）；缺口规格 §N7 验收点 1/2；UI 规格 V1-04；映射表行 V1-04；信标命名沿 UI 规格附录 D（ui_speed_badge/ui_pause_badge 快照型，S9 口径复用）。
- **依赖**：PR-γ issue 待建（1.0 收拢第一波前置）；[提案·待拍板] 层级项（口径 2）；无 [change]。

### D1-09-03 员工实体卡（PR-γ · N7 后半）
- **功能点**：员工从计数标签升级为可点实体卡（3 张），消除"点 0/3 才出指派"的入口过深（反馈③）。
- **规则细化**：**整卡规格引用 §N7 不重写**——验收点 3 原样引用（`test_staff_entity_cards_and_assign_refresh`：主台渲染 3 张员工实体卡（名/状态/在岗位）、assign_staff 成功后 resources_changed 发射且卡与计数 0.5s 内刷新、0 空闲员工时指派入口置灰+原因可查）；UI 细节唯一真源=V1-03（%Workspace 内常驻、点卡 1 次选中再点指派=2 次点击内完成、长按/悬停详情提示、staff_slot_empty/staff_roster_empty 空态键、staff_assign_disabled_reason）；映射表行=V1-03+§2 既有"员工 idle/assigned"行（同源并存）；卡与既有 StaffRow/StaffCountLabel 的替换关系随 PR 实施定（先改表再改码纪律）。
- **边界态**：训练中员工状态字样=training（V1-03 三态）；0 空闲员工拒绝路径与 D1-03-02 断言共用（PR-α/PR-γ 同锚不双写：v013 验收点 test_staff_assign_signals 归 PR-α 数据断言、卡刷新归 PR-γ 呈现断言，两单互引）。
- **验收锚**：v013 反馈③分诊行原文"实体不可见+入口过深（DR-015'点卡进详情'因无卡可点而变形）→PR-γ/UI 迭代"+DR-015 分配路径现裁。
- **规格与切片**：PR-γ 修复单（同 D1-09-02 单承载）；缺口规格 §N7 验收点 3；UI 规格 V1-03；映射表行 V1-03；信标=ui_staff_cards_state（快照型，附录 D）。
- **依赖**：PR-γ issue 待建；与 D1-03-02（PR-α）断言分工见边界态；无 [change]。

### D1-09-04 周报自动弹 R3 结构落地（GDD §13 结构落差收口）
- **功能点**：把"自动周报每周全弹"改造成 R3 结构：显著变化周才自动弹，其余 Dock 角标，4x 下一律不弹。
- **规则细化**：三件结构（沿 GDD §13 周报双挂载行 R3 原文，不添不减）——①≥~5% 显著变化口径才自动弹（阈值 ~ 占位照抄 DR-020/GDD §13，正式值随试玩反馈调，DR-009"数值红线可随试玩反馈调"同源纪律）；②不满足=Dock 角标（`has_unread_report` 字段已备、presenter 已置位，缺角标渲染消费——渲染形态沿 Dock 既有结构，不加键）；③4x 档下一律不弹（全部转角标）；显著变化口径的计算基准（对上周何值之比）**本卷不定义**——属 R3 口径细化，随建号由主策划+数值席联合定，防发明。
- **边界态**：决策卡周（含周报头条级事件）自动弹优先级=决策卡先于周报（既有同帧串行）；显著变化判定失败（除零/首周）=不弹转角标（缺数据安全向）；Game Over 周无周报（短路既有）。
- **验收锚**：GDD §13 周报双挂载行 R3 原文"R3：≥~5% 显著变化周才自动弹，其余 Dock 角标，4x 下一律不弹"+DR-020 周报双挂载裁决+#18 闭单（双态断言已过、R3 频率未覆盖=结构落差）。
- **规格与切片**：修复/补齐单（S~M 规模，随 PR-γ 批或独立，归属工程裁量）；GUT：test_dashboard_presenter.gd `_on_week_settled` 段扩展三断言（显著弹/角标/4x 不弹——用例名由测试席沿既有文件风格定，本卷不发明）；信标=Dock 角标态快照。
- **依赖**：显著变化口径定义（R3 细化，建号时定）；PR-γ 批；无 [change]（DR-020/GDD §13 已裁结构兑现）。

### D1-09-05 selftest 信标基建扩场景（PR-γ 组成部分——纪要 §四原文）
- **功能点**：按圆桌纪要 §四"PR-γ selftest 扩场景+信标+S6 硬化（同 PR）"原文，扩 selftest_web 场景覆盖并落信标快照/事件两型机制，为 N7 常显态与后续界面类验收提供断言载体。
- **规则细化**：现状=selftest_web 已有 8/8 场景（v0.1.3 归档实证）+面板栈信标（main.gd `_setup_debug_shot_driver` ?selftest=1 机制实证，仅 Web 且显式查询参数激活、正常游玩零影响）；扩场景=S9 口径（"任意失焦/遮罩后 10 秒内可辨识流速与暂停态"，v013 验收点原文）+员工卡指派链+暂停菜单分支；信标两型沿 UI 规格附录 D 约定（快照型=任意时刻读当前值/事件型=一次性记录发生序），命名约定 `ui_<panel_short>_<state_or_element>` 照抄；信标落地后回填映射表行（§1 列定义"信标落地前填'待回填'，lint 豁免该列"）。
- **边界态**：信标仅调试驱动激活时同步（正常游玩零开销，既有注释承诺维持）；selftest 冻结时钟+丢弃挂起决策卡的防污染机制（既有）扩场景时逐场景复用；桌面端等效断言=GUT 侧覆盖（selftest 仅 Web）。
- **验收锚**：圆桌纪要 §四原文"PR-γ selftest 扩场景+信标+S6 硬化（同 PR）"+v013 验收点"[T] 用户暂停/恢复/2x/4x 时主台存在常显态标识与档位显示（信标断言，selftest_web S9）"。
- **规格与切片**：PR-γ 修复单组成部分（同 D1-09-02/03 一单）；场景清单沿 v013 验收点+§N7；信标名回填映射表行 V1-03/V1-04+§2 既有行。
- **依赖**：PR-γ issue 待建；无 [change]。

---

## 模块 10：引导与文案（GDD §14 ｜ 代码落点 src/systems/text/text_service.gd · formatter.gd · src/data/texts.json · sensitive_words.json · main.gd INTRO）

**v0.1.x 现状**：已实现——texts.json 单一真源 40 键+TextService 单入口+Formatter（¥+万缩写+负号前置+{var} 单括号插值一次转义）、三断言（断链/死键/长度）、敏感词三层（sensitive_words.json 入 L4）、INTRO 四句开场白弹层（opening_line_intro/goal/rival/hint 全走 TextService，z1 不拦流淌）、W0"准备周"表述、naming_* 13 键入库。已知缺陷/体验债——①反馈①"开幕没有自动暂停"=设计意图（DR-029 D-3"开场不拦流淌"）与玩家期待的冲突，轻度复议候选悬置（圆桌裁决项）；②N1 归来摘要+引导气泡全套缺位（texts 无 welcome_back/return_/tutorial/guide_ 系键，grep 实证）；③N4 吐槽键+观察文本通道缺位（无 gossip_* 键）；④N8 试玩脚本真源缺位（docs/playtest/scripts.md 不存在，全部 [P] 锚悬空）。

### D1-10-01 归来摘要+引导气泡（N1 整卡承载）
- **功能点**：回来场景第一屏摘要（暂停菜单归来/读档/次日再玩时 10 秒内说清三类事：钱还好吗/有没有要我管的/大事）与锚定气泡引导通道（D-3，否决遮罩方案），共用"1 提醒"位。
- **规则细化**：**整卡规格引用 §N1 不重写**——4 [T]+1 [P] 原样引用（`test_return_summary_three_categories` / `test_return_summary_empty_state` / `test_return_summary_z1_no_feed_gate` / `test_anchor_bubble_dismiss_and_once` + [P] scripts.md#N1 归来至首次有效操作 ≤~10s、条目 ≤~3 条）；红线真源=DR-029 D-2（经对抗评审 M2-① 修正：红线真源=DR-029 D-2，非 DR-030）："1 提醒只指向已存在待办，绝不创造新待办；摘要必有=钱还好吗/有没有要我管的/大事三类"；UI 细节唯一真源=V1-01（RETURN_SUMMARY z1 只读弹层，DR-020 z2 白名单封闭不新增成员）/V1-02（锚定气泡 z3 不阻塞不入档）；生成器挂周结管线第 11 步后消费 flags/pending（不改管线顺序，DR-007 黄级红线）；触发=session_resumed 待建信号（数据侧=模块 8 D1-08-02 拆点）；**两卷衔接**：卷二将 N1 落其模块 5（D 组同源聚合层安排，其卷首有落位说明）——两卷引用同一 §N1 规格与同一 DR-029 D-2 红线，零分叉；本卷落模块 10=GDD §13 引导节/§14 文案管线归属。
- **边界态**：无任何待办+资金健康=空态文案（非空白不弹卡）；条目数 0 时"1 提醒"通道不出现角标；摘要条数上限与气泡停留策略=等试玩池悬置项（正式值随 1.0 试玩转正收口，m13）；二周目 meta.cfg 豁免开关本批只留豁免位（V1-02 空态口径）。
- **验收锚**：DR-029 D-2/D-3 原文（见上）+v013 反馈②教训引用（"参考 v0.1.3 反馈②常显态教训（状态必须可见）"，§N1 实施提示原文）。
- **规格与切片**：**缺口规格 §N1 整卡引用**（不重写不重命名）；UI 规格 V1-01/V1-02；映射表行 V1-01/V1-02；信标=ui_return_summary_visible（快照）/ui_guide_bubble_step（快照=当前步号，附录 D）。
- **依赖**：N1 issue 待建（随批1，先于建号须 PR-β lint 上线）；session_resumed 待建+存档时间戳（模块 8 D1-08-02）；PR5R flags 冻结包；等试玩转正（边界提案 §3.3）：摘要条数/气泡停留；无 [change]。

### D1-10-02 吐槽键+观察文本（N4 整卡承载）
- **功能点**：实现真空期"止痛药"观察文本通道：员工吐槽气泡（F1 池首批键）+猫（零状态版）+观察文本替代数值面板，文本归内容席管线供给。
- **规则细化**：**整卡规格引用 §N4 不重写**——3 [T]+1 [P] 原样引用（`test_gossip_bubble_deterministic_rotation`：确定性轮转不新增 RNG 消费点 grep 断言仍恰 3 处 / `test_gossip_pool_empty_greyed`：空池置灰不弹空白气泡 / `test_observation_text_no_numeric_panel`：员工详情无数值面板禁项 grep 断言 + [P] scripts.md#N4 气泡阅读 ≤~5s、点开后 30s 内无新增待办感）；UI 细节唯一真源=V1-17（观察文本行=员工详情区常显行、气泡=z3 浮层不入档、猫=零状态点不入档不发信号、gossip_pool_empty_reason 置灰原因）；设计定位防过度设计：真空期真解=V1-16 三线+V1-08 图鉴，本通道只是情绪补偿——禁加数值/禁加角标/禁接成就（E-1 三禁同源）。
- **边界态**：吐槽入口挂载点**待拍板**（Dock 第 5 键 vs 员工卡区轻键——DR-020 封闭"Dock 三键"，与 V1-09 招聘入口合并为一个待拍板项，动 Dock 键数则登 [change]）；猫点击无禁用态（零状态永不空）；池内容供给=文案席（F1 归内容席，本条只做通道与触发）。
- **验收锚**：DR-029 E"F1 吐槽池归内容席；猫=零状态版；三禁维持+放行通道焊死；定位=止痛药，真解=C 三线+图鉴"+DR-029 A-8"表达=观察文本+周报彩蛋行，禁数值面板"+DR-022③ 术语提示纪律。
- **规格与切片**：**缺口规格 §N4 整卡引用**（不重写不重命名）；UI 规格 V1-17；映射表行 V1-17；信标=ui_gossip_bubble_active（事件型）/ui_observation_line_present（快照，附录 D）。
- **依赖**：N4 issue 待建（1.0 前置，随批1 文案管线）；文案席 F1 池供给；**吐槽入口挂载点待拍板**（动 Dock 键数则 [change]）；无 [change]（挂载不落 Dock 则零改栈）。

### D1-10-03 试玩脚本真源 scripts.md（N8 整卡承载）
- **功能点**：建立 docs/playtest/scripts.md 作为全部 [P] 项引用的试玩脚本真源：先落 N1–N8 各条 [P] 的三段式脚本+基础回放脚本，后续 issue 建时同步追加。
- **规则细化**：**整卡规格引用 §N8 不重写**——3 [T]+1 [P] 原样引用，**文档类验收标注="校验脚本名"非"GUT 用例名"（口径 5，本卷全文统一）**：`test_playtest_scripts_sections_complete`（N1–N8 每条 [P] 编号锚点齐备含 N6 占位）/ `test_playtest_scripts_metrics_consistent`（基础回放与 N7/N1 代理指标一致：≤~10s/≤2 次点击等）/ `test_playtest_scripts_reproducible_setup`（前置存档态构造法可独立复现）——三条均纯文档校验入 CI 独立 check 不进 verify.sh 必跑集（DR-030 门禁分离，m12）；[P] scripts.md#base（干净安装照 #base 跑通，偏差 =0 处，回放全程 ≤~15 分钟）；**[P] 锚占位沿用各稿现状（口径 8）：scripts.md 未建，N1–N5/N7 各条 [P] 的 `docs/playtest/scripts.md#N*` 引用在建号后由 N8 统一映射替换（语义 slug），本卷不发明编号**。
- **边界态**：文件头注明"真源性质+追加纪律（新 issue 建 [P] 项时同步追加，禁止引用不存在的锚点）"；与试玩反馈固定表单（DR-030 反馈闭环，字段版式待首份反馈 issue 化定稿）互相引用；零游戏代码（流程件）。
- **验收锚**：DR-030"试玩闭环（反馈表单 issue 化/回写复核/停线复盘…）"+issue-spec §6"[P] 三段式：步骤脚本+预期感受+代理指标。[P] 项留给真人试玩勾选，禁止 agent 代跑冒充完成"。
- **规格与切片**：**缺口规格 §N8 整卡引用**（不重写不重命名）；校验脚本入 CI 独立 check（PR-β 同域）；锚点 slug 命名统一沿 §N8 建档动作（如 #return-summary-01）。
- **依赖**：N8 issue 待建（与 N1–N5/N7 建号同批或先行——[P] 总前置）；PR-β（引用存在性检查可选增强）；无 [change]（流程件无双签依据，m2 修正）。

### D1-10-04 INTRO 停喂语义轻度复议登记（反馈①——圆桌裁决项材料）
- **功能点**：产出 INTRO 停喂语义轻度复议材料并登记圆桌议程（与 N6 多任务槽同场裁决建议），**复议前现状行为保持不动**（DR-029 D-3 裁决效力维持）。
- **规则细化**：材料两案并陈（a 维持现状：INTRO z1 不拦流淌，世界照走——DR-029 D-3"开场白压缩 2 句或可跳、不拦流淌"现裁；b 复议案：读开场白期间临时停喂，属 z2 语义增员——触碰 DR-020 z2 白名单封闭纪律与 DR-029 D-3，须双案对比数据支持）；现状行为断言已有（test_intro_and_staff_stats.gd INTRO z1 不停喂实证），材料引用不重写；结论落点=圆桌纪要归档+v013 反馈①遗留行回填（沿 §6.1 双签后动作模式）；**未裁前任何 PR 不得顺手改 INTRO 层级**（DR 裁决效力维持，未裁不动工）。
- **边界态**：若裁 b 案=新增 z2 成员属 DR-020 白名单扩展（[change] 级复议，非本卷执行）；若裁 a 案=关闭 v013 反馈①遗留行，开场白保持"随手关、关了世界照走"。
- **验收锚**：v013 反馈①分诊行原文"INTRO 是 z1 常规层不拦流淌（v0.1.3 按 DR-020 z2 白名单实现，DR-029 D-3'开场不拦流淌'裁决）；但玩家期待'读开场白时世界等待'——设计意图与体验期待冲突，属轻度复议候选（非 bug）→圆桌裁决项"。
- **规格与切片**：复议材料段（本卷 §D1-10-04 即材料底稿，圆桌时直接引用）；无新 issue（裁决动作归圆桌，材料归本卷）；现状回归=test_intro_and_staff_stats.gd 既有断言。
- **依赖**：**圆桌裁决（与 N6 同场建议）**；v013 反馈①遗留行回填；[change] 级（仅当裁 b 案）。

### D1-10-05 术语首次提示触发机制落点（DR-022③ 文案纪律的机制化预留）
- **功能点**：把"术语首次出现配触发式一句话提示"从文案纪律落为机制预留点：术语首现触发+一次性提示通道（texts 键位随文案批实录），本卷只锁机制位不产文本。
- **规则细化**：触发口径=术语在 UI 可见面首次出现（迷雾面板/周报/教程气泡均为潜在触发面，具体触发面**本卷不定**——随 N1 引导气泡通道与批1 文案批联合定，防发明）；一次性=不跨周目重置（设计稿 2 红线"术语首次提示不继承（教学豁免 ≠ 术语豁免，DR-022③ 一次性文本）"原文——**不继承恰是本纪律的一半**，跨周目不重弹）；提示形态=一句话 toast 级（非弹层），不进 z2 不阻塞；文本供给=文案席（DR-022③"术语首次出现配触发式一句话提示（文案纪律）"归文案管线）。
- **边界态**：0 术语触发（全程未遇新术语）=零 toast 零残留；同周多术语首现=逐条提示但同屏 ≤3（toast 既有规则）不叠加阻塞；已提示术语再次出现=静默。
- **验收锚**：DR-022③原文+设计稿 2"不继承什么"红线原文（术语首次提示不继承）+GDD §4 术语口径行"术语首次出现配触发式一句话提示（文案纪律）"。
- **规格与切片**：机制预留点（并入 N1 引导通道单或批1 文案批，归属建号时定，S 规模）；GUT：once 语义断言沿 N1 气泡 once 用例模式（test_anchor_bubble_dismiss_and_once 同型，用例名测试席定不预造）。
- **依赖**：N1（通道载体候选）+文案批（文本供给）；**跨周目不重置**与设计稿 2 meta 通道关联（#44 落地后核）；无 [change]。

---

## 【模块×深化点×出处对账表】

> 27 个功能点逐条对账：出处=试玩反馈/缺口 N/PR 修复链/闭单缺项/DR 演进预留/代码内演进注释，全部可回溯，无发明项；"引用规格"列=已有产出编号（防分叉，本卷不重写）。

| 模块 | 功能点 | 出处（真源） | 引用规格（不重写） | [change]/待裁 |
|---|---|---|---|---|
| 1 时间驱动 | D1-01-01 指令/信号对账常量化 | DR-030②+圆桌纪要§四 PR-α 原文 | PR-α；v013 验收点 test_view_contract | 无 |
| 1 时间驱动 | D1-01-02 收入脉冲随机源收口 | game_world.gd:143 代码内演进注释"PR7 换 rng_stream"+DR-021 M2+ADR-0008 | 工程债收口单（PR-α 同批）；test_game_world.gd 万周断言复用 | 无（形态主程序裁量） |
| 2 经济 | D1-02-01 断言区间 JSON 合并 | DR-027+GDD §15+assertion_bounds `_meta.version="v1.0-frozen"` | 债收口单；test_assertion_bounds.gd 回归 | 无 |
| 2 经济 | D1-02-02 opening.json 真源收口 | DR-010 单一真源先例+opening.json `_meta.note` | 文案批增量单（批1 管线）；test_texts.gd 三断言 | 无 |
| 3 人员任务 | D1-03-01 【N6 占位】多任务槽 | v013 反馈④a 分诊+DR-018 演进预留+DR-023/ST4 | **设计稿 1 占位引用**；§N6 占位段；V1-05 | **[change] 未双签** |
| 3 人员任务 | D1-03-02 指派链路对账断言 | v013 反馈④b 分诊（"零断言锁定，回归裸奔"） | PR-α；test_staff_assign_signals/test_view_contract | 无 |
| 4 科技迷雾 | D1-04-01 【Q4 引用】节点定稿窗口过期处置 | GDD §17 Q4 原文+GDD §8.1+techs.json 13 节点实证 | 登记册更新单；V6 断言 | 无（引用 Q4 不代裁） |
| 4 科技迷雾 | D1-04-02 【Q3 引用】灵感兜底复核 | GDD §17 Q3 原文+DR-027⑤ | 登记册复核单；test_rng_stream/test_tech_fog 回归 | 无（引用 Q3 不代裁） |
| 4 科技迷雾 | D1-04-03 扩树信号触发器监控口径 | DR-027①+tech-tree 全景 §5.4/§三（"维持 14 不动"） | 试玩反馈表单采集口径增补（随 N8 同批）；V10 断言 | 无（监控项零机制改动） |
| 5 训练 SOTA | D1-05-01 命名仪式 UI 落地 | #18 闭单缺项（"[T] 信号渲染完整…命名框逐一有落点"自检与实证差口+"[P] 署名仪式感"未勾）+GDD §9+DR-002 | 修复单（PR-α 批暴露后建号）；test_panel_stack 既有用例扩展；texts 13 个 naming_* 键零新增 | 无（触发时点主程序裁量） |
| 5 训练 SOTA | D1-05-02 三线计数器（数据侧） | DR-029 C-6+GDD §3 自由期三线 | **§N3 整卡引用**；V1-16+映射表行 V1-16 | 无 |
| 5 训练 SOTA | D1-05-03 SOTA 次数计数入终局档 | #16 闭单缺项（验收点 4 原文"SOTA 次数"vs summary 实测无此字段）+GDD §12 | 修复单；test_game_over_and_save.gd 验收点 4 扩展 | 无 |
| 6 竞对 | D1-06-01 G-2 抢发文案+G-3 窗口口径 | DR-029 G-2/G-3+DR-027④+#14 闭单缺项（边界提案 §2.2 查证列） | **§N5 整卡引用**；V1-11+映射表行 V1-11；#40 同源互引（m9） | 无 |
| 7 事件 | D1-07-01 toast 计时链路收口 | DR-012"计时绑游戏时间"+panel_stack.gd :207 既有实现 | PR-α 同批债收口单；test_panel_stack toast 段扩展 | 无 |
| 7 事件 | D1-07-02 周报载荷字段集接线 | GDD §14"周报 report 字段集冻结"原文+GDD §13 心跳时刻 | 修复/补齐单；test_dashboard_presenter 扩展；Formatter 回归 | 无（字段集已裁，兑现缺口） |
| 8 存档 | D1-08-01 退出/切后台真实挂点 | #16 闭单缺项（三路径断言实测=直调 request_save）+GDD §12/DR-008 | 修复单；test_game_over_and_save.gd 路径 2 升级 | 无（Web 行为疑点 S2-05） |
| 8 存档 | D1-08-02 存档时间戳字段 | §N1 实施提示原文（session_resumed 时间戳差判定）+GDD §12 开放容器纪律 | N1 前置数据点（并入 N1 或独立 S 单） | 无（键位主程序裁量） |
| 9 界面 | D1-09-01 暂停菜单落地 | #67 issue 原文+映射表 §2 PAUSE_MENU 行 | **PR-δ=issue #67（已立）** | 无（重开归档待 #37/#44；确认弹层=开放问题①） |
| 9 界面 | D1-09-02 流速/暂停常显态 | v013 反馈②+DR-020 | PR-γ；**§N7 验收 1/2**；V1-04+映射表行 V1-04 | 层级高于遮罩=[提案·待拍板] |
| 9 界面 | D1-09-03 员工实体卡 | v013 反馈③+DR-015 | PR-γ；**§N7 验收 3**；V1-03+映射表行 V1-03 | 无 |
| 9 界面 | D1-09-04 周报自动弹 R3 结构 | GDD §13 R3 原文+DR-020+#18 闭单结构落差 | 修复/补齐单；test_dashboard_presenter 扩展 | 无（显著变化口径建号时定） |
| 9 界面 | D1-09-05 selftest 信标基建扩场景 | 圆桌纪要 §四"PR-γ selftest 扩场景+信标+S6 硬化"原文+v013 验收点 S9 | PR-γ 组成部分；映射表信标列回填纪律 | 无 |
| 10 引导文案 | D1-10-01 归来摘要+引导气泡 | DR-029 D-2/D-3（M2-① 修正留痕） | **§N1 整卡引用**；V1-01/V1-02+映射表行 V1-01/02 | 无（条数/停留=等试玩池） |
| 10 引导文案 | D1-10-02 吐槽键+观察文本 | DR-029 A-8/E-1+DR-022③ | **§N4 整卡引用**；V1-17+映射表行 V1-17 | 挂载点待拍板（动 Dock 键数则 [change]） |
| 10 引导文案 | D1-10-03 scripts.md 真源 | DR-030 试玩闭环+issue-spec §6 | **§N8 整卡引用**（校验脚本名口径） | 无（流程件免双签，m2） |
| 10 引导文案 | D1-10-04 INTRO 停喂复议登记 | v013 反馈①分诊（"轻度复议候选，非 bug"） | 本卷=材料底稿；test_intro_and_staff_stats 回归 | **圆桌裁决**（与 N6 同场建议；裁 b 案=[change]） |
| 10 引导文案 | D1-10-05 术语首次提示机制落点 | DR-022③+设计稿 2"术语首次提示不继承"红线+GDD §4 | 机制预留点（随 N1 通道或批1 文案批）；toast 既有规则 | 无（触发面随 N1 联合定） |

**对账结论**：27 点出处全部落位（试玩反馈×4 点④①②③、缺口 N×4 整卡+2 拆点、PR 修复链×7、闭单缺项×5、DR/代码演进预留×7、开放问题引用×2）；N6 零规格占位（口径 3）、V1-13 类边界在本卷无载体（危机卡属卷二 #31，两卷口径一致）；两卷 N1 双落位已在 §0.3+D1-10-01 双向标注，规格零分叉。

## 【疑点上报】（实证发现，供制作人/主程序/圆桌处置）

| # | 疑点 | 实证 | 建议处置 | 影响面 |
|---|---|---|---|---|
| S2-01 | 收入脉冲随机源内联且 restore 路径不回读：settle_week 内 `RandomNumberGenerator.new()`+`hash(str(_income_roll_seed,":",week))` 播种；`_income_roll_seed` 仅在 start_new_game 赋值（:143 seed+1 / :183 rng_seed 双处），restore 路径（:338–390 全文核验）不恢复该字段 | 读档后同 seed 双跑哈希一致断言（test_game_world）不覆盖"读档后再跑"场景；与 DR-021 M2/ADR-0008 分域纪律存在口径差 | D1-01-02 收口单处置（迁 rng_stream 或改确定性查表，主程序裁量）；先补"读档后哈希一致"回归断言再动 | 确定性验收边界；万周 nightly 不受影响 |
| S2-02 | 14 节点缺 1：techs.json 实表 13 节点，器用域（tool_use）仅 arm_will 1 节点，GDD §8.1 器用行=2 节点；且 Q4（长忆/器用 4 节点名）截止窗（PR5 录表前）已过 | python 实列 nodes=13（silver_leash…embodied）；GDD §8.1 与 DR-023 稿面均 14 | D1-04-01 归档处置：v0.2 前复核，"补第 14 节点"或"修订 GDD §8.1 表述"二选一留痕（改结构=黄级） | V6 分位断言口径；Q4 归档 |
| S2-03 | 命名仪式 UI 三缺：PanelStack.NAMING_DIALOG 在 z2 阻塞集合+presenter.open_naming_dialog() push 方法+texts.json 13 个 naming_* 键俱全，但无命名场景（src/ui/modals/ 无 naming tscn）、main.gd `_on_panel_pushed` 无 NAMING_DIALOG 分支、push 方法无任何调用方——push 即"遮罩出现无面板"，与 #67 同构；#18 自检"信号渲染完整断言"勾选与实证差口 | grep 实证（NAMING_DIALOG 分支缺失；open_naming_dialog 仅测试直调）；#18 自证表勾选"[x] 信号渲染完整" | D1-05-01 修复单（PR-α 批评审时暴露建号）；同时提示 code-review 席：自证表证据"只引用不复述"纪律（DR-030②）对"逐一有落点"类全称断言应附逐项清单 | 署名仪式感 [P] 验收（DR-002/截图时刻）；z2 白名单完整性 |
| S2-04 | toast 倒计时驱动链缺失：PanelStack.update_toasts(delta) 全库零调用点（grep 实证），DR-012"计时绑游戏时间"实际无喂帧源，toast 可能不消散 | grep update_toasts 零命中（main.gd/_process 只喂 driver） | D1-07-01 收口单（形态主程序裁量） | toast 同屏 ≤3 语义实效；V1-11 传闻 toast（卷二）前置 |
| S2-05 | 退出/切后台保险无真实挂点：src/ 全域无 NOTIFICATION_APPLICATION_FOCUS_OUT / WM_CLOSE_REQUEST 监听（main.gd 仅 RESIZED），#16 路径 2 测试为直调 request_save("suspend")；且 Web/Pages 形态下浏览器 visibilitychange→Godot 通知的映射行为未验证 | test_game_over_and_save.gd :26–31 直调实证；main.gd `_notification` 仅 RESIZED | D1-08-01 补挂点+Web 实测（映射形态主程序裁量，本卷不发明方案） | 三保险语义完整性；移动端试玩数据安全 |
| S2-06 | R3 自动周报结构落差：presenter `_on_week_settled` 无条件每周 push AUTO_REPORT（:131–138），GDD §13"≥~5% 显著变化才自动弹+其余角标+4x 不弹"未实现；#18 闭单双态断言不覆盖频率维度 | dashboard_presenter.gd 实证；GDD §13 R3 行 | D1-09-04 补齐单；显著变化口径建号时由主策划+数值席定 | 决策密度宪法（DR-009 有效决策 1–3/30s 的周报噪音源） |
| S2-07 | 周报载荷空壳：settle_week 的 report 仅含 week/money_row/line_state 三键，weekly_report_dialog 读 `report.get("rows", [])` 但载荷无 rows 键——周报弹层恒走"本周运转平稳"兜底文案；标题代码硬编码"第 %d 周 周报"（违反"文本一律键名引用"通用纪律）；texts.json 6 个 report_* 键全部零渲染消费（仅 2 键进 TEXT_STAT_LINE_KEYS 常量） | game_world.gd :543–553 与 weekly_report_dialog.gd :37–40 双侧实证；grep report_headline 零消费 | D1-07-02 补齐单（GDD §14 字段集兑现）；#18 自检"[T] 信号渲染完整断言"的周报行维度应复核 | 心跳时刻（GDD §13"周报时刻——玩家据此做下一轮规划"）的实际信息量；texts 40 键承诺兑现 |
| S2-08 | Game Over summary 缺 SOTA 次数字段：#16 验收点 4 原文"summary 字典字段断言（周数/SOTA 次数/最高分）"，实测 summary=week/best_score/rival_best/model_name/cum_income/reason 六键无次数；测试断言仅 has 周数/最高分/竞对基线/累计收入四项——闭单自检与验收点原文的差口未被测试暴露 | get_game_over_summary()（game_world.gd :315–323）与 test_game_over_and_save.gd :84–94 双侧实证 | D1-05-03 补齐单（S 规模）；Game Over 卡渲染同步补行 | 终局仪式信息完整性；#18"[P] Game Over 卡"试玩验收输入 |
| S2-09 | DR-002"宣发改名卡 v0.2"演进预留未收编：改名卡既不在卷二 21 条（#26–#45+N1/N2 无改名卡），也无缺口编号——"长期定案+演进预留（改名卡为已列演进（绿））"在两卷对账中均无落点 | decision-log DR-002 演进预留列 vs 卷二对账表逐行核对；边界提案 §五 DR-002 行标"已实施"（仅立项命名+宣发部分） | 建议：或补缺口编号（N 系外延）或显式改判至 v2.0 池，二选一留痕（主策划复核，本卷不代裁不立案） | DR 演进预留对账完整性（边界提案 §五"零漏译"目标的尾巴） |

**待拍板/待裁项汇总**（非疑点，系已登记口径）：①V1-04 层级高于遮罩 [提案·待拍板]（口径 2）；②N6 多任务槽 [change] 双签+圆桌（口径 3）；③N4 吐槽入口挂载点（动 Dock 键数则 [change]）；④INTRO 停喂复议（反馈①，圆桌与 N6 同场建议）；⑤主动重开确认弹层+归档口径（设计稿 2 开放问题①②）；⑥Q3/Q4 复核（登记册）；⑦等试玩池（摘要条数/气泡停留/gate 三值/警告线——沿边界提案 §3.3，随 1.0 试玩转正）。

## 【下游省工自问】

1. **主程序实施会先问：哪些单先开？**——修复链四单中仅 PR-δ=#67 已立；本卷给出归属建议：PR-α 先行（其拆点 D1-01-01/D1-03-02/D1-05-01 暴露/D1-07-01/D1-08-01 同批评审）、PR-γ 次之（承载 N7=D1-09-02/03）、PR-β 最先但属流程件（lint 卡口先于 N1–N5/N7/N8 建号，边界提案尾注 ⓪①②）。债收口单（D1-01-02/D1-02-01/D1-02-02/D1-07-01）已标"工程裁量归属"，不必等排期裁决。
2. **测试席会问：用例名哪些不能改？**——全部带名的 [T] 锚（test_staff_assign_signals/test_view_contract/test_speed_pause_always_visible/test_z2_auto_pause_distinct/test_staff_entity_cards_and_assign_refresh/test_freedom_* ×3/test_scoop_copy_collision_key/test_rumor_pool_two_week_window/test_rumor_determinism_same_seed/test_return_summary_* ×3/test_anchor_bubble_dismiss_and_once/test_gossip_* ×3/test_observation_text_no_numeric_panel/test_playtest_scripts_* ×3）**原样引用不重命名**（硬纪律）；本卷未给名的扩展断言（D1-07-01 计时边界/D1-08-01 挂点升级/D1-09-04 三断言）显式留白由测试席沿既有文件风格定，防两套命名。
3. **UI 席会问：映射表行动谁动？**——本卷零改表：V1-03/04/16/17 行与 §2 既有 5 行全部原样引用；唯一 [提案·待拍板]（V1-04 层级）拍板权在制作人/UI 席，拍板前该节不作为实施验收来源（UI 规格卷首纪律）。D1-09-03 员工卡与 StaffRow 的替换关系属实施细节，走"先改表再改码"纪律（映射表 §3）。
4. **issue-pipeline 建号会问：批1 前置顺序？**——PR-β（lint）→N8（[P] 总前置，或与 N1–N5/N7 同批）→N1–N5/N7→PR-α/PR-γ→批1（卷二）。N6/N4 挂载点/INTRO 三项不建号（未裁）；D1-05-01/D1-08-01/D1-09-04 三张闭单缺项修复单建议随 PR-α 评审同批立项，规模均 S~M。
5. **制作人拍板面最小化**——本卷需要拍板的只有：疑点 S2-01…S2-06 的处置优先级（全部有实证、有建议处置）、V1-04 层级 [提案·待拍板]、圆桌议程合并（N6+INTRO 复议同场）。其余全部为已裁内容的兑现与占位，零新裁决。
6. **与卷二的对账口径**——N1 双落位（§0.3）、N5 先行于 #40（m9）、N6 双签前零功能点（脚注同源）、[T]/[P] 计数互不混算（卷二 T=95/P=19 以其附 11 为准，本卷引用的 N 系计数以 gap-issue-specs 自查记录为准：N1=5/N2=4/N3=4/N4=4/N5=4/N7=4/N8=4）。
7. **本卷与边界提案 §五"零漏译"的关系**——本卷新增 6 条疑点（S2-01…S2-06 类实证债）全部是**代码实证对文档承诺的差口**（闭单自检 vs 实现、GDD 字段集 vs 载荷、演进注释 vs 未兑现），性质=验收补齐非范围新增；S2-09（DR-002 改名卡预留无落点）是唯一指向"DR 演进预留对账完整性"的疑点，移交主策划复核。两卷合并后建议把对账表模式（卷二 §五先例+本卷 §疑点上报）固化为"每批次关闭时强制销账工具"（边界提案跨席找茬 2 已提，process 标签随下一里程碑批量裁决）。

