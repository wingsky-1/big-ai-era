# MVP 整体框架设计稿（主程序 · v1.1 开工蓝本终稿 · 2026-09-07）

> 定位：v1.0 骨架经对抗评审受理（DR-021）后的定稿修订：吸收 B1–B4/M1–M7/Minor 全部修订、UI 席 Q1–Q6 按推荐裁定、数据字段协商 6 项、文案三项确认、节点表 v2.1（DR-022⑤），与 DR-000~023+DR-005R 全量对齐。本稿即开工蓝本：PR1/PR2 立即动工，PR3 起以本稿为准。
> 结论先行：单向五层+全 RefCounted 模拟核+单一门面 GameWorld 不变；命令 9→11、信号 10→11；周结管线补 Game Over 短路（判定写死在收支后）；演进矩阵改口"2 项已知红，预埋字段后归零"。v1.0 四项开工阻塞（争点①–④/效果枚举/竞对剧本/PanelStack 细节）全部关闭。

## A. 分层全景清单（[已]=脚手架已有；缩进表达依赖方向，只准向下；L2 为职责簇口径，允许同簇合并落文件）

```text
L4 src/data/
  [已] items.json — PR1 迁键后退役
  [新] techs/rivals/economy/tasks/benchmarks/model_bases/events/texts/stages/staff/sensitive_words.json — 全集见 C 节
L3 src/ui/（依赖 L0/L1，经注入 world 触达 L2；零写路径）
  [已] main/main.gd+.tscn — 改造为 MENU/宿主
  [新] game_loop_driver.gd — Δt 交 clock_math 累积，满周调 world.tick()；变速系数与停喂 tick 均属 View（Q2：关页/后台不可见=停喂，只在场才流淌）
  [新] panel_stack.gd — z0–z3 四层、注册表 9 面板、白名单"世界等玩家才停"（DR-020）
  [新] dashboard/（资源栏/工作区/竞对条/周报/决策卡/迷雾面板/toast 层/命名框/Game Over 卡）— 只渲染信号+转发命令
L2 src/entities/（游戏规则，全 RefCounted 无头单测；依赖 L0/L1）
  [新] game_world.gd — 唯一门面：收命令/发信号/组装子系统；只读 getter 与 UI 快照在此组装
  [新] game_clock.gd — 刻步进+周界触发周结；paused = user_paused OR blocked_by_card（M1 双源）
  [新] economy.gd — 三资源收支；apply_delta(resource,amount,reason) 唯一过账口（M3），周报对账可闭合
  [新] staff_roster.gd — 名册+分配；research_eff=Σ已分配研究力（DR-005R），分配变动即重算
  [新] task_queue.gd / tech_tree.gd / tech_fog.gd（迷雾五态+表级 fog_gate）⚠️③
  [新] training_project.gd / sota_board.gd（by_key 复合键容器预埋）/ rival_track.gd（8 动作时间线+外溢）
  [新] event_engine.gd — 谓词评估/加权抽取/效果注册表 9 类型（timing 显式）/pending+effects_pending 队列
  [新] stages.gd（阶段软门重评）/ snapshot_codec.gd（GameWorld↔存档字典唯一映射点）
L1 src/systems/（通用服务，仅依赖 L0）
  [已] data/data_loader.gd / save/save_system.gd（autoload、SaveSystem 唯一写入口、禁 class_name）/ save/save_migrator.gd（现 v2，PR2 重置 v1）/ state_machine / stats
  [新] text/text_service.gd + formatter.gd — texts 单一入口；{var} 单大括号插值且插值值一次转义防二次解析；¥万缩写/负号前置/结构化数值行
  [新] rng/rng_stream.gd — 分域 counter-based（ADR-0008），新随机域=加键零迁移
  [新] predicates/predicate_registry.gd — unlock/trigger/系统保留三类成对注册
L0 src/core/（零依赖）
  [新] game_constants.gd（枚举+RNG 域名；domain 7 值=5 域+crossover+elsewhere）/ clock_math.gd / score_math.gd（量纲 score=100/(1+exp(-(A-θ)/k)) 写死，k 单位=A 分点；θ/k 入表）
```

引用纪律同 v1.0：GameWorld 强持有子系统（单向树），子系统不回指、上下文参数传入；L3 持 world 用 weakref 防 Node↔RefCounted 循环。

## B. GameWorld API 面（单向数据流契约）

