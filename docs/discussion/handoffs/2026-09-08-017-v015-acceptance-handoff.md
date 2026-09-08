# Handoff — v0.1.5 收尾验收轮（#82 + scripts.md + ADR-0016）→ 下一会话：**P0 玩家入口（#104）+ 试玩轮次**

> 日期：2026-09-08 ｜ 本会话：主程序席完成 #82 收尾（含 5 个 [T] 用例）+ `docs/playtest/scripts.md` + 补建 ADR-0016，并完成 v0.1.5 完成定义核对
> 下一会话焦点：**issue #104（核心循环无玩家可达入口，P0）** → 试玩轮次 → `[P]` 勾选
>
> **本会话最大发现**：**13 单 `[T]` 100% 达成、verify 全绿、ADR 齐全，但游戏对玩家"接不了任务、开不了训练"**——`enqueue_task` / `start_training` / `SaveSystem.load_game` 在 `src/ui/**` **零调用方**，#72 起收入只来自占槽任务结算 → 新开局约 **W6 破产**，13 单的 `[P]` 真人验收**全部不可执行**（issue #104）。

---

## 一、已完成（本轮 3 个 PR，全部已合并 main@`889bdad`）

| 单/资产 | PR | 交付要点 | verify |
|---|---|---|---|
| **#82** 短单局收尾 | [#99](https://github.com/wingsky-1/big-ai-era/pull/99) | `FreedomTracker`（L2 RefCounted）：三线计数器入 `flags{}`（零迁移）、W25 弱展示 → 首达饱和阈值升主权重 + 横幅一次；`FinaleDialog`（L3 z2）：六项 + 回溯 3 条 + 一句话评价，与破产卡两套并存；`clock.json.run_weeks=160`；`ui_display.json.freedom/finale`；**5 个 [T] 用例**（`tests/unit/test_short_run_finale.gd`）+ presenter 自动弹断言 | 45/244/14687 |
| **#100** `scripts.md` | [#105](https://github.com/wingsky-1/big-ai-era/pull/105) | `docs/playtest/scripts.md`（1485 行）：13 锚点逐字覆盖 + 6 别名锚 + 每节七段；附录 B 逐条核对 `src/data` 键值；附录 C 登记 11 项阻塞/待裁；**新增门禁** `tests/unit/test_playtest_scripts.gd`（锚点齐全 + 七段完整 + 数值与数据表一致） | 46/248/14829 |
| **ADR-0016**（#78 补建） | [#106](https://github.com/wingsky-1/big-ai-era/pull/106) | `docs/adr/0016-l2-data-plane-contract.md`（128 行）：四条决策逐条标落地状态（①已落 ②已落 ③**部分落** ④已落）+ 可执行契约 R1–R6 + 决策对账表；遗留三项归 issue #103 | 45/244/14687 |

**issue 回写**：13 张 v0.1.5 单 `[T]` **100% 勾选**（52 项；#67 的 3 项本轮补勾，含测试文件行号证据）；`[P]` **全部未勾**（真人试玩未执行，且受 #104 阻塞）。

---

## 二、v0.1.5 完成定义核对（6 项）

| # | 完成定义 | 结论 | 证据 |
|---|---|---|---|
| 1 | 13 单合并 | ✅ | #67/#71–#82 全 CLOSED；#92（RNG 缺陷）随 #75 合并 |
| 2 | `[T]` 100% 勾选 | ✅ | 13 单共 52 项 `[T]` 全勾（本轮补 #67 的 3 项） |
| 3 | verify 全绿 | ✅ | main@`889bdad`：**46 scripts / 248 tests / 248 passing / 14829 asserts**（CI 同一命令） |
| 4 | 同 seed 万周双跑哈希一致 | ✅ | `test_numeric_data_migration.gd:125` `test_same_seed_hash_stable_after_data_migration`（seed 42/7 × 10000 周 × 双跑摘要相等） |
| 5 | 短单局专项 | ✅ `[T]` / ❌ `[P]` | `[T]`：`test_short_run_finale.gd` 5 用例全绿；`[P]`：`scripts.md#RF-02` 受 #104 阻塞 |
| 6 | ADR-0011~0016 齐全 | ✅ | `docs/adr/` 0001–0016 齐（0016 本轮补建） |

