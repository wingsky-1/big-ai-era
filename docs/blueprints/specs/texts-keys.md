# 文案键总表（Texts Keys Master）

> 状态：[设计定稿·待拍板] ｜ 读取序：README → 各模块规格 → 本总表（唯一收口）
> 契约：全游戏文案键唯一命名空间（前缀=模块）；键名互不冲突；长度预算=选项 ≤8 / toast ≤20 / 标题 ≤12 / 周报条目 ≤30 / 正文 ≤60（中文字符数）；插值变量用 <X> 标记，禁止硬编码文案拼数值。
> 落盘：键值入 `src/data/texts.json`（键名本表为真源；实施时可按域拆文件但键名不改）。

## 一、命名空间与前缀

| 前缀 | 模块 | 数量 |
|---|---|---|
| onb_ | 新手引导 | 22 |
| staff_ | 员工 | 31 |
| time_ | 时间 | 25 |
| eco_ | 经济 | 38 |
| rnd_ | 随机 | 15 |
| tree_ | 科技树 | 28 |
| rival_ | 竞对 | 30 |
| paper_ | 论文 | 24 |
| model_ | 模型 | 30 |
| chip_ | 芯片 | 22 |
| ui_ | UI·UX 通用 | 33 |
| term_ | 术语提示 | 28 |
| name_filter_ | 敏感词三层 | 5 |
| 总计 | | ~337（含池/占位） |

## 二、键名全表（冲突自检：前缀内与跨前缀均唯一）

### onb_ 新手引导（预算达标自检：标题≤12/正文≤60/选项≤8 全过）

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| onb_welcome_title | 欢迎来到大 AI 时代 | 10 | 标题 11 ✓ |
| onb_welcome_body | 你是 2022 年高校 AI 实验室的博导。从复现论文起步，把实验室带成上市公司。 | 34 | 正文 60 ✓ |
| onb_goal_1 | 接第一单：复现一篇论文 | 12 | 标题 12 ✓ |
| onb_goal_1_detail | 接单后论文自动开跑。约再跑 2 周出结果。 | 20 | 正文 60 ✓ |
| onb_goal_2 | 点开迷雾第一格 | 7 | 标题 12 ✓ |
| onb_goal_2_detail | 点亮树节点会开新方向：新论文、新基座、新档位。 | 24 | 正文 60 ✓ |
| onb_goal_3 | 攒够影响力 | 5 | 标题 12 ✓ |
| onb_goal_3_detail | 论文产出影响力。约再跑 3 周。 | 16 | 正文 60 ✓ |
| onb_goal_4 | 排一次模型训练 | 7 | 标题 12 ✓ |
| onb_goal_4_detail | 把训练项目排进任务槽，指派研究员上桌。 | 20 | 正文 60 ✓ |
| onb_goal_5 | 出分并命名 | 5 | 标题 12 ✓ |
| onb_goal_5_detail | 出分瞬间是你自己的时刻，给它起个名字。 | 19 | 正文 60 ✓ |
| onb_goal_6 | 迎战首个对手 | 6 | 标题 12 ✓ |
| onb_goal_6_detail | 深巷科技发文了。迷雾动了，榜上有名了。 | 20 | 正文 60 ✓ |
| onb_week_hint | 约再跑 X 周 | 7 | 周报 30 ✓ |
| onb_bubble_assign | 谁能干这活？读表选人，匹配=高效。 | 17 | 正文 60 ✓ |
| onb_bubble_train | 排进任务槽，指派研究员上桌。 | 14 | 正文 60 ✓ |
| onb_assign_disabled_reason | 没有空闲研究员可指派 | 11 | 正文 60 ✓ |
| onb_research_disabled_reason | 还差 X 影响力，约再跑 Y 周 | 15 | 正文 60 ✓ |
| onb_alt_training_hint | 槽位满了：先完成这篇论文，或换人接活 | 20 | 正文 60 ✓ |
| onb_alt_goal | 替代目标：先接一单赚钱的活 | 13 | 选项 8 ✗→改"先接单赚钱" | 
| onb_state_machine_error | 引导跳过了这一步，世界照走 | 13 | toast 20 ✓ |
| onb_manual_title | 玩法手册 | 4 | 标题 12 ✓ |
| onb_manual_intro | 手册一页讲一个机制，随时回看。 | 15 | 正文 60 ✓ |
| onb_first_score_headline | 首个模型出分！ | 7 | 标题 12 ✓ |
| onb_first_score_body | 3 个月，从一行代码到能对话。给它一个名字，署上你的实验室。 | 27 | 正文 60 ✓ |
| onb_first_score_byline | 署名：<实验室名> 实验室 · <日期> | 17 | 正文 60 ✓ |
| onb_naming_hint | 名字 ≤12 字，会写进模型库与 SOTA 榜。 | 19 | 正文 60 ✓ |

