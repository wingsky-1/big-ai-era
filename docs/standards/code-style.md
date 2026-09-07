# GDScript 代码规范

> 权威层级：本文件与 `AGENTS.md` 冲突时，以 `AGENTS.md` 红线为准。
> 强制力：`gdlint` + `gdformat`（scripts/verify.sh）机器强制执行其中大部分规则；
> 无法机器检查的条目（架构类）依赖 Code Review（gd-code-review skill）。
> 工具版本：gdtoolkit 4.3.x / Godot 4.7.x。

## 1. 语言现代性（Godot 4.x 禁令清单）

LLM 训练数据中 Godot 3 语法泛滥，以下旧语法**一律禁止**：

| 禁止（Godot 3） | 必须（Godot 4） |
| :--- | :--- |
| `export(int) var speed` | `@export var speed: int` |
| `onready var x = $X` | `@onready var x: Node = $X` |
| `yield(anim, "finished")` | `await anim.finished` |
| `move_and_slide(velocity)` | 先设 `velocity` 属性再无参调用 `move_and_slide()` |
| `InstancePlaceholder` / `PI` 等移除项 | 查阅官方 4.x API 文档 |

## 2. 类型系统

- 一切**可标注处强制强类型**：函数签名、变量、常量。
- 容器必须用 Typed 容器：`Array[String]`、`Dictionary[StringName, State]`。
- 推断可用但要显式：`var items := DataLoader.load_json(path)`（推断为 Dictionary）。
- `Variant` 只允许出现在 JSON 解析结果等动态边界，赋值给具体类型时显式转换：

```gdscript
var parsed: Variant = JSON.parse_string(text)
if parsed is not Dictionary:
    return {}
var data: Dictionary = parsed
```

- 跨类型节点获取必须断言：`var player := %Player as Player`，禁止裸 `get_node()` 弱类型蔓延。

## 3. 命名法

| 对象 | 规则 | 示例 |
| :--- | :--- | :--- |
| 类名（class_name） | PascalCase | `StatAttribute` |
| 文件/目录 | snake_case | `stat_attribute.gd` |
| 信号 | 过去式 snake_case（事件已发生） | `health_depleted` |
| 信号回调 | `on_<来源>_<事件>` | `_on_button_pressed` |
| 常量 | SCREAMING_SNAKE_CASE | `MAX_HEALTH` |
| 私有成员 | `_` 前缀 | `_base_value` |
| 枚举/枚举值 | PascalCase / SCREAMING_SNAKE | `enum State { IDLE, RUN }` |
| autoload | 场景职责命名，**脚本禁止 class_name** | `SaveSystem`（见 §8） |

## 4. 文件结构顺序（gdlint 机器强制）

从上到下依次为（gdlint `class-definitions-order` 默认序，违反即 verify 失败）：

`@tool`/`@static` 注解 → `class_name` → `extends` → 信号 → enum → 常量 → `@export` → 公有变量 → 私有变量 → `@onready` → `_init`/`_enter_tree`/`_ready`/`_process`/`_physics_process` 等虚方法 → 公有方法 → 私有方法 → 内部类。

> 注意：**`@onready` 排在普通变量之后**（gdlint 将其归类为独立类别），这是最常见的踩坑点。

## 5. 信号与节点引用（解耦三原则）

1. **Signal Up, Call Down**：子→父发信号；父→子直接调用。禁止子节点直接调用父方法。
2. **场景内寻址一律 `%UniqueName`**：编辑器中右键节点 → "Access as Unique Name"。
   禁止 `$../../Panel/Button` 相对路径与绝对路径。
3. **跨场景依赖用 `@export` 注入**：`@export var target: Node`，由组装方赋值。

Lambda 匿名连接的风险（场景销毁后悬空）——优先方法引用；必须用 lambda 时确认生命周期与宿主一致：

```gdscript
# 好：方法引用，随对象生命周期自动断开
button.pressed.connect(_on_button_pressed)

# 谨慎：lambda 持有外部引用，仅用于短生命周期对象
timer.timeout.connect(func(): queue_redraw())
```

## 6. 逻辑与表现分离（可测性根基）

- **核心规则**（伤害、经济、状态转换、冷却）：继承 `RefCounted`，**禁止引用任何 Node/SceneTree**。
- **表现层**（Node/Control）：监听逻辑对象信号 → 更新 Transform/动画/文本，仅此而已。
- 判定口诀："这段逻辑能在没有窗口的服务器上跑吗？" 不能 → 重构。
- 数值禁止硬编码：一律进 `src/data/*.json`（见 balance-designer skill）。

## 7. 异步与物理边界

- 修改物理体 Transform/velocity 只允许在 `_physics_process`；信号回调中必须 `call_deferred`。
- Headless/CI 环境 UI 布局需推两帧：`await get_tree().process_frame` × 2。
- 浮点比较**禁止 `==`**：用 `is_zero_approx()` / `is_equal_approx()` / `assert_almost_eq()`。

## 8. autoload 与 class_name

- **autoload 脚本禁止声明 `class_name`**：会与单例名冲突，Godot 4 直接报
  `Class "X" hides an autoload singleton` 解析失败（本项目已踩过，见 ADR-0001）。
- autoload 只放真正的全局服务（存档、配置），保持数量最少。
- 双向引用的 RefCounted（如 State ↔ StateMachine）：子方必须用 `weakref()` 持有，
  使用前 `get_ref()` 判空——防止 RefCounted 循环引用内存泄漏。

## 9. 格式化

- `gdformat` 自动格式化（默认列宽 100，tab 缩进）；禁止手工对抗格式化工具。
- 提交前 `bash scripts/verify.sh` 必须全绿；CI 与本地跑的是**同一条命令**。
- 文档注释用 `##`（生成 API 文档），行内注释 `#` 说明"为什么"而非"是什么"。
