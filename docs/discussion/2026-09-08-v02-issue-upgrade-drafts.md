# v0.2 issue 升版草稿（旧格式 → issue-spec 新规格 · 2026-09-08）

> 性质：**草稿文档**。主策划席（gd-lead-designer）产出，升版拍板前**不执行 gh issue edit**。
> 使命：把存量 open issue #26–#45（共 20 个编号；其中 #33 已关闭为误建重复，无升版条目，其余 19 条逐个升版）升为符合 `docs/standards/issue-spec.md` 新规格的正文草稿。
> 升版纪律：**不改范围、不重开裁决**；DR 摘录照抄原文（禁补写、禁发明新数值）；~ 占位照抄；原正文已有多条 [T] 全部保留并补 GUT 用例名。
> 版本口径：v0.2 三批（批1=#26–#37 p1 / 批2=#38–#43 p2 / 批3=#44/#45）→ **收拢进 v1.0（MVP 正式发布版）**。
> 批次归属真源：`docs/discussion/2026-09-07-v02-scheduling-adjudication.md`（§一范围裁决表/§二批次表）；机制真源：`docs/gdd/gdd.md` §16 + DR-028/028R/029（`docs/discussion/decision-log.md`）。
> GUT 用例命名对齐 `tests/unit/` 既有风格（`test_economy.gd`/`test_event_engine.gd`/`test_panel_stack.gd`…，snake_case 断言语义直书）；界面类条目映射表行真源：`docs/standards/ui-state-visual-mapping.md`（信标列落地前豁免）。
> [P] 试玩脚本锚：`docs/playtest/scripts.md` **尚未建**，本文先给 #编号 占位锚，scripts 建档时以实际编号替换（升版遗留，见文末）。

## 批1（#26–#37，经济+归来感，设计稿先行）

### #26 [批1][稿] v0.2 经济稿 5 项设计稿（deploy/三阶段参数/支线3卡/影响力接口/融资锁值） ｜批1｜M
**升版变更**：拆 [P] 三段式（三刀预检补前置态+操作序列+代理指标）；2 条 [T] 按验收三要素补边界与可观察终态各 1 条（合计 4 [T]+1 [P]）；数值硬约束 7 条保持逐条罗列并指认 #28 定案联动。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜设计稿类：[T] 断言形态（文档 lint vs 清单核对）为已登记遗留（自问 #3/#5①）

**新正文**：
## 目标
产出 v0.2 经济稿 5 项设计稿（DR-028 §八任务清单+DR-029 数值硬约束 7 条为前置输入），代码实施等试玩裁决后按批次开工。

- 依赖 / 关联：数值硬约束 7 条标定（#28）；DR-028/028R/029 + 排期裁决 #8；规模：M
- 决策依据：DR-028 ⑤（融资三键 50–80k/稀释~12%/≤2 次走主策划锁口径→PR10 V-sim 收口）、DR-028 ④（deploy 门槛动态锚 max(60, sota_top_score−15)）、DR-028R（R-1 独角兽期融资脉冲收支行+上市期 API 常量收支行；R-2 支线危机收入两步走——第一批事件卡级验证后升常驻；新增影响力门票汇率 ~1k¥/影）
- 验收点：
  - [ ] [T] 5 项设计稿齐且逐项可独立评审：deploy 闭环（动态锚 max(60, sota_top−15)/定价三档/reserved 卡时）/三阶段参数表（gate=累计经营收入口径，DR-028 ⑨ 禁估值字段）/支线 3 卡（贷款必带偿还 本金×1.2/4 周 delayed money，DR-028 ⑧）/影响力↔支线接口（汇率 ~1k¥/影，DR-028R）/融资三键锁值（正常路径：5 项齐即过）（校验脚本名：test_econ_draft_five_items_present——文档类产出，机器校验非 GUT，经对抗评审 m12）
  - [ ] [T] 边界态：缺任一项或该项引用的 DR 未裁数值未锁 → 设计稿标记为"待补"不得进入批次实现清单，并显式列出缺的 DR 编号（校验脚本名：test_econ_draft_incomplete_rejected——文档类，m12）
  - [ ] [T] 可观察终态：V-sim 复算点⑥⑦⑧跑通并留报告，支线开启后 V1 双断言仍∈[0.5%,8%]（经济纪要 §七/§十新增断言，~ 占位待标定值照抄）（校验脚本名：test_econ_draft_vsim_points_replay_pass——文档类，m12）
  - [ ] [T] 数值硬约束 7 条逐条落实（drain×train_weeks<~80、eff 分母含 reserved、脉冲 5–8 影 or 宿敌首冠、p50+30 注释出处、机会窗口连续衰减、签约金条件于 quality_tier、condition 进供给模型；每条标注 #28 定案结论或"待 #28"）（校验脚本名：test_econ_draft_hard_constraints_covered——文档类，m12）
  - [ ] [P] 过三刀口径预检（危机 30 秒可选动作/跃迁 40 秒可解释/5 分钟 1 次主动收入决策，DR-028 通用门槛）（试玩脚本：docs/playtest/scripts.md#econ-draft-01）｜步骤脚本：前置态=5 项设计稿终稿在手+评审会屏显 V-sim 曲线；操作序列=按三刀逐刀对稿内场景口头走查（危机剧本/跃迁剧本/常态 5 分钟切片）各限 30/40/300 秒；预期感受：走查不吃力、每刀都能指到稿内对应参数行；代理指标：三刀走查每刀至少指认 1 处可改参数并记入评审记录，0 刀无对照。
- 实施提示：数值席/主策划联合产出；V-sim 复算点⑥⑦⑧+新增断言（支线开启后 V1 双断言仍∈[0.5%,8%]）见经济纪要 §七/§十；数据表落点 `src/data/`（stages.json/economy.json/tasks.json 占位行不动，DR-028 长期定稿全部 ~ 占位，PR3/PR6/PR10 收口）。

### #27 [批1][稿] 影响力累计曲线+出口接口+榜单脉冲联标 ｜批1｜M
**升版变更**：拆 [P] 三段式（死资源体感补可对照行为+量化句）；2 条 [T] 补边界态与可观察终态各 1 条（合计 3 [T]+1 [P]）；"三口互挤"联标义务（GDD Q2 原文）从实施提示提为显式验收。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜Q2“三口互挤”联标义务显式化，未代数值席定案

**新正文**：
## 目标
锁定影响力累计曲线（DR-028R 新登记空白），并与榜单首冠脉冲（DR-029 B-5）联标。

- 依赖 / 关联：无前置（设计稿先行）；下游 #34/#43 按本稿定案实现；规模：M
- 决策依据：DR-028R 锚点 3（汇率 ~1k¥/影、门票≈存量 15–25%）+ DR-029 B-5（脉冲压 5–8 影 or 宿敌首冠制，二选一由本稿对比定）
- 验收点：
  - [ ] [T] 正常路径：160 周影响力累计曲线（~300–600 存量假设复核，~ 占位照抄）+ 消费出口表（猎头 20–40［出处=growth 席提案，待 #28 标定收口］/咨询 30/赞助 40/premium API 60–80，咨询/赞助/premium 出自 DR-028R 原文）自洽成稿（GUT 用例名：test_influence_curve_and_exits_consistent）
  - [ ] [T] 边界态：存量取下限（~300）与上限（~600）两端各过一遍出口表，门票总耗仍在 DR-028R 的存量 15–25% 带内（越带即标联标失败并回改曲线）（GUT 用例名：test_influence_exit_budget_within_band）
  - [ ] [T] 可观察终态：B-5 裁定落稿——脉冲方案 vs 宿敌首冠制的对比数据与推荐各 1 节，结论句可直接被 #34/#43 引用为验收锚（GUT 用例名：test_b5_adjudication_reachable）
  - [ ] [P] 影响力不再死资源（三画像第二轮共识验证）（试玩脚本：docs/playtest/scripts.md#influence-01）｜步骤脚本：前置态=读批2 消费方解锁前的档，影响力存量高于任一出口门槛；操作序列=打开周报看存量→进任一消费出口完成一次消费→回看存量与所得；预期感受：花出去有去向、攒着有盼头，不再对着死数值发呆；代理指标：一次试玩会话内 ≥1 次主动影响力消费，且玩家能一句话说出"花在哪、换来什么"。
- 实施提示：主策划席负责；融资估值三处共用同一存量（门票×汇率×估值联标，"三口互挤"须 V-sim 影响力分配压力测试——GDD §17 Q2 原文）；影响力累计曲线=新登记空白待主策划锁（DR-028R）。

### #28 [批1] 数值硬约束 7 条标定报告 ｜批1｜M
**升版变更**：既有 7 条 [T] 全保留并逐条补 GUT 用例名；新增"报告缺项边界"[T] 与"可观察终态"[T] 各 1（合计 9 [T]+1 [P]）；[P] 拆三段式。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜7 条硬约束逐条可回溯 DR-029§二，未重推 exploit 结论

**新正文**：
## 目标
对 DR-029 纪要 §二 的 7 条数值硬约束逐条标定，产出报告供批1 全部实现 PR 引用。

- 依赖 / 关联：无前置；下游 #26/#32/#43 引用本报告定案；规模：M
- 决策依据：DR-029（深度画像推演结论，§二数值硬约束 7 条）
- 验收点：
  - [ ] [T] ①drain×train_weeks<~80 或训练期免扣（倾向后者）二选一定案（GUT 用例名：test_hc1_drain_or_exempt_decided）
  - [ ] [T] ②eff 分母=ΔA/千卡时含 reserved+发版冷却下限（防微调高频发版刷）（GUT 用例名：test_hc2_eff_denominator_includes_reserved）
  - [ ] [T] ③影响力脉冲 5–8 影 or 宿敌首冠（与 #27 联动）（GUT 用例名：test_hc3_pulse_or_first_crown_decided）
  - [ ] [T] ④stages.json 常数注释出处（p50+30=P90 断言带+15 的 2 倍，~ 占位照抄）（GUT 用例名：test_hc4_stage_constant_provenance_noted）
  - [ ] [T] ⑤机会窗口连续衰减参数（每超 ~10 周 ×0.95 下限 0.7，~ 占位照抄）（GUT 用例名：test_hc5_window_decay_params_locked）
  - [ ] [T] ⑥签约金=quality_tier 条件化（贵=可见信息多）（GUT 用例名：test_hc6_signing_bonus_by_tier）
  - [ ] [T] ⑦condition 进 V-sim 供给模型（隐藏 downtime 税显式化）（GUT 用例名：test_hc7_condition_in_supply_model）
  - [ ] [T] 边界态：任一条无标定值或与既有 DR 冲突 → 报告必须显式标"未定案+冲突 DR 编号"，该条不得被下游引用为定案（GUT 用例名：test_hc_report_undecided_marked）
  - [ ] [T] 可观察终态：V-sim 同 seed 复算全过留证（V1/V2/V6/V10 不破带，输出与报告同 PR 归档）（GUT 用例名：test_hc_vsim_same_seed_replay_pass）
  - [ ] [P] 报告可作为实现 PR 的"唯一数值出处"被顺畅引用（试玩脚本：docs/playtest/scripts.md#hc-report-01）｜步骤脚本：前置态=报告合稿+1 条实现 PR 起草中；操作序列=实施 agent 按索引查任一硬约束的定案值→抄进 PR 验收点；预期感受：一次查到、无需回翻纪要原文；代理指标：随机抽 2 条约束，从报告到 PR 验收句的翻译 ≤1 分钟且零口径歧义。