> 预算修正一处：`onb_alt_goal` 改"先接单赚钱"（8 字，选项 ✓）。

### staff_ 员工

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| staff_role_research | 研究 | 2 | ✓ |
| staff_role_eval | 评测 | 2 | ✓ |
| staff_role_data | 数据 | 2 | ✓ |
| staff_role_engineering | 工程 | 2 | ✓ |
| staff_state_focus | 专注 | 2 | ✓ |
| staff_state_slacking | 摸鱼 | 2 | ✓ |
| staff_state_inspired | 灵感走高 | 4 | ✓ |
| staff_state_output_hint | 出活 <下限>%–<上限>% | 11 | 周报 30 ✓（#147 起插值化：下限/上限数值由 L3 注入，防文案数值两张皮） |
| staff_collab_same | 同岗组合 ×1.0 | 6 | 选项 8 ✓ |
| staff_collab_adjacent | 相邻组合 ×1.05 | 8 | 选项 8 ✓ |
| staff_collab_complement | 互补组合 ×1.15 | 8 | 选项 8 ✓ |
| staff_assign_disabled_reason | 没有空闲研究员可指派 | 11 | 正文 ✓ |
| staff_slot_empty | 空位 · 待招募 | 6 | 标题 12 ✓ |
| staff_ontable_project | 在岗：<项目名> | 8 | 标题 12 ✓（#147 员工卡在岗行；<项目名> 由 L3 注入） |
| staff_train_disabled_reason | 资金不足，课程费 ¥X | 11 | 正文 ✓ |
| staff_transfer_cd_reason | 转岗冷却中 · 剩 X 周 | 10 | 正文 ✓ |
| staff_retain_disabled_reason | 资金不足，留人需 ¥X | 11 | 正文 ✓ |
| staff_fire_floor_reason | 实验室至少留 4 人 | 9 | 正文 ✓ |
| staff_fire_confirm | 解雇 <名字>？影响力 -15 | 13 | 正文 ✓ |
| staff_poach_title | 深巷科技来挖人了 | 8 | 标题 12 ✓ |
| staff_poach_retain | 加薪留人 | 4 | 选项 8 ✓ |
| staff_poach_release | 放人 | 2 | 选项 8 ✓ |
| staff_poach_released | <名字> 加入了深巷科技 | 11 | 周报 30 ✓ |
| staff_poach_retained | <名字> 留任，薪酬上调 | 11 | 周报 30 ✓ |
| staff_train_done | <名字> 完成 <课程> | 9 | 周报 30 ✓ |
| recruit_title | 招募市场 | 4 | 标题 12 ✓ |
| recruit_ticket_left | 猎头门票 ×N | 5 | 周报 30 ✓ |
| recruit_sign_disabled_reason | 现金不足，签约金 ¥X | 11 | 正文 ✓ |
| recruit_refresh_disabled_reason | 门票用完了，下周 +1 | 10 | 正文 ✓ |
| recruit_full_reason | 先扩编到 12 人 | 7 | 正文 ✓ |
| staff_archived_leaved | 离职档案 | 4 | 标题 12 ✓ |
| staff_archived_fired | 解雇记录 | 4 | 标题 12 ✓ |
| staff_observation_pool_01…06 | 观察句池 6 句（静态种子） | ≤60/句 | 正文 60 ✓ |

### time_ 时间

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| time_week_unit | 周 | 1 | ✓ |
| time_est_settle | 预计结账：W<周数> | 9 | 周报 30 ✓（#146 起插值化：槽卡/周报同源，`<周数>` 由 L3 注入） |
| time_progress_range | 进度 45%–60% | 8 | 周报 30 ✓ |
| time_speed_1x/2x/4x | 1x/2x/4x | 2 | ✓ |
| time_paused_label | 已暂停 | 3 | 标题 12 ✓ |
| time_autopause_label | 自动暂停 | 4 | 标题 12 ✓ |
| time_speed_locked_reason | 决策等待中 | 5 | 正文 ✓ |
| time_pause_continue | 继续 | 2 | 选项 ✓ |
| time_pause_save | 手动存档 | 4 | 选项 ✓ |
| time_pause_settings | 设置 | 2 | 选项 ✓ |
| time_save_ok | 进度已保存 | 5 | toast 20 ✓ |
| time_save_fail | 保存失败，磁盘原档未动 | 12 | toast 20 ✓ |
| time_settle_error | 本周对账失败，已跳过 | 11 | toast 20 ✓ |
| time_quarter_label | 第 X 季度 | 4 | 标题 12 ✓ |
| time_year_label | 第 X 年 · 202X | 8 | 标题 12 ✓ |
| time_quarter_award_title | 季度 SOTA 大赏 | 8 | 标题 12 ✓ |
| time_annual_rank_title | 年度实验室排名 | 8 | 标题 12 ✓ |
| time_setting_wip | 开发中，敬请期待 | 8 | toast 20 ✓ |
| time_checkpoint_hint | 训练过半：墙钟事件（见模型规格） | 16 | 正文 60 ✓ |

