# 《大 AI 时代》— 开罗系 AI 实验室模拟经营

> 你是 2022 年某高校 AI 实验室的博导：复现论文、点亮 LLM 科技树、训练新模型、
> 在竞对夹击中把实验室带成上市公司。
> 状态：**v0.1.0 MVP 完整版本已发布**，已开放网页端直接试玩与全平台发行包下载。

🎮 **在线试玩地址（GitHub Pages）**：[https://wingsky-1.github.io/big-ai-era/](https://wingsky-1.github.io/big-ai-era/)
📦 **多端发行包下载（GitHub Release）**：[Release v0.1.0](https://github.com/wingsky-1/big-ai-era/releases/tag/v0.1.0)（含 Windows / Linux / Web 离线包）

## 工程底盘（继承自 godot-scaffold）

- **工程体系**：单向分层架构（core → systems → entities → ui → data），核心逻辑
  纯 `RefCounted` 化，天然可无头单测；数值全部外置 JSON。
- **Agent 专家体系**：6 大游戏研发角色 skill（制作人/主策划/主程序/数值/文案/UI-UX）
  + 4 个领域协议（Godot 4 坑位/试玩摄入/自验证/评审），随仓库走、克隆即生效。
- **自验证闭环**：`bash scripts/verify.sh` 一条命令 = 静态检查 + 引擎导入校验 +
  GUT 单测，本地与 CI **同一条命令**。
- **多端试玩**：CI 自动导出 Windows `.exe` / Linux / Web（单线程版，免配置部署
  GitHub Pages），打 tag 即发版，手机浏览器秒开试玩。
- **防崩盘机制**：存档 schema 升轨迁移链、Godot 3 语法疫苗、.tscn 合并纪律、
  ADR 决策留痕。

## 快速开始

### Agent（开发）

```bash
bash scripts/setup_env.sh --with-lint   # 自举 Godot 4.7.2 headless + gdtoolkit
bash scripts/verify.sh                  # 自验证：lint + import + GUT（须全绿）
```

规范入口：`AGENTS.md`（总览与红线）→ `.agents/skills/`（角色路由）→
`docs/standards/`（专项细则）。

### 本地构建

```bash
bash scripts/export_all.sh all build    # 三端导出到 build/
```

## 设计与交付文档

- [GDD 设计真源 (v3)](docs/gdd/gdd.md) — 核心循环 / 六大系统定稿 / MVP 范围
- [v0.1.0 竣工交接文档](docs/discussion/handoffs/2026-09-07-v010-to-v020-handoff.md) — PR1~PR10 完整交付物与 v0.2 开工交接
- [决策日志 (DR-000~029)](docs/discussion/decision-log.md) — 架构与核心数值裁决纪录
- [ADR (0001~0009)](docs/adr/) — 引擎选型、分层架构、存档迁移、确定性随机、状态机等决策
- [五大规范](docs/standards/) — 代码 / 测试 / Git / 资产 / 文档

## 版本配对（升级必读）

| 组件 | 版本 | 配对 |
| :--- | :--- | :--- |
| Godot | 4.7.2-stable | — |
| GUT | 9.7.1 | ↔ 4.7.x |
| gdtoolkit | 4.3.4 | — |

换版本改三处（`scripts/setup_env.sh`、`.github/workflows/*.yml`、`project.godot`），
详见 [ADR-0001](docs/adr/0001-engine-version-and-toolchain.md)。

## License

MIT