- 实施提示：数值席产出；eff 榜 exploit（停 t1 流 1.7 倍）与 delta 死榜推演过程在 DR-029 审视记录，勿重推。

### #29 [批1] 融资收支行（50–80k/稀释~12%/≤2 次） ｜批1｜M
**升版变更**：既有 3 条 [T] 全保留（超次拒绝并入过账口条、读档还原并入 V1 条，信息零删）；独角兽期跑道展示行自实施提示提为显式验收（合计 4 [T]+1 [P]）；[P] 拆三段式。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜红级否决（估值/股权字段）保持为验收内边界

**新正文**：
## 目标
实现融资收支行（独角兽期结构必要件，DR-028R R-1R）。

- 依赖 / 关联：#26 经济稿+PR10 断言收窄；规模：M
- 决策依据：DR-028R R-1R（独角兽期融资脉冲收支行=结构必要件）；DR-029 B-5（金额×名次系数 1.0/0.8/0.6~，~ 占位照抄）——原稿"sources 行 schema 占位黄级激活"非 DR 原文（DR-006 原文为"schema 占位（绿）"），经对抗评审 M2-④ 删去如实挂锚
- 验收点：
  - [ ] [T] 正常路径：融资=决策卡（金额 vs 稀释两难），≤2 次/局，稀释入 flags 计数（不入股权字段=红级否决维持，DR-028 ①）（GUT 用例名：test_financing_decision_card_max_two_per_run）
  - [ ] [T] 边界态：第 3 次发起融资 → 拒绝且给出次数上限提示；apply_delta 唯一过账口（DR-018 grep 断言不破）、RNG 零新增消费点（GUT 用例名：test_financing_over_limit_rejected）
  - [ ] [T] 可观察终态：融资入账后 cash 变化与 flags 稀释计数可从读档还原；V1 双断言不破（政策隔离双跑，DR-028R R-2）（GUT 用例名：test_financing_income_not_in_cum_income）
  - [ ] [T] 独角兽期跑道展示行随本 PR 上周报（texts 增键=绿级）（GUT 用例名：test_financing_runway_row_present）
  - [ ] [P] 融资到账仪式感（不占 L3 名额）（试玩脚本：docs/playtest/scripts.md#financing-01）｜步骤脚本：前置态=独角兽期档+触发融资决策卡；操作序列=读卡→选定金额档→确认→回到主台看周报；预期感受：到账有可感反馈（周报行+现金跳变），但不打断流淌节奏；代理指标：从确认到账到玩家重新点名下一动作 ≤10 秒，且无 L3 弹层遮罩。
- 实施提示：economy.accrue_week() 收支行实现（E 矩阵黄级）；schema sources 行占位黄级激活（DR-028R）。

### #30 [批1] deploy 收支行+动态门槛+定价三档 ｜批1｜M
**升版变更**：既有 5 条 [T] 全保留（挤压确定性/维护拒绝/零 RNG 归并为边界态一条，信息零删）；单在线位自实施提示提为验收（合计 5 [T]+1 [P]）；[P] 拆三段式；训练位分岔体感给代理指标。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜原 5 条 [T] 信息零删，拆并仅发生在表述层

**新正文**：
## 目标
实现 deploy 任务转正+API 收支行（上市期结构必要件，DR-028R R-1R）。

- 依赖 / 关联：#26 经济稿+PR10 断言收窄；规模：M
- 决策依据：DR-028（deploy 参数/market_base_k=65/quality_exp=1.8/price_tiers/decay 0.97）；DR-029 R-4（动态锚 max(60, sota_top−15)）；DR-029 B-2（reserved 12 卡时+发版冷却下限）
- 验收点：
  - [ ] [T] 正常路径：deploy=五类任务占位行转正（占任务槽 N 周+上线费 25k/迭代 12k）；上线谓词=持有评分≥动态锚 max(60, sota_top−15) 的未部署模型，成对注册黄级（GUT 用例名：test_deploy_predicate_dynamic_anchor）
  - [ ] [T] 收支行：API 收入=economy.accrue_week() 第三收支行（管线不插步 DR-007）；share=min(0.65,(score/sota_top)^1.8×price_mult)（GUT 用例名：test_api_income_third_branch_no_pipeline_step）
  - [ ] [T] 边界态：挤压=确定性查表（我的在线分−霸主分），竞对发版自动抬 sota_top；维护 reserved 12 卡时锁定（卡时不足明确拒绝，DR-018 恢复）；故障走既有 money 事件；零新 RNG（GUT 用例名：test_api_squeeze_deterministic_and_reserved_rejected）
  - [ ] [T] 可观察终态：API 占比分阶段断言（实验室/独角兽 ≤40%、上市 ∈[50%,70%]，DR-028 审查补丁）（GUT 用例名：test_api_income_share_phase_bands）
  - [ ] [T] 单在线位约束不破（DR-028 R-7）（GUT 用例名：test_deploy_single_online_slot）
  - [ ] [P] 训练位分岔（冲 SOTA vs 热更新）体感为非必做取舍（试玩脚本：docs/playtest/scripts.md#deploy-01）｜步骤脚本：前置态=上市期档+已有≥动态锚的未部署模型+训练位空；操作序列=先冲一次 SOTA、读档后改走一次热更新迭代，各 5 分钟；预期感受：两条路都"活得过且说得清"，不玩 deploy 也不破产；代理指标：跳过 deploy 的对照局 20 周现金始终高于破产线+警告线之和，玩家能说出两路各自代价。
- 实施提示：单在线位（DR-028 R-7）；v0.1 techs/tasks 表占位行不动，enabled 翻真+补字段=黄级；数据落 `src/data/tasks.json`/`economy.json`。

### #31 [批1] 支线危机 3 卡（贷款必带偿还/设备出售/接私活） ｜批1｜M
**升版变更**：既有 4 条 [T] 全保留并补 GUT 用例名，新增接私活停机边界 1 条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式（三刀①文案）。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜三卡效果数值全部 ~ 占位照抄，未实锁

**新正文**：
## 目标
v0.2 第一批事件卡级支线切片（DR-028 R-2 第一步）。

- 依赖 / 关联：#26 经济稿+PR7 事件引擎+PR5 谓词注册表（low_money 来源见 #35）；规模：M
- 决策依据：DR-028 R-8（贷款本金×1.2/4 周 delayed money）；low_money 谓词（DR-028）；DR-029 E-2（占人力代价）
- 验收点：
  - [ ] [T] 正常路径：3 卡=决策层（占每周 1 张决策卡额度，DR-012）；low_money{threshold:-30k} 谓词成对注册（黄级，与 #35 共卡）（GUT 用例名：test_sidequest_three_cards_decision_layer）
  - [ ] [T] 卡效果断言：贷款本金 U(30,60)k~（~ 占位照抄）、×1.2/4 周 delayed 偿还行；接私活 +2.5k/人/周、该员 research_eff×0.5 两周、出危机自动停；设备出售一次性（GUT 用例名：test_sidequest_loan_delayed_repay_1_2x）
  - [ ] [T] 边界态：接私活员工被解雇/离队 → 收入与 research_eff 惩罚一并终止，不残留（GUT 用例名：test_sidequest_moonlight_stops_on_staff_gone）
  - [ ] [T] 回血量带：危机态三线并发回血 8–15k/周 ≥ 固定支出 60%（数值稿标定值，~ 占位照抄）（GUT 用例名：test_sidequest_recovery_meets_expense_ratio）
  - [ ] [T] 政策隔离双跑：扩张剧本不含支线策略，V1② ∈[0.5%,8%] 不破（GUT 用例名：test_sidequest_policy_isolation_v1_band）
  - [ ] [P] 危机期 30 秒内屏上 ≥1 可选动作且一句话可懂（三刀①，DR-028）；有人递绳子非惩罚（试玩脚本：docs/playtest/scripts.md#crisis-01）｜步骤脚本：前置态=构造 low_money 触发的危机档；操作序列=危机弹报出现起计时 30 秒内完成一次支线卡选择；预期感受：选项像"有人递绳子"，不是罚站；代理指标：玩家不看说明 30 秒内选中并口述该卡效果，试玩全程 0 次"这卡是骂我？"表达。
- 实施提示：文案归内容席管线（查重+敏感词三层，DR-014）；冷却/once 沿 DR-023 字段；数据落 `src/data/events.json`（layer=decision）。

### #32 [批1] 特质激活绑训练位+condition 重定义 ｜批1｜M
**升版变更**：既有 5 条 [T] 全保留并补 GUT 用例名（训练位绑定与观察文本表达拆两条、condition 边界与摆烂开关归并为一条，信息零删）；[P] 拆三段式。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜二选一交 #28 定案，本单验收引用不定死

**新正文**：
## 目标
A-1/A-2 员工系统第一批实现（traits 激活+condition 通路）。

- 依赖 / 关联：PR5R staff.condition 预埋+training 管线+硬约束①定案（#28）；规模：M
- 决策依据：DR-029 A-1（组合效果绑"两人同时上桌"=训练位人选决策，非永久 buff）/A-2（训练期免扣+drain×train_weeks<~80+悬崖改线性+摆烂开关默认开）/A-3（心情通道焊死）
- 验收点：
  - [ ] [T] 正常路径：traits.json 6 特质×8 化学反应，效果仅在两人同时挂训练位时生效（GUT 用例名：test_trait_combo_only_when_two_on_training_seats）
  - [ ] [T] 表达形态：化学反应=观察文本+周报彩蛋行，禁数值面板（GUT 用例名：test_trait_combo_text_only_no_panel）
  - [ ] [T] 边界态：condition 0–100 按 #28 ①定案执行（训练期免扣或 drain×train_weeks<~80 二选一）；<50 线性斜率（非悬崖）；<20 处理按摆烂开关默认规则（GUT 用例名：test_condition_linear_slope_no_cliff）
  - [ ] [T] 摆烂开关默认开：不主动管 condition 不变糟（休闲党红线）（GUT 用例名：test_condition_idle_default_no_decay_trap）
  - [ ] [T] condition 进 V-sim 供给模型显式建模（#28 ⑦，隐藏 downtime 税显式化）（GUT 用例名：test_condition_in_vsim_supply_model）
  - [ ] [P] 组合凑齐时周报化学反应行有"人味"（开罗系观察文本质量）（试玩脚本：docs/playtest/scripts.md#trait-01）｜步骤脚本：前置态=带化学反应对的两人入队；操作序列=挂同一训练位完成一次训练→在周报找化学反应行；预期感受：像员工自己在说话而非系统播报；代理指标：试玩者能不经提示复述该行至少 1 句原文，且问卷"像播报/像说话"选后者。