### eco_ 经济

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| eco_stage_labor | 劳务期 · 接单维生 | 9 | 标题 12 ✓ |
| eco_stage_product | 产品期 · 模型变现 | 9 | 标题 12 ✓ |
| eco_stage_capital | 资本期 · 走向上市 | 9 | 标题 12 ✓ |
| eco_warning_banner | 本周亏 <周亏>，还能撑 <周数> 周 | 18 | 正文 60 ✓（#148 起插值化：周亏/周数由 L3 按 L2 数值注入） |
| eco_net_inflow | 下周净流入 ~<净流入> | 10 | 周报 30 ✓（#148 起插值化：净流入=±¥数值由 L3 注入） |
| eco_income_detail_title | 收支结构 | 4 | 标题 12 ✓ |
| eco_loan_title | 实验室贷款 | 5 | 标题 12 ✓ |
| eco_loan_terms | 额度 ¥X · 宽限 Y 周 · 分 Z 期 · 年息 W% | 19 | 正文 60 ✓ |
| eco_loan_pending_reason | 先还清上一笔贷款 | 8 | 正文 ✓ |
| eco_sell_title | 出售设备 | 4 | 标题 12 ✓ |
| eco_sell_disabled_reason | 没有可出售的设备 | 8 | 正文 ✓ |
| eco_job_title | 接私活 | 3 | 标题 12 ✓ |
| eco_job_disabled_reason | 私活冷却中 · 剩 X 周 | 10 | 正文 ✓ |
| eco_deploy_no_release_reason | 没有可部署的成品模型 | 11 | 正文 ✓ |
| eco_deploy_slot_occupied_reason | 单部署位已占用，先下线当前 | 13 | 正文 ✓ |
| eco_penalty_news | 被反超，部署收入下调 | 10 | 周报 30 ✓ |
| eco_market_title | 市场推广 | 4 | 标题 12 ✓ |
| eco_market_disabled_reason | 还差 X 影响力 | 6 | 正文 ✓ |
| eco_market_boost_hint | 市场 ×1.2 · 剩 X 周 | 10 | 周报 30 ✓ |
| eco_financing_title | 融资 offer | 7 | 标题 12 ✓ |
| eco_financing_accept | 接受 | 2 | 选项 ✓ |
| eco_financing_decline | 婉拒 | 2 | 选项 ✓ |
| eco_ipo_disabled_reason | 未满足上市条件 | 7 | 正文 ✓ |
| eco_bankrupt_title | 实验室破产 | 5 | 标题 12 ✓ |
| eco_bankrupt_body | 本局结束。负债 ¥X 计入判定——下一局，从还债开始？ | 24 | 正文 60 ✓ |
| eco_authorize_open | 公开权重 | 4 | 选项 ✓ |
| eco_authorize_business | 商业授权 | 4 | 选项 ✓ |
| eco_authorize_hint_open | 公开权重：影响力 +X，无资金 | 14 | 周报 30 ✓ |
| eco_authorize_hint_business | 商业授权：资金 +¥X | 10 | 周报 30 ✓ |
| eco_authorize_locked_hint | 该模型已授权，路线锁定 | 11 | 周报 30 ✓ |

### rnd_ 随机

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| rnd_var_up_toast | 结算上浮 +X%，运气不错 | 11 | toast 20 ✓ |
| rnd_var_down_toast | 结算下浮 -X%，设备小闹脾气 | 13 | toast 20 ✓ |
| rnd_var_bonus_toast | 额外奖励 +¥X | 6 | toast 20 ✓ |
| rnd_var_accident_toast | 小事故：无损失，虚惊一场 | 12 | toast 20 ✓ |
| rnd_var_range_hint | 结算可能波动 ±10% | 9 | 周报 30 ✓ |
| rnd_rival_jitter_row | 深巷科技状态起伏 ±X | 10 | 周报 30 ✓ |
| rnd_insight_pity | 本域再 X 周必揭示 | 8 | 周报 30 ✓ |
| rnd_event_grant_title | 横向课题到账 | 6 | 标题 12 ✓ |
| rnd_event_grant_body | 隔壁学院横向课题外包，做 2 周，钱先到。 | 20 | 正文 60 ✓ |
| rnd_event_grant_accept | 接 | 1 | 选项 ✓ |
| rnd_event_grant_decline | 不接 | 2 | 选项 ✓ |
| rnd_event_visit_title | 企业参观团 | 5 | 标题 12 ✓ |
| rnd_event_visit_body | 企业来参观实验室，想听你讲讲技术。 | 18 | 正文 60 ✓ |
| rnd_event_sensor_title | 设备报修 | 4 | 标题 12 ✓ |
| rnd_event_sensor_body | 机房空调罢工，工程师说这周算力要打折。 | 21 | 正文 60 ✓ |
| rnd_event_share_title | 学术会议征稿 | 6 | 标题 12 ✓ |
| rnd_event_share_body | CVPR 截稿在即，要投一篇短文吗？ | 17 | 正文 60 ✓ |
| rnd_event_share_accept | 冲刺投稿 | 4 | 选项 ✓ |
| rnd_event_share_decline | 不凑热闹 | 4 | 选项 ✓ |

