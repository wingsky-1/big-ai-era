# v1.0.0 新版架构设计（Architecture · Lead Programmer）

> 状态：[设计稿·待评审] ｜ 日期：2026-09-10
> 读取序：README → 13 份规格 → `texts-keys.md` / `numerics-master.md` → **本文件（架构唯一真源）** → 实施 issue
> 性质：**纯架构设计文档**（蓝图重构 v1.0.0 的程序侧总纲），不含游戏代码正文；类名/信号名/目录树/时序伪代码为极小示意片段，实施以本文为底稿进 issue 管线后再落码。
> 原则位：本文只解决"代码怎么长"；"玩法长什么样"以 `docs/blueprints/specs/` 13 份规格为准，冲突时规格优先、并回本文勘误。

---

## ① 设计原则与硬约束

### 1.1 重构执行约束（继承 decisions-100.md §〇）

1. **src/ 归档重写**：旧 src/（44 脚本 / 17 表，v0.1.x）作为工程底料归档保留（工程底盘 / RefCounted 惯例 / GUT 方法作参考）；重写以 `docs/blueprints/specs/` 为唯一真源；`src/data/*.json` 键名**全部按新规格重建（新键名重建，非旧表迁移）**；旧键名与本文/规格不一致时，以本文 §⑥ 重建清单 + 规格 D.1 键名规划为准，禁止"顺手沿用旧键"。
2. **只在场才流淌**：不做离线玩法；存档读档与多周目暂不考虑（G5/制作人裁明）——架构按"单局从头到尾推进 + 周结自动存 + 暂停手动存两档"设计，**不预留**多周目存档分区、时间补偿、回归摘要。
3. **版本计划容器 = 里程碑 v1.0.0**（最小可玩闭环）；P1/P2 只做**结构预留**（本文 §⑦），不预建死代码。

### 1.2 架构硬约束（承接 AGENTS.md + code-style.md）

| # | 约束 | 落地形式 | 检查/门禁 |
|---|---|---|---|
| H1 | L0→L4 单向分层，禁止逆向/同层互引 | 目录树 + preload 纪律（§②）；依赖只向下 | grep 断言 + GUT（§⑨） |
| H2 | 核心规则 100% RefCounted、零 Node 依赖 | L1/L2 全部 `RefCounted`；Node 只存在于 L3 | headless 可跑判定口诀：**"这段逻辑能在没有窗口的服务器上跑吗？"** 不能→重构 |
| H3 | 数值/配置零硬编码 | 一切进 `src/data/*.json`；代码内只出现**键名引用** | gdlint + 禁词断言 + 数据表验收（§⑨） |
| H4 | 表现层零业务计算 | L2 只出数（`get_*_view()`），L3 只格式化/布局（ADR-0016 决策 ①②④ 全量继承） | `test_l3_no_business_math` 类禁词断言（§⑤/§⑨） |
| H5 | 信号命名过去式 snake_case；Signal Up, Call Down | §⑤ 信号清单；子→父发信号，父→子直调 | 命名 gdlint + code-review |
| H6 | stringly-typed 防线：封闭集合一律 enum | §③ 全表：任务槽 type / 员工岗位 / 状态带 / 树迷雾态 / 项目子状态 / 周报行 / 竞对预警 / 命名仪式态 | enum 注册表 + GUT 断言 |
| H7 | 随机源登记制 + 确定性（ADR-0008 继承） | §② L1 `RngStream`；六域各自独立流；**新增随机域=登记表+供给口径联标+万周断言三件套** | grep 消费点 + 同种子双跑哈希 |
| H8 | 存档破坏性变更走 SaveMigrator 链 | §⑧ schema v1 起步 + 迁移链 + 单测（AGENTS.md 红线 6） | `test_save_migrator_*` |
| H9 | 双向引用 weakref | RefCounted 父子/容器互引一律 weakref（红线 5） | code-review |
| H10 | autoload 最少化 | 全局 autoload 仅 `SaveSystem`（存档 IO/原子写）；autoload 脚本禁 class_name | grep autoload 清单 |
| H11 | Godot 4 现代语法、无旧语法 | code-style §1 禁令表 | gdformat/gdlint |
| H12 | 单文件规模纪律 | §⑧ 规模预算表；超限按拆分方向重构（§⑧） | gdlint max-file-lines / max-public-methods |
| H13 | **归档红线**：src/ 旧文件不删除、不并入新实现路径；重建期间新旧文件不可同名共存于新树（防 preload 串档） | 新实现落**原位重写**（同一 src/ 树，按层清空重建），旧文件先 `git mv` 入 `src/_archive_legacy/` 再铺新文件 | PR 自检清单 |
| H14 | 三态/四态覆盖 + 信标断言 | ui-state-visual-mapping.md 惯例：每 UI 行 = 验收 checkbox；信标名"待回填"lint 豁免 | issue 验收 |

> H13 说明：decisions-100.md 说"作为工程底料归档保留"。若归档=原文件保留在 src/ 原位，将与重建文件冲突。**实施执行决策**：`src/_archive_legacy/`（git mv 后目录级忽略 lint/GUT）承载旧底料，src/ 顶层目录清空重建；若制作人希望"原位不动"（见开放问题 P1），则需给旧文件加 `@warning_ignore` 或按层分批替换，代价较高，待拍板。

### 1.3 层内语义收紧（相对旧 ADR-0002 的补充裁决）

1. **L0 core 零依赖是硬边界**：clock 纯函数、score 纯函数、math 全部静态；**禁任何 enum 依赖数据表**（enum 是编译期符号，数据表是运行期键——enum 值与其数据键之间只有"同名字符串"约定时由 §③.2 同源派生防线兜底）。
2. **L1 systems 通用服务不携带玩法规则**：凡"某个具体玩法数值/某个产物规则"一旦出现即属 L2/数据表；L1 只提供机制载体（时钟刻度、RNG 域、文本服务、账本簿记）。
3. **L2 entities 是玩法唯一持有者**：一切状态变更命令（contract commands）与状态输出（数据面）都收敛在 L2；L1 不直接持有 L2 状态，L3 只能经注入触达 L2（ADR-0002 注入语义 + ADR-0016 数据面契约）。
4. **L4 data 是唯一数值真源**：运行期数值只能来自 `DataLoader` 读表；**L3 禁读 L4**（ADR-0016 决策②，违反即打回）。

### 1.4 演进判据（写进 PR 自检清单的架构问句）

新增/改动代码时对号入座：
- 这段是**玩法规则**？→ L2 RefCounted + 数据表键。
- 这段是**表现/排版**？→ L3，且所需的数必须已在 L2 数据面。
- 这段是**通用机制**？→ L1。
- 这段逻辑**离开窗口服务器能跑吗**？不能→拆回 L2。
- 我是不是在**算一个 L2 应该出好的数**？是→回 L2 补数据面（刻意摩擦，ADR-0016 理由 3）。
- 这段用了**新字符串当类型**？→ 回 enum 或同源派生（§③.2）。
- 我**加了随机**？→ 先查 rng 登记表，新域缺三件套=不合格。

---

## ② 分层与目录树

### 2.1 目标目录树（v1.0.0 重建后）