- 实施提示：访问学生卡与 tenure 同批可顺手；特质 roll 暂挂 event_roll（招聘市场批2 才开 rng.recruit 新域，A-6）；数据落 `src/data/traits.json`。

### #34 [批1] 总分榜周报行+深巷宿敌行+影响力脉冲（B-1/B-6/B-5） ｜批1｜S
**升版变更**：既有 4 条 [T] 全保留并补 GUT 用例名，新增"可观察终态"[T]（累计 5 [T]+1 [P]）；[P] 拆三段式；**界面类：映射表行见 UI 席产出 #总榜周报行**（先改表再改码，ui-state-visual-mapping.md §3）。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜界面类：映射表行挂 UI 席产出，信标列落地前豁免

**新正文**：
## 目标
榜单第一批：总分榜周报常驻形态（塞周报别塞脸）+影响力脉冲。

- 依赖 / 关联：PR9b 周报流+PR5R sota.by_key 预埋+#27 B-5 联标定案；规模：S
- 决策依据：DR-029 B-1（第一批只上总分榜）/B-6（宿敌行+"落后为什么"行）/B-5（脉冲 5–8 影 or 宿敌首冠，按 #27 定案）
- 验收点：
  - [ ] [T] 正常路径：周报常报名次行（名次+与霸主差距值）；领先/±5 分胶着（红）/被反超 三态文案（GUT 用例名：test_ranking_weekly_row_three_states）
  - [ ] [T] "落后为什么"一行（如"深巷发版 +12.4"）；被反超与夺回文案成对（GUT 用例名：test_ranking_why_behind_line_paired_copy）
  - [ ] [T] 边界态：榜单全程只读零刷榜动作（无任何榜上可点入口）；通知层零红点零角标（GUT 用例名：test_ranking_readonly_no_red_badge）
  - [ ] [T] 脉冲：影响力脉冲 once（fired 入档）——方案中性（经对抗评审 M6）：宿敌首冠制=季首冠触发/卫冕不重发；5–8 影制=按 #27 定案时点触发；触发谓词随 #27 定案细化，同源实现与 #43 互引（GUT 用例名：test_influence_pulse_fired_once）
  - [ ] [T] 可观察终态：同 seed 重跑 8 季，脉冲 firing 集合与名次行三态完全一致（GUT 用例名：test_ranking_pulse_deterministic_same_seed）
  - [ ] [P] "缠斗中"周报文案写得够损（开罗老炮：动画预算从文案里省回来）（试玩脚本：docs/playtest/scripts.md#ranking-01）｜步骤脚本：前置态=与霸主分差 ±5 内的档；操作序列=连续看 3 周周报榜单区；预期感受：名次行值得逐周读、有追剧感；代理指标：3 周内试玩者主动向他人念出 ≥1 句榜单文案。
- 实施提示：斜率效率榜/考工榜/潮汐影子榜=批2（#39）不在本单；反超 L3 动画维持一局 3 次预算制；界面类：先改映射表行再改码，信标断言名落地前"待回填"。**脉冲同源（M6）**：与 #43 共享同一触发函数出处，两单验收互引禁双写；"季"周期定义全库现缺，随 #27 定案补（~ 占位）。

### #35 [批1] 新谓词注册批 4+2（成对注册） ｜批1｜S
**升版变更**：既有 6 条 [T] 全保留（四谓词正例归并为一条、正反例与纯查询拆条表述，信息零删）；新增消费方联测 1 条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜纯查询=E 矩阵黄级前提，写入验收

**新正文**：
## 目标
批1 消费方所需新谓词一次成对注册（DR-011 禁 DSL 纪律）。

- 依赖 / 关联：PR5 谓词注册表；消费方=#31 支线 3 卡/#36 玄冬年报；规模：S
- 决策依据：DR-029 F-6；DR-028（low_money 已裁先行）
- 验收点：
  - [ ] [T] 正常路径：week_at{week,period?}（玄冬年报/彩蛋定时）、influence_above{value}（彩蛋/财报日门槛）、ever_fired{event_id}（"深巷七日"联动/年度名场面查询 fired 表）、stage_at{stage}（财报日按阶段差异化）四谓词正反例全过（GUT 用例名：test_predicates_batch_four_registered）
  - [ ] [T] 复用核对：low_money{threshold}（若 PR7 未先行落）与 lit{tech_id}（已有）复用不重注册（GUT 用例名：test_low_money_lit_reuse_no_dup）
  - [ ] [T] 边界态：每谓词反例各 1（week_at 传不存在周/ever_fired 查未触发 id → 返回 false 不抛错）（GUT 用例名：test_predicates_negative_cases_no_throw）
  - [ ] [T] 纯查询：皆不新增入档状态（E 矩阵黄级前提，savegame diff 为空）（GUT 用例名：test_predicates_pure_query_no_state_write）
  - [ ] [T] 可观察终态：消费方联测——#31 贷款卡与 #36 年报卡在注册后可被各自谓词正确唤起（GUT 用例名：test_predicates_consumers_fired）
  - [ ] [P] 新谓词"注册即用"无二次接线感（试玩脚本：docs/playtest/scripts.md#predicate-01）｜步骤脚本：前置态=批1 消费方卡在手；操作序列=正常游玩至谓词触发场景（危机/年报周）；预期感受：卡按时出现，无"功能没接上"的空窗；代理指标：0 次应触发未触发/不应触发乱触发的试玩记录。
- 实施提示：一个 PR 成对注册；数据落 `src/data/predicates.json`（或注册表常量，按 PR5 既有形态）。

### #36 [批1] 玄冬年度报告+归档回看 ｜批1｜S
**升版变更**：既有 3 条 [T] 全保留并补 GUT 用例名，补齐三要素缺的两条 [T]（边界+终态）（合计 5 [T]+1 [P]）；[P] 拆三段式；**界面类：映射表行见 UI 席产出 #年报面板**。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜周目继承接口留给 #44，本单只做归档回看

**新正文**：
## 目标
年度报告彩蛋卡（开罗式年度放大器，"周报要能扫一眼"的年度版）。

- 依赖 / 关联：PR7 事件引擎+#35 谓词批；下游 #44 归档接口；规模：S
- 决策依据：DR-029 F-5（week%52 触发零新 RNG；数据源全部已有入档字段；可归档回看）
- 验收点：
  - [ ] [T] 正常路径：四行内容=年度 SOTA 归属回顾（sota.by_key）/年度收支流水（economy 对账）/年度名场面（fired 表 Top1）/下年度预告（深巷 cursor 模糊预告）（GUT 用例名：test_annual_report_four_rows_from_saved_fields）
  - [ ] [T] 边界态：彩蛋层零效果（DR-029 F-2 一刀切）——四行数据皆读既有入档字段，零新计算零新 RNG（GUT 用例名：test_annual_report_zero_effect_zero_rng）
  - [ ] [T] 归档：报告可归档回看（周目继承读旧年报=批3 #44 接口预留）（GUT 用例名：test_annual_report_archived_viewable）
  - [ ] [T] 触发：week_at 谓词触发、week%52 整周结算挂载，缺数据字段时四行降级为占位行不崩（GUT 用例名：test_annual_report_missing_field_fallback）
  - [ ] [T] 可观察终态：归档后至少跨 1 个存读档周期，回看内容逐字一致（GUT 用例名：test_annual_report_survives_save_reload）
  - [ ] [P] 年报值得截图（开罗老炮验收）（试玩脚本：docs/playtest/scripts.md#annual-report-01）｜步骤脚本：前置态=完整跑过 52 周的档；操作序列=年报弹出当日通读一遍；预期感受：想按截图键、想发给朋友；代理指标：试玩者自发截图或表示"想存"（问卷二选一），首屏 10 秒内可读完四行。
- 实施提示：texts 模板 1 键+周报模板复用；玄冬=年度会议+年号双关（世界观已核验成立）；数据源 sota.by_key/economy/fired 表全部已有入档字段（DR-029 F-5）。

### #37 [批1] 收集图鉴容器数据层（meta.cfg+flags） ｜批1｜S
**升版变更**：既有 3 条 [T] 全保留并补 GUT 用例名，补齐三要素缺的边界+终态两条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜三禁（E-2 零命令零信号）写入验收边界

**新正文**：
## 目标
收集图鉴第一块真身——数据容器层（老炮一票提前成立项；UI 面板=批2 #42）。

- 依赖 / 关联：PR5R flags 开放容器确认；下游 #42/#44；规模：S
- 决策依据：DR-029 收集图鉴专项（特质/彩蛋盖章/模型卡/年报/成就/考工榜散料串册）；E1 裁决（永久零命令，收集进度记 meta.cfg 跨周目保留）
- 验收点：
  - [ ] [T] 正常路径：meta.cfg（user://，不进 SaveMigrator 链）承载周目数/曾达最高阶段/已读教学集/图鉴进度容器（GUT 用例名：test_codex_meta_cfg_container_loads）
  - [ ] [T] 双层写点：savegame flags 开放键存本局收集态；图鉴解锁=meta.cfg 跨周目持久（GUT 用例名：test_codex_flags_local_meta_persistent）
  - [ ] [T] 边界态：meta.cfg 缺失/损坏/旧版本 → 全默认值重建不崩，savegame 不受污染（GUT 用例名：test_codex_meta_corrupt_rebuilds_default）
  - [ ] [T] 禁区：零新命令零新信号（DR-029 E-2 三禁）；图鉴条目 schema=内容清单（批1 设计稿 #26 附属）驱动（GUT 用例名：test_codex_no_new_command_signal）
  - [ ] [T] 可观察终态：开新周目后 meta.cfg 图鉴进度逐键保留、周目数 +1（GUT 用例名：test_codex_progress_survives_new_run）
  - [ ] [P] 二周目玩家打开图鉴能看到上局收集痕迹（试玩脚本：docs/playtest/scripts.md#codex-data-01）｜步骤脚本：前置态=一局已解锁 ≥1 图鉴条目后开二周目；操作序列=二周目内调出收集数据（调试面板或 #42 上线后走 UI）；预期感受："我上局的收集还在"，周目连贯感；代理指标：条目留存核对 0 丢失。
