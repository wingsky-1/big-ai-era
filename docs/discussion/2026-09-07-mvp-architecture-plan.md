# MVP 整体框架设计稿（主程序 · v1.0 · 2026-09-07）

> **定位**：开工前最后一道架构方案。制作人之问："能否设计出合理的整体框架并适配未来演进"——本稿为正式回答。
> **结论先行**：既有讨论足以落成自洽 MVP 框架——单向五层 + 全 RefCounted 模拟核 + 单一门面 GameWorld + schema v1 冻结包。12 个演进方向全部有预留（绿/黄，无红项，红已被设计期前置消除）。开工前必须拍板：争点①–④（阻塞 PR5–7 数据）、事件效果枚举集、竞对剧本、PanelStack 细节（见 G）。
> **状态**：待对抗评审 + 制作人确认。

## A. 分层全景清单（[已]=脚手架已有，[新]=新增；缩进表达依赖方向，只准向下）

```text
L4 src/data/（纯配置，被读不反向）
  [已] items.json — 演示表，按 N43 迁键进 texts.json 后退役
  [新] techs/rivals/economy/tasks/benchmarks/model_bases/events/texts/stages/staff.json — 全集见 C 节
L3 src/ui/（依赖 L0/L1，经注入的 GameWorld 引用触达 L2；零写路径）
  [已] main/main.gd+.tscn — 启动自检场景，改造为 MENU/宿主
  [新] game_loop_driver.gd — 每帧把 Δt 交 L0 clock_math 累积，满周调 world.tick()；变速系数留在 View
  [新] panel_stack.gd — z 三层弹窗栈、常规互斥栈深 1、白名单不暂停
  [新] dashboard/（资源栏/工作区/竞对条/周报/决策卡/迷雾面板/toast 层/命名框/Game Over 卡）— 只渲染信号+转发命令
L2 src/entities/（游戏规则，全 RefCounted 可无头单测；依赖 L0/L1）
  [新] game_world.gd — 唯一门面：收命令/发信号/组装子系统
  [新] game_clock.gd — 刻步进+周界触发周结；paused=决策卡阻塞唯一源
  [新] economy.gd — 三资源收支聚合（三源 enabled 分支）
  [新] staff_roster.gd — 名册+分配；research_eff=已分配均值（R1a）
  [新] task_queue.gd — 任务五类矩阵执行
  [新] tech_tree.gd — 点亮/解锁重评/加成聚合
  [新] tech_fog.gd — 迷雾五态纯函数状态机（揭示/外溢/交叉/pity）⚠️③
  [新] training_project.gd — 训练计时+出分调用
  [新] sota_board.gd — 严格大于判定、平局归霸主
  [新] rival_track.gd — 8 动作时间线+±15% 扰动+论文动作外溢
  [新] event_engine.gd — 谓词评估/加权抽取/效果应用/pending 队列
  [新] stages.gd — 阶段软门重评（实验室期→自由期）
  [新] snapshot_codec.gd — GameWorld↔存档字典互转（唯一映射点）
L1 src/systems/（通用服务，仅依赖 L0）
  [已] data/data_loader.gd — JSON 唯一加载入口
  [已] save/save_system.gd — autoload 持久化 IO（禁 class_name，维持唯一 autoload）
  [已] save/save_migrator.gd — 迁移链纯静态（现 CURRENT_VERSION=2，PR2 重置 v1）
  [已] state_machine/、stats/ — 通用 FSM 与属性容器（staff 复用 stats）
  [新] text/text_service.gd — texts.json 单一入口（L1 注入，不进 autoload）
  [新] text/formatter.gd — ¥万缩写/负号前置/结构化数值行（C3/C4）
  [新] rng/rng_stream.gd — 分域 counter-based RNG（ADR-0008）
  [新] predicates/predicate_registry.gd — 解锁/触发谓词枚举共享注册表
L0 src/core/（零依赖）
  [新] game_constants.gd — 枚举/RNG 域名/常量
  [新] clock_math.gd — accumulator 变速数学纯静态
  [新] score_math.gd — C1 退化 Cobb-Douglas+sigmoid（因子向量表驱动，θ/k 入参）
```