**写路径命令（11 个，UI→GameWorld）**
| 方法 | 语义要点 |
|---|---|
| start_new_game(seed) | 建档：seed 初始化各 rng 域计数器+置初始态（B1） |
| get_ui_snapshot() | 全量 UI 快照（B1），字段见下 |
| assign_staff(staff_id, slot_id) | 分配到任务槽/训练位，重算 Σ research_eff |
| unassign_staff(staff_id) | 撤回并重算 |
| enqueue_task(task_id) | 校验 tasks.unlock{predicate,params}+资金 |
| start_research(tech_id) | 点亮：预扣 RP+结项资金 |
| start_training(base_id) | 单基座⚠️④、占研究槽、0 人拒绝 |
| choose_decision(pending_id, option_idx) | 效果经 apply_delta 过账→清 blocked_by_card；稍后处理仅 UI 收起、阻塞不变（DR-022①） |
| submit_model_name(raw) | 命名⚠️②：长度+sensitive_words 校验→插值一次转义；跳过=默认名池确定性轮转（游标入 flags，零 RNG） |
| set_paused(on) | 只写 user_paused；L2 忽略与 pending 冲突的 set_paused(false)（Q4），UI 同步屏蔽速度键 |
| request_save(reason) | 手动/退出/切后台，统一经 SaveSystem 唯一写入口 |

**get_ui_snapshot() 返回结构**（reload/读档/回菜单重进的初始渲染唯一来源）：week；resources{money, compute{tier,hours_remaining}, influence}；research_eff/tech_bonus（派生值）；techs{lit, fog 状态, crossover_progress, pity}；tasks{queue, active{task_id,weeks_left}}；staff 列表（含 assigned）；training{base_id, weeks_left}；rivals{cursor}；pending_decision；user_paused；game_over；model_name；sota{best, rival_best, by_key}。**不含 rng 计数器与 flags 全量**（UI 无需、防误用）。

**读路径信号（11 个，GameWorld→UI）**：v1.0 十信号保留，两处修订——①week_settled：**report 字段集冻结**（Q6：收支行/声誉行/事件行/迷雾行/训练行，对齐 texts 40 键周报模板），并增 naming_request 载荷字段（Q1：仅该周首次出分且未命名时携带，去重游标入 flags，重复出分不重发）；②新增 **progress_ticked**（M7：任务/RP 进度刻级跳动、值变才发，UI 不得自行推算进度）。

**只读 getter**（Q3）：get_staff_view / get_training_view / get_fog_view，一律返回拷贝。Q2 周报自动弹=View 停喂 tick、恢复=pop 完成帧；Q5 game_over 清场由 PanelStack 内部处理。注入口与测试入口（decision_policy / simulate_weeks(n, policy, seed) / 万周与 nightly 同 seed 双跑哈希）同 v1.0。

## C. 数据表（仅列与 v1.0 有差异的表；economy/benchmarks/model_bases/stages 同 v1.0；**粗体=冻结包字段**）

| 表 | 差异 |
|---|---|
| techs.json | 节点表 v2.1（总 14 不变）：深思线改序 对齐→思维链→推理增强，复现灵犀 Chat 硬依赖对齐节点；袖珍智能改开放权重线交叉支路（他者道路余 2 占位，交叉边重接）；通感线 min_week 锚后防穿越。新增表级 **fog_gate{rumored,visible}**；**domain 7 值枚举** |
| tasks.json | 新增 **unlock{predicate,params}**（M4） |
| events.json | trigger 增 **once:bool**（fired 入档）；效果对象显式 **timing** 字段（触碰训练状态机一律 delayed）；效果枚举 9 类型冻结：money/compute/influence/rp_grant/fog_reveal/inject_task/start_training/flag_set/delay_training |
| rivals.json | **spill_fields/spill_rp_gate** 升表级默认参数，timeline 单动作 params 可覆写；8 动作剧本定稿（2 论文+4 发版+2 涨价引用；spill 翻态零 RNG=表序首个 hidden 节点+gate 分档） |
| texts.json | 起步集 40 键；max_len 按字符数计；单大括号插值+转义防二次解析（玩家名含 {week} 不被解析，配防注入单测） |
| staff.json | 增 condition 占位（enabled:false，PR5R 预埋，接 E#12 归零） |

