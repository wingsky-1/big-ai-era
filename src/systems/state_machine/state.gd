class_name State
extends RefCounted

## 状态机状态基类：纯逻辑（RefCounted），由宿主（通常是 Node）持有驱动。
##
## 架构红线：本类不声明 [class StateMachine] 类型注解，避免两个 class_name
## 互相引用造成循环依赖；对状态机的回访一律通过弱引用 [member _machine]，
## 使用前必须判空（见 docs/standards/code-style.md 内存章节）。

var _machine: WeakRef = null


## 进入状态时调用（在上一状态 exit 之后）。
func enter() -> void:
	pass


## 离开状态时调用。
func exit() -> void:
	pass


## 每帧逻辑推进，由 [method StateMachine.update] 委派。
func update(_delta: float) -> void:
	pass


## 由 StateMachine 注入；子类通过 [method get_machine] 访问。
func set_machine(machine: RefCounted) -> void:
	_machine = weakref(machine)


## 获取宿主状态机的弱引用；调用方须先 get_ref() 判空再使用（弱引用安全校验）。
func get_machine() -> WeakRef:
	return _machine