```text
src/
├── core/                      # L0 纯常量/枚举/数学（零依赖，禁 import 其他层）
│   ├── enums.gd               #   全局 enum：ProjectType/ProductKind/DomainId/…
│   │                          #   （enum 常量按 §3.2 与数据键同源，不 import 数据）
│   ├── clock_math.gd          #   周/季/年/节拍纯函数（周→季度→年度→仪式周判定）
│   ├── score_math.gd          #   n 维合成 Σ(维×权)、饱和/守卫护栏纯函数
│   ├── format_math.gd         #   展示精度/缩位/整数化（纯数学，无文案）
│   └── …                      #   （不得出现 .tscn/.tres；静态函数为主）
├── systems/                   # L1 通用服务（仅依赖 L0）
│   ├── data/
│   │   ├── data_loader.gd     #   读表 + 校验 + 缓存（表结构断言/键类型校验）
│   │   └── data_schema.gd     #   每表 JSON 的 schema 断言（形状/类型/必需键）
│   ├── save/
│   │   ├── save_system.gd     #   autoload（唯一 autoload）：原子写/读 IO/存档版本
│   │   └── save_migrator.gd   #   迁移链 v1→v2→…（纯字典，headless 可单测）
│   ├── rng/
│   │   └── rng_stream.gd      #   分域 counter RNG + 域登记 + 计数器入档（ADR-0008）
│   ├── text/
│   │   ├── text_service.gd    #   文案键查表 + <X> 插值（键缺失/插值缺失=断言错误）
│   │   └── text_formatter.gd  #   数字格式化（无文案内容，只做格式）
│   ├── ledger/
│   │   └── ledger.gd          #   唯一过账口：收支行/类别枚举/周内累计/对账闭合
│   └── meta/
│       └── lab_meta.gd        #   实验室名/默认名池（开放容器入档）
├── entities/                  # L2 玩法核心（RefCounted；仅依赖 L0/L1）
│   ├── game_world.gd          #   ⭐唯一状态持有者：组合/装配/发布命令面+数据面
│   ├── game_clock.gd          #   时间与节拍（刻度/周/季/年/仪式日历；失焦策略由装配方）
│   ├── roster.gd              #   员工名册（4→8→12 扩展；双向引用 weakref）
│   ├── staff.gd               #   员工个体：属性/岗位/状态带/培训/观察句 id/在职年限
│   ├── task_board.gd          #   ⭐统一任务槽容器：4 槽 × 三类项目 + 指派 + 结算推进
│   ├── projects/
│   │   ├── project.gd         #   抽象基类：进度/周耗/上桌/协作/出分前统一接口
│   │   ├── paper_project.gd   #   论文项目（复现/研究/课题三型；n 维 4 维）
│   │   ├── model_project.gd   #   训练项目（基座/卡时/checkpoint 墙钟/上桌上限）
│   │   └── compute_project.gd #   算力项目（自研/出租/集群——P0 数据占位,P2 内容）
│   ├── archives/
│   │   ├── paper_archive.gd   #   谱系单向（P1）；P2 双向引用网络（结构预留点）
│   │   ├── model_library.gd   #   模型库（命名/n 维/峰值/曲线/部署状态/谱系）
│   │   └── chip_owned.gd      #   自购芯片/定制档位存档（P2 自研入池）
│   ├── n_dims.gd              #   ⭐n 维共享引擎：布局/权重/三源合成/维度数组
│   ├── ndim_profiles.gd       #   维度布局表驱动适配层（表→运行期布局对象，不 import 数据）
│   ├── resources.gd           #   三资源 cash/influence/card_hours + 供给台账/存量
│   ├── economy.gd             #   工资/运维/救济三件套/市场系数/融资 IPO 条件（P2 部分占位）
│   ├── deploy.gd              #   部署位/定价/被反超惩罚/授权锁档
│   ├── tech_tree.gd           #   树：迷雾五态/研究/升级/翻雾三通路（自持独立 fog 子类？见§4.3）
│   ├── fog.gd                 #   迷雾状态（若拆分：状态机子类，见 §7）
│   ├── rivals/
│   │   ├── rival.gd           #   竞对个体：时间线消费指针/分数曲线/动作数据
│   │   └── rival_pack.gd      #   竞对包（P0=深巷；P2=多竞对；§4.2 接口预留）
│   ├── events/
│   │   ├── event_engine.gd    #   事件卡引擎：池轮转表/通知 z3/决策 z2 出卡
│   │   └── decision_card.gd   #   决策卡内容封装（标题/叙事/选项/效果声明）
│   ├── onboarding/
│   │   ├── tutorial_machine.gd#   引导状态机（六步/替代路径/自检兜底）
│   │   └── goal_card.gd       #   目标卡（自由期三线/阶段目标链 P1）
│   ├── weekly_report.gd       #   周报构建：行类型枚举/呈现顺序/显著变化谓词
│   ├── settlement.gd          #   周结序列编排（只调用各系统结算接口，见 §5.3）
│   ├── name_filter.gd         #   敏感词三层（白名单/词表/近音）
│   └── snapshot_codec.gd      #   World↔存档/快照字典唯一映射点（继承 ADR-0016 承诺）
├── ui/                        # L3 表现层（Node；依赖 L0/L1 + 注入触达 L2 数据面）
│   ├── main/main.tscn|gd      #   根场景/主台装配/注入
│   ├── panel_stack.gd         #   PanelStack 弹窗栈 z0–z3（enum PanelId 扩展见 §6）
│   ├── dashboard/…            #   四主区：工作区（任务槽卡/进度条主视觉）
│   ├── staff_area/…           #   员工区实体卡/状态带/协作角标/横滑行
│   ├── resource_bar/…         #   资源栏/卡时预算条/净流入副行/竞对轻量入口
│   ├── panels/
│   │   ├── task_board_panel.gd #   TASK_BOARD：选题/训练/算力/对照表四页签
│   │   ├── tech_tree_panel.gd  #   TECH_TREE：迷雾列表+1-hop 微图+pity 条
│   │   ├── staff_detail_panel.gd
│   │   ├── paper_archive_panel.gd
│   │   ├── model_library_panel.gd
│   │   ├── chip_yard_panel.gd
│   │   ├── relief_market_panel.gd
│   │   ├── rival_curve_panel.gd
│   │   ├── report_archive_panel.gd
│   │   └── pause_menu_panel.gd
│   ├── modals/
│   │   ├── decision_card_dialog.gd  #   z2 决策卡
│   │   ├── naming_dialog.gd         #   z2 命名框
│   │   ├── weekly_report_dialog.gd  #   z2 自动周报
│   │   └── finale_dialog.gd         #   L3 终局
│   ├── widgets/
│   │   ├── ndim_bars.gd             #   n 维条形图（竖屏主形态；雷达=横屏可选）
│   │   ├── curve_view.gd            #   只读曲线（对决/现金流；L2 出数 L3 只画）
│   │   ├── goal_card_view.gd
│   │   └── toast_layer.gd           #   z3 通知
│   ├── presenters/                  #   L2→L3 数据适配（view 字典→控件可读格式）
│   │   └── dashboard_presenter.gd
│   ├── responsive_layout.gd         #   竖屏/横屏折叠布局
│   └── theme/                       #   tokens/主题（旧主题底料参考）
├── data/                      # L4 纯配置（重建清单见 §6；被读不反向）
│   ├── texts.json             #   texts-keys.md 全键
│   ├── numerics/*.json        #   （或平铺，见 §6 决策点）
│   └── …
└── _archive_legacy/           # 归档底料（git mv 保留；lint/GUT 忽略，见 H13）
    └── …                      #   （旧 v0.1.x src 全量，目录级 .gdignore）
```

> 注：`game_world.gd` 因"契约面+数据面聚合"豁免 max-file-lines 与 max-public-methods（继承 ADR-0016 代价条款）；其余 L2 类遵守 §⑧ 规模纪律。

### 2.2 目录树设计要点（为什么这样长）

1. **projects/ 子目录把三类项目收在同一槽语义下**（§④ 是本文核心类设计）。
2. **archives/（谱系/模型库）与 projects/ 分离**：项目是"进行时"，档案是"完成物资产"；同一产物完成 = 项目结算 → 档案入册两个动作，互不耦合。
3. **rivals/、events/、onboarding/ 各成包**：三个系统在 P0/P1/P2 各自独立演进（事件池扩池、竞对扩员、引导加步），包内私有协作类（如 decision_card）不被外部直连。
4. **n_dims.gd 单独立于任何产物类之外**：三产物（论文/模型/芯片）共用合成/权重/来源逻辑（§4.2）；产物类只声明自己的维度布局与来源权重，实际合成一律调 n_dims（单一公式真源，numerics-master 对账① 的代码落点）。
5. **presenters/ 与 panels/ 分开**：presenter 是"纯数据适配器"（view 字典→界面字段，禁业务计算），panel 是"控件/交互"；两者都属 L3，但 presenter 可 headless 单测、panel 需要场景测试——分开后 UI 的纯逻辑部分也可进 unit（旧 dashboard_presenter 惯例继承）。
6. **tech_tree.gd 与 fog.gd**：先按合一写，若迷雾状态机独立成类（§7.5 拆分之一）再拆；目录树给出 fog.gd 占位（标注"若拆分"），**不做死**。

### 2.3 依赖方向可执行检查（写入 PR 自检与 GUT 断言，见 §9.3）

```gdscript
# 示意（tests/unit/test_layer_rules.gd 内部实现，非产品代码）
for path in _files_of("src/ui"):
    assert_false(_imports(path, "src/entities/"))   # L3 禁 import L2（只允许注入触达）
    assert_false(_imports(path, "src/data/"))       # L3 禁读 L4
for path in _files_of("src/entities"):
    assert_false(_imports(path, "src/ui/"))         # L2 禁 import L3
for path in _files_of("src/core"):
    assert_false(_imports(path, "src/"))            # L0 零依赖
```

---

## ③ 11 系统职责落位表

> 11 系统（蓝图 README §三矩阵）是**设计维度**；代码层不建同名"系统类"，而是落到 RefCounted 核心类与数据表。下表=系统→核心类→边界→依赖的权威映射；同一系统可能拆在多个类，同一类可能服务多个系统，**以"状态唯一持有者"判定归属**。