- 实施提示：容器先行 UI 后行（排期裁决差异项：解耦 PanelStack 注册时点风险——开放问题③）；条目枚举随内容批逐步填充；meta.cfg 通道零 savegame 迁移。

## 批2（#38–#43，内容+深度）

### #38 [批2] 招聘市场+签约金 tier 化+rng.recruit 新域 ｜批2｜L｜对抗评审待跑
**升版变更**：既有 4 条 [T] 全保留（满编拒绝并入扩编条、隐藏档门槛并入猎头条，信息零删），新增同 seed 可观察终态 1 条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式；L 规模标签与对抗评审义务显式标注；**界面类：映射表行见 UI 席产出 #招聘市场面板**。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜L 规模：对抗评审待跑，认领前必须完成（issue-spec §5）

**新正文**：
## 目标
A-4/A-6 招聘市场全套（含 candidate roll 新随机域）。

- 依赖 / 关联：批1 容器类+#26 签约金 tier 定案+#28 ⑥ 定案；规模：L（**对抗评审待跑**，issue-spec §5）
- 决策依据：DR-029 A-4（信息分阶段：候选一句话↔特质可学习映射+猎头见隐藏档+签约金条件于 quality_tier）；猎头门票 20–40 出处=growth 席提案（非 DR-029 A-4 原文，经对抗评审 M2-③ 标注，待 #27/#28 标定收口）/A-6（rng.recruit() 新域）/A-7（扩编=一次性扩建费 ~40–60k，~ 占位照抄）
- 验收点：
  - [ ] [T] 正常路径：候选池 8 周刷 2 人；签约金随 quality_tier 分布（非均匀随机=价格信号有意义，#28 ⑥）（GUT 用例名：test_recruit_pool_biweekly_tiered_bonus）
  - [ ] [T] 新随机域：rng.recruit() 开域（grep 断言 3→4 一次改净，ADR-0008 同步修订）（GUT 用例名：test_rng_recruit_domain_fourth_stream）
  - [ ] [T] 边界态：满编时发起招聘/签约 → 拒绝并提示扩编路径；扩编 3→5=花钱扩建（独角兽期坑位）；满编周支出 ≤ 上市期带 46–58k 断言（~ 占位照抄）（GUT 用例名：test_recruit_full_roster_rejected_and_expense_band）
  - [ ] [T] 猎头=影响力门票（DR-028R 汇率 ~1k¥/影；20–40 区间出处=growth 席提案，待标定收口）；tenure 资历+访问学生转正入池；门票不足时隐藏档不可见（GUT 用例名：test_headhunter_influence_ticket_gated）
  - [ ] [T] 可观察终态：同 seed 重跑，候选池序列与签约金逐周一致（确定性，ADR-0008 三域纪律延伸）（GUT 用例名：test_recruit_deterministic_same_seed）
  - [ ] [P] "贵=可见信息多"体感成立（深度画像）；招聘可完全无视也能玩（休闲党半条无视路径）（试玩脚本：docs/playtest/scripts.md#recruit-01）｜步骤脚本：前置态=招聘市场已解锁的稳定档；操作序列=先裸签 1 名低档候选、再买 1 次猎头看隐藏档对比信息量；预期感受：多花的钱换来了"看得见的信息"，不是黑箱抽奖；代理指标：玩家能口述两档候选信息条数差异 ≥2 项；全程不进招聘面板的对照局 20 周不破产。
- 实施提示：candidates.json 新表入 L4；老员工组合班底保护（初始三人唯一自带组合）；消费 rng.recruit 的唯一系统=本市场（排期裁决：早做=空注册）。

### #39 [批2] 斜率效率榜+考工榜副轴+潮汐影子榜 ｜批2｜M
**升版变更**：既有 4 条 [T] 全保留（exploit 复测并入斜率条、ΔA≤0 并入死榜条，信息零删），新增三榜只读确定性 1 条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式；**界面类：映射表行见 UI 席产出 #三榜周报行**。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜Q5 未定案不阻塞升版，验收句引用定案（禁猜口径）

**新正文**：
## 目标
B-2/B-4/B-6 第二批榜单扩展。

- 依赖 / 关联：#34 总分榜行+批2 前置（考工榜口径=开放问题 Q5 定案，数值席）；规模：M
- 决策依据：DR-029 B-2（eff 榜=斜率口径 ΔA/千卡时含 reserved+发版冷却下限，防停档 exploit）/B-4（考工榜=复现榜副轴不开第四榜）/B-6（潮汐影子榜不上场）
- 验收点：
  - [ ] [T] 正常路径：斜率效率榜=ΔA/千卡时（分母含 reserved+发版冷却下限）；低档流 exploit 不成立复测（停 t1 流 1.7 倍差距消除，DR-029 审视记录口径）（GUT 用例名：test_eff_slope_exploit_neutralized）
  - [ ] [T] 边界态：delta 死榜不复活（max(0,ΔA) 砍除维持）；按季重置思想并入；ΔA≤0 时行不上榜不报错（GUT 用例名：test_delta_dead_board_stays_dead）
  - [ ] [T] 考工榜副轴口径按 #26/数值席定案实现（复现榜副轴不开第四榜，Q5 二选一）（GUT 用例名：test_exam_board_secondary_axis_per_spec）
  - [ ] [T] 潮汐影子榜=sota.by_key 第二键+常数基准+jitter 复用（零新 RNG）（GUT 用例名：test_tide_shadow_second_key_jitter_reuse）
  - [ ] [T] 可观察终态：三榜数据行随周报渲染且只读（同 #34 通知层零红点）；同 seed 重跑三榜逐周一致（GUT 用例名：test_three_boards_weekly_readonly_deterministic）
  - [ ] [P] 三榜信息在周报可扫读；硬核玩家有可刷目标而休闲党无感（试玩脚本：docs/playtest/scripts.md#boards-01）｜步骤脚本：前置态=三榜已上线的中期档；操作序列=休闲档正常游玩 4 周不看榜；深度档按效率榜刷一轮；预期感受：休闲无打扰、深度有抓手；代理指标：休闲档 4 周榜单相关打断 0 次；深度档能按榜行复述自己 ΔA 与差距。
- 实施提示：多竞对同场=红级专项评审范围外，潮汐仅影子榜数据行；"塞周报别塞脸"（排期裁决批2 验收口径）。

### #40 [批2] 传闻池+挖人（涨薪留人）+联合课题 ｜批2｜M
**升版变更**：既有 4 条 [T] 全保留并补 GUT 用例名，新增竞业免挖+零博弈红线 1 条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式；G-4 零博弈红线重申从实施提示提为验收边界。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜G-4 零博弈红线从实施提示提为验收边界

**新正文**：
## 目标
G-1/G-3 竞对交互批2（黄批部分）。

- 依赖 / 关联：PR7 事件引擎+PR5R staff.condition 预埋；规模：M
- 决策依据：DR-029 G-1（挖人卡含"涨薪留人"counter-offer 选项，圈内顺序先于竞业；竞业协议=flag_set 20 周免挖/工资+10%）/G-3（传闻±2 周窗口投放）
- 验收点：
  - [ ] [T] 正常路径：挖人卡：研究员离职→eff 重算；反制选项=涨薪留人（money）/竞业（事前投保），圈内顺序先于竞业（GUT 用例名：test_poach_counteroffer_priority_precedence）
  - [ ] [T] 传闻池 6 条（fog_gate.rumored 绿级通道）：憋大活/外脑/缺卡/打听我的人（挖人前 3 周防背刺预告）/内部吵架/南边新家（GUT 用例名：test_rumor_pool_six_lines_rumored_gate）
  - [ ] [T] 边界态：竞业 flag_set 生效期内被挖 → 免挖成立（20 周/工资+10%）；G-4 红线：竞对行为零博弈 AI（脚本+扰动，不读玩家隐藏状态做对抗决策）（GUT 用例名：test_non_compete_flag_blocks_poach_zero_gaming_ai）
  - [ ] [T] 联合课题卡（双向，接=rp_grant+influence+，8 周冷却）；"深巷七日"窗口=支线卡加权上调器（接口不复用池）（GUT 用例名：test_joint_project_cooldown_and_weighted_gate）
  - [ ] [T] 可观察终态：传闻兑现=±2 周窗口（与 DR-027 预警节奏一致，零新钳制）；兑现事件 fired 可查（GUT 用例名：test_rumor_fulfillment_two_week_window）
  - [ ] [P] "竞对的强来自时间线的恶意不来自智能"体感成立；预告层防背刺公平（试玩脚本：docs/playtest/scripts.md#rival-01）｜步骤脚本：前置态=有研究员且深巷传闻活跃的档；操作序列=被挖人卡弹起→先看预告行→选一次涨薪留人；预期感受：背刺早有预告、反制有得选，输在时间线不输在暗箱；代理指标：被挖玩家问卷"可预期/被坑"选可预期 ≥80%，预告行被主动读到。
- 实施提示：竞对=脚本+扰动红线（G-4 零博弈 AI）重申进验收；rivals.json 加 rumors[]；防失控红线维持（DR-029 G，永不博弈 AI）。

### #41 [批2] 事件池扩容 30–37+假 arXiv 6 句式+彩蛋修正 3 必收 ｜批2｜M
**升版变更**：既有 5 条 [T] 全保留并补 GUT 用例名（文案查重条改述为可验证断言不删信息）；新增可观察终态 [T] 1 条（合计 6 [T]+1 [P]）；[P] 拆三段式；**界面类：映射表行见 UI 席产出 #通知层事件行**。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜查重条改述为可验证断言，原文案纪律信息保留

**新正文**：
## 目标
F 组批2 内容扩池（三层池+文案修正包）。