**结论**：**工程侧 6/6 达成；产品侧 `[P]` 0/13**——`[P]` 的阻塞不是"没时间试玩"，而是**当前构建玩家玩不到核心循环**（见 §三）。

---

## 三、最大风险：issue #104（P0，阻塞全部 `[P]`）

| 事实（代码核查 main@`889bdad`） | 证据 |
|---|---|
| `enqueue_task` 在 `src/ui/**` **零调用方** | 唯一可达路径 = 事件卡 `evt_hardware_sponsor`（`once: true`、`p_week 0.35`）选项 2 `inject_task` → **随机一次，不可重复** |
| `start_training` 在 `src/ui/**` **零调用方** | 训练/出分/命名/竞对压迫/封顶三线全部不可达 |
| `SaveSystem.load_game` **全仓零调用方**；`request_save` 在 UI 零调用方 | 无读档入口、无手动存档入口 |
| #72 起收入**只**来自占槽任务结算（脉冲源退役），固定支出 9000/周 | 新开局 50k → 约 **W6 破产** |

**影响**：`#RE-02`/`#RT-01`/`#RP-02`/`#RR-02`/`#RS-05`/`#RU-02`/`#RF-02` 七条 `[P]` 不可执行（`scripts.md` §0.5 + 附录 C C-1/C-2/C-3）。
**待裁决**：v0.1.5 收尾前补最小入口，还是立 v0.1.6 单、`[P]` 挂起（详见 issue #104 备注）。

---

## 四、遗留清单（下一会话/后续批次处置）

| # | 遗留 | 建议 |
|---|---|---|
| **L1** | **#104 P0**：接任务/开训练/读档无玩家入口（§三） | **最高优先**：制作人裁决范围（v0.1.5 补入口 / 立 v0.1.6） |
| **L2** | `docs/playtest/scripts.md` 的 `[P]` 全部未勾（13 单） | 依赖 #104 + 试玩构建（见 L6） |
| **L3** | **复现线死亡螺旋**：`TaskQueue.can_enqueue` 的 `money < cost` 门在资金转负时连 `cost == 0` 任务也拒 → 断流 | **已立 issue #101**（v0.2 危机线批次裁决） |
| **L4** | `naming_sensitive_reject` 文案键缺失 + `ui_display.json` 文案双轨 | **已立 issue #102**（注意 `texts.json` 键数被 3 处硬断言锁定） |
| **L5** | **`game_world.gd` 已 1308 行**（`#82` 再 +280；靠 `# gdlint:disable = max-file-lines` 豁免） | 后续单必须拆类（`freedom_tracker` 已拆出，可继续拆 `report_builder`/`forecast_builder`）；否则门面膨胀不可逆 |
| **L6** | **v0.1.5 无 tag / 无 Release**（最新 Release = v0.1.3）→ 人类没有可试玩构建 | 主程序席打 tag `v0.1.5` → CI 三端构建 + Release + Pages；**tag 由制作人确认后执行** |
| **L7** | **封顶周次口径三处不一致**：需求/纪要 W54；`test_saturation_guardrail.gd` 实测 W61（真跑）/W89（上界）；handoff 016 记 W81/W89 | `scripts.md` 已不绑定周次；官方口径由数值席收口（#101 同批或另单） |
| **L8** | **每周结自动弹 z2 周报**（160 周 = 160 次）→ 长局节奏与时长预算 | `scripts.md` C-7；建议立 issue 收敛自动弹频率（≥5% 显著变化才弹，映射表 V1-06 规划未落地） |
| **L9** | **任务池 RP 密度趋同**（37.5/37.5/36.7/35 RP/周）→ "钱 vs RP 配比"只剩钱一维 | `scripts.md` C-11；`#RT-01` 的 `[P]` 按"是否主动切换任务"判，RP 维回调属 v0.2 复议（触 §6 供给带需重算） |
| **L10** | **ADR-0016 三项待收口**（决策③ 调试入口 / L3 直读内部字段 / R6 门禁仅覆盖 4/15 文件） | **已立 issue #103**（v0.2；裁定：决策③ 走"调用移出 L3"，不契约化） |
| **L11** | `AutoTaskPolicy` 注释仍写旧 income（33000/4 周），#80 已改 60000/4 周 | 顺手修注释（下次触及该文件时） |
| **L12** | 竞对 L1–L3 分数未重标（维持 35/58/75），需求 §10.5 目标分区间仍待数值席 | 只改 `rivals.json` 即可，非阻塞 |