引用纪律：GameWorld 强持有子系统（单向树），子系统不回指、需要上下文由参数传入；L3 持 world 用 weakref 防 Node↔RefCounted 循环。

## B. GameWorld API 面（单向数据流契约）

**写路径命令（9 个，UI→GameWorld）**
| 方法 | 语义 / 参数要点 |
|---|---|
| assign_staff(staff_id, slot_id) | 分配到任务槽/训练位；空槽时重算 research_eff |
| unassign_staff(staff_id) | 撤回分配 |
| enqueue_task(task_id) | 入队：校验解锁谓词+资金 |
| start_research(tech_id) | 点亮：预扣 RP+结项资金 |
| start_training(base_id) | 发起训练（单基座⚠️④，占研究槽；0 人拒绝） |
| choose_decision(pending_id, option_idx) | 决策卡必选→应用效果→解除 paused |
| submit_model_name(raw) | 命名⚠️②：长度/敏感词校验→插值变量；跳过=默认名池 |
| set_paused(on) | 全局暂停（与决策卡阻塞同源） |
| request_save(reason) | 手动/退出/切后台存触发 |

**读路径信号（10 个，GameWorld→UI）**
| 信号 | 载荷 | 消费者 |
|---|---|---|
| resources_changed | money/compute/influence | 资源栏（刻级） |
| week_settled | report 字典 | 周报面板 + R3 显著周判断 |
| decision_pending | card（选项+预告） | 决策卡弹窗 |
| sota_updated | entry | 竞对条/播报 |
| fog_changed | revealed_ids/域计数/crossover | 迷雾面板 C 方案 |
| task_state_changed | task_id/state | 工作区 |
| stage_advanced | stage_id | 晋升播报（动画预算内） |
| model_named | name | 全播报位插值刷新 |
| game_over | summary（周数/SOTA 次数/最高分） | 结算卡 |
| toast_queued | payload | toast 层逐帧消费（不入档） |

**注入口与测试入口**：`decision_policy: AutoDecisionPolicy`（RefCounted，`pick(card, options) -> int`；默认 -1=等人类；测试注入脚本策略同帧自动应答）。`simulate_weeks(n, policy=null, seed=0) -> Array[Dictionary]`：headless 推进 n 周返回逐周报告；verify.sh 万周模拟与 nightly 同 seed 双跑哈希比对均走此入口。

## C. 数据表全集（**粗体 = schema v1 冻结包字段**；其余亦属 v1 初版）

| 表 | 用途 | 关键字段 |
|---|---|---|
| techs.json | 科技节点 14 个⚠️③ | id/domain/rp_cost/cost/effect{type,value,target,enabled 占位}/**unlock{predicate,params}**/**crossover**/**min_week**/prereq(仅翻雾参考) |
| rivals.json | 竞对时间线 | rival_id/**timeline[]{week,action,params}**/**spill_fields**/**spill_rp_gate**/jitter_pct |
| economy.json | 经济参数 | wage/warn_line/bankruptcy_line/stage_depr/income{reproduce,grant}/**sources{wage,reproduce,grant,financing,api 的 enabled 占位}**/compute_tiers[]{tier,price,capacity} |
| tasks.json | 任务五类矩阵 | id/**type(复现/研究/课题实配，deploy 行占位)**/duration/rp_output/income/**enabled** |
| benchmarks.json | 评测，1 行⚠️④ bench_gkp | bench_id/**sigmoid{theta,k}**/baseline |
| model_bases.json | 基座，1 行⚠️④ base_pushi_1b | base_id/tier/quality/cost_per_week |
| events.json | 事件池 8 张 | event_id/kind(decision\|notice)/trigger{predicate,weight}/slots{text_key,effects[]}/**rng_domain**/**inspiration{base,pity,cap}**(仅灵感卡⚠️①) |
| texts.json | 文本唯一真源 | key/zh/max_len |
| stages.json | 阶段容器 | stage_id/gate{predicate,params}/expected_p50/economy_mod/**enabled:false 占位** |
| staff.json | 3 人初始配置 | staff_id/name/research/engineering/wage/**traits[](enabled:false)** |

**savegame schema v1**：schema_version/week/resources{money,compute,influence}/**rng{root_seed,event_roll,rival_jitter,inspiration}**/techs{lit,fog_visibility,crossover_progress,pity}/tasks{queue,active}/staff{assigned}/training{base,weeks_left}/rivals{cursor,jitter_state}/events{pending[{event_id,shown_options,applied_effects}]}/**player_model_names**/**stages{current}**/sota{best,rival_best}/flags{named,game_over}。影响力 MVP 只进不出（无出口字段）。破坏性变更一律走 SaveMigrator 链上追加。

