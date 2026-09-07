# 0002. 单向拓扑分层架构（Layer-first 目录）

日期：2026-09-07 / 状态：accepted

## 背景

Godot 的 `class_name` 全局注册 + `preload` 机制下，按特性划分目录
（features/player、features/combat）极易形成跨特性循环引用：
编译期静默把类型降级为 Nil，运行时才爆 `Invalid call on Nil`，
且 Agent 编码时更难察觉。需要一种让依赖方向天然单向的结构。

## 决策

五层单向拓扑，依赖只允许自上而下（上层 import 下层，禁止反向与同层互引）：

```text
L0 core/      纯常量、枚举、数学工具（零依赖）
L1 systems/   通用服务：状态机、数值、存档、数据加载（仅依赖 L0）
L2 entities/  游戏对象（依赖 L0/L1）
L3 ui/        表现层（依赖 L0/L1，经注入可触达 L2 数据）
L4 data/      纯配置 JSON/CSV（被 L1-L3 读取，不反向）
```

配套约定：
- 核心规则继承 `RefCounted`（state_machine / stats / save_migrator 均如此），
  Node 只做表现；
- 跨场景对象引用用 `@export` 注入 + `%UniqueName` 场景内寻址；
- 数值/配置外置 `src/data/*.json`。

## 备选方案

- **Feature-first**：内聚性好，但 Godot 无模块系统，靠纪律防循环不可靠（尤其对 Agent）。
- **纯 autoload 单例中心化**：上手快，但形成上帝对象，调用链不可追踪。

## 后果

- 正向：依赖违规可以 grep 出来（`preload` 指向不允许的层即违规）；
  纯逻辑层可无头毫秒级单测；目录即架构图。
- 代价：跨层跳转文件路径较长；新特性需要在多层各建文件（用 gd-lead-programmer
  skill 中的模板降低摩擦）。