---

## 五、硬约束与参数（不变，见 016 §4）

红线与参数组**未变**：Σrp_cost **14210 禁调**、RP 供给带 `[4910, 6810)`、竞对 L4 = **95**（守卫带 [93,98]，禁超玩家 99）、卡时=周预算、`base.cost` 即全程卡时费（不得再计 money）、**存档零迁移**（新增状态入 `flags{}`/`events.cooldowns{}`）、**RNG 消费点 3 处**、事件 `p_week 0.35` / 单卡上限 5000/60/20 / 周闸 600 / 冷却 8 周、固定运维 3000/周（lab 周支出 9000）、单局 160 周 ≈1600s。

**本轮新增数据键**：`clock.json.run_weeks=160`；`ui_display.json.freedom{display_week:25,…}` / `ui_display.json.finale{…}`。

---

## 六、本轮踩坑记录（下会话直接复用）

| # | 坑 | 结论 |
|---|---|---|
| 1 | **PR 与 main 冲突时 GitHub 不跑 CI**（`gh pr checks` = "no checks reported"，`actions/runs?branch=` 计数 0） | 先 `git merge origin/main` 解冲突再 push，CI 才会触发（本轮 #99 实测） |
| 2 | JSON 冲突手工解时**闭合括号落在冲突公共上下文** | 解完必须 `json.load` 验一遍（本轮 `ui_display.json` 出现"缺 `}` / 尾逗号 / 缺逗号"三连） |
| 3 | `PackedStringArray` 与 `Array` 断言**不相等**（GUT 报 `Cannot compare ARRAY to PACKED_STRING_ARRAY`） | 逐元素 `str()` 比对，或两侧同类型 |
| 4 | 枚举显式值触发 #71 数值门禁 | `PRIMARY = 2` 命中 → 改**隐式枚举值**（白名单只有 0/1/-1） |
| 5 | 引用漂移：`#78` 声称已建 ADR-0016，文件实际缺失 | 合并前用 `ls docs/adr/` 对账"文档声称 vs 文件存在"；代码注释引用 ADR 时必须落到文件 |
| 6 | 子 agent 的"现状核查"必须自己复核 | 本轮复核确认了 `src/ui/**` 对 `enqueue_task`/`start_training` **零命中**（最大发现）；也复核了 ADR-0016 的行号/门禁文件数断言 |
| 7 | `simulate_weeks(1, policy)` + `AutoTaskPolicy.fill(world)` 是长局集成的稳妥驱动 | 无任务纯模拟约 **W6 破产**（50k / 9000 周支出）；测试用 `restore` 注入局面比真跑 25 周更快更稳 |
| 8 | 经 `restore()` 注入 `flags.player_best_score` 可合法驱动"封顶/保霸"路径 | `restore` 是公开契约、`flags` 是开放容器，不碰私有字段即可测封顶分支 |

---

## 七、下个会话唤起 Prompt（复制直接发送）

