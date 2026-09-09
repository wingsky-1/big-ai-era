# v1.0.0 开发驱动 Prompt（主程序席 · 协调子 agent 程序团队）

> **用途**：复制本文件「§九 可复制 Prompt」段落，直接发送给下一个会话的**主程序席 agent**，即可驱动 v1.0.0（7 批 32 单）的实施与子 agent 编排。
> **前置状态（2026-09-09 已就绪）**：蓝图重构真源包已合 main（#122）；22 项决策闭环（G1–G14+A1–A8）；架构文档入库；GitHub 旧管线已清（30 旧 issue+2 旧里程碑+PR#117 关闭）；v1.0.0 里程碑 32 单（#123–#154）全建全挂、每单带关键文件关联；src/ 旧实现**待归档**（#123）。
> **配套真源**：`docs/blueprints/specs/`（设计/数值/架构/计划唯一真源）→ 本 Prompt（执行）→ GitHub issue（DoD）。

---

## 一、设计说明（给人类看，不随 Prompt 复制）

本 Prompt 与 v0.1.5 旧版（`2026-09-08-015-dev-driver-prompt.md`）同构但有三点升级：

1. **真源升级**：设计真源= `docs/blueprints/specs/*`（13 规格+decisions-100+architecture-100+release-plan-100），旧 GDD/讨论稿**不再作为实施依据**（红线：不读旧实现 src/，只作 `_archive_legacy/` 底料参考）；
2. **架构升级**：实施须落 architecture-100 的目标目录树（TaskBoard/n_dims/Settlement/SotaBoard 等新形状），旧代码零复用；
3. **编排升级**：批内并行/批间串行由"改动面+数据键依赖"判据驱动，主程序席验收合并子 agent PR（跑 verify+抽查自证表证据）。

## 二、硬锚点（复制后仍生效）