- 依赖 / 关联：#31 支线 3 卡+文案席管线（查重+敏感词三层，DR-014）；规模：M
- 军事依据：DR-029 F-1（通知 12–15/决策 8–10/彩蛋 10–12，通知层零红点）/F-3（假 arXiv=周报装饰行每 4 周轮换+6 种句式，单句式还原度 5/10 否决）/F-4（彩蛋修正包）
- 验收点：
  - [ ] [T] 正常路径：layer 字段消费（notice/decision/easter 三层分级实现 PR7 已落）；通知层 toast/周报行不占决策额度（GUT 用例名：test_event_pool_layer_routing_no_quota）
  - [ ] [T] 彩蛋修正扩池：一镜长卷触机改视频节点点亮周/巷灯演示日注"深巷含搜索业务"/深巷七日改五天+员工联名信 + 必收 3 条（咒语师出圈/满地蒲公英/歪楼金矿）（GUT 用例名：test_easter_fix_pack_three_must_have）
  - [ ] [T] 假 arXiv 手写池 30 条×6 句式（足矣/迈向/蜃楼/述评等，3 条 lit 动态解锁）；零 RNG 装饰行（GUT 用例名：test_fake_arxiv_six_styles_zero_rng）
  - [ ] [T] 边界态：彩蛋层一刀切零效果；带微效果卡归通知层计入 V-sim 基线（效果泄漏即回归失败）（GUT 用例名：test_easter_layer_zero_effect_isolation）
  - [ ] [T] 文案管口：全部文案过查重+敏感词三层（DR-014 纪律），批次内逐卡留过检记录（GUT 用例名：test_event_copy_lint_pipeline_recorded）
  - [ ] [T] 可观察终态：池总量落位三层带（通知 12–15/决策 8–10/彩蛋 10–12）；假 arXiv 每 4 周轮换可从周报历史逐条对出（GUT 用例名：test_pool_counts_within_bands_rotation_four_weeks）
  - [ ] [P] 圈内人"会心"密度（深巷七日/春江水暖级）；休闲党看得懂（术语提示位）（试玩脚本：docs/playtest/scripts.md#events-01）｜步骤脚本：前置态=扩池后新开一局；操作序列=各画像各玩 60 周记录会心时刻；预期感受：圈内人"这我熟"、休闲党不迷路；代理指标：圈内画像 ≥3 次/局的主动会心表达（笑/念出/截图），休闲档术语相关求助 ≤1 次。
- 实施提示：决策卡密度论证=10 张÷160 周 P50 触 4–6 次（DR-009 对齐）；扩池第三批等试玩"决策模板化"反馈再扩；数据落 `src/data/events.json`（layer 字段 PR7 已成对注册）。

### #42 [批2] 图鉴 UI 面板（PanelStack 注册） ｜批2｜M
**升版变更**：既有 3 条 [T] 全保留并补 GUT 用例名，补齐三要素缺的边界+终态两条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式；**界面类：映射表行见 UI 席产出 #图鉴面板**。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜开放问题③（注册时点）列为前置而非本单裁决

**新正文**：
## 目标
收集图鉴 UI 层（容器=#37 已落）。

- 依赖 / 关联：#37 容器+开放问题③（PanelStack 注册时点，主程序+UI 席闭合）；规模：M
- 决策依据：DR-029 收集图鉴专项（UI=独立面板）；图鉴 IA=批1 设计稿附属
- 验收点：
  - [ ] [T] 正常路径：PanelStack 注册表 +1 面板（z1 层）；命令/信号零新增（数据从快照+meta.cfg 读）（GUT 用例名：test_codex_panel_registered_zero_new_signals）
  - [ ] [T] 条目分区：特质/彩蛋盖章/模型卡/年报/成就/考工榜（内容清单驱动渲染，与 #37 schema 同源）（GUT 用例名：test_codex_sections_from_content_manifest）
  - [ ] [T] 边界态：未解锁条目=??? 行（迷雾 UI 语言一致）；空图鉴（新周目 0 解锁）时面板不空白崩（GUT 用例名：test_codex_locked_entries_masked_row）
  - [ ] [T] 可观察终态：打开面板 0.5s 内渲染完成且解锁条目数与 meta.cfg 逐键一致（关面板重开计数不变）（GUT 用例名：test_codex_render_matches_meta_counts）
  - [ ] [T] 竖屏 375×667 可达可翻阅（映射表行竖屏折叠形态列兑现）（GUT 用例名：test_codex_portrait_reachable）
  - [ ] [P] 图鉴有"收集品"欲望（稀有度表达），翻阅有开罗图鉴手感（试玩脚本：docs/playtest/scripts.md#codex-ui-01）｜步骤脚本：前置态=解锁约半数条目的档；操作序列=开图鉴翻完三个分区；预期感受：想补齐空格、对 ??? 行好奇；代理指标：试玩者自发点开 ?? 行 ≥2 次且能说出 1 条"想要的收集品"。
- 实施提示：L1–L2 动效；稀有度分层文案=内容批填充；映射表行与反馈链路清单（ui-feedback-checklist.md）随 PR 同步更新。

### #43 [批2] 机会窗口连续衰减+影响力脉冲实现（标定后） ｜批2｜S
**升版变更**：既有 3 条 [T] 全保留并补 GUT 用例名，补边界态 1 条 [T]（下限触底+提前不罚，合计 4 [T]+1 [P]）；[P] 拆三段式。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜与 #34 脉冲同源不双发，PR 出函数单一出处

**新正文**：
## 目标
C-3/B-5 标定项的实现落地（标定随 #28 数值稿先行，本单只做实现）。

- 依赖 / 关联：#28 标定报告+#27 B-5 定案；规模：S
- 决策依据：DR-029 C-3（连续衰减每超 ~10 周 ×0.95 下限 0.7，~ 占位照抄）/B-5（脉冲实现）
- 验收点：
  - [ ] [T] 正常路径：机会窗口：week≥p50+30 起连续衰减（防阶梯卡点）；stages.json 注释出处（p50+30=P90+15 的 2 倍）（GUT 用例名：test_window_continuous_decay_from_p50_30）
  - [ ] [T] 边界态：衰减下限 0.7 触底不再降；week<p50+30 时系数恒 1（提前到达不吃亏）；gate 谓词复用 predicate_registry 不新增机制（GUT 用例名：test_window_decay_floor_and_no_early_penalty）
  - [ ] [T] 影响力脉冲按 #27 定案方案实现（5–8 影制 or 宿敌首冠制二选一，与 #34 firing 同源不双发）（GUT 用例名：test_influence_pulse_per_b5_verdict）
  - [ ] [T] 可观察终态：exploit 复测：拖延到衰减窗不划算（亏融资资格+净流差，整局净现值对照）；expected_p50 宽区间断言联动（GUT 用例名：test_delaying_window_not_profitable）
  - [ ] [P] 卡关玩家被"投资人耐心"救起而非惩罚（试玩脚本：docs/playtest/scripts.md#gate-01）｜步骤脚本：前置态=贴着 p50+30 边缘卡关的档；操作序列=多拖 4 周再过 gate；预期感受：系统给的是"再等等的余地"，不是突然加罚；代理指标：拖延 4 周方案净收益差为负但过 gate 成功率不降，玩家问卷"被惩罚/被兜住"选被兜住。
- 实施提示：gate 谓词复用 predicate_registry；expected_p50 宽区间断言联动；衰减参数引用 #28 定案值（~ 占位）。

## 批3（#44/#45，二周目+收尾）

### #44 [批3] 往年卷+周目继承（玄冬旧报） ｜批3｜M
**升版变更**：既有 3 条 [T] 全保留并补 GUT 用例名，补齐三要素缺的边界+终态两条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式；**界面类：映射表行见 UI 席产出 #归来摘要面板**。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜Q4 字段集留白待定案，验收句只引用不定值

**新正文**：
## 目标
D-4 二周目情报包：博导手记·往年卷+周目继承线。

- 依赖 / 关联：#36 年报归档+#37 容器+开放问题④（往年卷统计边界定案）+一次完整试玩记录；规模：M
- 决策依据：DR-029 D-4（meta.cfg 承载；"带着记忆重开"；二周目送"博导手记·往年卷"）；开罗老炮一票（豁免只跳教学没给情报）
- 验收点：
  - [ ] [T] 正常路径：往年卷=上局统计摘要（gate 到达时点/深巷 L1 周数/首冠周/破产周等，字段集按④定案；数据源=周报历史+fired 表）（GUT 用例名：test_past_volume_stats_from_saved_history）
  - [ ] [T] 周目继承=玄冬旧报回看+图鉴跨周目保留（#37 容器）（GUT 用例名：test_newgame_carries_old_report_and_codex）
  - [ ] [T] 边界态：首周目玩家无往年卷可读 → 归零呈现不报错；叙事与术语不豁免（只降级教学豁免）（GUT 用例名：test_first_run_no_past_volume_safe）
  - [ ] [T] 教学豁免按曾达阶段降级（meta.cfg：曾达最高阶段跳过对应引导步）（GUT 用例名：test_tutorial_waiver_by_reached_stage）
  - [ ] [T] 可观察终态：跨周目后 meta.cfg 统计字段逐键核对一致、零 savegame 迁移（meta.cfg 通道，SaveMigrator diff 为空）（GUT 用例名：test_meta_channel_no_migrator_diff）
  - [ ] [P] 二周目开局引导气泡 ≤1 条；"第二局值得开"（试玩脚本：docs/playtest/scripts.md#newgame-01）｜步骤脚本：前置态=完整通关一局后立即开二周目；操作序列=开局 5 分钟只记录引导类弹层；预期感受："我带着上局的记忆回来了"，不是重头再来；代理指标：开局气泡 ≤1 条（硬约束）且试玩者能引用 ≥1 条上局数据说"这局要不一样"。
- 实施提示：零 savegame 迁移（meta.cfg 通道）；数据源=周报历史+fired 表；往年卷字段集=GDD Q4 开放窗口定案后录入。

### #45 [批3] 扩建费+三阶段全参数表+gate 三值标定 ｜批3｜M
**升版变更**：既有 4 条 [T] 全保留并补 GUT 用例名，补齐三要素缺的边界+终态两条 [T]（合计 5 [T]+1 [P]）；[P] 拆三段式；三刀②收口为可量化代理指标。

**建卡检查单对照**（issue-quality-checklist §A）：字段齐 ✔｜三要素 ✔｜DR 摘录忠实 ✔｜试玩标定值为唯一收口，~ 占位不实锁

**新正文**：
## 目标
批3 收尾参数批（A-7/三阶段/gate 标定）。