```markdown
你是《大 AI 时代》项目（Godot 4.7.2 + GUT，仓库 /home/tangyi/dev/game/big-ai-era）的**主程序席兼实施协调者**。
上一会话完成 v0.1.5 收尾验收轮：#82（PR #99）、docs/playtest/scripts.md（PR #105）、ADR-0016（PR #106）全部合并 main@889bdad；
13 单 [T] 100% 勾选、verify 46/248/14829 全绿、ADR-0011~0016 齐全；[P] 0/13 未勾。

## 先读
1. `docs/discussion/handoffs/2026-09-08-017-v015-acceptance-handoff.md`（本交接：完成定义核对 + P0 风险 + 遗留 L1–L12 + 踩坑）
2. `docs/discussion/handoffs/2026-09-08-016-v015-closeout-handoff.md`（§4 硬约束与参数组）
3. `docs/playtest/scripts.md`（13 单 [P] 验收脚本；§0.5 能力边界 + 附录 C 阻塞项）
4. `docs/adr/0016-l2-data-plane-contract.md`（L3 零业务计算契约 R1–R6）
5. `AGENTS.md` + `docs/standards/{code-style,testing,scene-asset}.md`

## 任务（按序）
1. **处置 issue #104（P0）**：核心循环无玩家可达入口（接任务/开训练/读档/手动存档）——
   先给方案（任务管理面板 PanelId.TASK_MGMT 已预留 vs 主台快捷入口），经对抗评审后实施；这是全部 [P] 的前置。
2. 打 tag `v0.1.5` 交付可试玩构建（需制作人确认）→ 按 `docs/playtest/scripts.md` 排试玩轮次。
3. 试玩通过后回写 `[P]` 勾选 + 归档 `docs/playtest/2026-09-08-v015-feedback.md`。
4. 按需处置遗留：#101（复现线死亡螺旋）/ #102（toast 文案键）/ #103（ADR-0016 收口）/ L5（game_world.gd 1308 行拆分）。
5. 每单闭环：读 issue 验收点 → 实施（红线）→ `bash scripts/verify.sh` 全绿 → 自证表 → PR（引用 issue）→ 回写 issue 勾选。

## 硬约束
Σrp_cost 14210 禁调；RP 供给带 [4910,6810)；竞对 L4 ∈[93,98] 禁超玩家；卡时=周预算；
`base.cost` 即全程卡时费（不得再计 money）；存档零迁移；RNG 消费点 3 处。

## 每批结束给四行汇报
`批次 / verify / 断言（新增 [T] 数 + 勾选 [P] 数）/ 风险`
```

---

## 八、持久事实源

- **main**：**`889bdad`**（本轮 3 个 squash：`ffce0f3` #99 → `0dc37ea` #105 → `889bdad` #106）。
- **verify**：**46 scripts / 248 tests / 248 passing / 14829 asserts**（`bash scripts/verify.sh`，CI 同一命令）。
- **issue**：v0.1.5 milestone 13 单 + #92 **全部 CLOSED**；新立 **#100**（scripts.md，已关）、**#101**（复现线死亡螺旋）、**#102**（toast 文案键）、**#103**（ADR-0016 收口）、**#104**（P0 玩家入口，**OPEN**）。
- **PR**：本轮 #99 / #105 / #106 均已合并并删分支。
- **ADR**：`docs/adr/` 0001–0016 齐全（0016 本轮补建）。
- **试玩资产**：`docs/playtest/scripts.md`（1485 行，13 锚点 + 6 别名锚；门禁 `tests/unit/test_playtest_scripts.gd`）。
- **worktree**：`/home/tangyi/dev/game/wt-82`（#82 已合并，**可清理**）；`wt-78`/`wt-79`/`wt-81` 亦已交付可清理。
- **分支**：`main` 为唯一主干；本轮 `feat/82-short-run-finale`/`docs/100-playtest-scripts`/`docs/78-adr-0016` 已合并可删。
