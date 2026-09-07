---
name: gd-issue-pipeline
description: >
  基于 GitHub issue 的排期与跟踪工作流：功能点矩阵 → issue 拆分（拓扑序+验收点+DR 引用）→
  认领实施 → verify 证据闭环 → 双签变更控制 → 周期燃尽回顾。GitHub 为唯一持久事实源，
  agent 无状态、任何新会话可从 issue/PR/评论重建视图续跑。
  触发信号："建 issue"、"排期"、"开工 #N"、"issue 进度"、"燃尽回顾"、"这个变更加不加"。
  Do NOT trigger for: 设计讨论（用 gd-producer/gd-lead-designer）、代码实施本身（用
  gd-lead-programmer）、试玩反馈分诊（用 gd-playtest-intake）。
whenToUse: MVP 第一阶段 PR1–PR10 排期与跟踪；任何"从 issue 开工/汇报进度/收口/燃尽回顾"的回合。
---

# gd-issue-pipeline — issue 排期与跟踪工作流

> 本 skill 是《大 AI 时代》"设计已冻结、实施靠 issue 驱动"阶段的调度规程。
> 完成定义（DoD 单一事实源）：**issue 全部验收点闭环 + verify.sh 全绿 + PR 合入 main**。
> 一切实施从 issue 开始；关 issue 必附 verify 证据；改范围必走 `[change]` 双签。

## 0. 前置与原则

1. **GitHub 为唯一持久事实源**：排期、状态、变更、证据全部落在 issue/PR/评论里；
   agent 无状态——会话恢复一律从 GitHub 重建视图（`gh issue list` + 状态行评论），
   不从聊天记录恢复。
2. **双载体状态外化**：标签承载粗粒度态（跨会话一眼可查）；格式化状态行评论承载
   细粒度态；两者不一致时以标签为准，先告警再续跑。
3. 来源文档：`docs/discussion/2026-09-07-mvp-modules-storyline.md`（69 功能点+issue
   拆分建议+九拍故事线）与 `docs/discussion/decision-log.md`（已生效决策 DR 号）。
   issue 内容与这两份文档冲突时，先停下来说明冲突，不静默改设计。

## 1. 标签与状态机

### 1.1 一次性配置（维护者/主策划执行）

```bash
gh label create "status/scheduled"   -c 1d76db -d "已排期待开工"
gh label create "status/in-progress" -c fbca04 -d "实施中（draft PR 已开）"
gh label create "status/review"      -c 0e8a16 -d "verify 全绿待验收"
gh label create "status/done"        -c c0c0c0 -d "已合入关闭"
gh label create "blocked-human"      -c d93f0b -d "熔断：待制作人裁决/双签"
gh label create "p0-critical-path"   -c b60205 -d "关键路径，阻塞后续 PR"
gh label create "p1" -c e99695 && gh label create "p2" -c cccccc
```

### 1.2 状态机（仅沿箭头迁移）

```text
scheduled → in-progress（认领+draft PR 开出）
          → review（verify 全绿证据已贴）
          → done（PR 合入，issue 关闭）
任意态 → blocked-human（熔断协议，见 §5）→ 恢复后回到原态
```

- 禁止跳段：`scheduled → done`（没有实施）与 `in-progress → done`（没有 review 证据）都违规。

## 2. 排期协议（建 issue）

### 2.1 issue 模板（字段缺一不建）

```markdown
## 目标
<一行动词短语，与功能点矩阵条目一一对应>

- 所属 PR / 依赖：<PR5 ｜ 依赖 #12、#13>
- 规模：S/M/L（1 Agent 1 PR 承重上限）
- 决策依据：<DR-005R、DR-023 等决策日志号>
- 验收点：
  - [ ] [T] <可翻 GUT 的断言 1>
  - [ ] [T] <断言 2>
  - [ ] [P] <试玩主观项，写明预期感受>

## 实施提示
<引用架构稿对应节/数据表/参考文件路径；避免后人重新发现>
```

### 2.2 拆分与排序规则

1. **拓扑序即排期序**：按依赖链 PR1→PR10 排 milestone v0.1.0；关键路径
   （阻塞后续 PR 的，如 PR3 GameWorld 骨架）加 `p0-critical-path`。