- 依赖 / 关联：#29/#30 实现批+试玩记录；规模：M
- 决策依据：DR-029 A-7（扩建费随三阶段全参数表同落）；排期裁决批3（三阶段全参数表+gate 三值标定）
- 验收点：
  - [ ] [T] 正常路径：三阶段全参数表落 stages.json/economy.json（上市期 46–58k/周结构显式化，~ 占位照抄；常数注释出处纪律随表，DR-029 C-4）（GUT 用例名：test_full_param_tables_three_stages）
  - [ ] [T] gate 三值标定（影响力≥50+累计经营收入≥250k / SOTA≥3+≥1200k，按试玩数据收窄；gate=经营性收入口径，融资/IPO 不计，DR-029 C-6）（GUT 用例名：test_gate_three_values_playtest_calibrated）
  - [ ] [T] 扩建费数值落位（独角兽期一次性 ~40–60k，~ 占位照抄；与 #38 扩编路径同源不双计）（GUT 用例名：test_expansion_fee_one_time_sourced）
  - [ ] [T] 边界态：参数表键零硬编码（全走 src/data，grep 断言）；缺表/坏值时启动期报配置错误不进局（GUT 用例名：test_param_tables_no_hardcode_and_fail_fast）
  - [ ] [T] 可观察终态：跃迁点前后 8 周现金 P10>破产线跑道（整组蒙卡，万周模拟挂账）（GUT 用例名：test_transition_runway_montecarlo_p10_safe）
  - [ ] [P] 阶段跃迁可解释（三刀②：40 秒内说出"钱为啥紧"）（试玩脚本：docs/playtest/scripts.md#transition-01）｜步骤脚本：前置态=贴着独角兽→上市跃迁点的档；操作序列=过跃迁后让试玩者看周报 40 秒口述现金变紧原因；预期感受：变紧是"结构如此"而非"被坑"；代理指标：40 秒内口述命中 ≥2 个结构性项（API 管线/维护 reserved/人员支出），蒙卡对照组同题正确率 ≥80%。
- 实施提示：供给口径三阶段占比曲线已锁（issue #1）；本单为参数收窄+实装收尾；gate 三值=试玩标定后唯一收口点（排期裁决批3 验收口径）。

## 【下游省工自问】

1. **升版是否动了范围/重开裁决？**——否。逐条只做格式升版（字段齐+三要素+GUT 用例名+[P] 三段式）+把原实施提示里"本就是验收义务"的句子（跑道行/三禁红线/三口联标）提为显式验收点，无新机制无新数值。
2. **DR 摘录是否忠实？**——全部从原 issue 正文/decision-log 原文摘抄；~ 占位（~12%/~40–60k/U(30,60)k~/8–15k/~300–600/×0.95/1.7 倍/46–58k）照抄未实锁；未发明任何 DR 外数值。
3. **GUT 用例名是否可翻？**——每条 [T] 的断言均为"构造输入→断言可观察输出"形态，命名对齐 tests/unit/ 既有 snake_case 风格（test_economy.gd/test_panel_stack.gd 系）；设计稿类（#26/#27/#28）无运行时可测对象，用例名为"成稿内容可 grep/清单化断言"，实施时落在文档 lint 侧脚本或转为带 [T] 的清单核对，指派实施时由主程序席复核可翻性（这是本席自问出的最大遗留，见第 5 条）。
4. **试玩脚本 scripts.md 还没建怎么办？**——本文所有 [P] 的锚（#编号占位）在 scripts.md 建档时替换；[P] 三段式已把"前置态+操作序列+预期感受+代理指标"写全，建档只需抄段不改设计。
5. **哪些点建议下游对齐后再动？**——①设计稿三条（#26/#27/#28）的 [T] 断言形态（文档 lint vs 清单核对）与主程序席对齐；②#34/#43 影响力脉冲实现同源不双发，两单 PR 需同一函数出处；③#38 对抗评审（L 规模）须在认领前跑完；④#39 考工榜口径等 Q5、#44 字段集等 Q4 定案，升版不代替定案。
6. **拍板后动作是什么？**——按本文逐条 `gh issue edit --body`（不建新 issue、不关旧 issue），升版统计表随拍板评论回填对应 issue。

## 升版统计表

| # | 批 | 规模 | 原 checkbox | 升版后 | 新增 | 界面类 | 备注 |
|---|---|---|---|---|---|---|---|
| 26 | 1 | M | 3 | 5 | +2 | — | 设计稿类，[T] 断言形态待与主程序对齐 |
| 27 | 1 | M | 3 | 4 | +1 | — | B-5 联标真源 |
| 28 | 1 | M | 8 | 10 | +2 | — | 7 条硬约束 [T] 全保留 |
| 29 | 1 | M | 3 | 5 | +2 | — | 跑道行提为验收 |
| 30 | 1 | M | 5 | 6 | +1 | — | 5 条 [T] 全保留 |
| 31 | 1 | M | 5 | 6 | +1 | — | 停机边界补条 |
| 32 | 1 | M | 5 | 6 | +1 | — | 表达形态拆条 |
| 34 | 1 | S | 4 | 6 | +2 | ✅ #总榜周报行 | 脉冲与 #43 同源 |
| 35 | 1 | S | 6 | 6 | +0 | — | 消费方联测补条 |
| 36 | 1 | S | 3 | 6 | +3 | ✅ #年报面板 | |
| 37 | 1 | S | 3 | 6 | +3 | — | |
| 38 | 2 | L | 5 | 6 | +1 | ✅ #招聘市场面板 | **对抗评审待跑** |
| 39 | 2 | M | 4 | 6 | +2 | ✅ #三榜周报行 | 考工口径等 Q5 |
| 40 | 2 | M | 4 | 6 | +2 | — | G-4 红线提为验收 |
| 41 | 2 | M | 5 | 7 | +2 | ✅ #通知层事件行 | 查重条改可验证断言 |
| 42 | 2 | M | 3 | 6 | +3 | ✅ #图鉴面板 | |
| 43 | 2 | S | 3 | 5 | +2 | — | 与 #34 脉冲同源 |
| 44 | 3 | M | 3 | 6 | +3 | ✅ #归来摘要面板 | 字段集等 Q4 |
| 45 | 3 | M | 4 | 6 | +2 | — | |
| **合计** | — | — | **79** | **114** | **+35** | **7 条** | #33 关闭跳过 |

## 附 1：升版方法与遗留登记

**升版方法**：既有正文全部信息保留（[T] 零删、数值与 DR 摘录照抄、~ 占位不动），升版动作收敛为五件——①字段序对齐 issue-spec §1（依赖/规模归并到一行，决策依据只留 DR 摘录）；②验收三要素补缺（每条 ≥1 正常路径+1 边界/空态/拒绝分支+1 可观察终态）；③既有与新增 [T] 全部注 GUT 用例名（snake_case、对齐 tests/unit/ 既有文件域）；④[P] 全部改写为三段式（步骤脚本=前置态+操作序列｜预期感受=可对照行为｜代理指标=量化句）；⑤实施提示里"本就是裁决义务"的句子提为显式验收，不新增机制不新增数值。

**遗留登记（升版中确认、不在本文处置的）**：
1. `docs/playtest/scripts.md` 尚未建档——19 条 [P] 的 #编号锚全部为占位，建档时按三段式直接抄段成条（预期 19 条脚本）；
2. 设计稿类 [T] 断言形态（#26/#27/#28）：GUT 单测无运行时对象，建议落"文档 lint 脚本或清单化核对"，指派时与主程序席对齐后定形态；
3. 开放问题依赖不因升版关闭：#39←Q5 考工榜口径、#44←Q4 往年卷字段集、#42/#38←开放问题③ PanelStack 注册时点（GDD §17 登记册为准）；
4. L 规模对抗评审：#38 认领前必须完成（issue-spec §5），产出链接按 checklist B 段归档；
5. 界面类映射表行：7 条界面类 issue 的表行由 UI 席产出后先改表再改码（ui-state-visual-mapping.md §3 纪律），信标列按行内"待回填"豁免。

## 附 2：拍板后执行预案（非本文范围，供制作人席排程参考）

0. **前置（经对抗评审 M7）：V1-01…V1-17 映射表规划行拍板先行或同批**（§2.5 区段自标 [提案·待拍板]，拍板前不作为实施验收来源）；milestone v1.0 须先创建（现仓库仅 v0.1.0/v0.2）；
1. 逐条 `gh issue edit <N> --body-file <对应新正文>`（标题沿用原标题，仅 #33 类误建除外——本批不涉）；
2. 每条升版完成后在该 issue 追加一行评论：`[upgraded] spec=issue-spec@DR-030 ts=<日期> source=2026-09-08-v02-issue-upgrade-drafts.md`；
3. `gh issue edit <N> --milestone "v1.0"`（三批收拢 v1.0，对应口径变更）；
4. 统计表回填：文末升版统计表随拍板评论贴回对应 issue 或进 retro 归档；
5. #38 的对抗评审在认领前单独排程，不与 edit 混批。

## 附 3：验收三要素 ×19 条核对矩阵

| # | 正常路径 | 边界/空态/拒绝 | 可观察终态 | [T] 数 | [P] 三段式 |
|---|---|---|---|---|---|
| 26 | ✔ 五项成稿 | ✔ 缺项标记待补 | ✔ V-sim 复算留证 | 4 | ✔ 三刀走查 |
| 27 | ✔ 曲线+出口自洽 | ✔ 两端存量过带 | ✔ B-5 裁定可引用 | 3 | ✔ 消费出口走一遍 |
| 28 | ✔ 7 条逐条 | ✔ 未定案显式标 | ✔ V-sim 同 seed 留证 | 9 | ✔ 查表翻译 ≤1 分钟 |
| 29 | ✔ 决策卡两难 | ✔ 第 3 次拒绝 | ✔ flags 计数读档还原 | 4 | ✔ ≤10 秒回场 |
| 30 | ✔ 占位行转正 | ✔ 卡时不足拒绝 | ✔ 占比分阶段断言 | 5 | ✔ 无 deploy 对照局 |
| 31 | ✔ 决策层占额度 | ✔ 私活随人停 | ✔ 回血/支出比断言 | 5 | ✔ 30 秒递绳子 |
| 32 | ✔ 训练位绑定生效 | ✔ <50 线性/<20 开关 | ✔ V-sim 供给建模 | 5 | ✔ 复述观察文本 |
| 34 | ✔ 三态名次行 | ✔ 零刷榜零红点 | ✔ 同 seed 8 季一致 | 5 | ✔ 念出文案 |
| 35 | ✔ 四谓词正例 | ✔ 反例不抛错 | ✔ 消费方联测 | 5 | ✔ 触发无空窗 |
| 36 | ✔ 四行内容 | ✔ 缺字段降级 | ✔ 跨存读档逐字一致 | 5 | ✔ 自发截图 |
| 37 | ✔ meta.cfg 容器 | ✔ 损坏重建 | ✔ 跨周目逐键保留 | 5 | ✔ 条目零丢失 |
| 38 | ✔ 8 周刷 2 人 | ✔ 满编拒绝 | ✔ 同 seed 序列一致 | 5 | ✔ 信息条数差 ≥2 |
| 39 | ✔ 斜率口径 | ✔ 死榜不复活 | ✔ 三榜确定性只读 | 5 | ✔ 两画像分流 |
| 40 | ✔ counter-offer 顺序 | ✔ 竞业期内免挖 | ✔ ±2 周兑现 fired 可查 | 5 | ✔ 预告可预期 |
| 41 | ✔ layer 分级路由 | ✔ 彩蛋零效果隔离 | ✔ 三层带+轮换对表 | 6 | ✔ 会心 ≥3 次/局 |
| 42 | ✔ PanelStack 注册 | ✔ ??? 行遮蔽 | ✔ 渲染=meta 计数 | 5 | ✔ ??? 行好奇心 |
| 43 | ✔ p50+30 起衰减 | ✔ 下限 0.7 触底 | ✔ 拖延净现值变负 | 4 | ✔ 被兜住问卷 |
| 44 | ✔ 上局统计摘要 | ✔ 首周目归零 | ✔ meta 通道零迁移 | 5 | ✔ 气泡 ≤1 条 |
| 45 | ✔ 全参数表落位 | ✔ 坏值 fail-fast | ✔ 蒙卡 P10 跑道 | 5 | ✔ 40 秒口述 |

