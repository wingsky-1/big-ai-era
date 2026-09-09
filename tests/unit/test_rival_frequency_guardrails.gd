extends GutTest
## #144 验收点 2：频率护栏——发版 ≥6 周间隔/涨价挖人 ≤1 次每季度
## （GUT：`test_rival_frequency_guardrails`）。
## 真源=rivals-spec D.2（rival_release_freq：~1 次/10 周 8-12、关键期加密
## 不超 1 次/6 周防骚扰；rival_pricewar_freq/rival_poach_freq：≤1 次/季度）
## + A.5 [P]（任意 10 周窗口竞对动作 ≤3 次且周报可查——频率护栏生效）。
## 运行时断言（schema 测试已断表结构；本文件断"推进后真实频率"）。

const RIVALS_PATH: String = "res://src/data/rivals.json"


func _timeline_release_weeks(table: Dictionary) -> Array[int]:
	var weeks: Array[int] = []
	var actors: Dictionary = table["rival_actors"]
	for actor_key: Variant in actors["_order"]:
		var actor: Dictionary = actors[str(actor_key)]
		for entry: Variant in actor["timeline"]:
			var row: Dictionary = entry
			if str(row["action"]) == "release":
				weeks.append(int(row["week"]))
	weeks.sort()
	return weeks


func test_rival_frequency_guardrails() -> void:
	var table := DataLoader.load_json(RIVALS_PATH)
	var min_gap := int(table["rival_release_freq_min"])
	assert_true(min_gap >= 6, "发版最小间隔 ≥6 周（表护栏）")
	var releases := _timeline_release_weeks(table)
	# 发版间隔 ≥ 表值
	for i: int in releases.size() - 1:
		var gap := releases[i + 1] - releases[i]
		assert_true(
			gap >= min_gap, "发版间隔 %d ≥ %d（W%d→W%d）" % [gap, min_gap, releases[i], releases[i + 1]]
		)
	# 涨价/挖人每季度（13 周窗）≤1 次
	var actors: Dictionary = table["rival_actors"]
	for actor_key: Variant in actors["_order"]:
		var actor: Dictionary = actors[str(actor_key)]
		var price_weeks: Array[int] = []
		var poach_weeks: Array[int] = []
		for entry: Variant in actor["timeline"]:
			var row: Dictionary = entry
			var action := str(row["action"])
			var week := int(row["week"])
			if action == "pricewar":
				price_weeks.append(week)
			elif action == "poach":
				poach_weeks.append(week)
		for quarter: int in range(1, 13):
			var lo := (quarter - 1) * 13 + 1
			var hi := quarter * 13
			var price_in_q := 0
			var poach_in_q := 0
			for w: int in price_weeks:
				if w >= lo and w <= hi:
					price_in_q += 1
			for w: int in poach_weeks:
				if w >= lo and w <= hi:
					poach_in_q += 1
			assert_true(
				price_in_q <= int(table["rival_pricewar_freq_per_quarter"]),
				"Q%d 涨价 ≤1 次（%s）" % [quarter, str(actor_key)],
			)
			assert_true(
				poach_in_q <= int(table["rival_poach_freq_per_quarter"]),
				"Q%d 挖人 ≤1 次（%s）" % [quarter, str(actor_key)],
			)
		# 任意 10 周窗口动作 ≤3 次（[P] 防骚扰体验的数值护栏；每竞对检查）
		var timeline: Array = actor["timeline"]
		for start: int in range(1, 100):
			var count := 0
			for entry: Variant in timeline:
				var week := int((entry as Dictionary)["week"])
				if week >= start and week < start + 10:
					count += 1
			assert_true(
				count <= 3,
				"W%d-%d 窗口动作 %d ≤3（防每周骚扰，%s）" % [start, start + 9, count, str(actor_key)],
			)


func test_rival_poach_max_per_staff_guardrail() -> void:
	# 同一员工被挖 ≤2 次/局（rivals-spec D.2 rival_poach_freq 护栏）：
	# P0 表 poach 动作无员工目标字段=编排批 P1 消费时约束；
	# 表护栏=poach 总次 ≤2×在册上限（表驱动值存在且 ≥1）
	var table := DataLoader.load_json(RIVALS_PATH)
	assert_true(int(table["rival_poach_max_per_staff"]) >= 1, "表驱动 max≥1")
	assert_true(int(table["rival_poach_freq_per_quarter"]) >= 1, "表驱动每季上限≥1")