2. L 规模 PR 拆实现 issue（每个 issue 独立可验收）；数据表内容
   （14 节点/8 事件卡/断言区间 JSON）单列 issue，不与逻辑混装。
3. `[T]`/`[P]` 必须如实标注：主观体验项（"仪式感""压迫感"）禁止写成可测断言；
   九拍故事线作为 PR9b/9c 的 `[P]` 验收脚本引用。
4. 每个 issue 创建后立刻打 `status/scheduled` + 优先级标签。
5. **双签闸门**：范围新增/砍除/验收点修改 = 变更，须评论
   `[change] <理由> <影响面>` 并获制作人 👍 后才可执行（对齐 DR-006 冻结纪律）。

### 2.3 认领（原子化，吸取 oss-triage 教训）

开工先写独占认领评论并读回验证——**标签写入非原子，禁止以打标签作为认领依据**：

```bash
gh issue comment <N> --body "[claim] agent=<agent-id> ts=$(date +%s)"
gh issue view <N> --json comments --jq '.comments[-1].body'   # 读回确认是自己的
gh issue edit <N> --add-label status/in-progress
```

## 3. 跟踪协议（实施 loop）

1. **回合纪律**：每个工作回合以三选一收尾——结论行（`issue #N → <状态>, 关键指标,
   PR#M`）/ todo 更新 / `blocked-human` 上报。禁止"还在跑，下轮看"。
2. **状态行评论**：状态每次变化写一条（新评论追加，不编辑旧条）：

   ```text
   [track] ts=<unix> state=in-progress next=TF3 谓词注册表 evidence=<commit/PR 链接>
   ```

3. **进入 review 的唯一凭据**：`bash scripts/verify.sh` 全绿输出关键行贴进 issue；
   `[T]` 验收点逐条勾选；`[P]` 项保持未勾（留给试玩，禁止冒充完成）。
4. **PR 关联**：PR body 写 `Closes #N`；PR 合入 = issue 关闭 + `status/done` +
   摘除其余 status 标签。gd-code-review 通过是合入前置。
5. **周期燃尽**（里程碑回顾或每周）：

   ```bash
   gh issue list --milestone "v0.1.0" --state open --json number,title,labels \
     --jq '.[] | "#\(.number) \(.title) [\([.labels[].name] | join(","))]"'
   ```

   输出三行式汇报：进度（done/total）、阻塞（blocked-human 清单）、下一步（p0 优先）。

## 4. 与其他 skill 的协作

| 场景 | 调用 |
| :--- | :--- |
| 排期裁决/砍需求 | `gd-producer`（本 skill 只执行裁决结果） |
| 实施与自验证 | `gd-lead-programmer` + `gd-verify-loop`（证据产出方） |
| PR 评审 | `gd-code-review` |
| 玩法改动同步 GDD/ADR | `gd-lead-designer` + `adr-authoring` |
| 试玩反馈回流 | `gd-playtest-intake` → 产出新 issue（打 p1/p2）进同一管线 |

## 5. 熔断协议（blocked-human）

触发条件（任一）：①验收点发现设计矛盾（两文档冲突且 decision-log 无解）；
②需要双签的变更无人确认；③连续 2 个回合无实质推进；④verify 红 >1 天无法定位。
执行：打 `blocked-human` 标签 + 状态行注明 `blocked_reason=<一句话>` + 向制作人
汇报三行式（卡点/已试过/需要什么）。恢复：摘标签回原态，卡点结论评论留痕。

## 6. 红线（硬护栏，配对正面对象）

| 正面对象 | 红线 |
| :--- | :--- |
| 一切实施从 issue 开始 | 禁止无 issue 开工——"顺手改一下"也先建 issue（它消耗同一条关键路径） |
| 关 issue 必附 verify 证据 | 禁止无证据关 issue / 合 PR |
| 改范围走 `[change]` 双签 | 禁止绕过双签改验收点或范围 |
| `[P]` 项留给试玩勾选 | 禁止把主观项标成完成 |
| 认领=评论+读回验证 | 禁止以打标签代替认领（原子性） |