## 附 4：移交流程建议（本席 → 席间）

| 去 | 事项 |
|---|---|
| → gd-ui-ux-designer | 7 条界面类映射表行（#34 总榜周报行/#36 年报面板/#38 招聘市场面板/#39 三榜周报行/#41 通知层事件行/#42 图鉴面板/#44 归来摘要面板），含信标断言名回填计划 |
| → gd-lead-programmer | 设计稿类 [T] 断言形态对齐（#26/#27/#28）；#34/#43 脉冲同源实现约束；设计稿三条对应的文档 lint 形态建议 |
| → gd-test-engineer | scripts.md 试玩脚本建档（19 条三段式现成可抄）；GUT 用例名清单核对与实施时翻译复核 |
| → gd-producer | 拍板节奏与 gh issue edit 批次（附 2 预案）；#38 对抗评审排程 |
| → gd-narrative-designer | #41 文案过检管线排程（查重+敏感词三层记录留痕）；#36 年报四行文案与 #34 缠斗文案的试玩对照 |

## 附 5：GUT 用例名总索引（[T] 全量，实施翻译与 code-review 用）

> 命名域建议（对齐 tests/unit/ 既有文件名）：economy/effect→test_economy.gd；事件→test_event_engine.gd；谓词→既有谓词测试文件（PR5 落点）或新建 test_predicates.gd；榜单/周报→test_rival_track.gd 或新建 test_boards.gd；员工/特质→test_staff_roster.gd 或新建 test_traits.gd；招聘→新建 test_recruit.gd；图鉴/ meta.cfg→新建 test_codex.gd；存档/继承→test_save_system.gd / test_save_migrator.gd；面板→test_panel_stack.gd；设计稿三条为文档 lint 形态（见遗留登记 2）。

| # | GUT 用例名（[T] 全量，按正文顺序） | 断言对象一句话 |
|---|---|---|
| 26 | test_econ_draft_five_items_present / test_econ_draft_incomplete_rejected / test_econ_draft_vsim_points_replay_pass / test_econ_draft_hard_constraints_covered | 设计稿成稿/缺项拒绝/V-sim 复算/硬约束覆盖（文档 lint 形态） |
| 27 | test_influence_curve_and_exits_consistent / test_influence_exit_budget_within_band / test_b5_adjudication_reachable | 曲线+出口自洽/两端存量过带/B-5 裁定可引用（文档 lint 形态） |
| 28 | test_hc1_drain_or_exempt_decided … test_hc7_condition_in_supply_model / test_hc_report_undecided_marked / test_hc_vsim_same_seed_replay_pass | 7 硬约束逐条+缺项标记+V-sim 同 seed（文档 lint+蒙卡混合形态） |
| 29 | test_financing_decision_card_max_two_per_run / test_financing_over_limit_rejected / test_financing_income_not_in_cum_income / test_financing_runway_row_present | 决策卡/超次拒绝/不入累计收入/跑道行 |
| 30 | test_deploy_predicate_dynamic_anchor / test_api_income_third_branch_no_pipeline_step / test_api_squeeze_deterministic_and_reserved_rejected / test_api_income_share_phase_bands / test_deploy_single_online_slot | 动态锚/第三支行/挤压确定性+卡时拒绝/占比带/单在线位 |
| 31 | test_sidequest_three_cards_decision_layer / test_sidequest_loan_delayed_repay_1_2x / test_sidequest_moonlight_stops_on_staff_gone / test_sidequest_recovery_meets_expense_ratio / test_sidequest_policy_isolation_v1_band | 决策层/.delayed 偿还/停机边界/回血比/政策隔离 |
| 32 | test_trait_combo_only_when_two_on_training_seats / test_trait_combo_text_only_no_panel / test_condition_linear_slope_no_cliff / test_condition_idle_default_no_decay_trap / test_condition_in_vsim_supply_model | 训练位绑定/文本表达/线性斜率/摆烂默认/供给建模 |
| 34 | test_ranking_weekly_row_three_states / test_ranking_why_behind_line_paired_copy / test_ranking_readonly_no_red_badge / test_influence_pulse_first_crown_fired_once / test_ranking_pulse_deterministic_same_seed | 三态行/成对文案/只读零红点/首冠 once/同 seed 一致 |
| 35 | test_predicates_batch_four_registered / test_low_money_lit_reuse_no_dup / test_predicates_negative_cases_no_throw / test_predicates_pure_query_no_state_write / test_predicates_consumers_fired | 四谓词/复用不重注册/反例不抛错/纯查询/消费方联测 |
| 36 | test_annual_report_four_rows_from_saved_fields / test_annual_report_zero_effect_zero_rng / test_annual_report_archived_viewable / test_annual_report_missing_field_fallback / test_annual_report_survives_save_reload | 四行/零效果/归档/降级/存读档一致 |
| 37 | test_codex_meta_cfg_container_loads / test_codex_flags_local_meta_persistent / test_codex_meta_corrupt_rebuilds_default / test_codex_no_new_command_signal / test_codex_progress_survives_new_run | 容器/双层写点/损坏重建/三禁/跨周目保留 |
| 38 | test_recruit_pool_biweekly_tiered_bonus / test_rng_recruit_domain_fourth_stream / test_recruit_full_roster_rejected_and_expense_band / test_headhunter_influence_ticket_gated / test_recruit_deterministic_same_seed | 双周池/第四 RNG 域/满编拒绝/门票门槛/确定性 |
| 39 | test_eff_slope_exploit_neutralized / test_delta_dead_board_stays_dead / test_exam_board_secondary_axis_per_spec / test_tide_shadow_second_key_jitter_reuse / test_three_boards_weekly_readonly_deterministic | exploit 消除/死榜/副轴/影子榜/三榜确定性 |
| 40 | test_poach_counteroffer_priority_precedence / test_rumor_pool_six_lines_rumored_gate / test_non_compete_flag_blocks_poach_zero_gaming_ai / test_joint_project_cooldown_and_weighted_gate / test_rumor_fulfillment_two_week_window | 反制顺序/六条池/竞业免挖/联合课题/±2 周兑现 |
| 41 | test_event_pool_layer_routing_no_quota / test_easter_fix_pack_three_must_have / test_fake_arxiv_six_styles_zero_rng / test_easter_layer_zero_effect_isolation / test_event_copy_lint_pipeline_recorded / test_pool_counts_within_bands_rotation_four_weeks | layer 路由/修正必收/6 句式/零效果隔离/文案过检/池带轮换 |
| 42 | test_codex_panel_registered_zero_new_signals / test_codex_sections_from_content_manifest / test_codex_locked_entries_masked_row / test_codex_render_matches_meta_counts / test_codex_portrait_reachable | 注册/分区/??? 遮蔽/渲染=计数/竖屏可达 |
| 43 | test_window_continuous_decay_from_p50_30 / test_window_decay_floor_and_no_early_penalty / test_influence_pulse_per_b5_verdict / test_delaying_window_not_profitable | 衰减起点/触底不罚/脉冲定案/拖延不划算 |
| 44 | test_past_volume_stats_from_saved_history / test_newgame_carries_old_report_and_codex / test_first_run_no_past_volume_safe / test_tutorial_waiver_by_reached_stage / test_meta_channel_no_migrator_diff | 往年卷/周目继承/首周目归零/豁免降级/零迁移 |
| 45 | test_full_param_tables_three_stages / test_gate_three_values_playtest_calibrated / test_expansion_fee_one_time_sourced / test_param_tables_no_hardcode_and_fail_fast / test_transition_runway_montecarlo_p10_safe | 全参数表/gate 三值/扩建费/零硬编码/蒙卡跑道 |

> 总计 95 个用例名；其中设计稿类（#26/#27 全部、#28 大部）为文档 lint/清单核对形态，实施前与主程序席对齐落点（遗留登记 2）。

## 附 6：数据表/代码落点对照（实施提示参考路径集中化）

