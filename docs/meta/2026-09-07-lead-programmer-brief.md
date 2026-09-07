# 主程序工作简报 — MVP 实施开工（2026-09-07）

> 你（子 agent）在会话中被授予 **主程序（Lead Programmer）** 职责：按 gd-issue-pipeline
> 工作流推动 v0.1.0 里程碑 21 个 issue 的实施。本简报是本次委任的开工凭据，后续回合
> 制度见文末"回合纪律"。

## 0. 项目根与身份

- 仓库：`/home/tangyi/dev/game/big-ai-era`（分支 `pr1-text-system` 已为你建好，基于 main）
- 远程：`github.com/wingsky-1/big-ai-era`（gh 已登录 wingsky-1）
- 身份：lead-programmer；写代码时参考 `.agents/skills/` 下 gd-lead-programmer /
  gd-verify-loop / gd-godot4-gotchas / gd-code-review（如可读）
- **红线**（违反即返工）：
  1. `bash scripts/verify.sh` 全绿才可汇报完成（本地 CI 同一命令）
  2. 核心逻辑 RefCounted 化，逻辑/表现分离；autoload 脚本禁 class_name
  3. 数值禁止硬编码，一切进 `src/data/*.json`
  4. Godot 3 旧语法（yield / export(int) / 字符串 connect）零容忍
  5. RefCounted 双向引用必须 weakref
  6. 验证门禁命令与 shell 都用工具的 workdir 参数，禁止 `cd` 链式写法

## 1. 开工序列（issue 拓扑序）

| 序 | issue | 内容 | 规模 |
|---|---|---|---|
| 1 | #2 | [PR1] 文本体系：texts 40 键+TextService+Formatter+三断言+sensitive_words | S |
| 2 | #3 | [PR2] 存档机制壳：schema v1 重置+双缓冲写+迁移链 | S |
| 3 | #4 | [PR3] GameClock 刻步进+暂停双源+变速与停喂门控 | — |
| 4 | #5 | [PR3] GameWorld 骨架+UI 快照+万周模拟+断言区间占位 | — |
| 5 | #6 | [PR4] Economy 双来源收支+apply_delta 唯一过账口 | — |
| … | #7–#24 | PR4 名册任务队列 → PR5 迷雾/谓词/techs 表 → PR5R 冻结 → PR6 训练出分命名 → PR7 RNG/竞对/事件 → PR8 存档三保险+GameOver → PR9a/b/c UI → PR10 收口 | — |

- 完整 issue 清单：`gh issue list --milestone v0.1.0`
- **DoD（单一事实源）**：issue 全部验收点闭环 + verify.sh 全绿 + PR 合入 main
- **认领协议（原子化）**：
  ```bash
  gh issue comment <N> --body "[claim] agent=lead-programmer ts=$(date +%s)"
  gh issue view <N> --json comments --jq '.comments[-1].body'   # 读回确认
  gh issue edit <N> --add-label status/in-progress
  ```
- **状态行评论**（状态变化时追加，不编辑旧条）：
  `[track] ts=<unix> state=in-progress next=<步> evidence=<commit>`
- **进入 review 唯一凭据**：verify.sh 全绿输出关键行贴进 issue + [T] 验收点逐条勾选
  （[P] 项保持未勾，留给试玩）；PR body 写 `Closes #N`；PR 合入后 issue 打 status/done。
- **熔断协议**：设计矛盾/需双签变更/连续 2 回合无实质推进/verify 红>1 天 →
  打 blocked-human 标签+状态行+向制作人汇报（卡点/已试过/需要什么）。

## 2. PR1 实施要点（issue #2 全文见 gh issue view 2）

**目标**：texts.json 40 键起步集 + TextService 单一入口 + Formatter（¥万缩写/负号前置/
结构化数值行）+ 断链/死键/长度三断言 + sensitive_words.json 入 L4；items.json 迁键后退役。

**关键输入**：
- `docs/discussion/2026-09-07-round3-meeting-notes.md` §四：40 键=开场白 4 句全文 +
  命名域 11 键 + 周报 6 模板；事件卡 8 张全文同段有；5 域 3 道路名、默认名池 10 个
- `docs/discussion/decision-log.md` DR-010：{var} 单大括号插值、插值值一次转义防二次
  解析；max_len 按字符数（选项≤8/toast≤20/标题≤12/周报条目≤30/正文≤60）；
  Formatter 单真源（金额 ¥+万缩写+负号前置）
- 架构稿 v1.1 §A：L1 `src/systems/text/text_service.gd + formatter.gd`
  （仅依赖 L0，禁 autoload）；敏感词三层=Unicode 白名单+30±词表+sensitive_words.json
- 现有基础设施：`src/systems/data/data_loader.gd`（读 L4 JSON）、
  `tests/unit/test_data_loader.gd`（参考测试写法）、`src/data/items.json`（迁键后退役）
- GUT 9.7.1：tests/unit/ 下 test_*.gd，参照现有测试；verify.sh 会 headless 跑全部

**口径硬锚**（数值预演报告+issue #1，不得偏离）：
- 开局资金 50k；破产线 -200k；sigmoid θ=95/k=13；K=4.0；灵感 base=0.10/pity=8/cap=12 硬保底
- 竞对 L1=12 周；预警黄灯 ⌈0.15t⌉ 周/红灯 2 周

## 3. 回合纪律（每次你被重新拉起时执行）

1. 先 `gh issue list --milestone v0.1.0 --state open` + git 状态重建视图（无状态原则）
2. 查看当前 PR 分支进度 → 继续或收尾（verify 全绿→PR→报告）
3. 每回合以三选一收尾：结论行（issue #N → 状态, 关键指标, PR#M）/ todo 更新 /
   blocked-human 上报
4. PR 合入 main 后拉下一分支继续下一 issue；串行为主，独立底座类工作可并行申报

## 4. 沟通与升级

- 每回合产出结论行即可，不需要等待确认；范围/验收点改动一律走 [change] 评论+制作人双签
- 设计口径疑问：以 decision-log + 架构稿 v1.1 + issue #1 口径落档为准
- 发现文档间矛盾且无解 → 熔断 blocked-human 上报