| 系统 | 代码落位（L2 核心类） | 职责边界（做什么 / 不做什么） | 关键依赖（向下） | 对应数据表 |
|---|---|---|---|---|
| 时间 | `GameClock`（+ L1 无）+ `Settlement` 编排 | 走：墙钟刻度/倍率/暂停/周→季→年/仪式日历；**只走时不算账**。不：结算内容、事件判定、存档时机 | L0 clock_math | `time.json` |
| 员工 | `Roster` + `Staff`（个体） | 走：名册 4→8→12/转岗冷却/培训/解雇离职/状态带/观察句绑定/招募集（P2）；**指派不落 Roster**（见 §4.1 指派写点防双真源：上桌=槽成员，Roster 只出谓词）；**不算产物分**（只输出属性×适配×协作系数供 n 维合成取用） | L1 ledger(工资只读行) | `staff.json` + `economy.json`(工资/扩编费) |
| 经济 | `Resources` + `Economy` + `Ledger`(L1) + `Deploy` | 走：现金/影响力/卡时三资源存量；收支唯一过账口；工资/运维/救济三件套/贷款/私活；部署定价与惩罚；市场系数；融资 IPO（P2） | L1 ledger | `economy.json` |
| 随机 | `RngStream`(L1) + `EventEngine` + 各系统内的掷点 | 走：六域独立流/登记表/计数器入档/事件池轮转；**禁未登记 rand()**；事件只出"卡/行声明"，效果由目标系统执行（决策卡内容与执行分离） | L0（hash 数学） | `rng.json` + `events.json` |
| 科技树 | `TechTree`（迷雾状态见 §4.3） | 走：14 节点表/迷雾五态/翻雾三通路/pity/研究/升级/解锁与定向强化效果登记；**效果执行**委托各目标系统（开选题→TaskBoard+PaperPool、开基座→ModelPool、开档位→ChipYard）；**不直接改资源**（经 Economy 命令） | L1 ledger / rng | `tech_tree.json` |
| 竞对 | `Rival` + `RivalPack` | 走：时间线脚本消费指针（零博弈 AI）/守卫带 L1–L4/撞车判定/价格战/挖人/传闻/外溢翻雾；**不常驻**（只发事件+出数，L3 不常显）；P2 多竞对=包内加员 | L1 rng(rival 域) | `rivals.json` |
| 论文 | `PaperProject` + `PaperPool`（并入 TaskBoard 页签数据） + `PaperArchive` | 走：三型选题/域 RP 权重/工期报酬/谱系单向；**质量归档案、RP 归域存量**分账清晰 | n_dims + TaskBoard 槽 + ledger | `papers.json` |
| 模型 | `ModelProject` + `ModelPool`（基座池） + `ModelLibrary` + `SotaBoard`（独立；见 A3） | 走：基座选择/训练定值/checkpoint 墙钟/出分仪式出数/SOTA 判定/命名入册/部署/迭代 P2/授权锁档；**score 唯一守守卫带** | n_dims + chips(卡时) + ledger | `models.json` |
| 芯片 | `ChipYard`（档位）+ `ComputeProject`（算力项目 P2）+ `CardHoursBudget`（可并入 Resources） | 走：档位 T0–T4 供给/价格/解锁面/周预算/超分配拒绝/出售折价/运维行；P2 算力项目=任务槽第三类；**档位画像=芯片 n 维基础来源** | ledger / tech_tree(解锁) / task_board(算力项目) | `chips.json` |
| UI/UX | L3 全部（panel_stack/dashboard/widgets/presenters）+ L2 只出数 | 走：主台四主区/弹窗栈 z0–z3/竖屏折叠/动画预算/周报双挂载/数值在涨/信标；**禁业务计算、禁读 L4、禁直调非契约命令** | 全部经 World 数据面/命令面 | `ui.json`（显示阈值/动画时长/字号 token） |
| 新手引导 | `TutorialMachine` + `GoalCard`（+ flags 开放容器入档） | 走：六步状态机/替代目标/目标卡出数/命名仪式 z2 触发（经 settlement 钩子）；**引导只读世界状态+发指令，绝不直接改玩法状态**；错误态=跳过不阻塞 | 读各系统数据面谓词 | `onboarding.json` |

### 3.1 边界判据三条（写进 code-review）

1. **状态唯一持有**：某状态（如"这名员工在岗哪个项目""这档卡已拥有"）只在一个类内可变，其余只读。出现"两处能改同一状态"= 违规。
2. **效果执行归属**：效果数据（决策卡选项/节点效果/事件效果）声明在内容/事件侧，**执行**在目标系统侧；内容侧不得偷偷改状态（EventEngine 只出卡、不落账）。
3. **只读查询不进命令面**（ADR-0016 决策④ 继承）：带副作用方法不得伪装 `get_*` 塞进数据面；数据面方法必须纯只读轻量。

### 3.2 跨模块字典键同源派生（H6/H7 的落地）

- 数据表键名 = `texts-keys.md` / 各规格 D.1 的真源键名（**新键名重建**，§6）。
- 代码侧键名引用的**唯一例外**：入档开放容器（flags/ledger 类别等）与"数据表 JSON 内字符串枚举值"可保持字符串（跨版本兼容优先，code-style §2.1 例外条款）——但**同层内**传值（信号载荷/字典键/Array 元素）一律 enum 化。
- 表与 enum 的映射：表内写 `project_type: "paper"` 等稳定字符串（存档兼容），代码侧 enum `ProjectType.PAPER`；**映射只允许单向**：enum→字符串经一张集中映射（如 `ProjectType.to_data_key()`），字符串→enum 只在 DataLoader schema 校验层出现一次。禁止散落 `"paper" == type` 字面量。

---

## ④ 任务槽三型与 n 维评分的类设计

### 4.1 三类项目共用任务槽（规格全局骨架：槽恒 4）

```text
TaskBoard（容器，恒 4 槽）
 ├─ 槽位 slot[0..3]：持 0..1 个 Project + 0..N 个上桌员工引用（weakref）
 │    协作系数计算 → L2 内部
 ├─ ProjectState enum：EMPTY / QUEUED / IN_PROGRESS / FINISHED_PENDING
 │      —— QUEUED 预留给 P2 深队列（P0 直接入空槽=IN_PROGRESS，见 4.3）
 ├─ commands：assign_staff / unassign_staff / start_paper / start_training /
 │     start_compute（P2）/ cancel_project
 └─ outputs：get_task_view() → Array[槽 view]（每槽：type/标题/进度区间/
      预计结账 Wx/上桌者/协作系数/卡时周耗/checkpoint 标/子状态）
```

- **槽位不是队列**：P0 槽满即拒（各 `*_disabled_reason` 单一原因源），不做排队——规格 OP-PAP-01 "排入空任务槽"、numerics-master §四"任务槽恒 4"。
- **Project 抽象基类**（三型共用）：

```text
Project（RefCounted，abstract 语义）
 ├─ 数据：project_type（enum）/ title 键 / 工期(周定值) / 进度(周内刻级) /
 │    剩余周 / 周耗卡时 / 上桌上限 / 协作系数 / 状态
 ├─ 统一钩子：week_tick() → advance（周结由 TaskBoard 驱动，逐项目调用）
 ├─ 子类覆写：_on_week_tick（训练=推进 checkpoint；论文=推进；算力 P2=推进）
 │           _on_finished() → 产出结算声明（发给 World 统一过账，见 4.3 结算）
 └─ 上桌人列表：同槽满 2 人=协作（×1.0/1.05/1.15 读表）
```

- **为什么收进一个容器而不是三类队列分治**：槽位互斥（三类项目抢同一批 4 槽）、指派语义统一（"谁上桌"不因项目类型而异）、结算统一由 TaskBoard 在周结推进。旧实现已实证两类教训：ADR-0015 背景 1/4 的"结算口径分散导致周报收支裂缝与确定性真源受损"、v0.1.3 #104 的"零发射死信号与 L3 半业务层"——槽/结算语义必须是单点，L3 才能只画。
- **指派写点防双真源**：指派命令在 `TaskBoard` 执行（**槽成员 id 列表=唯一写点**）；`Staff/Roster` 不写"在岗项目"字段，只提供 `is_idle()/is_assignable()` 谓词与属性读。员工卡"在岗：<项目名>"= World 聚合 view（遍历槽反查），杜绝"Roster 存一份在岗、TaskBoard 存一份上桌"的双写漂移；双向一致性由 GUT 断言（每员工至多在一槽、槽成员均存在）。

### 4.2 n 维评分=共享组件（单一公式真源）

- **决策：不按产物各自实现，n_dims.gd 为共享组件**。理由：
  1. numerics-master §1.1"合成公式三产物同构 Σ(维×权)"是硬裁决（对账① GUT 断言 `test_ndim_formula_all_products`），三份代码=三份漂移风险，违反单一真源；
  2. 来源构成同构（员工×树×芯片三源，各产物只是权重不同）→ 一次实现四处复用；
  3. 维度扩展（P2 加维/加产物=数组增长）只有共享实现才"加数据即通"（§7.2）。