## D. 周结管线 v2 伪代码

```gdscript
# GameWorld.settle_week()；前置不变式：pending_decisions 为空（决策卡阻塞=GameClock.paused，带卡不结周）
rpt = economy.accrue_week()                          # 1 收支：工资/课题脉冲/复现小额（financing/api 行 enabled 跳过）
if training.finished():                              # 2 出分（L0 纯函数，零 RNG）
    s = ScoreMath.evaluate(research_eff, tech_bonus, compute_tier, c1_table)
    first = sota.submit(s, rival_board)              # 3 SOTA：严格大于/平局归霸主
    if first: prompt_naming(skippable)               # ⚠️② 立项命名
rival.advance(rng.rival_jitter())                    # 4 竞对 ±15%【RNG 域 1】
for a in rival.fresh_paper_actions():                #    论文动作（1–2 个）→外溢
    fog.spill(a.spill_fields, a.spill_rp_gate)
fog.advance(week_rp, crossover_keys)                 # 5 迷雾推进（纯函数）
tech_tree.reevaluate_unlocks(predicates)             #    解锁重评
if rng.inspiration().hit(): events.inject_inspiration()  # 【RNG 域 2】灵感时机⚠️①
events.evaluate(rng.event_roll())                    # 【RNG 域 3】加权抽卡→决策卡入 pending+置 paused / toast 队列
stages.reevaluate()                                  # 阶段软门重评
emit week_settled(rpt)
SaveSystem.save_game(SnapshotCodec.to_save(self))    # 6 存档点=周界自动存（唯一写盘点）
```

RNG 消费点恰 3 处（grep 可验）：rival_jitter / inspiration / event_roll。

## E. 演进扩展点矩阵（绿=纯数据追加 / 黄=加代码不改旧 / 红=需迁移或重构）

| 未来方向 | 当前预留点 | 扩展动作 | 破坏面 |
|---|---|---|---|
| 出分扩维 data_quality | score_math 因子向量表（∑a=1）+Formatter 结构化数值行 | 表加行+K 重锚+断言重标 | 绿 |
| 新解锁谓词 | predicate_registry 成对注册 | 加枚举+评估器 | 黄 |
| 他者道路 3 线 | techs 3 传闻占位节点+spill_fields 落点 | 纯数据追加 | 绿 |
| 三阶段激活 | stages.json 容器+stages.gd 常开+stage_depr 已接 | gate 标定+enabled 翻真 | 黄 |
| 多基座多榜单 | 两表多行 schema+sota_board 复合键 (base,bench) | 加选择器+榜聚合 | 黄 |
| 融资+API | economy sources{financing,api} enabled 占位+tasks deploy 行 | 开关+收支行实现 | 黄 |
| 隐藏特质化学反应 | staff.traits 占位+stat_attribute 聚合器 | 评估器+组合表 | 黄 |
| 多槽存档 | save_game(data, slot:=0) 路径参数化 | 槽位 UI+索引文件 | 黄（零迁移） |
| 假传闻 | 迷雾五态含 rumored+事件 effects 通用字段 | 新事件卡+文本 | 绿 |
| 英文本地化 CSV | texts 键真源+TextService 单入口（max_len 与语言无关） | locale 加载器+CSV 迁移 | 黄（键不变零迁移） |
| 研究失败 | 任务 outcome 枚举占位（缺省 success，不入档） | outcome 分支+字段 | 黄 |
| 体力士气回归 | stat_attribute 通用容器+工资修正项插槽 | 属性回归+公式加项 | 黄 |