**savegame schema v1（全量）**：schema_version / week / resources{money, **compute{tier,hours_remaining}**, influence} / **rng{}**（开放 dict：root_seed 等四域在册，新随机域=加键零迁移） / techs{lit, fog_visibility, crossover_progress, pity} / tasks{queue, **active{task_id,weeks_left}**} / staff{assigned, condition 占位} / training{base, weeks_left} / rivals{cursor, jitter_state} / events{**fired**（once 配套）, pending[{event_id, shown_options, applied_effects, week_due}], **effects_pending[]}**（delayed 效果队列，周结出分前消费；week_due 承载 M2 顺延、确定性入档）/ player_model_names / stages{current} / sota{best, rival_best, **by_key{} 预埋**} / **flags{}**（开放 dict：named/game_over/name_cursor 等在册，新 flag=加键零迁移）。影响力 MVP 只进不出；破坏性变更走 SaveMigrator 链；字段集冻结时点=科技树 v2 定稿后（共识 3），由 PR5R 执行。

## D. 周结管线 v2.1

```gdscript
# GameWorld.settle_week()；前置不变式：pending_decisions 为空（blocked_by_card→paused，带卡不结周）
rpt = economy.accrue_week()                     # 1 收支（全部经 apply_delta 过账）
if economy.money <= bankruptcy_line:            # 2 Game Over 短路——判定写死在收支后（B3）
    flags.game_over = true
    SaveSystem.save_game(to_save(final))        # 终局档（SaveSystem 唯一写入口）
    emit game_over(summary)                     # 跳过出分/SOTA/竞对/迷雾/事件/阶段/周报，直接返回
for e in events.effects_pending: apply(e)       # 3 pre-settle：delayed 效果在出分前消费（训练类在此触碰状态机）
if training.finished():                         # 4 出分：research_eff=Σ（DR-005R），m=compute.tier 联动
    if sota.submit(ScoreMath.evaluate(...), rival_board) and not flags.naming_done:
        rpt.naming_request = {...}              # 5 SOTA 严格大于/平局归霸主；命名请求（Q1）
rival.advance(rng.rival_jitter())               # 6 竞对±15%【RNG 域 1】+论文外溢（零 RNG 确定性规则）
fog.advance(week_rp, crossover_keys)            # 7 迷雾推进+解锁重评
if rng.inspiration().hit(): inject_inspiration()    # 8 灵感【RNG 域 2】⚠️①
ev = events.evaluate(rng.event_roll())          # 9 事件【RNG 域 3】
# M2：灵感与事件同周命中且事件抽中决策卡→week_due=下周入 pending 顺延（每周至多 1 张决策卡，notice 不占额）
apply(ev.effects)                               # 经 apply_delta 过账；应用后补一次解锁重评（Minor）
stages.reevaluate()                             # 10 阶段软门重评
emit week_settled(rpt)
SaveSystem.save_game(SnapshotCodec.to_save(self))   # 11 周界自动存（三保险时机见 PR8）
```

RNG 消费点仍恰 3 处（grep 可验）：rival_jitter / inspiration / event_roll；默认名池兜底不设第 4 点。

## E. 演进扩展点矩阵（绿=纯数据追加 / 黄=加代码不改旧 / 红=需迁移或重构；撤销 v1.0"无红"）

| 未来方向 | 当前预留点 | 扩展动作 | 评级 |
|---|---|---|---|
| 出分扩维 data_quality | 因子向量表+结构化数值行 | 表加行+K 重锚+断言重标 | 绿 |
| 新解锁谓词 | registry 成对注册 | 枚举+评估器 | 黄（前提：不新增入档状态） |
| 他者道路（余 2 占位） | techs 占位+fog_gate | 数据+翻雾标定+谓词 | 黄（交叉支路后非纯数据） |
| 三阶段激活 | stages 容器+stage_depr 已接 | gate 标定+enabled 翻真 | 黄（前提：不引入新字段/资源） |
| 多基座多榜单 | sota.by_key{} 复合键容器（已预埋） | 选择器+榜聚合 | 红→预埋后归零 |
| 融资+API | sources 占位+deploy 行 | 开关+收支行实现 | 黄 |
| 隐藏特质化学反应 | traits 占位+stat_attribute | 评估器+组合表 | 黄 |
| 多槽存档 | save_game(slot:=0) 参数化 | 槽位 UI+索引 | 黄（零迁移） |
| 假传闻 | 五态含 rumored+effects 通用字段 | 新事件卡+文本 | 绿 |
| 英文本地化 CSV | texts 键真源+TextService | locale 加载器+CSV 迁移 | 黄（调用面零改；max_len per-locale 与结构化数值行须重构） |
| 研究失败 | outcome 枚举占位（缺省 success，不入档） | outcome 分支+字段 | 黄（前提：维持不入档，否则迁移） |
| 体力士气回归 | staff.condition 占位（已预埋） | 属性回归+工资修正 | 红→预埋后归零 |