- 类设计：

```text
n_dims.gd（共享合成引擎，静态为主 + 少量实例方法）
 ├─ func compose(profile: DimProfile, sources: DimSources) -> DimResult
 │    // profile=布局+权重；sources=员工贡献×树强化×芯片发挥×波动登记
 │    // DimResult{values: Array[float], score: float}——values 永远数组
 ├─ func saturate_clamp(...) / guard_check(...)   // 饱和 98/首满 W80 护栏
 ├─ ndim_profiles.gd（表驱动适配层）
 │    func layout(kind: ProductKind) -> DimProfile    // {dim_ids[], weights[]}
 │    // 数据真源=各表 dims/weights 数组；适配层=表→结构体唯一转换点
 └─ 产物侧只声明：
     PaperProject  dim_ids=["novelty","rigor","impact","repro"]
     ModelProject  dim_ids=["reasoning","knowledge","chat","speed","cost"]
     ChipTier      dim_ids=["compute","eff","cost","stability"]
```

- **维度永远数组化**：`values`/`weights`/`dim_ids` 全部 `Array`，配套每产物一个 `dim_label_key[]` 文案键数组（texts-keys 总表键名）→ 新增一维=表+文案键数组加一项，代码零改动（§7.2 扩展路径）。
- **n 维三大来源合成点归属**：`n_dims.compose()` 内部逐维做 `Σ 源×源权重`；源的**取值**由各系统提供（员工贡献由 Project 侧按岗位适配表折算后传入；树强化由 TechTree 查询；芯片发挥由 ChipYard 按档位画像计算——各系统只交"自己的那一份原始值"，合成单一化）。芯片发挥波动、状态带波动在此处**登记入 rng 域统计**（ADR-0008 纪律：消费点可数）。

### 4.3 结算（出分/完成）的执行链——"产出结算声明"防跨层

- 项目完成**不直接发钱/发分**。统一模式（§5.3 周结序列内）：

```text
Project._on_finished() → 产出结算声明（产出对象，纯数据） → Settlement
  → 按产物类型路由（单一 match）：
     paper   → PaperArchive.archived + domain_rp 入账 + influence/cash 过账
     model   → ModelLibrary.archived + 出分计算/命名待办 + SOTA 判定
     compute → ChipYard/能力解锁（P2）
  → 所有资源变更都经 Ledger（唯一过账口，ADR-0015 账期契约）
```

- 该模式防三类事故：项目偷偷改资源（账目不闭合）；产出逻辑散到 L3 呈现时才决定（缺 view）；同周多完成串行揭晓无契约。
- SOTA 判定/守卫带：**"严格大于=破纪录/平局归霸主"只在 L2 一处实现**（models-spec 硬语义）。玩家侧最高分唯一权威 = 独立 `SotaBoard`（只读引用模型库峰值，详见开放问题 A3——本节按独立类示意，评审拍板后回填）；竞对分数=时间线基线 + rng.rival 扰动（±≤2），`Rival` 持有并输出 `get_rival_view()`（守 ADR-0016 数据面）。

### 4.4 槽容器与"是否预留深队列"（P2 算力项目扩槽语义）

- P0 直接入空槽；P2 加算力项目后仍 4 槽（numerics-master §四：上桌上限随基座而非扩槽）；**扩槽=红级**（chips-spec 开放问题 1 收口：解锁面不改任务槽）。
- 若 P2 出现"队列溢出"诉求（自研芯片排队等槽），新增 `QUEUED` 子状态为**纯扩展**（现在枚举里**不写**，加时随 P2 issue 同批：加枚举值+迁移零成本，因为 enum 值不入档，槽 type 入档的是稳定字符串）。预留原则：**不加死代码，只保证"加枚举=可扩展"的形态**（ProjectState 枚举现在含 QUEUED 与否见开放问题 A3——建议 P0 含 EMPTY/IN_PROGRESS/FINISHED_PENDING 三态，QUEUED 等到 P2 再入）。

---

## ⑤ 信号/数据流/周结算时序

### 5.1 L2 出数 / L3 只画的接缝（继承并收紧 ADR-0016）

1. **数据面 = L2 门面上的只读方法**：一律 `get_*_view()` 返回深拷贝字典/基础类型（`Dictionary`/`Array`/`int`/`String`），**不返回 L2 内部对象引用**（防 L3 越权改状态；旧 `staff_roster_dialog` 直读 roster 属违规，见 ADR-0016 对账表）。
2. **命令面 = 契约命令清单**（World 门面，显式注册可 grep）：`request_save` / `set_speed` / `set_paused` / `assign_staff` / `unassign_staff` / `start_paper` / `start_training` / `cancel_project` / `start_research` / `upgrade_node` / `buy_tier` / `sell_tier` / `open_relief`(借/卖/私活) / `deploy` / `undeploy` / `authorize` / `market_boost` / `submit_model_name` / `skip_naming` / `resolve_decision` / `ack_report` / `read_gray_dot` / `dismiss_tutorial_step`…——**P0 实施时以 spec 操作清单为据逐条核过**；每命令=一个玩家操作或系统装配的落点，禁止 L3 直调非契约方法。
3. **快照 vs 数据面分工**（ADR-0016 决策④继承）：存档/读档首渲染用 `ui_snapshot()` 全量只读快照（唯一映射点 SnapshotCodec）；运行中增量更新走数据面查询 + 信号驱动重渲染。**不新增"预告类"信号**（预告=查询，进数据面）。

### 5.2 信号清单（命名=过去式 snake_case；Signal Up, Call Down）

**L2 世界层对外广播**（装配到 L3/测试；全部"事件已发生"语义）：

| 信号 | 载荷（示意） | 发射点 | 消费方（示意） |
|---|---|---|---|
| `week_settled` | `{week, quarter, year, report_id}` | Settlement 周结完成 | L3 周报/灰点/资源栏翻新；引导判定；测试 |
| `resources_changed` | `{cash, influence, card_hours_used, …delta}` | Resources 过账后 | 资源栏跳动/预警横幅/指派可派性 |
| `task_board_changed` | `Array[槽 view]` 或 `{type, slot_index}` | TaskBoard 任一槽状态变 | 工作区槽卡刷新 |
| `project_finished` | `{slot_index, kind, kind_view}` | 项目完成结算后 | 揭晓序列编排（周报内） |
| `staff_assigned` / `staff_unassigned` | `{staff_id, slot_index}` | Roster/TaskBoard | 员工卡/槽卡/协作角标 |
| `staff_state_rolled` | `{staff_id, state, range_hint}` | 周结状态带掷点 | 员工卡状态带（周粒度，周内稳定） |
| `staff_trained` / `training_finished` | `{staff_id, course_id, gain}` | 培训结算 | 属性跳动/周报行 |
| `paper_archived` | `{paper_id, quality_view}` | 论文入谱后 | 谱系/周报行 |
| `model_scored` | `{model_id, name, score, ndim_view}` | 出分仪式出数 | L2 金框头条/命名框 |
| `model_named` | `{model_id, name}` | 命名确认 | 弹层关闭/库刷新 |
| `sota_updated` | `{player_best, rival_best, record}` | SOTA 判定后 | 对决曲线/头条 |
| `rival_timeline_advance` | `{weeks_left, warn_level}` | Rival 周结推进 | 黄/红灯周报行 |
| `rival_action_fired` | `{action, payload}` | Rival 动作命中（发版/涨价/挖人/撞车） | 决策卡/头条/周报行 |
| `fog_changed` | `{domain, node_id, state}` | TechTree 翻雾/研究 | 迷雾面板/域计数 |
| `node_lit` | `{node_id, effect_view}` | 研究完成 | 解锁弹卡 |
| `chip_purchased` / `tier_changed` | `{tier, view}` | ChipYard | 资源栏卡时/徽章 |
| `card_hours_reset` | `{budget, used}` | 周结重置 | 预算条 |
| `decision_pending` | `{card_id, decision_view}` | EventEngine/竞对/救济出卡 | z2 决策卡（决策先于周报） |
| `toast_queued` | `{toast_view}` | 事件通知/存档结果 | z3 toast |
| `report_rows_built` | `{report_view}` | 周报构建完成 | 周报双挂载（z2 自动弹/灰点判定） |
| `tutorial_step_advanced` | `{step_id, goal_view}` | TutorialMachine | 目标卡/气泡 |
| `save_finished` | `{ok, reason}` | SaveSystem | toast |
| `game_over_triggered` | `{kind: IPO 或 bankrupt, summary_view}` | 终局判定 | L3 终局 |