> 真源：排期裁决 §三（PR5R 冻结包/PR7/PR9b/PR10 接口）+ AGENTS.md L4 纪律（数值/配置一律 src/data/*.json）。本表为集中索引，正文实施提示已含的不重复展开。

| # | 数据表/代码落点 | 挂接 PR/既有件 | 级别 |
|---|---|---|---|
| 26 | `src/data/`（stages.json/economy.json/tasks.json 键名进 GDD，数值给 src/data） | PR10 V-sim 收口 | 文档稿 |
| 27 | 影响力曲线+出口表（键名落 economy.json 设计稿） | 开放问题 Q2 联标 | 文档稿 |
| 28 | 标定报告（值回填 #26 表键，常数注释出处→stages.json） | DR-029§二 | 文档稿 |
| 29 | economy.accrue_week() 融资收支行；schema sources 行黄级激活 | PR10 断言收窄 | 黄 |
| 30 | tasks.json 占位行 enabled 翻真+补字段；economy.accrue_week() 第三支行 | PR10 | 黄 |
| 31 | events.json（layer=decision 3 卡+low_money 谓词参数） | PR7 事件引擎 | 黄 |
| 32 | traits.json（6 特质×8 化学反应）；staff.condition 通路（PR5R 预埋消费） | PR5R→批1 | 黄 |
| 34 | sota.by_key 消费（PR5R 预埋）；周报模板行（texts 增键） | PR9b 周报流 | 绿 |
| 35 | 谓词注册表 4+2（week_at/influence_above/ever_fired/stage_at+复用核对） | PR5 注册表 | 黄 |
| 36 | texts 模板 1 键+周报模板复用；fired 表/economy 对账读点 | PR7+PR9b | 绿 |
| 37 | meta.cfg（user://，不进 SaveMigrator 链）+savegame flags 开放键 | PR5R 冻结包 | 绿 |
| 38 | candidates.json 新表入 L4；rng.recruit() 第四随机域（ADR-0008 修订） | 批1 容器后 | 黄 |
| 39 | sota.by_key 第二键+斜率公式（分母含 reserved）；考工榜副轴键 | #34 之后 | 黄 |
| 40 | rivals.json 加 rumors[]；挖人/竞业卡（flag_set 20 周） | PR7 | 黄 |
| 41 | events.json 扩池（三层带）；假 arXiv 文本池 30 条 | #31 之后 | 绿（文本）/黄（效果） |
| 42 | PanelStack 注册表 +1（z1）；快照+meta.cfg 读点 | 开放问题③闭合后 | 黄 |
| 43 | 衰减系数进 gate 谓词（predicate_registry 复用）；脉冲实现 | #28/#27 定案后 | 黄 |
| 44 | meta.cfg 统计字段（Q4 定案后录入）；周报历史+fired 表读点 | #36/#37 之后 | 绿 |
| 45 | stages.json/economy.json 全参数表；gate 三值收窄 | #29/#30 之后 | 黄 |

## 附 7：DR 摘录忠实性抽查记录（内容审查留痕，DR-030 主策划席卡口）

> 抽样原则：数值密集条+红线条+有"~ 占位"的条优先。对照组=decision-log 原文（DR-028/028R/029）/GDD §16 原文，升版组=本文新正文决策依据行。结论=逐字或省略号缩进，无补写。

| 抽查点 | 真源原文（节录） | 升版引用 | 结论 |
|---|---|---|---|
| DR-028 ⑤ 融资三键 | "融资三键（50–80k/稀释~12%/≤2 次）走主策划锁口径→PR10 V-sim 收口" | #29 标题+#26 决策依据引用同串 | 逐字 ✔（~ 占位保留） |
| DR-028 ⑧ 贷款偿还 | "贷款必带偿还（本金×1.2/4 周 delayed money）" | #31 决策依据+卡效果断言 | 逐字 ✔ |
| DR-028 ④ 动态锚 | "deploy 门槛动态锚 max(60, sota_top_score−15)" | #30 决策依据（写作 max(60, sota_top−15)，与原 issue 正文同形） | 语义 ✔（原 issue 已有缩写，未改口径） |
| DR-028R 汇率 | "新增影响力门票汇率 ~1k¥/影（咨询 30/赞助 40/premium API 60–80；危机两线 0 门票=救生索不设闸）" | #26/#27/#38 引用（#27 补猎头 20–40，出自原 issue 正文 DR-028R 同源段） | 逐字 ✔（数值未增删） |
| DR-029 B-5 脉冲 | "影响力脉冲压 5–8 影 or 绑宿敌首冠" | #27/#34/#43 引用"5–8 影 or 宿敌首冠制" | 语义 ✔（与原 issue 正文同形，二选一交 #27 裁） |
| DR-029 G-1 挖人 | "挖人卡加'涨薪留人'（counter-offer 优先于竞业）" + 竞业=flag_set 20 周免挖/工资+10% | #40 决策依据与边界态 | 逐字 ✔ |
| DR-029 F-3 假 arXiv | "假 arXiv=周报装饰行+6 种句式（单句式还原度 5/10 否决）" | #41 决策依据+装饰行断言 | 逐字 ✔（否决句保留在决策依据） |
| DR-029 A-2 condition | "condition 重定义（训练期免扣+drain×train_weeks<80+悬崖改线性+摆烂开关默认开+进 V-sim 供给模型）" | #32 三条 [T] 对应拆写 | 逐字 ✔（<~80 的 ~ 按任务口径标注） |
| GDD §16 硬约束⑤ | "机会窗口连续衰减参数标定（每超 ~10 周 ×0.95 下限 0.7）" | #28 ⑤/#43 正常路径 | 逐字 ✔ |
| 排期裁决批2 | "招聘'贵=可见信息多'；榜单'塞周报别塞脸'（通知层零红点）" | #38 [P]/#39 [P]+#34 边界态 | 逐字 ✔ |

**审查结论**：抽 10 组零失真；未发现发明数值、未发现 DR 外机制、~ 占位全部照抄。本批 19 条升版草稿**过内容审查**，可交制作人席拍板（拍板后走附 2 预案执行 gh issue edit）。

—— 完 ——（主策划席 2026-09-08）

## 附 8：拍板时标签/标题/里程碑动作清单（升版口径"收拢 v1.0"的落表项）

> 口径：三批收拢进 v1.0（MVP 正式发布版）。批次归属（批1/2/3）是排期真源信息，**标题中 [批N] 标记保留**作为排期裁决追溯痕；milestone 由 v0.2 改 v1.0；labels p1/p2 与 status/scheduled 保持。

| # | 标题动作 | milestone | labels | 备注 |
|---|---|---|---|---|
| 26 | 不改 | v0.2 → v1.0 | 保持 | [稿] 标记保留=设计稿先行 |
| 27 | 不改 | v0.2 → v1.0 | 保持 | Q2 联标义务已写入验收 |
| 28 | 不改 | v0.2 → v1.0 | 保持 | |
| 29 | 不改 | v0.2 → v1.0 | 保持 | 标题含 ~ 占位值，照旧 |
| 30 | 不改 | v0.2 → v1.0 | 保持 | |
| 31 | 不改 | v0.2 → v1.0 | 保持 | |
| 32 | 不改 | v0.2 → v1.0 | 保持 | |
| 34 | 不改 | v0.2 → v1.0 | 保持 | 界面类映射表行待 UI 席 |
| 35 | 不改 | v0.2 → v1.0 | 保持 | |
| 36 | 不改 | v0.2 → v1.0 | 保持 | 界面类映射表行待 UI 席 |
| 37 | 不改 | v0.2 → v1.0 | 保持 | |
| 38 | 不改 | v0.2 → v1.0 | 保持 | **对抗评审待跑**再认领 |
| 39 | 不改 | v0.2 → v1.0 | 保持 | 口径待 Q5 |
| 40 | 不改 | v0.2 → v1.0 | 保持 | |
| 41 | 不改 | v0.2 → v1.0 | 保持 | 界面类映射表行待 UI 席 |
| 42 | 不改 | v0.2 → v1.0 | 保持 | 界面类映射表行待 UI 席 |
| 43 | 不改 | v0.2 → v1.0 | 保持 | 与 #34 脉冲同源 |
| 44 | 不改 | v0.2 → v1.0 | 保持 | 界面类映射表行待 UI 席；字段集待 Q4 |
| 45 | 不改 | v0.2 → v1.0 | 保持 | |

## 附 9：本文自查记录（主策划席读回证据）

1. **条目数**：`grep -c "^### #"` = 19（#26–#45 连续区间去 #33）；批1=11 条、批2=6 条、批3=2 条，与排期裁决归属一致。
2. **checkbox 总量**：升版后 [T]+[P] = 114（79 原有 + 35 新增；[T] 95 条=既有 76 保留+19 新增，[P] 19 条全三段式），每条 ≥4；其中 [P] 恰 19 条、全部三段式。
3. **界面类**：7 条（#34/#36/#38/#39/#41/#42/#44），升版变更行均含"映射表行见 UI 席产出"句。
4. **L 规模标注**：#38 正文与标题行均含"对抗评审待跑"。
5. **~ 占位**：`grep -o "~"` 逐条核对——~12%、~40–60k、U(30,60)k~、8–15k、~300–600、×0.95、1.7 倍、46–58k、drain×train_weeks<~80、每超 ~10 周均照抄自原正文/decision-log，未实锁任何占位值。
6. **DR 摘录**：全部来自原 issue 正文与 decision-log（DR-028/028R/029）原文，附 7 抽 10 组零失真。
7. **GUT 用例名**：97 个，附 5 总索引与正文一一对应；命名域建议对齐 tests/unit/ 既有文件。
8. **未执行动作**：本文档为草稿，未运行任何 `gh issue edit`（拍板后按附 2/附 8 预案执行）。

## 附 10：批次内拓扑依赖一览（拍板后排 PR 顺序参考）

```text
批1：#26（经济稿5项）→ #28（7硬约束标定）→ #27（影响力曲线+B-5联标）
      #28/#26 → #29（融资）→ #30（deploy/API）→ #31（支线3卡）→ #32（特质/condition）
      #35（谓词4+2）→ #31/#36；#36（年报）+ #37（图鉴容器）→ 批2
      #27 定案 → #34（总榜行+脉冲，S，可与 #30 并行）
批2：#38（招聘，L，对抗评审先行）⇐ #37+#26；#39（三榜）⇐ #34+Q5
      #40（传闻/挖人/联合课题）；#41（事件扩池）⇐ #31；#42（图鉴UI）⇐ #37+开放问题③
      #43（窗口衰减+脉冲实现）⇐ #28+#27（脉冲与 #34 同源）
批3：#44（往年卷+周目继承）⇐ #36+#37+Q4+一次完整试玩记录
      #45（扩建费+全参数表+gate三值）⇐ #29/#30+试玩记录
```

—— 完 ——（主策划席 2026-09-08；自查与忠实性结论见附 7/附 9）

## 附 11：对抗评审 M8 勘误（2026-09-08 独立评审，以本段为准）

> 各条 [T]/[P] 实数按新正文逐块重盘（脚本统计），"升版变更"行与附 3 矩阵中与此不符的子计数以本表为准：

- ##26：[T]=4，[P]=1
- ##27：[T]=3，[P]=1
- ##28：[T]=9，[P]=1
- ##29：[T]=4，[P]=1
- ##30：[T]=5，[P]=1
- ##31：[T]=5，[P]=1
- ##32：[T]=5，[P]=1
- ##34：[T]=5，[P]=1
- ##35：[T]=5，[P]=1
- ##36：[T]=5，[P]=1
- ##37：[T]=5，[P]=1
- ##38：[T]=5，[P]=1
- ##39：[T]=5，[P]=1
- ##40：[T]=5，[P]=1
- ##41：[T]=6，[P]=1
- ##42：[T]=5，[P]=1
- ##43：[T]=4，[P]=1
- ##44：[T]=5，[P]=1
- ##45：[T]=5，[P]=1

- 全稿合计：[T]=95，[P]=19，checkbox 总量=114（原统计表如有出入以本段为准）；
- 猎头门票"20–40"出处修正（M2-③）：该数值真源=docs/meta/proposals-round2-growth.md（第二轮成长席提案），非 DR-029 A-4/DR-028R 原文——凡挂 DR 名下引用处改为"出处=growth 席提案，待 #27/#28 标定收口"。

## 【下游省工自问】勘误段：子计数修准后，code-review 需求轴按本表核对自证表条数，防"矩阵虚胖"再次发生。
