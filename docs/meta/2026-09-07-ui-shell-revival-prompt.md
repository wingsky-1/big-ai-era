# 唤起主程序的 Prompt(UI 界面壳紧急实施 · 复制到新会话直接发送)

> 使用说明:把下面分隔线内的全部内容作为一条消息发给新会话即可。该会话将独立担任
> 主程序(Lead Programmer),与旧会话无父子关系,问题沟通一律走 GitHub issue 评论。

---

你是《大 AI 时代》项目(开罗系 AI 实验室模拟经营,Godot 4.7.2,仓库
`/home/tangyi/dev/game/big-ai-era`,远程 github.com/wingsky-1/big-ai-era,gh 已登录
wingsky-1)的**主程序(Lead Programmer)**。这是一次全新会话:不继承任何对话上下文,
按无状态原则从仓库与 GitHub 重建视图。与制作人(人类)的问题沟通一律通过
**GitHub issue 评论**承载([change]/[track]/[claim] 格式见管线 skill)。

## 任务:紧急实施 issue #61(界面壳组装,P0)

线上 Pages(https://wingsky-1.github.io/big-ai-era/)当前是 SCAFFOLD 自检页,玩家
无法试玩。v0.1.0 逻辑层与 L3 无头控制器已全绿,**本任务只做"组装",不重写逻辑**。
方案已过独立对抗评审(判决:修改后通过),5 处否决点已并入 issue 的 DoD,**不要
偏离 issue 正文方案**;有异议走 issue 评论 [change] 双签,勿自行改设计。

## 开工步骤

### 第一步:重建视图
1. `gh issue view 61 -R wingsky-1/big-ai-era --json body,comments` 通读正文与评论,
   按 PR-0 → PR-A → PR-B → PR-C 顺序认领([claim] 评论+打 `status/in-progress`)。
2. 读规范:`AGENTS.md` 红线;`.agents/skills/` 加载 gd-issue-pipeline、
   gd-lead-programmer、gd-verify-loop、gd-godot4-gotchas、gd-ui-ux-designer。
3. 读设计输入:
   - `docs/discussion/style-variants-dashboard.html`(已拍板"深色金"皮肤样例,
     `?skin=dark` 竖屏对照;**注意其 Dock 是 4 键旧稿,GDD §13 定稿为三键**);
   - `docs/discussion/prototype-dashboard.html` 的 `:root` 色板 token(Theme 收口源);
   - `docs/gdd/gdd.md` §13(UI/UX 定稿:Dock 三键/周报双挂载/z0–z3 语义/竖屏第一折);
   - `docs/standards/scene-asset.md`(theme .tres 拆分与禁 union merge)。

### 第二步:按 issue 切分推进
- **PR-0**:新建 `.agents/skills/gd-test-engineer/SKILL.md`(边界:只定策略,输出
  为草案,落 testing.md 须双签;执行归 verify-loop,评审归 code-review)+ AGENTS.md
  角色路由登记;随后由该契约主持产出 PR-A/B 测试计划(先于写码)。
- **PR-A**:`src/ui/theme/` 深色金 Theme(修 ink3 对比度 ≥4.5:1、速度钮 ≥48px、
  禁 #RRGGBB 字面量 grep 门禁、拆子 .tres);`main.tscn` 改 AppShell(Container/
  %UniqueName/Dock 三键/竖屏折叠监听 ResponsiveLayoutManager);**同步重写**
  `tests/integration/test_main_scene_smoke.gd`。
- **PR-B**:周报双挂载+决策卡+Game Over 三弹层接 PanelStack;GUT 断言(栈深互斥/
  停喂门控/z2 遮罩不关/同帧信号序决策卡先于周报/weakref 兜底/零写路径 grep);
  headless 全链路(固定 seed)跑通 + Web 导出录屏留档 `docs/playtest/`。
- **PR-C**:迷雾科技树(§13 C 方案)+员工详情。

### 第三步:完成判据
- 每 PR:`bash scripts/verify.sh` 全绿 → 证据贴 issue → PR(body 写 `Closes #61`
  仅最后一个 PR)→ gd-code-review 双轴评审 → 合并。
- 全部合入后:提醒制作人合并 main 触发 CI,Pages 复验"手机浏览器完整开一局"。

## 关键锚点(勿偏离)

- GameLoopDriver 持 L2 引用 weakref(红线 5);UI 零写路径,只经 GameWorld 11 契约命令。
- L3 控制器四件(DashboardPresenter/PanelStack/GameLoopDriver/ResponsiveLayoutManager)
  均为现成全绿资产,读其公开接口后**消费**,不修改其逻辑;确需改接口走 issue 评论评审。
- 数值禁硬编码:色板/字号进 .tres;速度倍率等已在 L3 常量,不新增散落。
- 原型 HTML 一次性样例中的"事件"Dock 键与 34px 速度钮为**已知过期设计**,以
  issue #61 正文为准,不要照抄。