> 纪律：信号**不做**"预告/查询"职责（如 `week_will_settle`），只做事件广播；查询一律数据面。旧 11 个契约信号的经验：**每个信号必须至少一个真实发射点**（旧 `decision_pending` 曾是零 emit 死信号，v0.1.3 #104 教训）——新信号登记时发射点/消费点同 PR 落地，验收点含"信号可达"。

**L3 内部信号**：面板开合/焦点/折叠等按既有 PanelStack 惯例，**只向上**；L3 对 L2 只调用命令面 + 订阅广播。

### 5.3 周结结算序列（事件时序；对 ADR-0015 步序的新版修订）

> 承接 ADR-0015 的账期/破产判定步序结论；新增：产出揭晓与事件/仪式次序（规格 OP-TIM-03"结算序列固定序：进度结算 → 收支对账 → 事件/竞对/仪式 → 周报呈现"）。

```text
Settlement.run_settle(week_n)：
  phase 0  门控：z2 阻塞态必须清空（决策已决/命名已决），否则跳过本 tick
  phase 1  卡时预算重置（card_hours_used=0；chips 周供给语义）
  phase 2  经营收入结算：
             for slot in TaskBoard: project.week_tick()   // 刻级推进
             完成项目 → 产出结算声明 → 按型路由（论文入谱+RP/影响/资金 /
                                          模型出分→命名待办+SOTA / 算力 P2）
  phase 3  固定支出：工资×在册、运维×档位、部署常量收入（被反超惩罚乘数）
  phase 4  ledger 快照（收入-支出=净 恒等，对账尾注）
  phase 5  破产判定短路（全部收入之后；负债计入终局）——若破产：跳过 6–9
  phase 6  账期翻页（reset_week_ledger）
  phase 7  事件/竞对/仪式序列（同帧按信号到达序串行）：
             7a 事件卡引擎（rng.event，通知 z3/决策 z2 声明）
             7b 竞对时间线推进（rival_timeline_advance / rival_action_fired）
             7c 迷雾翻雾/灵感（rng.insight）+ 研究完成 node_lit
             7d 员工状态带掷点（rng.staff，周粒度一次）
             7e 仪式日历（季度大赏/年度排名；与竞对发版错峰，time_ritual_no_overlap）
  phase 8  周报构建（report_rows_built；显著变化谓词单一源判定弹/灰点）
  phase 9  自动存档（周结后原子写，time_autosave_point）
  phase 10 week+=1；广播 week_settled（周报呈现=收尾，z2 由 L3 挂载）
```

- 确定性纪律：**phase 内零墙钟依赖**（周数是唯一时间单位）；全部 RNG 消费只在登记域内、消费点可 grep。
- 命名仪式（出分强制命名）**不在 settlement 内完成**：phase 2 出分后置 `naming_pending`，settlement 在 z2 命名框关闭后才允许进入下一周 tick（阻塞由 PanelStack 门控体现——z2 期间世界停）。同周多模型出分 → 命名队列串行（逐个 z2）。
- "4x 下自动周报不弹"与"平淡周灰点"是 **L3 呈现谓词**（消费 `report_rows_built` 的显著标记），不改变 phase 8 的构建；归档重看走 REPORT_ARCHIVE 同构渲染。

---

## ⑥ src/data/*.json 重建清单（新键名重建，非旧表迁移）

> 铁律：**不读旧 17 表键名**（旧键只作"内容底料"人工参考）；键名唯一真源=texts-keys.md（文案键）+ 各规格 D.1/D.2（数值键）+ numerics-master（跨模块收口键）。实施时每表配 `data_schema.gd` 断言（形状/类型/必需键/键名拼写自检），并跑 `test_data_schema_*`。

| 表文件 | 内容（键名真源） | 备注 |
|---|---|---|
| `texts.json` | texts-keys.md 全表 ~330 键（可平铺或按域拆块，键名不变；真源=总表） | **新键名重建**；唯一性/长度预算 GUT 断言同规格 |
| `time.json` | time-spec D.2：墙钟 1x/2x/4x、季 13/年 52、节拍表（仪式错峰）、存档时机、失焦阈值、结算序列时长、平淡周阈值 | 节拍表=跨表共享日历（rivals 发版周错峰读同表） |
| `economy.json` | economy-spec D.2：阶段/工资/运维/救济/贷款/私活/市场系数/融资 IPO/部署惩罚 | 三阶段结构、供给台账参数 |
| `staff.json` | staff-spec D.2：初始 4 人/岗位矩阵/属性成长/培训课程/抗药性/状态带/协作表/招募参数(P2)/观察句绑定 | 观察句=静态种子绑定（id 入档，文本变不破坏档） |
| `rng.json` | randomness-spec D.2：六域参数（触发率/幅度带/冷却/pity/频率带）+ 最坏组合护栏 | 新域=登记表加行（三件套） |
| `tech_tree.json` | tech-tree-spec D.2：14 节点（域/类型/效果/前置/成本曲线/升级上限/翻雾规则/pity） | 效果声明=解锁/乘子/降费三型 + 引用目标系统键（不开新伪系统） |
| `rivals.json` | rivals-spec D.2：时间线脚本/守卫带 L1–L4/撞车/价格战/挖人/传闻/外溢表 | 时间线=表驱动脚本（零博弈 AI）；守卫带与玩家曲线联标（numerics-master） |
| `papers.json` | papers-spec D.2：选题池（三型×五域）/工期/报酬/RP/影响力/质量来源权重/维度集与权重 | 维度权重表公开（读表胜天） |
| `models.json` | models-spec D.2：基座表（域/档位要求/工期/卡时/上桌上限/画像倾向）/出分公式护栏/饱和/迭代(P2)/默认名池 | 训练时长=定值；checkpoint=50% 确定性 |
| `chips.json` | chips-spec D.2：档位 T0–T4（供给/价格/运维/画像/解锁面）/出售折价/算力项目(P2)/稳定性发挥 | 档位画像刻意 trade-off 非单调 |
| `events.json` | randomness-spec A.1/C.1：事件池（通知/决策/背景装饰三类，正文案池 ≥24 张内容席补全） | 池=确定性轮转表（零新 RNG） |
| `onboarding.json` | onboarding-spec D.2：六步表/目标卡/教学节拍（W1/W3/W4/W9/W10/W13 锚点） | 教学节拍与 time.json 日历同源核对 |
| `ui.json` | ui-ux-spec D.2：显示分级阈值/动画时长/字号 token/进度条规格/toast 上限 | 呈现参数（L2 数据面出数时读取，L3 不读） |
| `sensitive_words.json` | onboarding C.5：三层（whitelist/blocklist/homophone_map） | 内容席维护；全局共用 |
| `assertion_bounds.json` | numerics-master 护栏断言集中收口（各表护栏可集中或分散，二选一见下） | 若分散到各表则无本表（见决策点 D6） |

**三个重建期决策点（先按建议执行，实施首表时校验，见 §⑪）**
- **D6 护栏存储形态**：建议**护栏跟键走**（各表内嵌护栏字段或同表 bound 块），断言运行时读键——"防改数不改护栏"；若跟键造成表结构臃肿，再收口 assertion_bounds.json。倾向：跟键走。
- **D7 数值表文件形态**：规格 D.1 只给"一系统一表"；若实施时单表超规模预算（§⑧，JSON ≤300 行），允许**按内容拆文件**（如 papers_topics.json/paper_ndim.json）但键名前缀稳定、测试对账按前缀组跑。
- **D8 旧表复用口径**：`economy.json / staff.json / rivals.json / texts.json` 等与旧表同名——**重建**（结构/键名全新），旧文件先行 `git mv` 入 `_archive_legacy/`，防同路径覆盖后 Git 误判为 rename 混淆评审；如 Git 判定 rename 导致 diff 不可读，可用 `git mv` + 重建顺序规避（见 H13 执行细节）。

---

## ⑦ P1/P2 拓展预留清单（不 YAGNI，也不做死）

按三档标注：**A=数据表驱动天然扩展**（加数据即可）/ **B=接口预留**（要留形状但不必实现）/ **C=明确不做预留**（P2 立项时重构，现在做了=做死/浪费）。

