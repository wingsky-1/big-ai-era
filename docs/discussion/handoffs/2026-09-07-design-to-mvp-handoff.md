# Handoff — 《大 AI 时代》：设计讨论闭环 → MVP 实施交接

> 日期：2026-09-07 ｜ 上一会话：设计讨论+排期闭环（本文件归档于项目 `docs/discussion/handoffs/`）
> 下一会话焦点：**MVP 第一阶段实施**（issue #2/#3 立即开工 → #4/#5 → … → #21 发版）

## 给下一会话的定位

你是《大 AI 时代》项目的游戏工作室 Agent。设计讨论阶段**已全部闭环**（DR-025 闸门关闭），
制作人已收到开工终审呈报、**尚未下达开工令**——收到"开工"后按 `gd-issue-pipeline`
工作流从 #2/#3 开始实施；若制作人提出排期/口径调整，改动成本此刻最低。

## 开工前必读（按序）

1. `docs/discussion/README.md` ——讨论归档索引（入口总账）
2. `docs/discussion/decision-log.md` ——**决策日志 DR-000~027**（全部已生效决策+复议留痕；
   含 DR-000"按推荐生效+留痕"工作机制与 DR-016 长期项目共识）
3. `docs/discussion/2026-09-07-mvp-architecture-plan-v11.md` ——架构稿 v1.1（**开工蓝本**，
   A–G 七节；命令 11/信号 11/周结管线 v2.1/12-PR 序列）
4. `docs/discussion/2026-09-07-mvp-balance-preview.md` ——数值预演（V 断言初值+参数移交清单）
5. `docs/discussion/2026-09-07-mvp-modules-storyline.md` ——69 功能点矩阵+九拍故事线+GDD v3 大纲
6. GitHub：里程碑 [v0.1.0](https://github.com/wingsky-1/big-ai-era/milestone/1)（21 issues，
   due 2026-10-19）+ [issue #1](https://github.com/wingsky-1/big-ai-era/issues/1)（五项口径落档）

## 建议调用的 skill

- `gd-issue-pipeline` ——**实施主工作流**（认领→实施→verify 全绿→PR→评审→合入；状态机+熔断协议）
- `gd-lead-programmer` + `gd-verify-loop` ——实施与自验证闭环
- `gd-code-review` ——PR 双轴评审（合入前置）
- `gd-godot4-gotchas` ——写/审 GDScript 前速查
- `gd-producer` ——范围裁决、里程碑验收
- `gd-playtest-intake` ——试玩反馈回流（PR10 后启用）
- GDD v3 收敛时：`gd-lead-designer` + `adr-authoring`

## 实施关键事实（不重复细节，只给锚点）

- **开工序列**：#2 [PR1]文本体系 → #3 [PR2]存档机制壳（均可立即开工，p0）→ #4/#5 [PR3]GameClock/GameWorld（p0）→ **V-sim 复算闸门**（PR3 后真 Economy 复算）→ #8–15 → #16 → #17–19 → #20–21。
- **硬红线**（AGENTS.md）：verify.sh 全绿才可汇报完成；数值零硬编码（断言区间 JSON 自 PR3 宽占位）；Godot 3 语法零容忍；RefCounted 循环引用必须 weakref；autoload 禁 class_name。
- **架构铁律**：实时流淌只是 View 层概念，模拟层永远 tick 步进；RNG 只在周结消费（恰好 3 处，grep 可验）；GameClock.paused = user_paused OR blocked_by_card。
- **变更控制**：范围/验收点改动一律 `[change]` 评论 + 制作人双签（issue #1 口径同此）。
- **环境**：Godot 4.7.2（~/.local/bin/godot）、gdtoolkit 4.3.4、gh 已登录（wingsky-1）；本地 `bash scripts/verify.sh` 全绿；仓库 github.com/wingsky-1/big-ai-era（公开，Pages/Release workflow 沿用脚手架）。
- **UI 契约**：PanelStack z0–z3、面板注册表 9 面板、暂停白名单"世界等玩家才停"（详见 v1.1 B 节+round3 纪要）。
- **原型**：`docs/discussion/prototype-dashboard.html`（A 工作台+B 周报流拼装已定稿，静态服务 3180 端口可看）。

## 玩家之声与打磨重点（实施时的体验罗盘）

四画像共识：迷雾树是最强钩子但**揭示节奏决定生死**（保底宁紧勿松）；命名仪式是出圈记忆点（要"想参与"）；真空期无微操是头号流失场景（MVP 用真空三件套兜底）；UI=A 工作台+B 周报流。打磨排序与 v0.2 清单见 `2026-09-07-round3-meeting-notes.md` §五。

## 协作纪律（延续）

方案先行；结构性改动先子代理对抗评审；每项决策进 decision-log 留痕（复议不覆盖只追加）；
双视角纪律（DR-019：职责立场+玩家代入）；GDD v3 收敛待开工后与 ADR-0005~0009 同批落笔
（ADR-0009 待裁 TechFog 独立 vs 复用 L1 state_machine）。

## 本文件归档说明

本 handoff 由会话按 `handoff` skill 生成并应用户要求归档至项目
`docs/discussion/handoffs/`（上游交接文档 `/tmp/handoffs/big-ai-era-design-session.md`
的同类延续；敏感信息无，gh 凭据在系统层不入档）。
