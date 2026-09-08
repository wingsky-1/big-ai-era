class_name GameClock
extends RefCounted

## 刻步进周引擎（L2 游戏规则，RefCounted 无 Node 依赖，v1.1 §A）。
## 职责：Δt→刻累积、周界触发周结、暂停双源判定；settle_week 全序归
## GameWorld（#5），本类只保证触发与阻塞语义（DR-007 / DR-021 M1）。
##
## 暂停真值表（M1 双源 OR）：user_paused OR blocked_by_card = paused。
## paused 时 Δt 丢弃（不累积），恢复流淌从当前累积余量继续。
## 变速系数属 View：Driver 已对 Δt 预乘，本类不感知速度（Q2）。

signal tick_advanced(week_ticks: int)
signal week_boundary_reached(week: int)

const CLOCK_PATH: String = "res://src/data/clock.json"

var week: int = 0
var week_ticks: int = 0
var user_paused: bool = false
var blocked_by_card: bool = false
var paused: bool = false
var tick_seconds: float = 0.0
var ticks_per_week: int = 0

var _accumulator: float = 0.0
var _settle_target: Object = null


## 配置节拍并绑定周结宿主（GameWorld 提供 settle_week()）。
## Weakref 防止 GameWorld↔GameClock 循环引用泄漏（红线 5）。
func setup(config: Dictionary, settle_target: Object) -> void:
	var tick_variant: Variant = DataLoader.require_key(config, "tick_seconds", CLOCK_PATH)
	var week_variant: Variant = DataLoader.require_key(config, "ticks_per_week", CLOCK_PATH)
	if tick_variant == null or week_variant == null:
		return
	tick_seconds = float(tick_variant)
	ticks_per_week = int(week_variant)
	_settle_target = weakref(settle_target)


## 双源暂停 OR 合成（M1）：任一为真即暂停。
func _update_paused() -> void:
	paused = user_paused or blocked_by_card


## 喂入帧时长；paused 时丢弃 Δt。跨周时逐周回调宿主 settle_week()——
## 长帧跨多周（卡顿/恢复）也保持每周一次周结，次序确定。
func advance(delta_seconds: float) -> void:
	_update_paused()
	if paused or delta_seconds <= 0.0:
		return
	var step := ClockMath.accumulate(_accumulator, delta_seconds, tick_seconds)
	_accumulator = float(step["accumulator"])
	var gained: int = int(step["ticks"])
	if gained <= 0:
		return
	var ticks_before := week_ticks
	week_ticks = ClockMath.week_ticks_after(week_ticks, gained, ticks_per_week)
	var weeks := ClockMath.weeks_crossed(ticks_before, gained, ticks_per_week)
	tick_advanced.emit(gained)
	if weeks <= 0:
		return
	for i in weeks:
		week += 1
		week_boundary_reached.emit(week)
		var target: Object = (
			_settle_target.get_ref() if _settle_target is WeakRef else _settle_target
		)
		if target == null or not target.has_method("settle_week"):
			push_error("GameClock: 周结宿主不可用（weakref 失效或缺 settle_week），周界未结账")
			return
		target.settle_week()


## 决策卡入队/出队（DR-022①：带卡不结周，blocked 状态由 GameWorld 维护）。
func set_blocked_by_card(blocked: bool) -> void:
	blocked_by_card = blocked
	_update_paused()


## 暂停键（Q4：blocked 期间请求解除用户暂停由 GameWorld 拦截，本层只存真值）。
func set_user_paused(on: bool) -> void:
	user_paused = on
	_update_paused()
