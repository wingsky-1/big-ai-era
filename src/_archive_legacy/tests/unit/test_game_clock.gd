extends GutTest

## GameClock 单元测试（issue #4）：刻步进、周结触发、暂停双源 OR 真值表、
## 带卡不结周、暂停期 Δt 丢弃。
## 暂停真值表（M1）：
##   | user_paused | blocked_by_card | paused |
##   |-------------|-----------------|--------|
##   | false       | false           | false  |
##   | true        | false           | true   |
##   | false       | true            | true   |
##   | true        | true            | true   |

const WEEK_SECONDS: float = 10.0  # 0.25s * 40 刻

var _clock: GameClock
var _settled_weeks: Array = []


func before_each() -> void:
	_clock = GameClock.new()
	_settled_weeks = []
	_clock.setup(DataLoader.load_json("res://src/data/clock.json"), self)
	_clock.week_boundary_reached.connect(func(w: int) -> void: _settled_weeks.append(w))
	autofree(_clock)


## 测试宿主周结桩：记录调用即可（settle_week 全序归 #5 GameWorld）。
func settle_week() -> void:
	pass


func test_steps_accumulate_to_week_boundary() -> void:
	_clock.advance(WEEK_SECONDS)  # 一整周
	assert_eq(_clock.week, 1, "满 40 刻应推进一周")
	assert_eq(_clock.week_ticks, 0, "跨周后周内刻数回落")
	assert_eq(_settled_weeks, [1], "周界应触发一次周结")


func test_partial_advance_does_not_settle() -> void:
	_clock.advance(2.5)  # 10 刻，不足一周
	assert_eq(_clock.week, 0, "未满周不应推进")
	assert_eq(_clock.week_ticks, 10, "周内刻数应累积")
	assert_eq(_settled_weeks, [], "不应触发周结")


func test_long_frame_settles_each_crossed_week() -> void:
	_clock.advance(WEEK_SECONDS * 2.5)  # 长帧跨 2.5 周
	assert_eq(_clock.week, 2, "跨 2.5 周应完成 2 次周结")
	assert_eq(_settled_weeks, [1, 2], "每周各触发一次周结（次序确定）")


func test_pending_card_blocks_week_settlement() -> void:
	# 带卡不结周（blocked_by_card→paused）：Δt 丢弃，周不推进。
	_clock.advance(WEEK_SECONDS)
	_clock.set_blocked_by_card(true)
	_clock.advance(WEEK_SECONDS * 3)
	assert_eq(_clock.week, 1, "阻塞期世界停摆，不应跨周")
	assert_eq(_settled_weeks, [1], "阻塞期不应有新周结")
	_clock.set_blocked_by_card(false)
	_clock.advance(WEEK_SECONDS)
	assert_eq(_clock.week, 2, "解除阻塞后恢复流淌并正常结周")


func test_pause_truth_table_or_semantics() -> void:
	# 真值表 4 组合逐一断言（M1 双源 OR）。
	_clock.user_paused = false
	_clock.blocked_by_card = false
	_clock.advance(0.1)
	assert_false(_clock.paused, "组合1: false|false → 流淌")

	_clock.set_user_paused(true)
	assert_true(_clock.paused, "组合2: user_paused|false → 暂停")

	_clock.set_user_paused(false)
	_clock.set_blocked_by_card(true)
	assert_true(_clock.paused, "组合3: false|blocked → 暂停")

	_clock.set_user_paused(true)
	assert_true(_clock.paused, "组合4: true|true → 暂停")

	_clock.set_user_paused(false)
	_clock.set_blocked_by_card(false)
	assert_false(_clock.paused, "双源都解除才恢复")


func test_paused_discards_delta_not_accumulate() -> void:
	# 暂停期 Δt 丢弃：恢复后不应"补帧"跳时间（只在场才流淌）。
	_clock.set_user_paused(true)
	_clock.advance(WEEK_SECONDS)
	assert_eq(_clock.week_ticks, 0, "暂停期不应累积任何刻")
	_clock.set_user_paused(false)
	_clock.advance(2.5)
	assert_eq(_clock.week_ticks, 10, "恢复后从零重新累积")
	assert_eq(_clock.week, 0, "恢复后不追帧")


func test_tick_signal_emitted() -> void:
	watch_signals(_clock)
	_clock.advance(2.5)  # 10 刻
	assert_signal_emitted(_clock, "tick_advanced", "步进刻数应发信号")
	var params: Array = get_signal_parameters(_clock, "tick_advanced")
	assert_eq(int(params[0]), 10, "信号应携带本帧跨过的刻数")


func test_settle_target_weakref_lost_reports_error() -> void:
	# 宿主被释放：周界到点但无法结账，应 push_error 显式暴露（防静默丢周）。
	var orphan := GameClock.new()
	autofree(orphan)
	var host := Node.new()
	autofree(host)
	orphan.setup(DataLoader.load_json("res://src/data/clock.json"), host)
	host.free()
	orphan.advance(WEEK_SECONDS)
	assert_push_error("周结宿主不可用", "宿主失效应有明确错误提示")