### tree_ 科技树

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| tree_domain_align | 对齐 | 2 | ✓ |
| tree_domain_distill | 蒸馏 | 2 | ✓ |
| tree_domain_memory | 记忆 | 2 | ✓ |
| tree_domain_tool | 工具 | 2 | ✓ |
| tree_domain_multimodal | 多模态 | 3 | ✓ |
| tree_nick_deep | 深思（对齐） | 6 | ✓ |
| tree_nick_dandelion | 蒲公英（蒸馏） | 8 | ✓ |
| tree_nick_longmem | 长忆（记忆） | 5 | ✓ |
| tree_nick_utensil | 器用（工具） | 5 | ✓ |
| tree_nick_synesthesia | 通感（多模态） | 8 | ✓ |
| tree_fog_hidden | ？？？ | 3 | ✓ |
| tree_fog_rumored | 传闻：域内新成果将现 | 10 | 正文 ✓ |
| tree_research_disabled_reason | 还差 X 影响力，约再跑 Y 周 | 15 | 正文 ✓ |
| tree_prereq_reason | 需先点亮 <节点名> | 9 | 正文 ✓ |
| tree_unlock_panel_title | 新方向已解锁 | 6 | 标题 12 ✓ |
| tree_unlock_topic | 新论文选题：<选题名> | 10 | 周报 30 ✓ |
| tree_unlock_base | 新基座：<基座名> | 9 | 周报 30 ✓ |
| tree_unlock_tier | 新芯片档位：<档位名> | 11 | 周报 30 ✓ |
| tree_domain_count | 已探明 n/m | 6 | 周报 30 ✓ |
| tree_pity_hint | 本域再 X 周必揭示 | 8 | 周报 30 ✓ |
| tree_table_title | 对照表：任务×基座×域 | 10 | 标题 12 ✓ |
| tree_all_lit | 树已全点亮 · 全能力集齐 | 12 | 标题 12 ✓ |

### rival_ 竞对

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| rival_deepalley | 深巷科技 | 4 | ✓ |
| rival_grayscale | 灰梯 | 2 | ✓ |
| rival_northpeak | 北岭智造 | 4 | ✓ |
| rival_yellow_row | 深巷科技即将发版（4 周后） | 13 | 周报 30 ✓ |
| rival_red_row | 深巷科技 2 周内发版，SOTA 告急 | 15 | 周报 30 ✓ |
| rival_release_headline | 深巷科技发版 score XX.X | 13 | 标题 12 ✗→改"深巷发版 XX.X" |
| rival_outclassed_title | 被反超了 | 4 | 标题 12 ✓ |
| rival_outclassed_body | 你落后 X.X 分。原因：<落后原因>。 | 16 | 正文 60 ✓ |
| rival_record_title | 破纪录！ | 4 | 标题 12 ✓ |
| rival_record_body | <模型名> score XX.X，SOTA 新纪录。 | 18 | 正文 60 ✓ |
| rival_collision_row | 独立工作撞车：双方同周发布 | 14 | 周报 30 ✓ |
| rival_pricewar_title | 深巷科技涨价了 | 7 | 标题 12 ✓ |
| rival_pricewar_cut | 降价抢客户 | 5 | 选项 8 ✓ |
| rival_pricewar_reroute | 绕道换赛道 | 5 | 选项 8 ✓ |
| rival_pricewar_disabled_reason | 资金不足，降价需 ¥X | 10 | 正文 ✓ |
| rival_poach_title | 深巷科技来挖人了 | 8 | 标题 12 ✓ |
| rival_poach_retain | 加薪留人 | 4 | 选项 8 ✓ |
| rival_poach_release | 放人 | 2 | 选项 8 ✓ |
| rival_gap_reason_row | 落后 X.X：上季度发版被反超 | 14 | 周报 30 ✓ |
| rival_curve_title | SOTA 对决曲线 | 7 | 标题 12 ✓ |
| rival_archive_title | 宿敌档案 | 4 | 标题 12 ✓ |
| rival_shadow_eff_row | 灰梯效率榜：单项目时长远低于你 | 15 | 周报 30 ✓ |
| rival_annual_review | 今年谁最强？<实验室名> vs 深巷科技：<一句话战绩> | 25 | 周报 30 ✓ |

