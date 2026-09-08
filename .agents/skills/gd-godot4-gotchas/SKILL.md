---
name: gd-godot4-gotchas
description: Godot 3→4 语法与 API 纠偏清单 + 引擎级坑位速查（类型降级、UID 断链、headless 行为差异）。写或审查任何 GDScript/Godot 配置前速查。
whenToUse: 编码前预防、审查发现可疑旧语法、调试引擎行为异常、迁移 Godot 3 代码时。
---

# Godot 4 语法与引擎坑位速查

> LLM 训练数据被 Godot 3 内容污染，本清单是防污染疫苗（参考 GodotPrompter 理念）。
> 工程以 Godot **4.7.x** + GDScript 2.0 为准。

## 一票否决的 Godot 3 残留（出现即打回）

| Godot 3（禁） | Godot 4（必须） |
| :--- | :--- |
| `export(int) var x` | `@export var x: int` |
| `onready var x = $X` | `@onready var x: Node = $X` |
| `yield(obj, "sig")` / `yield()` | `await obj.sig` / `await get_tree().process_frame` |
| `move_and_slide(velocity)` | 设 `velocity` 属性后无参调用 `move_and_slide()` |
| `onready var x = get_node("X")` 弱类型 | `@onready var x := %X as SpecificType` |
| `Spatial` / `KinematicBody` | `Node3D` / `CharacterBody3D` |
| `PoolStringArray` 等池类型 | `PackedStringArray` |
| `OS.window_size` | `DisplayServer.window_get_size()` |
| `funcref` | `Callable` |
| `.connect("sig", self, "method")` 字符串连接 | `sig.connect(method)` |

## 高频静默坑（不报错但坏行为）

1. **循环引用三连坑**（同一根因：两个 `class_name` 互相引用）：①编译期类型静默降级为 Nil，运行时才 `Invalid call on Nil`；②RefCounted A↔B 强引用互持永不释放（内存泄漏）。解法一体：依赖箭头保持单向（上层持下层），确需回指时子方用 `weakref`。本仓库铁律：RefCounted 双向引用必须 weakref（AGENTS.md 红线 5）。
3. **autoload 与 class_name 同名**：解析直接失败（本仓库真实踩过）。
4. **浮点等值比较** `if v == 0.0`：用 `is_zero_approx()` / `is_equal_approx()`。
5. **物理改动时机**：非 `_physics_process` 中改刚体 → `call_deferred`。
6. **UI 信号回调改场景树**（如换场景）：`call_deferred` 防回调中树被冻结。
7. **Headless 差异**：Control.size 不自动布局（推两帧）；Input 模拟不可用；
   音频驱动必须 Dummy。
8. **文件移动断 UID**：跨目录移动资源用编辑器内操作，或移动后跑 import 修复引用。
9. **`.tres` 手改 ID**：sub_resource/ext_resource 的 id 冲突 = 静默丢属性。
10. **Dictionary 顺序**：Godot 4 字典保持插入序（可依赖），但 JSON 解析出的
    数字键全为 String，取值注意类型。
11. **`project.godot` 是 ConfigFile 格式**：注释必须用 `;`——`#` 不是注释，会被
    解析器一路吞进键名（v0.1.2 实证：`# 注释...\ntheme/custom=...` 使键变成
    "注释...theme/custom" 复合键，`get_setting` 静默返回空，无任何报错）。
12. **Theme 类工程设置冷导入必炸**（v0.1.2 CI 实证）：`gui/theme/custom` 指向的
    Theme 若引用需导入的资产（如字体），冷环境首次 `--import` 时编辑器启动路径
    会先解析该设置，此刻资产未导入 → 资源断链 ERROR。本地 `.godot` 恒为热态
    永远暴露不了；**必须 `rm -rf .godot` 冷环境复验**。本仓库裁决：移除该兜底
    设置，字体收口走场景级 theme 挂载（ADR-0010）。
13. **enum 名避开内置类**（v0.1.3 实证）：`enum Panel {}` 与内置 `Panel` 控件类
    撞名，外部脚本解析 `XX.Panel.FOO` 报 "Could not resolve external class member"
    且类型两边不一致。命名前查 ClassDB（`ClassDB.class_exists("名字")`）。
14. **导出要求目标目录预先存在**：`--export-release` 前先 `mkdir -p`（报错
    "Target folder does not exist"）；CI release-build 与截图管线均已内置。
15. **get_stack() 撞名**（v0.1.3 实证）：类内裸调 `get_stack()` 解析到 GDScript
    内置全局函数（返回调试栈 Array），自己的方法被遮蔽且报错指向诡异；类内
    调用一律写 `self.get_stack()` 或直接引用成员变量。
16. **内置 WebSocket 是 EventTarget**（v0.1.3 实证，适用于本仓库 Node E2E 管线）：
    Node ≥22 原生 `WebSocket` 没有 `.once()`，用 `addEventListener(ev, fn, { once: true })`。

## 引擎版本升级检查单

- `project.godot` features 数组同步新版本号
- GUT 版本配对表核对（testing.md）
- 跑 `verify.sh` + 一次本地导出（export_all.sh）双确认
- 变更写 ADR（参照 ADR-0001）
