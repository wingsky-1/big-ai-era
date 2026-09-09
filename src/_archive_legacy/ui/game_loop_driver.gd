class_name GameLoopDriver
extends Node

## 游戏循环驱动器（L3 表现层）：唯一吃 _process 增量的地方——对 Δt 预乘
## 变速系数（变速属 View，Q2），经 [method feed_frame] 喂给 GameClock；
## 关页/后台不可见时停喂（DR-022②"只在场才流淌"），零模拟层改动。
##
## L3 持 L2 引用用 weakref 防 Node↔RefCounted 循环（红线 5）。

signal fed(delta_seconds: float)

const SPEED_MULTIPLIERS: PackedFloat32Array = [1.0, 2.0, 4.0]  # num-ok: 变速档（ADR-0006：变速属 View）
const DEFAULT_SPEED_INDEX: int = 0

var speed_index: int = DEFAULT_SPEED_INDEX
var visible_gate: bool = true  # View 门控：窗口可见才流淌（UI 帧信号驱动）

var _world_ref: WeakRef = null
var _clock_ref: WeakRef = null


## 组装方注入 GameWorld（须提供 get_clock()）与可选项 GameClock。
func setup(world: Object) -> void:
	_world_ref = weakref(world)


func _ready() -> void:
	set_process(false)  # 未注入 world 前不空转


func _process(delta: float) -> void:
	feed_frame(delta)


## 喂帧入口（也供测试/上层显式调用）：门控+变速后交给时钟。
func feed_frame(delta: float) -> void:
	if not visible_gate:
		return
	var clock := _resolve_clock()
	if clock == null:
		return
	var speed: float = SPEED_MULTIPLIERS[clampi(speed_index, 0, SPEED_MULTIPLIERS.size() - 1)]
	var scaled: float = delta * speed
	fed.emit(scaled)
	clock.advance(scaled)


## 变速循环切换（1x→2x→4x→1x）。
func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEED_MULTIPLIERS.size()


func get_speed_multiplier() -> float:
	return SPEED_MULTIPLIERS[clampi(speed_index, 0, SPEED_MULTIPLIERS.size() - 1)]


## 停喂门控显式开关（与 visible_gate 同源：不可见=停喂 tick，DR-022②）。
func set_feeding_enabled(enabled: bool) -> void:
	visible_gate = enabled


func _resolve_clock() -> Object:
	if _clock_ref != null:
		return _clock_ref.get_ref()
	var world: Object = _world_ref.get_ref() if _world_ref != null else null
	if world == null or not world.has_method("get_clock"):
		return null
	var clock: Object = world.get_clock()
	_clock_ref = weakref(clock)
	return clock
