# AGENTS.md — 项目规范总览

> 本文件是 Agent 的常驻规范入口（DSH 自动注入）。保持精简：只放红线与索引，
> 细节在专项文档。**与专项文档冲突时，本文件红线优先。**

## 1. 项目定位与协作模式

- **《大 AI 时代》**：开罗系 AI 实验室模拟经营（实时流淌制，2D，移动同步）。
  工程底盘继承自 godot-scaffold；游戏设计真源在 `docs/gdd/gdd.md`（当前为讨论稿 v2，
  进入实现前须先冻结 MVP 范围）。
- **协作模式**：Agent 负责讨论→实现→自验证→交付；人类负责想法、审美、试玩反馈。
- **试玩闭环**：合并 main → CI 三端构建 → Pages 秒玩 / Release exe → 人类反馈 Issue → Agent 分诊迭代。

## 2. 架构总览（单向分层，禁止逆向依赖）

```text
L0 src/core/      纯常量/枚举/数学（零依赖）
L1 src/systems/   通用服务：state_machine / stats / save / data（仅依赖 L0）
L2 src/entities/  游戏对象（依赖 L0/L1）
L3 src/ui/        表现层（依赖 L0/L1，经注入触达数据）
L4 src/data/      纯配置 JSON/CSV（被读取，不反向）
```

- 核心规则 = `RefCounted`（无 Node 依赖，headless 可单测）；Node 只做表现。
- 数值/配置一律 `src/data/*.json`；代码零硬编码数值。
- autoload 全局服务保持最少（现有：`SaveSystem`），**autoload 脚本禁 class_name**。
- 引擎/工具链版本配对（GODOT 4.7.2 + GUT 9.7.1 + gdtoolkit 4.3.x）见 ADR-0001。

## 3. 工作流速览

**开发闭环**（Agent）：读规范与文档 → 实现 → `bash scripts/verify.sh` 全绿 →
PR（自检清单）→ 评审（gd-code-review）→ 合并 → 人类试玩。

**反馈闭环**（人类 → Agent）：试玩 Issue → gd-playtest-intake 分诊 →
对应专家角色处理 → 归档 `docs/playtest/`。

**环境自举**（本地新机器）：`bash scripts/setup_env.sh --with-lint`。

**发布**：main 全绿 → tag `vX.Y.Z` → CI 自动三端构建 + Release + Pages。

**角色路由**（详细行为契约见 `.agents/skills/`）：

| 场景 | 调用 skill |
| :--- | :--- |
| 排期/砍需求/里程碑 | `gd-producer` |
| 多席设计会议/交叉裁决 | `gd-council-facilitator` |
| 玩家画像审视（DR-019） | `gd-player-persona-review` |
| 机制设计/GDD/验收标准 | `gd-lead-designer` |
| 编码/架构/修 Bug/ADR | `gd-lead-programmer` |
| 数值表/公式/模拟验证 | `gd-balance-designer` |
| 文本/i18n/命名 | `gd-narrative-designer` |
| 界面/HUD/适配 | `gd-ui-ux-designer` |
| 测试策略/门禁草案 | `gd-test-engineer` |
| Godot 语法疑虑 | `gd-godot4-gotchas` |
| 试玩反馈处理 | `gd-playtest-intake` |
| 改完代码自检 | `gd-verify-loop` |
| PR 前自查/评审 | `gd-code-review` |

## 4. 硬性红线（违反即打回）

1. **verify.sh 全绿才可汇报完成**——本地与 CI 同一命令，本地必须自验证。
2. 核心逻辑 `RefCounted` 化，逻辑/表现分离；不可单测的架构 = 返工。
3. 数值禁止硬编码；一切进 `src/data/`。
4. Godot 3 旧语法（`yield`/`export(int)`/字符串 connect 等）零容忍。
5. autoload 脚本禁 `class_name`；RefCounted 双向引用必须 `weakref`。
6. 破坏性存档变更必须走 `SaveMigrator` 迁移链 + 单测。
7. 玩法机制改动同步 GDD；架构决策补 ADR（同 PR 完成）。
8. `.tscn/.tres` 冲突禁 merge=union，手动解决（scene-asset.md）。

## 5. 规范索引表

| 主题 | 文档 | 何时读 |
| :--- | :--- | :--- |
| GDScript 代码规范 | `docs/standards/code-style.md` | 编写/评审任何 `.gd` 前 |
| 测试规范 | `docs/standards/testing.md` | 新增/修改 `tests/` 时 |
| Git 工作流 | `docs/standards/git-workflow.md` | 开分支、提交、PR、发版前 |
| 场景与资产 | `docs/standards/scene-asset.md` | 新建场景、导入资产前 |
| 文档体系 | `docs/standards/documentation.md` | 写 GDD/ADR、归档反馈前 |
| 设计真源 | `docs/gdd/gdd.md` | 实现任何机制前 |
| 架构决策 | `docs/adr/` | 技术选型/改动前 |
