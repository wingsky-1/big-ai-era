class_name StatAttribute
extends RefCounted

## 数值属性包：base + flat 修正 + percent 修正。
## 纯逻辑（RefCounted），不依赖场景树，可无头毫秒级单测。
## 表现层通过 [signal changed] 单向监听，禁止反向耦合。

## 数值发生任何变化时发出，携带计算后的最终值。
signal changed(value: float)

var _base_value: float
var _flat_bonus: float = 0.0
var _percent_bonus: float = 0.0


func _init(base_value: float = 0.0) -> void:
	_base_value = maxf(base_value, 0.0)


## 最终值 = (base + flat) * (1 + percent)，下限 0。
func get_value() -> float:
	return maxf((_base_value + _flat_bonus) * (1.0 + _percent_bonus), 0.0)


func get_base_value() -> float:
	return _base_value


func set_base_value(value: float) -> void:
	_base_value = maxf(value, 0.0)
	_notify()


func add_flat_bonus(delta: float) -> void:
	_flat_bonus += delta
	_notify()


func add_percent_bonus(delta: float) -> void:
	_percent_bonus += delta
	_notify()


## 清除全部修正，仅保留基础值。
func clear_modifiers() -> void:
	_flat_bonus = 0.0
	_percent_bonus = 0.0
	_notify()


func _notify() -> void:
	changed.emit(get_value())