| # | P1/P2 能力 | 规格出处 | 档 | 预留方式 |
|---|---|---|---|---|
| E1 | 员工 4→8→12 | staff-spec / numerics-master §四 | A | 初始员工表加行=扩容（扩编费门槛表驱动）；L2 不存在"写死 4 人"循环；名册 UI 用数据面总数渲染；**图鉴 P2**=新面板（注册表 +1 行，P2 立项） |
| E2 | 新域/新基座/新档位 | tech-tree / models / chips | A | 全部=表加行：域数组/基座表/档位表 + 文案键加键 + 维度标签键数组加项；树"每域 ≥1 解锁型/无排他"由表结构断言保证（非代码分支） |
| E3 | n 维维度扩展（数组化） | numerics-master §1.1 | A | §4.2：dim_ids/weights/标签键 三数组 + 权重和=1 校验；代码零循环写死维数；**唯一注意**=存档 n 维字段数组化（numerics-master §八） |
| E4 | 迭代/授权（P2） | models-spec OP-MDL-05/06 | B | 模型档案含部署/授权字段（P0 实落：deploy 全流程为 P0 成品变现，economy-spec 三阶段）；迭代版本号键位预留（值恒 0，不预实现逻辑）；P2 加 `iteration_project` 与现 Project 体系天然同构（同槽同指派） |
| E5 | 算力项目（自研/出租/集群，P2） | chips-spec OP-CHP-05 | B | ComputeProject 类占位 + 数据表占位（events 型脚本不实现）；ProjectState/QUEUED 见 §4.4；**接口形状**：算力项目=占槽+效果入账，与 Paper/Model 同接口，P2 只补 `_on_finished` 路由分支 |
| E6 | 多竞对同场（红级 P2） | rivals-spec 开放问题 2 | B | `RivalPack` 容器（P0 只装深巷科技 1 员）；时间线消费指针/分数曲线/预警谓词按"每竞对一份"设计；灰梯=影子榜（P1 可在包内加员）；**P0 不加任何"单竞对特判"分支**（`if rival.name=="深巷"` 即违规） |
| E7 | 引用网络 P2 双向 | papers-spec OP-PAP-04 | B | P1 谱系单向="我引用了谁"（cites 数组入档）；P2 双向=加"被引"索引/查询 + 档案 UI 扩展——**引用方向字段现在预留为数组结构**（入档即含 cites），不加代码 |
| E8 | 收集图鉴（P2） | ui-ux-spec A.2 COLLECTION | B | PanelId 注册表加行即通（§6 注册纪律）；档案类（员工/模型/论文）已天然是"收集容器"，图鉴=只读聚合视图走数据面（L2 出集合 view，L3 只画） |
| E9 | 自由期三线/阶段目标链（P1） | onboarding G2 | B | flags 开放容器现就承载 `freedom_*` 计数（numerics-master §八）；目标卡 GoalCard 的"最有盼头一条+替代目标"= P1 在 TutorialMachine/GoalCard 内扩展判定，不新增系统 |
| E10 | ~~P2 全部预实现~~ | — | C | 不预建：深队列 QUEUED、图鉴面板、多竞对 AI、双向引用 UI、自研芯片内容、融资 IPO 全流程——P2 立项时按本架构加表/加类/加注册，架构形状已保证不加"形状改动" |
| E11 | 时区/回归摘要/离线补偿 | 制作人裁明不做 | C | **明确不做预留**：不做多周目存档分区、不做离线收益表、不做"归来"事件；如在 P2 意外重启需求=需求管线重走（非本架构承诺面） |

**预留判据（code-review 用）**：加字段/加表/加注册 = 允许的预留；加 `if p2:` 分支/加空实现类/加无人调用的方法 = 违规预留（YAGNI 面）。

---

## ⑧ 单文件大小纪律

### 8.1 规模预算表（目标上限，超限=拆分信号）

| 文件类型 | 预算 | 超限信号 | 拆分方向（按职责/子状态拆，不按功能硬切） |
|---|---|---|---|
| L0 core 单文件 | ≤200 行 | 接近上限 | 按数学域拆（clock/score/format 本就分离）；enum 集中文件 `enums.gd` 单独成类豁免行数（纯枚举可超，以"可读性"为准） |
| L1 systems 单文件 | ≤300 行 | 通用服务膨胀 | 按机制拆分（如 text_service/text_formatter；save_system/save_migrator IO 与迁移本就分离） |
| **L2 玩法核心类** | **≤500 行**（game_world 豁免，继承 ADR-0016 代价条款；task_board/n_dims/settlement 严控） | 核心类超限 | ① 按**子状态机**拆：state 逻辑→独立 State 类（StateMachine 惯例，ADR-0002 已备）；② 按**职责面**拆：命令面/数据面/内部推进三类方法**不能拆文件**（门面内聚优先，ADR-0016），先拆"可独立成类且无状态回读"的内部服务（如结算各 phase 处理器）；③ 拆出的类必须可独立单测，拆完行数仍超=再拆 |
| L3 UI 脚本 | ≤400 行 | 表现脚本膨胀 | ① 拆"view 适配"（presenter，纯数据可单测）；② 拆子控件/子场景（widgets）；③ 弹层内容按页签/标签拆子场景（如 task_board 四页签各一 scene）；面板状态逻辑与排版分离后仍超=信号/刷新逻辑回 L2 数据面查缺 |
| 数据表 JSON | ≤300 行 | 表超限 | 按内容域拆文件（键名前缀稳定，D7）；**事件池/选题池/文案池**为开放池（内容席扩充），可先行拆文件防单文件膨胀 |
| tests 单文件 | ≤400 行 | 测试膨胀 | 按被测系统拆文件；模拟类（万周）独立文件 |

**判读口径**：gdlint `max-file-lines` / `max-public-methods` 已有引擎级执行（旧实现豁免案：game_world.gd `:1–5` 与 tech_tree_dialog 局部豁免）；**超限先拆再提交**，禁止"加了豁免注释继续堆"（豁免只在 game_world 门面一处成立）。

### 8.2 与 code-style §4 文件结构序的一致性

每文件内部结构 gdlint 强制（class_name→extends→信号→enum→常量→@export→公有→私有→@onready→虚方法→公有方法→私有方法→内部类）；拆分时保持"文件=一个职责的完整结构序"——**禁把半截逻辑散到多个文件再接**（每个拆分单元必须是可独立读懂的类/子场景）。

---

## ⑨ 存档 schema（v1.0.0 起步）

> 依据：numerics-master §八 存档字段清单扩展为具体结构；破坏性变更走 SaveMigrator 链（AGENTS.md 红线 6 / ADR-0003：版本号缺失=按 v1 处理、只升不降、禁跳步、未来版本拒绝加载）。

### 9.1 顶层结构（示意；键名=实施排期首表时再冻结）

```jsonc
{
  "schema_version": 1,
  "save_kind": "auto" | "manual",
  "meta": { "saved_at_week": 1, "created_at": "…" },
  "game": {
    "seed": 12345,                          // 同种子可复现（numerics-master §八 时间行）
    "week": 1, "quarter": 1, "year": 2022,  // 周粒度唯一时间（G5 收口）
    "speed": 1,                              // 恢复后档位保持（time-spec OP-TIM-05）
    "lab": { "name": "…" },                  // 实验室名（开放字符串，三层过滤已过）
    "rng": {                                 // 分域计数器：加键零迁移（ADR-0008 决策 2）
      "root_seed": 12345,
      "event": 12, "insight": 3, "rival": 5, "task": 0, "staff": 0, "recruit": 0
    }
  },
  "resources": {
    "cash": 123456, "influence": 23, "card_hours_used": 7,
    "ledger": [ … ],                        // 只增不删（对账闭合证据链）
    "supply": { "influence_total": 999 }    // 供给台账（三源对账；economy D.3）
  },
  "staff": [ {                               // 员工=数组（4→8→12=数组增长）
    "id": "s1", "role": "research",          // role=稳定字符串（存档兼容；代码 enum 映射单向）
    "attrs": {"theory": 52, "engineering": 48, "data": 44, "communication": 50},
    "state": {"current": "focus", "weeks_in": 2, "pity_count": 0},
    "observation_id": 3,                     // 静态种子绑定：文本变不破坏档
    "training": {"course_id": "c1", "weeks_left": 2, "times_taken": {}},
    "career": {"transfers_left_cd": 0, "poached_count": 0, "leaved": false}
  } ],
  "task_board": { "slots": [ {               // 槽恒 4；type=稳定字符串枚举
    "type": "paper" | "model" | "compute" | null,
    "project": { …完整项目快照… },
    "assigned_staff": ["s1", "s2"]           // weakref 引用序列化=id 数组（读档重建引用）
  } ] },
  "tree": {
    "fog": { "align": {"deep": "lit", "x1": "visible"}, "…": {} },
    "nodes_lit": { "deep": 1 },              // 升级级数（无排他全可研）
    "rp_by_domain": { "align": 45, "…": 0 }  // 域 RP 键名稳定（改名需迁移）
  },
  "rivals": {
    "deep_alley": {                          // P0 单竞对=包内数组 len=1 亦可（见 E6）
      "timeline_consumed": 8,                // 时间线消费指针：表更新不破坏档
      "score_curve": […], "actual_weeks": […]
    }
  },
  "products": {
    "papers": [ { "id": "p1", "title_key": "paper_topic_…", "domain": "align",
                  "ndim": [71, 62, 55, 68],  // ← n 维字段数组化（维度扩展=数组增长）
                  "influence": 20, "cites": ["rival_p1"], "status": "published" } ],
    "models": [ { "id": "m1", "name": "灵犀初号", "base": "mini",
                  "ndim": […], "score": 62.4, "peak": 62.4,
                  "deploy": {"state": "online", "cum": 123},
                  "authorize": null,          // 授权二选一锁档记录（G6）
                  "iterations": 0 } ],        // P2 迭代版本号位：先留键位，值恒 0（E10 纪律：不预实现逻辑）
    "chips": { "owned_tier": "t1", "ndim_profile": […], "selfmade": null }
  },
  "economy": {
    "stage": "labor", "loan": {"active": false, "left": 0},
    "market_boost": {"left_weeks": 0}, "private_jobs_left": 3,
    "deploy_penalty": 0.0
  },
  "flags": {                                  // 开放容器字符串键（跨版本兼容优先，code-style §2.1 例外）
    "onb_step": "step_4", "scored": true, "freedom_*": …
  },
  "events": { "pool_cursor": 5, "cd_left": { "grant": 0 } },
  "reports": [ …环形缓冲周报快照… ]           // 归档重看数据源（容量上限表驱动）
}
```