矩阵内无红项即本稿设计目标：红被前置消除（榜单复合键/stages 独立系统/存档槽位参数化）。唯一已知升级条件：若"他者道路"需要互斥竞争态、超出迷雾五态语义，TechFog 扩态→红（存档迁移），届时再议。

## F. PR 拆分建议（每个 PR 合入后 verify.sh 全绿且游戏可跑）

| PR | 内容 | 依赖 | 验收要点 | 规模 |
|---|---|---|---|---|
| 1 | texts.json+TextService+Formatter+断链/死键/长度三断言；items.json 退役 | — | 三断言绿；冒烟可跑 | S |
| 2 | schema 重置 v1+SaveSystem 双缓冲（tmp→校验→换名+.bak） | — | 迁移+坏档回退单测 | S |
| 3 | GameWorld 骨架+GameClock+GameLoopDriver+snapshot_codec+simulate_weeks+万周模拟接入 verify.sh | 1 | 万周<5s；同 seed 双跑哈希一致 | L |
| 4 | economy/tasks/staff 三表+task_queue+staff_roster+资源刻级信号 | 3 | 收支曲线断言；分配/撤回 | L |
| 5 | techs 14 节点⚠️③+tech_tree+tech_fog+谓词注册表+防软锁+分位数断言 | 4 | 四类解锁/占位不可研单测 | L |
| 6 | model_bases/benchmarks+训练出分+sota_board+R1(a) 通路+命名防注入⚠️② | 4 | research_eff=0 不可训；命名插值 | L |
| 7 | rng_stream 三域(ADR-0008)+rival 8 动作+event_engine 8 卡+pending 入档 | 5,6 | 消费点 grep 断言；预告=结算一致 | L |
| 8 | 存档三保险（周界/退出/切后台）+Game Over 结算卡(R5) | 2,7 | 刷新恢复；破产流程 | M |
| 9 | PanelStack+四主区 Dashboard+决策卡+toast+周报 R3+命名仪式+竖屏降级+引导 R6 | 8 | UI 零写路径 grep；Pages 真机冒烟 | L |
| 10 | V1–V8 断言区间进 JSON+百局 smoke+真人试玩 DoD | 9 | 断言区间冻结 | M |

另：MENU build 不等 MVP，可随 PR1–2 任一合入即上 Pages 真机验加载/内存。

## G. 自评：开工前仍需讨论的方案清单

1. **争点①–④裁决**（制作人）：本稿按推荐方案设计；改判波及面均为黄级（①灵感改纯触发计数器；③删态删谓词），不阻塞 PR1–4，但**阻塞 PR5–7 数据定稿——开工前必拍**。
2. **事件卡 effects 枚举集**（money/rp/fog_reveal/inspiration/flag…）：阻塞 PR7 数据；效果应用走注册表模式，结构上不阻塞 PR3–6。
3. **竞对 8 动作剧本+论文动作选定**：内容层缺口，阻塞 PR7 数据；spill 通路已预留。
4. **PanelStack 细节**（不暂停白名单清单/周报例外/动画三级落位）：阻塞 PR9；请 UI 席出交互细节稿。
5. **GameWorld 门面拆分时机**：单门面 9 方法+10 信号可控；触发条件=信号>15 或出现按系统簇的重复订阅时拆 EventBus——登记为重构触发器而非预先设计，不阻塞开工。
6. **灵感三键 base/pity/cap 初值与分位数断言区间**⚠️①：PR5/7 带占位值合入，PR10 由 V-sim 标定收口，不阻塞。
7. **TechFog 独立纯函数 vs 复用 L1 state_machine**：倾向独立（五态转移表驱动；state_machine 按 Node 场景语义设计），需 ADR-0009 落笔确认，不阻塞。
8. **敏感词三层兜底词库来源**：文案席交付项，阻塞 PR6 文本、不阻塞通路。

最大残余风险（诚实声明）：本稿保证"不崩、可验证、可演进"，不保证"好玩"——该风险只能由 PR10 后真人试玩证伪，与制作人评估结论一致。