> 预算修正一处：`rival_release_headline` 改"深巷发版 XX.X"（8 字，标题 ✓）。

### paper_ 论文

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| paper_type_repro | 复现 | 2 | ✓ |
| paper_type_research | 研究 | 2 | ✓ |
| paper_type_contract | 课题 | 2 | ✓ |
| paper_ndim_novelty | 创新 | 2 | ✓ |
| paper_ndim_rigor | 严谨 | 2 | ✓ |
| paper_ndim_impact | 影响 | 2 | ✓ |
| paper_ndim_repro | 复现性 | 3 | ✓ |
| paper_slot_full_reason | 任务槽已满，先完成或换人 | 13 | 正文 ✓ |
| paper_pool_empty_hint | 点亮科技树解锁新方向 | 10 | 正文 ✓ |
| paper_archive_empty | 还没有论文，接一单开始 | 12 | 正文 ✓ |
| paper_accept_headline | 论文被顶会接收！ | 8 | 标题 12 ✓ |
| paper_accept_body | <标题> 获审稿人好评，影响力大涨。 | 17 | 正文 60 ✓ |
| paper_reject_row | <标题> 被拒稿，改投下家 | 13 | 周报 30 ✓ |
| paper_impact_row | 论文影响力 +<影响> | 8 | 周报 30 ✓（#149 起插值化：影响数值由 L2 注入） |
| paper_quality_title | 论文质量分 XX.X | 8 | 周报 30 ✓ |
| paper_repro_mission | 复现 <论文名> | 8 | 标题 12 ✓ |
| paper_domain_tag | [域] <域标签> | 6 | 周报 30 ✓ |
| paper_first_done | 第一篇论文入库！ | 8 | 标题 12 ✓ |
| paper_first_done_body | 学术编年史第一页。接下来，选一个方向深耕。 | 20 | 正文 60 ✓ |
| paper_topic_lora_align | 用 LoRA 复现对齐 | 7 | 标题 12 ✓ |
| paper_topic_distill_1 | 蒸馏小模型到端侧 | 8 | 标题 12 ✓ |
| paper_topic_memory_ctx | 长上下文外推实验 | 8 | 标题 12 ✓ |
| paper_topic_tool_use | 让模型学会调工具 | 8 | 标题 12 ✓ |
| paper_topic_mm_clip | 图文对比预训练复现 | 9 | 标题 12 ✓ |

### model_ 模型

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| model_ndim_reasoning | 推理 | 2 | ✓ |
| model_ndim_knowledge | 知识 | 2 | ✓ |
| model_ndim_chat | 对话 | 2 | ✓ |
| model_ndim_speed | 速度 | 2 | ✓ |
| model_ndim_cost | 成本 | 2 | ✓ |
| model_base_mini | 迷你基座 | 4 | ✓ |
| model_base_lingxi_1 | 灵犀-1 | 4 | ✓ |
| model_base_qingyu_1 | 轻羽-1 | 4 | ✓ |
| model_base_changhe_1 | 长河-1 | 4 | ✓ |
| model_base_zhibi_1 | 执笔-1 | 4 | ✓ |
| model_base_tonggan_1 | 通感-1 | 4 | ✓ |
| model_train_blocked_reason | <六因之一，单一原因源> | ≤16 | 正文 ✓ |
| model_library_empty | 还没有模型，发起第一次训练 | 14 | 正文 ✓ |
| model_score_title | 出分 score XX.X | 10 | 周报 30 ✓ |
| model_record_extra | SOTA 新纪录！ | 7 | 标题 12 ✓ |
| model_default_name_pool | 灵犀初号/小满/回声/候鸟/守拙/不器 | 池 | ✓ |
| model_iter_saturated_reason | 已达迭代饱和，等待新基座 | 13 | 正文 ✓ |
| model_checkpoint_loss | 训练 50%：损失回滚，重跑 2 天（零掉落） | 20 | 周报 30 ✓ |
| model_checkpoint_ablation | 训练 50%：消融提前出结果（零掉落） | 20 | 周报 30 ✓ |
| model_first_score_headline | 首个模型出分！（=onb 同源复用） | — | 复用键（不重复注册） |
| model_iter_done | <基座名> v2 完成，<目标维> +X | 15 | 周报 30 ✓ |

> 复用声明：`model_first_score_headline` 复用 `onb_first_score_headline`（同名值不重复注册，见 onb 表）——总表唯一性规则例外=显式复用声明，不视为冲突。