### 9.2 序列化与一致性要点

1. **一映射点**：`SnapshotCodec` 是 World↔字典唯一映射点（继承 ADR-0016 承诺）；存档/快照/呈现三方口径同源。
2. **浮点入档**：金额/分数入档用 int 分单位或保留 1 位小数的安全格式（`score` 存 1 位小数 int ×10 可加可选；先按"JSON 安全数字+显示 1 位"处理，实施定档）。
3. **引用序列化**：RefCounted 互引一律序列化为 id 数组/键名，读档后由 World 重建引用（天然规避 weakref 序列化问题）。
4. **ledger 只增**：周结 ledger 行追加不删（对账闭合证据链；容量上限由表驱动，超限滚最旧行——滚行必须保持"本周结收支净=0 恒等"断言仍过）。
5. **reports 环形缓冲**：归档可回看容量有限（如 52 周），超限滚最旧；滚行进"周报已滚"记录防 UI 空洞。

### 9.3 破坏性变更纪律

- `schema_version` 变更=加迁移分支+单测（`test_save_migrator_*`），禁跳步；键名重构=破坏性；数组增长/开放容器加键=非破坏性（零迁移）。
- v1.0.0 首表与旧 v0.1.x 存档**不兼容**（schema 语义全变）——重建首版直接 `schema_version: 1` 起步，旧档不迁移（旧实现作废，decisions-100 §〇）；**未来**版本才承担迁移义务。

---

## ⑩ 测试与 verify

### 10.1 GUT 单测分层（测试规范继承 + 新规划）

```text
tests/
├── unit/                      # 纯逻辑 RefCounted，headless 毫秒级
│   ├── test_clock_math.gd / test_score_math.gd / test_format_math.gd
│   ├── test_data_loader.gd / test_data_schema.gd      # 每表 schema 断言
│   ├── test_rng_stream.gd    # 同种子可复现/分域独立/计数器入档
│   ├── test_ledger.gd        # 唯一过账口/收支闭合
│   ├── test_text_service.gd  # 键存在/插值完整（texts-keys 验收点落地）
│   ├── test_n_dims.gd        # Σ(维×权)、三源合成、饱和护栏（numerics-master 对账①）
│   ├── test_task_board.gd    # 三型共槽/槽恒 4/满槽拒绝（papers-spec 验收点）
│   ├── test_projects_*.gd    # 论文/训练/算力各子类（工期定值/checkpoint/进度）
│   ├── test_staff.gd         # 指派/状态带周粒度/培训/观察句静态种子
│   ├── test_tech_tree.gd     # 迷雾五态/pity/无排他/效果分层
│   ├── test_rivals.gd        # 时间线确定性/守卫带/频率护栏/撞车
│   ├── test_economy.gd       # 过账/破产判定/贷款护栏/部署公式（economy-spec 验收点）
│   ├── test_settlement.gd    # 周结步序/账期契约/破产短路位置
│   ├── test_save_migrator.gd # 迁移链逐级/未来版本拒绝
│   ├── test_onboarding.gd    # 六步状态机/教学节拍断言
│   ├── test_name_filter.gd   # 三层过滤（onboarding 验收点）
│   ├── test_layer_rules.gd   # 分层 import 断言 + L3 禁词 + L3 零业务计算
│   ├── test_view_contract.gd # 数据面方法存在性/只读无副作用（ADR-0016 面）
│   └── test_contract_commands.gd  # 命令面清单/每命令可达（防死命令）
├── integration/               # 场景/管线联通（headless 冒烟）
│   ├── test_main_scene_smoke.gd
│   ├── test_panel_flows.gd    # z1 面板开合/注册表完整（PanelId 全注册）
│   ├── test_weekly_report_render.gd
│   └── test_playtest_loop_headless.gd  # 自动策略跑 N 周管线（旧惯例继承）
├── simulation/                # 万周模拟/数值对账（新目录）
│   ├── sim_montecarlo.gd      # 万周：循环数∈[9,13]/资金闭环/无单侧通关
│   ├── sim_ndim_guardrails.gd
│   ├── sim_economy_stages.gd
│   ├── sim_staff_scale.gd
│   ├── sim_rng_bands.gd       # 各域频率∈带/同种子双跑哈希（ADR-0008 决策 4）
│   └── sim_tradeoffs.gd       # 防唯一解推演（论文域 RP/点树顺序/协作组合）
├── support/                   # 自动策略（auto_decision_policy 等，旧惯例继承）
└── fixtures/
```

### 10.2 UI 信标与呈现证据

- 信标断言名（`ui-*`）：在 L3 控件挂确定性 `beacon` 属性（键=ui-state-visual-mapping 总表/各规格 B.2 建议名），供 Web 导出 selftest（`scripts/selftest_web.mjs`）轮询断言（收敛等待，非固定 sleep——testing.md E2E 纪律）。
- 呈现验收三通道：headless GUT（逻辑态断言）+ Web 真渲染证据（截图归档 `docs/playtest/screenshots/`）+ 人/试玩 [P] 勾选——**禁仅凭 headless 汇报 UI 完成**（v0.1.1/v0.1.2 教训）。

### 10.3 verify.sh 结构建议（对现有脚本的增量）

```text
现有（保留）：
  1. gdformat --check + gdlint（src tests）
  2. 字体 LFS 指针检查 + godot --headless --import --quit（资产完整性）
  3. GUT headless（tests/ 全量；防假绿三重断言：退出码/All tests passed/Tests≥1）
新增建议（进 verify 主链，加 --quick 跳过模式可选）：
  4. 分层 import 断言 + L3 禁词（并入 GUT 层规则测试，替代 grep 散断言）
  5. 数据表 schema 校验（DataLoader 冷加载全表 + test_data_schema_*）
  6. 万周模拟确定性（sim_montecarlo 主链跑；万局分布统计归 nightly）
  7. gdformat/gdlint 的 src 范围含新树全量（_archive_legacy/ 目录级豁免）
```

- **门禁分离原则**（issue-spec §7）：issue_lint/issue-gate 是 CI 独立 check，永不并入 verify.sh 必跑集——新增 4–6 全部是"代码质量门禁"，不掺流程检查。
- 归档目录豁免实现：`src/_archive_legacy/.gdignore` + verify 脚本对该目录显式跳过（gdformat/gdlint/GUT 都不扫），保留 git 历史但不出现在门禁。
- 时序防呆（testing.md 机制 6）：性能断言只拦量级劣化（防呆线=实测 2~3 倍），真门禁=确定性哈希+nightly 蒙卡。

### 10.4 测试验收点 ↔ 规格验收点映射纪律

每张规格的验收点清单（[T]/[P]）是测试 issue 的真源：实施某系统 issue 时把该行测试名直接落进 tests/ 对应文件（`test_<behavior>`），GUT 用例名与规格一致；[P] 项移交试玩脚本 `docs/playtest/scripts.md`（禁止 agent 代跑冒充，issue-spec §6）。

---

## ⑪ ADR 候选清单（待按 adr-authoring 补录）

> 与 AGENTS.md 红线 7"架构决策补 ADR（同 PR 完成）"呼应；编号续 docs/adr/ 现表（0001–0016）。标注★=建议随 v1.0.0 首批落地（决策点 §⑫ 拍板后同批）。

