extends GutTest

## ClockMath 纯函数表驱动测试（issue #4 / L0）：Δt 累积、满刻、满周与边界。


func test_accumulate_table_driven() -> void:
	var cases: Array = [
		# [accumulator, delta, tick_seconds, 期望 accumulator, 期望 ticks]
		[0.0, 0.25, 0.25, 0.0, 1],  # 恰好一整刻
		[0.0, 0.1, 0.25, 0.1, 0],  # 不足一刻全累积
		[0.2, 0.1, 0.25, 0.05, 1],  # 跨刻保留余量
		[0.0, 1.0, 0.25, 0.0, 4],  # 长帧跨 4 刻
		[0.0, 0.0, 0.25, 0.0, 0],  # 零增量
		[0.24, 0.02, 0.25, 0.01, 1],  # 余量接力
	]
	for case: Array in cases:
		var step := ClockMath.accumulate(float(case[0]), float(case[1]), float(case[2]))
		assert_almost_eq(
			float(step["accumulator"]), float(case[3]), 0.0001, "accumulate 余量 %s" % str(case)
		)
		assert_eq(int(step["ticks"]), int(case[4]), "accumulate 刻数 %s" % str(case))


func test_accumulate_ignores_negative_delta() -> void:
	# 暂停/停喂由上层保证 delta<=0 不喂；双保险：数学层也拒绝负增量。
	var step := ClockMath.accumulate(0.1, -0.5, 0.25)
	assert_almost_eq(float(step["accumulator"]), 0.1, 0.0001, "负增量不应累积")
	assert_eq(int(step["ticks"]), 0, "负增量步进为 0")


func test_weeks_crossed_boundaries() -> void:
	var cases: Array = [
		# [week_ticks_before, ticks_gained, ticks_per_week, 期望跨周数]
		[39, 1, 40, 1],  # 周界最后一刻触发
		[38, 1, 40, 0],  # 未到周界
		[39, 41, 40, 2],  # 长帧跨两周
		[0, 80, 40, 2],  # 整两倍周
		[0, 0, 40, 0],  # 无步进
	]
	for case: Array in cases:
		assert_eq(
			ClockMath.weeks_crossed(int(case[0]), int(case[1]), int(case[2])),
			int(case[3]),
			"weeks_crossed %s" % str(case)
		)


func test_week_ticks_after_wraps() -> void:
	assert_eq(ClockMath.week_ticks_after(39, 1, 40), 0, "跨周后刻数回落到 0")
	assert_eq(ClockMath.week_ticks_after(38, 1, 40), 39, "周内推进")
	assert_eq(ClockMath.week_ticks_after(39, 81, 40), 0, "跨两周整点回落")
	assert_eq(ClockMath.week_ticks_after(39, 82, 40), 1, "跨两周余一刻")