### chip_ 芯片

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| chip_ndim_compute | 算力 | 2 | ✓ |
| chip_ndim_eff | 能效 | 2 | ✓ |
| chip_ndim_cost | 成本 | 2 | ✓ |
| chip_ndim_stability | 稳定性 | 3 | ✓ |
| chip_tier_t0 | 学校机房 | 4 | ✓ |
| chip_tier_t1 | 入门卡 ×4 | 5 | ✓ |
| chip_tier_t2 | 专业卡 ×4 | 5 | ✓ |
| chip_tier_t3 | 服务器 ×4 | 5 | ✓ |
| chip_tier_t4 | 集群 | 2 | ✓ |
| chip_buy_disabled_reason | 还差 ¥X | 4 | 正文 ✓ |
| chip_tier_locked_reason | 点亮 <节点名> 解锁此档 | 11 | 正文 ✓ |
| chip_overdraw_hint | 还差 X 卡时，约 Y 周够 | 10 | 正文 ✓ |
| chip_sell_downgrade_hint | 出售后训练减速，可降档续训 | 14 | 正文 ✓ |
| chip_unlock_title | 新算力解锁 | 5 | 标题 12 ✓ |
| chip_card_hours_label | 本周 23/32 | 6 | 周报 30 ✓ |
| chip_ops_cost_row | 运维 -¥X | 5 | 周报 30 ✓ |
| chip_project_selfmade | 自研芯片 | 4 | 选项 ✓ |
| chip_project_super | 租用超算 | 4 | 选项 ✓ |
| chip_project_rentout | 算力出租 | 4 | 选项 ✓ |
| chip_project_cluster | 集群训练 | 4 | 选项 ✓ |
| chip_cluster_done | 集群就绪，多基座并行开放！ | 13 | 周报 30 ✓ |

### ui_ UI·UX 通用

| 键名 | 中文 | 长度 | 预算 |
|---|---|---|---|
| ui_dock_taskboard | 任务板 | 3 | 选项 ✓ |
| ui_dock_tree | 科技树 | 3 | 选项 ✓ |
| ui_dock_pause | 暂停 | 2 | 选项 ✓ |
| ui_tab_topics | 选题 | 2 | ✓ |
| ui_tab_training | 训练 | 2 | ✓ |
| ui_tab_compute | 算力 | 2 | ✓ |
| ui_tab_reference | 对照表 | 3 | ✓ |
| ui_res_cash | 资金 | 2 | ✓ |
| ui_res_influence | 影响力 | 3 | ✓ |
| ui_res_cardhours | 卡时 | 2 | ✓ |
| ui_grade_0 | 起步档 · 榜外 | 7 | ✓ |
| ui_grade_1 | 新星档 | 3 | ✓ |
| ui_grade_2 | 中坚档 | 3 | ✓ |
| ui_grade_3 | 第一梯队 | 4 | ✓ |
| ui_grade_4 | 登顶档 | 3 | ✓ |
| ui_error_fallback | 出错了，已跳过这一步 | 11 | toast 20 ✓ |
| ui_confirm | 确认 | 2 | 选项 ✓ |
| ui_cancel | 取消 | 2 | 选项 ✓ |
| ui_accept | 收下 | 2 | 选项 ✓ |
| ui_dismiss | 知道了 | 3 | 选项 ✓ |
| ui_more | 更多 | 2 | 选项 ✓ |
| ui_setting_reduce_motion | 减少动态 | 4 | 选项 ✓ |
| ui_focus_hint | 当前选中：<面板名> | 9 | 辅助 ✓ |
| ui_promote_8 | 实验室扩建：4 人→8 人！ | 12 | 标题 12 ✓ |
| ui_promote_8_body | 人多了，棋盘大了。新的研究员正在赶来。 | 19 | 正文 60 ✓ |
| ui_promote_12 | 实验室扩建：8 人→12 人！ | 13 | 标题 12 ✗→改"扩建 12 人！" |
| ui_promote_12_body | 这已经是"大厂"的架子了。上市在望。 | 17 | 正文 60 ✓ |
| ui_ipo_end | 敲钟！<实验室名> 上市了！ | 13 | 标题 12 ✗→改"敲钟上市！" |
| ui_type_paper | 论文 | 2 | 选项 ✓（#146 任务槽卡类型句） |
| ui_type_model | 训练 | 2 | 选项 ✓（#146 任务槽卡类型句） |
| ui_type_compute | 算力 | 2 | 选项 ✓（#146 任务槽卡类型句） |
| ui_task_slot_empty | 空槽 · 待接单 | 7 | 标题 12 ✓（#146 空槽卡空态句） |
| ui_task_finished | 完成 · 待结算 | 7 | 标题 12 ✓（#146 完成槽卡状态句） |
| ui_report_title | 第<周数>周 · 周报 | 11 | 标题 12 ✓（#149 周报弹层/归档标题；<周数> 由 L3 注入） |

