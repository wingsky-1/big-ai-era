extends GutTest

## GameLoopDriver 门控与变速测试（issue #4）：不可见=停喂 tick、变速系数
## 预乘、门控开关。L3 层 Node 测试推帧用 feed_frame 显式喂（headless 不模拟 _process）。

var _driver: GameLoopDriver


func before_each() -> void:
	_driver = GameLoopDriver.new()
	autofree(_driver)
	add_child_autofree(_driver)


func _make_world_stub(advance_log: Array) -> Object:
	# GameWorld 桩：只提供 get_clock()，时钟 advance 记录喂入值。
	var clock_stub := Node.new()
	autofree(clock_stub)
	var script := GDScript.new()
	script.source_code = """
extends Object
signal tick_advanced(ticks: int)
signal week_boundary_reached(week: int)
var week: int = 0
var week_ticks: int = 0
var user_paused: bool = false
var blocked_by_card: bool = false
var paused: bool = false
var tick_seconds: float = 0.25
var _log: Array
func advance(delta: float) -> void:
	_log.append(delta)
func set_log(log_array: Array) -> void:
	_log = log_array
"""
	script.reload()
	var stub: Object = script.new()
	autofree(stub)
	stub.set_log(advance_log)
	var world_script := GDScript.new()
	world_script.source_code = """
extends Object
var _clock: Object
func get_clock() -> Object:
	return _clock
func set_clock(clock: Object) -> void:
	_clock = clock
"""
	world_script.reload()
	var world: Object = world_script.new()
	autofree(world)
	world.set_clock(stub)
	return world


func test_feeding_enabled_by_default() -> void:
	var log: Array = []
	_driver.setup(_make_world_stub(log))
	_driver.feed_frame(0.1)
	_driver.feed_frame(0.2)
	assert_eq(log.size(), 2, "门控开启时每帧都应喂入")


func test_invisible_gate_stops_feeding() -> void:
	# 停喂门控（DR-022②）：不可见=零喂入，恢复可见继续流淌。
	var log: Array = []
	_driver.setup(_make_world_stub(log))
	_driver.set_feeding_enabled(false)
	_driver.feed_frame(0.1)
	_driver.feed_frame(0.1)
	assert_eq(log.size(), 0, "不可见时不应喂任何帧")
	_driver.set_feeding_enabled(true)
	_driver.feed_frame(0.1)
	assert_eq(log.size(), 1, "恢复可见后继续喂帧")


func test_speed_multiplier_scaling() -> void:
	var log: Array = []
	_driver.setup(_make_world_stub(log))
	_driver.feed_frame(1.0)
	assert_almost_eq(float(log[0]), 1.0, 0.0001, "1x 不缩放")
	_driver.cycle_speed()  # 2x
	_driver.feed_frame(1.0)
	assert_almost_eq(float(log[1]), 2.0, 0.0001, "2x 预乘 Δt")
	_driver.cycle_speed()  # 4x
	_driver.feed_frame(1.0)
	assert_almost_eq(float(log[2]), 4.0, 0.0001, "4x 预乘 Δt")
	_driver.cycle_speed()  # 回到 1x
	_driver.feed_frame(1.0)
	assert_almost_eq(float(log[3]), 1.0, 0.0001, "循环回 1x")
	assert_almost_eq(_driver.get_speed_multiplier(), 1.0, 0.0001, "变速查询应同步")


func test_speed_multipliers_data_matches_contract() -> void:
	# 变速档位契约：1x/2x/4x（GDD 已定基调）。
	var multipliers: PackedFloat32Array = GameLoopDriver.SPEED_MULTIPLIERS
	assert_eq(multipliers.size(), 3, "应有 3 个变速档")
	assert_almost_eq(multipliers[0], 1.0, 0.0001, "1x")
	assert_almost_eq(multipliers[1], 2.0, 0.0001, "2x")
	assert_almost_eq(multipliers[2], 4.0, 0.0001, "4x")


func test_clock_json_beats_loaded() -> void:
	# 节拍数值在 L4 clock.json（红线 3），GameClock 直接注入消费（无代码默认值/常量）。
	var config := DataLoader.load_json("res://src/data/clock.json")
	var clock := GameClock.new()
	autofree(clock)
	clock.setup(config, self)
	assert_eq(
		clock.ticks_per_week,
		int(config["ticks_per_week"]),
		"GameClock 应从 clock.json 注入 ticks_per_week（死键已收口）"
	)
	assert_gt(clock.tick_seconds, 0.0, "tick_seconds 应为正数")