结论改口：**2 项已知红，预埋 sota.by_key/staff.condition 后归零，预埋动作归属 PR5R**。唯一升级条件保留：他者道路若需互斥竞争态→TechFog 扩态=红（存档迁移），届时专项评审。

## F. PR 拆分（重划后全量；每 PR 合入后 verify.sh 全绿且游戏可跑）

| PR | 内容 | 依赖 | 验收要点 | 规模 |
|---|---|---|---|---|
| 1 | texts 40 键+TextService+Formatter+断链/死键/长度三断言+sensitive_words.json 入 L4；items 退役 | — | 三断言绿+防二次解析单测 | S |
| 2 | 存档机制壳：schema 重置+双缓冲（tmp→校验→换名+.bak）+迁移链；不做字段冻结 | — | 迁移+坏档回退单测 | S |
| 3 | GameWorld 骨架+GameClock 双源 paused+Driver+snapshot_codec+start_new_game/get_ui_snapshot+simulate_weeks+万周模拟；断言区间 JSON 宽区间占位入库（M6，守数值红线） | 1 | 万周<5s；同 seed 双跑哈希一致 | L |
| 4 | economy（apply_delta）+tasks/staff 三表+task_queue（unlock）+staff_roster（Σ）+资源/progress_ticked 刻级信号 | 3 | apply_delta 对账闭合；research_eff=Σ 单测 | L |
| 5 | techs 14 节点 v2.1+tech_tree+tech_fog（fog_gate）+谓词注册表+防软锁+分位数断言 | 4 | 解锁/翻雾/占位不可研单测 | L |
| 5R | PR2 精化稿：schema 字段集冻结（协商 6 项落定）+预埋 sota.by_key/staff.condition+冻结单测 | 5 | 冻结清单核验；预埋键存在 | S |
| 6 | model_bases/benchmarks+训练出分（m=compute.tier 联动）+sota_board+rival_board 占位（竞对常数线，PR7 换真数据零改动）+命名防注入+名池轮转 | 4 | research_eff=0 不可训；插值转义 | L |
| 7 | rng 三域+rival 8 动作剧本+event_engine（9 效果/timing/once/effects_pending/同周双卡顺延） | 5R,6 | 消费点 grep=3；预告=结算一致 | L |
| 8 | 存档三保险（周界/退出/切后台，SaveSystem 唯一写入口+三保险时机）+Game Over 短路+终局档+game_over 信号+summary 字典（结算卡 UI 不在本 PR） | 2,7 | 破产短路单测；刷新恢复 | M |
| 9a | PanelStack 骨架（z0–z3/注册表/白名单/双挂载）+决策卡（三态+稍后处理）+toast | 8 | UI 零写路径 grep | M |
| 9b | Dashboard 四主区+周报（双挂载）+命名仪式+Game Over 结算卡+竖屏降级 | 9a | 信号渲染完整；栈深/焦点归还 GUT | L |
| 9c | 引导+Pages 真机冒烟 | 9b | 8 秒加载红线；竖屏折叠核对 | S |
| 10 | 断言区间收窄冻结+nightly（万次模拟+同 seed 双跑哈希）+百局 smoke+真人试玩 DoD | 9c | 区间冻结；四画像真人对标 | M |

另：MENU build 不等 MVP，随 PR1–2 上 Pages 验加载/内存。

## G. 自评：遗留讨论清单

G1 争点①–④ / G2 效果枚举 / G3 竞对剧本 / G4 PanelStack 细节 / G8 敏感词——全部关闭（数据三件套 DR-023、文案包、DR-020+本稿 Q 裁定）。保留三项：①灵感三键与断言区间初值——PR3 宽区间占位、PR10 由 V-sim 收口（预演报告已给初值）；②TechFog 独立纯函数 vs 复用 L1 state_machine——倾向独立，待 ADR-0009 落笔；③GameWorld 门面拆分触发器——信号>15 或按系统簇重复订阅时拆 EventBus，登记为重构触发器而非预先设计。新增最大不确定项=**V-sim 预演**（RP 供需 / 现金流蒙特卡洛 / sigmoid 量纲 / ±15% 下 SOTA ε 分布 + DR-005R K 重锚），插 PR3 后、PR5R 之前——是 PR5–7 数值定稿的闸门，无结构改动（**预演已完成**，见 `2026-09-07-mvp-balance-preview.md`）。

残余风险声明不变：本稿保证"不崩、可验证、可演进"，不保证"好玩"——由 PR10 后真人试玩证伪。