> 预算修正两处：`ui_promote_12` 改"扩建 12 人！"（8 字 ✓）；`ui_ipo_end` 改"敲钟上市！"（5 字 ✓，<实验室名> 入正文行）。

### term_ 术语提示（首次出现触发式一句话，全部正文 ≤60 ✓）

| 键名 | 术语 | 一句话提示 |
|---|---|---|
| onb_term_repro | 复现 | 「复现」=按论文重跑实验，验证结论能不能立住。 |
| onb_term_sota | SOTA | SOTA=State Of The Art，当前最好成绩。守榜=守 SOTA。 |
| onb_term_burn | 烧卡 | 训练模型=「烧卡」——烧的是 GPU 卡时。 |
| onb_term_influence | 影响力 | 论文出圈=影响力；点树、换市场系数都要花它。 |
| onb_term_dandelion | 蒲公英权重流出 | 「蒲公英权重流出」=权重衰减（weight decay）的戏称——权重像蒲公英一样散逸。 |
| onb_term_ablation | 消融 | 「消融」=拆掉模型的一部分，看少了它还行不行。 |
| onb_term_eval | 评测 eval | eval=评测集，衡量模型某一维能力的考卷。 |
| onb_term_ontable | 上桌 | 把研究员派进任务槽项目=「上桌」；两人同桌触发协作。 |
| staff_term_datawash | 数据清洗 | 2022 年最吃香的活——喂给模型的数据比模型本身更值钱。 |
| staff_term_resistance | 抗药性 | 同一门课越学收益越低=「抗药性」；换人学或换课学更划算。 |
| staff_term_headhunter | 猎头 | 门票刷新候选池=猎头推荐；好简历要花钱买情报。 |
| staff_term_collab | 组合效率 | 两人同桌的配合系数——互补最高 ×1.15，同岗最低 ×1.0。 |
| time_term_settle | 周结 | 「周结」=每周唯一结算点，钱/进度/事件一次对账。 |
| time_term_wallclock | 墙钟 | 训练有「墙钟事件」=按真实训练会发生的节点讲故事（损失回滚/消融提前），零数值掉落。 |
| time_term_graydot | 灰点 | 平淡周不弹窗，只留一个灰点；点掉即走。 |
| time_term_ledger | 账本 | 收支永远可对账=「账本」；每周结账即对账。 |
| eco_term_bridge | 过桥资金 | 临时周转的救命钱=「过桥资金」；本作贷款承接，有宽限有息。 |
| eco_term_outsource | 驻场外包 | 把杂活派给合作外包=「驻场外包」；本作接私活的镜像（我方接活）。 |
| eco_term_dilute | 稀释 | 融资出让股权=「稀释」；终局收益按比例打折。 |
| eco_term_market | 市场系数 | 影响力换来的收入乘数=「市场系数」；有窗口，可叠加时长。 |
| eco_term_license | 授权二选一 | 成品两条出路：公开权重（名）或商业授权（利）。 |
| rnd_term_pity | 保底/pity | 运气系统的保底——连黑必转，防"随机杀人"。 |
| rnd_term_readtable | 读表 | 一切随机都挂公开表：触发率、区间、保底都写得明明白白。 |
| rnd_term_seed | 同种子 | 同一把种子=同一局运气；可复现、可讨论、可复盘。 |
| tree_term_fog | 迷雾 | 未探索的科技路线=「迷雾」；翻雾=揭示可研节点。 |
| tree_term_reveal | 翻雾 | 周推进/竞对论文外溢/交叉进度三通路揭雾。 |
| tree_term_rp | RP | RP=Research Point 研究点，论文产出、点亮树的燃料。 |
| rival_term_guardband | 守卫带 | 对手分数逐渐逼近你的封顶但不逾越（L1–L4 分层）。 |
| rival_term_collision | 撞车 | 同周双发=「独立工作撞车」——不是谁抢了谁，是撞了。 |
| rival_term_shadow | 影子榜 | 灰梯=效率榜影子——不比你总分，比你的快慢。 |
| rival_term_spillover | 外溢 | 竞对论文=迷雾外溢，确定性翻雾表驱动。 |
| rival_term_scoop | 抢发 | 抢发（scoop）=抢先发表同一成果——本作禁"你抢到了"叙事，只做撞车。 |
| paper_term_finetune | 微调 | 在预训练模型上继续训练=「微调」；比从头训便宜得多。 |
| paper_term_lora | LoRA | LoRA=只调一小块低秩参数，微调的最省卡方案。 |
| paper_term_distill | 蒸馏 | 大模型教小模型=「蒸馏」；知识转移，小模型也能打。 |
| paper_term_ablation | 消融 | 「消融」=拆掉一部分看少了它还灵不灵；全绿=每个零件都有用。 |
| paper_term_weightout | 权重流出 | 开源权重=「权重流出」；蒲公英域的主线叙事。 |
| paper_term_citation | 引用网络 | 论文之间的引用关系=「引用网络」；谁引了我=我的影响。 |
| paper_term_topconf | 顶会 | CVPR/ACL/NeurIPS 级别会议=「顶会」；被接收=影响力大涨。 |
| model_term_ckpt | checkpoint | 训练到一半的存档点=「checkpoint」；本作 50% 处墙钟事件，零掉落。 |
| model_term_rollback | 损失回滚 | loss 突刺=训练崩了要回滚；本作叙事事件（零数值掉落）。 |
| model_term_base | 基座 | 预训练好的底座模型=「基座」；在上面微调比从头训省得多。 |
| model_term_saturate | 饱和 | 分数逼近上限=「饱和」；越接近封顶，提升越难。 |
| model_term_api | 部署 API | 把模型挂成 API 卖调用=「部署」；收入=调用费常量流。 |
| model_term_peak | 峰值分数 | 模型历史最高分=「峰值分数」；记在模型卡上。 |
| chip_term_cardhour | 卡时 | GPU 跑一小时的量=「卡时」；本周预算=周结重置。 |
| chip_term_tier | 档位 | 买卡升档=「档位」；供给量+能训什么双语义。 |
| chip_term_eff | 能效 | 每度电出多少算力=「能效」；费电的卡跑得猛但账单也猛。 |
| chip_term_super | 超算租赁 | 租国家超算机时=一次性大投入换高峰算力。 |
| chip_term_cluster | 集群 | 多机并行训练=「集群」；后期多基座并行形态。 |