| 编号（建议） | 一句话主题 |
|---|---|
| 0017★ | 蓝图重构执行：src/ 归档重写为 `_archive_legacy/`（git mv 保留底料、目录级豁免门禁），新实现以 docs/blueprints/specs/ 为唯一真源 |
| 0018★ | 统一任务槽容器（TaskBoard 4 槽 × Project 抽象基类 × 三类项目同接口同指派同结算）替代旧 task_queue 三处消费点分治 |
| 0019★ | n 维评分=共享组件 n_dims（单合成公式真源 Σ(维×权)，维度数组化，三产物同构；不按产物各写一份） |
| 0020★ | L2 产出结算声明模式：项目完成不发资源，产出对象经 Settlement 按型路由唯一过账（与 ADR-0015 账期契约合并为同一结算管线） |
| 0021★ | 存档 v1.0.0 schema 起步与旧档弃迁（schema_version=1 起、与旧实现不兼容、未来版本才承担迁移义务） |
| 0022 | 数据表护栏"跟键走"（各表内嵌 bound 块）vs 集中 assertion_bounds.json——首表实施时定 |
| 0023 | 事件卡/决策卡"出卡与执行分离"：内容侧只声明、目标系统侧执行（防决策卡偷改状态） |
| 0024 | 竞对 RivalPack 容器化与"单竞对特判=违规"纪律（P0 深巷独居，灰梯 P1/多竞对 P2=加员不加形状） |
| 0025 | 周报显著变化谓词与"自动弹/灰点/4x 不弹"呈现收敛的单一谓词源（time-spec/ui-ux-spec 同标收口） |
| 0026 | 表现层"数据面=只读深拷贝查询 + 命令面=显式注册清单 + 快照唯一映射点"契约升级（ADR-0016 的 v1.0.0 修订版） |
| 0027 | L3 命名/拆包纪律落地：presenters/ 与 panels/ 分离（纯数据适配 headless 可单测） |
| 0028 | 单文件规模预算表 + 拆分方向（§⑧）成为 gdlint 豁免的判定基准（豁免只留 game_world 门面一处） |
| 0029 | 万周模拟/数值对账进 verify 主链与确定性哈希门禁的分层（主链蒙卡+nightly 万局） |
| 0030 | （P2 前置登记，不实施）多竞对同场红级复议的架构前置材料：压力面分离验证（总分/效率/后期各司其职）与主界面感知预算复核 |

---

## ⑫ 验收点清单（转 issue 时按三段式展开）

- [ ] [T] 分层 import 断言：L3 禁 import L2/L4、L2 禁 import L3、L0 零依赖全过（GUT：`test_layer_rules`）
- [ ] [T] L3 零业务计算禁词断言：`DataLoader/load_json/res://src/data` 在 src/ui 零命中，且新增数据面方法存在性断言（GUT：`test_view_contract` / `test_l3_no_business_math`）
- [ ] [T] 命令面清单与数据面清单锁定：命令数/数据面方法数显式断言，只读查询不进命令面（GUT：`test_contract_commands`）
- [ ] [T] 每信号至少一个真实发射点+一个消费点（防死信号；GUT：`test_signal_reachability`）
- [ ] [T] 任务槽：三类项目互斥占槽 ≤4、槽恒 4、满槽/六因拒绝各显单一原因（GUT：`test_shared_task_slots_three_types` / `test_train_blocked_single_reason_source`）
- [ ] [T] n 维合成：三产物 Σ(维×权) 与权重表一致、score∈[0,100]、权重和=1 表校验、维数数组化无写死维数（GUT：`test_ndim_formula_all_products` / `test_ndim_weight_sum_1`）
- [ ] [T] 周结步序契约：唯一过账口、ledger 收支净=0 恒等、破产判定在收入结算后（GUT：`test_settlement_step_order` / `test_ledger_weekly_balance_closes`）
- [ ] [T] 存档 schema：version 起步/迁移链逐级/未来版本拒绝/快照=唯一映射点（GUT：`test_save_migrator_chain` / `test_snapshot_codec_roundtrip`）
- [ ] [T] 数据表 schema：每表键名拼写/类型/必需键断言；护栏跟键断言（GUT：`test_data_schema_*`）
- [ ] [T] 单文件规模：gdlint max-file-lines/max-public-methods 全绿，豁免仅 game_world 门面一处（verify）
- [ ] [T] 同种子万周双跑哈希一致；六域频率 ∈ 理论带 ±20%；最坏组合 ≥×0.80（GUT：`test_rng_frequency_bands_10k_weeks` 等 simulation 组）
- [ ] [P] 主台 10 秒看懂：任务进度第一视觉（进度条主视觉放大）+ 人在干活（员工卡），指派 ≤2 击（试玩脚本）
- [ ] [P] 首循环 W1–W13 六步目标卡全部达成且无空等；首出分=想截图的时刻（试玩脚本）
- [ ] [P] 平淡周不打扰（灰点一次消失）；濒死自救同屏；4x 挂 10 周回来能说清 3 件事（试玩脚本）
- [ ] [P] 竞对不常驻主界面：任意普通周扫主台无竞对常驻元素，威胁时间/差距 5 秒内查得到（试玩脚本）
- [ ] [P] 数据表重建后"读表胜天"成立：档位/选题/节点/课程信息全公开可查且与玩法一致（试玩脚本）

---

## 开放问题登记（需要数值/制作人返回后才能定的架构点；不静默假设）

| # | 问题 | 类型 | 建议 | 状态 |
|---|---|---|---|---|
| A1 | 周结"墙钟表现节奏"落点：数值只认周数，但 1x 墙钟 ~20–30s 的**刻级表现驱动**是否在 L2 发 tick 信号（增信号/性能）还是 L3 自定时器（只画，不动 L2）——影响 §5.2 信号面 | 程序架构 | 倾向 L3 自定时器轮询数据面（周内只动表现，time-spec §D.3 口径），L2 只发周结级信号；待 time 数值稿返回后确认 | 待拍板 |
| A2 | `game_world.gd` 门面膨胀上限：ADR-0016 已豁免，但 v1.0.0 系统数从 4→11，门面方法数预估超旧 2 倍——是否拆"领域门面"（如 world.game 总门面 + 各系统视图聚合器）还是继续单门面豁免 | 程序架构 | 倾向：单门面+视图聚合器拆文件（数据面方法可搬出为纯只读聚合类，World 只做命令面）；但聚合器不得持有可写状态，需 ADR 固化 | 待评审 |
| A3 | SOTA 判定唯一权威落点：ModelLibrary 自持 vs 独立 SotaBoard 只读引用——影响 §5.2 `sota_updated` 发射面与档案一致性断言 | 程序架构 | 倾向独立 `SotaBoard`（榜语义独立于收藏语义；rivals 守卫带读它天然解耦），读档重建无环 | 待评审 |
| A4 | 里程碑 v1.0.0 的**实施顺序**：规格 13 份 + 本架构 → issue 拆分拓扑序（底层先行：L0/L1/数据表 → 槽/n 维 → 各系统 → 引导/UI）——需制作人排期回合 | 排期 | 建议按 §6 数据表 + §5 结算管线为第一批 issue（管线先行），UI 分批后置 | 待制作人 |
| A5 | 归档执行姿势：`git mv` 入 `_archive_legacy/`（推荐，门禁干净）vs 原位保留（需逐文件豁免）——H13 已按推荐写，待拍板 | 工程 | 见 H13 说明 | 待拍板 |
| A6 | 数值推演四连（G4/G9/G12/G13）未返回前，n 维权重/树预算/守卫带**键值**以"占位→建议→护栏"三档写入数据表（numerics-master 现状），架构不依赖具体值——但**联标断言（首满 W80/树≤30%）随键值首批落表即锁定**，值变更=表变更+断言重跑 | 数值联动 | 架构已按"键驱动断言"设计，数值稿返回前不冻结具体键值；返回后重跑万周模拟 | 依赖数值席 |
| A7 | 若制作人拍板"v1.0.0 不含芯片可购买前 P1 的芯片→树解锁联动细节"等**范围收缩**，本架构的任务槽/三型项目/算力占位是否同步收（ComputeProject 数据占位删除=非破坏性） | 范围 | 结构已按全规格骨架设计；任何范围收缩=从架构表删行（保留 ADR 登记），不反向影响已定型部分 | 待制作人 |
| A8 | PanelId 注册表（ui-ux-spec A.2）P0 实际落地面板数量与"注册纪律"的增键时机（TASK_BOARD/TECH_TREE/STAFF_DETAIL/… 分批登记 vs 一次全注册空壳） | 程序架构 | 建议**随面板 issue 逐批登记**（空壳面板=死代码，违反 §7 预留判据）；注册表完整断言随最后一面板收口 | 待评审 |

---

## 附：本文与既有规范的勘误关系

- 若本文与 `AGENTS.md` 冲突：以 AGENTS.md 红线为准（如 H8 存档纪律、H2 RefCounted）。
- 若本文与某规格冲突：**规格为设计真源优先**，本文勘误并回填（如 §5.3 时序与 time-spec OP-TIM-03 固定序保持一致）。
- 若本文与 ADR 冲突：ADR 为已裁决架构真源优先，本文勘误；新增决策点（§⑪ ADR 0017–0030）以 ADR 正式编号为准。