| 锚点 | 内容 | 为什么 |
|---|---|---|
| **真源锚** | `docs/blueprints/specs/` 13 规格 + decisions-100（22 决策）+ architecture-100 + release-plan-100 = 唯一真源；**禁读旧 src/ 实现**（只允许 `_archive_legacy/` 底料参考） | 重构红线：旧实现已作废，读它=被旧形状带偏 |
| **顺序锚** | 批0(#123–129) → 批1(#130–134) → 批2(#135–138) → 批3(#139–141) → 批4(#142–144) → 批5(#145–151) → 批6(#152–154)；**批内按依赖**，数据表/schema 先行（#128） | 拓扑=排期；管线先行防返工 |
| **架构锚** | 分层 L0→L4 单向；核心 RefCounted；L2 出数 L3 只画；TaskBoard 4 槽三类同接口；n_dims 单公式真源；Settlement 唯一过账；SotaBoard 独立；`_archive_legacy/` 门禁豁免 | architecture-100 全篇 |
| **数值锚** | 键名真源=texts-keys.md（文案）+各规格 D.1/D.2+numerics-master（收口）；**数值修正已入档**：协作 ×1.08/×1.18、data 系数 1.25、树乘子 +2–3%、迭代 Δ≤2 饱和带、芯片品质分单调+算力权重 0.50 | G4/G9/G12/G13 已回写 |
| **停手锚** | 不重开已裁 DR；不读旧实现；无 issue 不合码；[P] 留真人试玩禁 agent 代勾；范围收缩=删行+ADR（A7） | 纪律红线 |

## 三、子 agent 程序团队编排（主程序席核心职责）

### 3.1 分派模板（必须按此格式，禁一句话派活）

```markdown
【任务】实施 GitHub issue #<N>「<标题>」
【仓库】/home/tangyi/dev/game/big-ai-era（分支：feat/<N>-<slug>）
【DoD】逐字复制 issue 验收点（≥3 [T] + [P]），不得增删改
【真源】<该单实施提示节列出的关键文件：规格 D.2 键名表 + architecture-100 §章节>
【改动面】<该单将新建/修改的 src/ 路径清单（按 architecture-100 §2.1 目录树）>
【硬约束】<1–3 条：分层/RefCounted/数值进 data/键名真源/存档迁移链>
【验证】bash scripts/verify.sh 全绿 + 新增断言列出用例名与断言点
【交付】PR（body 引用 #<N>）+ 自证表（验收点→文件:行号→GUT 用例名→passing，只引用不复述）+ issue 验收点勾选
【禁止】改 issue 验收点 / 跳过 verify / 读旧 src/ 实现 / 引入新依赖 / 顺手做相邻单
```

### 3.2 并行判据（主程序席每次派活前过一遍）

单的依赖全部已合并 ∧ 改动面不重叠（按 §2.1 目录树核对）∧ 不触碰同一数据键/同一数据表 → **可并行**；否则串行。批内典型并行组：批0 的 #124/#125/#126/#127（文本/RNG/存档/时钟互不依赖，但都依赖 #123 归档+可能都建 src/ 骨架——**先 #123+#128 串行，再放并行**）；批5 UI 的 #146–#151 在 #145 骨架后部分并行。

### 3.3 子 agent 交付验收（主程序席必做，禁直接信任）

1. 本地跑 `bash scripts/verify.sh` 复核全绿；
2. 抽查自证表证据真实性：打开声称的 `文件:行号` 核对断言确在；
3. 核对 issue 验收点逐条可勾（未勾满=打回补齐）；
4. 数据表键名与 texts-keys/numerics-master 真源拼写一致（防 stringly-typed）；
5. 通过后合 main；PR 合入=issue 自动关+`status/done`。

---

## 四、每单闭环（五步，缺一不可）

1. **读**：issue 验收点（即 DoD，**不得自行降级**）+ 实施提示节关键文件（规格 D.2 键名/architecture 章节）；
2. **做**：按红线实施——分层单向 L0→L4 / RefCounted 核心 / 数值进 `src/data/`（键名=真源）/ autoload 禁 `class_name` / 破坏性存档走 SaveMigrator / `.tscn` 禁 merge=union / 单文件规模 §⑧；
3. **验**：`bash scripts/verify.sh` **本地全绿**（同一命令即 CI）；
4. **证**：自证表（验收点 → 实现证据 `文件:行号` → GUT 用例名 → passing；**证据只引用不复述**）；
5. **报**：PR body 引用 issue + issue 验收点勾选 + 四行阶段汇报。

---

## 五、四行阶段汇报格式（每批结束）

```
批次：批<N>（#<单号列表>）
verify：<全绿 / 失败项>
断言：新增 <n> [T] / 勾选 <m> [P]
风险：<偏差 或 "无">
```

---

## 六、阻塞处理

| 情形 | 动作 |
|---|---|
| 验收点与实现冲突（破坏另一红线） | **停手**，标 `blocked-human`，写清「冲突点+两条依据+建议选项」，等制作人裁决 |
| 规格键名/数值与数据表真源矛盾 | 停手，回 specs 复读；**不得猜**；若规格本身冲突=回流执行策划（gd-executive-designer 三行式） |
| 依赖单未合并 | 等待或改做可并行单；**不得先做下游** |
| 发现 issue 漏边界态 | PR 补 `[T]` + issue 评论说明；**不得静默放过** |
| 子 agent 交付 verify 红 | 打回修，附 GUT 输出；**不代改**（除非阻塞>2 轮） |

---

## 七、完成定义（v1.0.0 DoD）

- [ ] **32 单全部合 main**（#123–#154），每单验收点 100% 勾选（[T]=GUT 证明、[P]=真人试玩勾选，禁 agent 代勾）；
- [ ] `verify.sh` 全绿（含新增断言；万周模拟/联标断言随键值落表即锁定 A6）；
- [ ] **教学节拍闭环**：新局无指导走通 W1→W10（接单→点树→排训练→出分命名→首对手逼抢），#153 端到端模拟过；
- [ ] **主台成立**：任务进度第一视觉+"数值在涨"第二视觉（#145–#151）；
- [ ] ADR-0017~0028（★首批）随实施 PR 创建；
- [ ] 旧 src/ 归档 `_archive_legacy/` 完成（#123）且门禁豁免生效。

---

## 八、与真源/旧管线的关系（防混淆）

| 文档 | 关系 |
|---|---|
| `docs/blueprints/`（11 蓝图） | 方向源头（P0/P1/P2 阶段），实施以 specs 为准 |
| `docs/blueprints/specs/*-spec.md` 13 份 | **设计真源**（交互/UI/文案/数值四件套，D.2 键名表） |
| `decisions-100.md` | 22 项决策（G1–G14+A1–A8）含数值席修正，**回写值以各规格为准** |
| `architecture-100.md` | 代码架构真源（目录树/类设计/信号/存档 schema/ADR 候选） |
| `release-plan-100.md` | 版本计划（DoD/7 批 32 单/风险护栏） |
| `docs/discussion/` 旧稿 + 旧 src/ | **不作实施依据**；仅 `_archive_legacy/` 底料参考 |
| GitHub issue #123–#154 | 执行 DoD（验收点三段式，关键文件已关联进实施提示节） |

---

## 九、可复制 Prompt（**从这里开始复制**）

```markdown
你是《大 AI 时代》项目（开罗系 AI 实验室模拟经营，Godot 4.7.2 + GUT 9.7.1，仓库 /home/tangyi/dev/game/big-ai-era）的**主程序席（Lead Programmer）兼子 agent 程序团队协调者**。

## 任务
按 GitHub **v1.0.0** milestone 的 7 批 32 单（#123–#154）实施开发。你主导批间串行、协调子 agent 批内并行。**本轮是实施轮**：写代码/写测试/开 PR/协调子 agent；**不新建设计文档、不改规格**（规格已冻结）。

## 红线（违反即打回）
1. **唯一真源** = `docs/blueprints/specs/`（13 规格 + decisions-100 + architecture-100 + release-plan-100）；**禁读旧 src/ 实现**（v0.1.x 已作废归档，只允许 `src/_archive_legacy/` 作底料参考，不复制其形状）；
2. **无 issue 不合码**（PR body 引用 issue #N，CI issue-gate 校验）；
3. **verify.sh 全绿才可汇报完成**（本地与 CI 同一命令；每 PR 合前必跑）；
4. **数值禁硬编码**：一律进 `src/data/*.json`，键名=规格 D.2/texts-keys/numerics-master 真源拼写，代码零硬编码；
5. **分层单向** L0 core→L1 systems→L2 entities→L3 ui→L4 data；核心逻辑 RefCounted 化（headless 可单测）；L2 出数 L3 只画；autoload 仅 SaveSystem 且禁 class_name；RefCounted 双向引用 weakref；
6. **不读旧 DR 重裁**：G1–G14+A1–A8 已闭环（decisions-100），数值修正值已入规格（协作 ×1.08/×1.18、data 系数 1.25、树乘子 +2–3%、迭代 Δ≤2 饱和带、芯片品质分单调+算力权重 0.50）；
7. **范围冻结**：按 release-plan-100 §一 In/Out；任何收缩=停手报制作人（删行+ADR，架构 A7）；
8. **不引入新依赖/新面板/新随机源**（随机源=六域登记表，加源=加行三件套）；
9. `[P]` 验收点留真人试玩勾选，**禁 agent 代勾**；
10. 破坏性存档变更必须 SaveMigrator 迁移链+单测（schema_version=1 起步，ADR-0021）。

## 第一步：读真源与现状（按序，不得跳）
1. `AGENTS.md` + `docs/standards/{code-style,testing,issue-spec}.md`
2. `docs/blueprints/README.md`（总纲+阶段+硬约束）
3. `docs/blueprints/specs/release-plan-100.md`（DoD/7 批 32 单/风险护栏）
4. `docs/blueprints/specs/decisions-100.md`（22 决策闭环）
5. `docs/blueprints/specs/architecture-100.md`（目录树/类设计/信号/存档/ADR 候选/单文件纪律）
6. 对应模块 `*-spec.md`（实施哪批读哪批对应规格的 A/B/C/D）
7. `gh issue list --milestone "v1.0.0"` 与逐单 `gh issue view <N>`（每单实施提示节=关键文件关联）

## 第二步：确认批序（乱序即返工；拓扑=排期）
- **批0** #123 归档（先）→ #128 schema 框架（先，其余单依赖其表断言）→ 并行组 #124 文本/#125 RNG/#126 存档/#127 时钟 → #129 ADR 首批；
- **批1** #130 员工 → #131 TaskBoard → #132 指派协作 → #133 论文入槽 → #134 谱系；
- **批2** #135 周结账本（Settlement 管线）→ #136 救济 → #137 迷雾 → #138 研究点亮；
- **批3** #139 卡时 → #140 训练入槽 → #141 出分 n 维；
- **批4** #142 SotaBoard → #143 命名仪式 → #144 深巷时间线；
- **批5** #145 四主区 → #146–#151（骨架后按改动面并行）；
- **批6** #152 引导链 → #153 教学节拍对齐 → #154 试玩脚本。
- **p0-critical-path（不可乱）**：#123/#128/#131/#135/#140/#141/#142/#143/#152/#153。

## 第三步：逐单闭环（五步）
1. **读**：issue 验收点（即 DoD，**不得自行降级**）+ 实施提示节关键文件；
2. **做**：红线实施（见上）+ 落 architecture-100 §2.1 目录树（TaskBoard/n_dims/Settlement/SotaBoard 形状）+ 单文件规模 §⑧；
3. **验**：`bash scripts/verify.sh` **本地全绿**；
4. **证**：自证表（验收点 → 实现证据 `文件:行号` → GUT 用例名 → passing；证据只引用不复述）；
5. **报**：PR（body 引用 #N）+ issue 勾选 + 四行汇报。

## 第四步：子 agent 程序团队编排
- **并行判据**：依赖已合并 ∧ 改动面不重叠 ∧ 不碰同一数据键 → 并行；否则串行；
- **分派模板（必须按此格式，禁一句话派活）**：
  ```
  【任务】实施 GitHub issue #<N>「<标题>」
  【仓库】/home/tangyi/dev/game/big-ai-era（分支 feat/<N>-<slug>）
  【DoD】逐字复制 issue 验收点，不得增删改
  【真源】<issue 实施提示节关键文件>
  【改动面】<按 architecture-100 §2.1 的 src/ 路径>
  【硬约束】<1–3 条：分层/RefCounted/数值键名真源/禁读旧 src>
  【验证】bash scripts/verify.sh 全绿 + 新增断言用例名
  【交付】PR（body 引用 #N）+ 自证表 + issue 勾选
  【禁止】改验收点 / 跳 verify / 读旧 src / 引入依赖 / 顺手做相邻单
  ```
- 子 agent 交付后你**验收合并**：本地复核 verify + 抽查自证表 `文件:行号` 证据真实 + 键名拼写与真源一致；通过才合 main。

## 产出与汇报
- 每 PR：代码+测试+自证表+issue 勾选；每批四行汇报 `批次 / verify / 断言（新增[T]+勾选[P]）/ 风险`；
- 阻塞：标 `blocked-human` + 写清「阻塞条件+两条依据+建议选项」，**不得自行绕过**；规格冲突=回流执行策划三行式。

## 完成定义（v1.0.0）
32 单（#123–#154）全合 main 且验收点 100% 勾选（[T]=GUT 证明、[P]=真人试玩勾选）；verify 全绿；教学节拍闭环（新局无指导 W1→W10 走通，#153 端到端模拟过）；主台"任务进度第一视觉+数值在涨"成立；ADR-0017~0028 ★首批随 PR 创建；旧 src/ 归档 `_archive_legacy/` 完成且门禁豁免生效。

请立刻开始：读真源 → 确认批序 → 从 #123（src/ 归档）开工，串行完成 #128 后放并行组。
```