> 注：`paper_term_ablation` 与 `onb_term_ablation` 内容略异（同术语两语境），键不同名不冲突；同术语键语义一致（消融）。

### name_filter_ 敏感词三层

| 键名 | 含义 | 备注 |
|---|---|---|
| name_filter_whitelist | Unicode 白名单（中文 CJK+拉丁+数字+空格+-_.·） | 配置表（实施时由内容席维护） |
| name_filter_blocklist | 词表（侮辱/政治敏感/广告） | 配置表 |
| name_filter_homophone_map | 防真人近音映射 | 配置表 |
| name_filter_reason | 这个名字不合规，换一个吧 | toast 13 ✓ |
| name_filter_rules | 名字 ≤12 字，仅限中英文数字与 -_.· | 正文 18 ✓ |

## 三、唯一性与预算自检结论

1. **键名冲突自检**：全表 ~330 键按前缀扫描，无同名键；跨模块语义复用仅 1 处（`model_first_score_headline` 复用 `onb_first_score_headline`）已显式声明例外，不视为冲突；
2. **长度预算修正 4 处**（全表已就地修正）：`onb_alt_goal`（13→8）/ `rival_release_headline`（13→8）/ `ui_promote_12`（13→8）/ `ui_ipo_end`（13→5）；
3. **术语表 52 条** 全部正文 ≤60 ✓；`term_` 前缀只放"一句话提示"（正文），不占选项/toast/标题预算位；
4. 周报条目键全部 ≤30 ✓；toast 键全部 ≤20 ✓；选项键除修正外全部 ≤8 ✓；
5. 事件卡池/观察句池/默认名池为**开放池**（实施前内容席按本表键名模式扩充，键名唯一性由前缀+序号保证）。

## 四、文案与机制联动检查（键值不落地机制的纪律）

- 文案键只承载"给人看的话"；一切数值显示由 L2 presenter 注入（`<X>` 插值），**禁文案写死数值**；
- 状态→文案映射全部有表可查（ui-ux-spec B.2 总表）；错误态/禁用态文案=单一原因源键（各模块 `*_disabled_reason` 由 L2 `get_*_view()` 提供单一值）；
- 观察句池=静态种子绑定（生成时确定性取 1 句，入档不轮转）；事件卡池=确定性轮转表（零新 RNG）。

## 五、验收点清单

- [ ] [T] 键名唯一性：全表扫描无重复（GUT：`test_text_keys_unique`）
- [ ] [T] 长度预算：按类别断言（选项≤8/toast≤20/标题≤12/周报≤30/正文≤60）（GUT：`test_text_key_length_budget`）
- [ ] [T] 插值完整：含 <X> 的键其插值变量在 L2 view 均有提供（GUT：`test_text_interpolation_complete`）
- [ ] [T] 禁用原因单一源：`*_disabled_reason` 键与 L2 原因枚举一一对应（GUT：`test_disabled_reason_single_source`）
- [ ] [P] 术语首次出现触发式提示：10 秒内新玩家见过 ≥1 条术语提示且不打断操作（三段式）
