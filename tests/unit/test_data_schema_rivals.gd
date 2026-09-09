extends GutTest
## #142+#144 rivals.json schema 断言（#128 data_schema 框架挂载）：
## 键名/类型 + 结构自检（L1-L4 分数带 20-40/40-60/60-80/80-100、
## max≤100 封顶硬红线、带区间单调不重叠、时间线脚本约束）。
## #142 落守卫带块；#144 增量挂时间线/动作/频率键（键名真源=rivals-spec
## D.2 + numerics-master §守卫带联标）。

const RIVALS_PATH: String = "res://src/data/rivals.json"

const RIVALS_SCHEMA: Dictionary = {
	"rival_guard_L1": {"type": "dict"},
	"rival_guard_L2": {"type": "dict"},
	"rival_guard_L3": {"type": "dict"},
	"rival_guard_L4": {"type": "dict"},
	"rival_jitter": {"type": "float"},
	"rival_release_freq_min": {"type": "int"},
	"rival_pricewar_freq_per_quarter": {"type": "int"},
	"rival_poach_freq_per_quarter": {"type": "int"},
	"rival_poach_max_per_staff": {"type": "int"},
	"rival_paper_effect": {"type": "dict"},
	"rival_actors": {"type": "dict"},
}


func test_rivals_schema_valid() -> void:
	var table := DataLoader.load_json(RIVALS_PATH)
	assert_false(table.is_empty(), "rivals.json 可加载")
	var result := DataSchema.validate_table(table, RIVALS_SCHEMA)
	assert_true(result.ok, "rivals.json schema 校验全过: %s" % str(result.errors))


func test_rivals_key_spelling_matches_source() -> void:
	# 键名拼写自检（#128 机制）；真源=rivals-spec D.2
	var table := DataLoader.load_json(RIVALS_PATH)
	var expected: Array[String] = [
		"rival_guard_L1",
		"rival_guard_L2",
		"rival_guard_L3",
		"rival_guard_L4",
		"rival_jitter",
		"rival_release_freq_min",
		"rival_pricewar_freq_per_quarter",
		"rival_poach_freq_per_quarter",
		"rival_poach_max_per_staff",
		"rival_paper_effect",
		"rival_actors",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "rivals.json 键名拼写与真源一致: %s" % str(result.errors))


func test_guard_bands_ascending_not_overlapping() -> void:
	# 守卫带结构护栏：min/max 递增相接不重叠；max≤100 封顶硬红线
	var table := DataLoader.load_json(RIVALS_PATH)
	var keys: Array[String] = [
		"rival_guard_L1",
		"rival_guard_L2",
		"rival_guard_L3",
		"rival_guard_L4",
	]
	var expected_mins: Array[float] = [20.0, 40.0, 60.0, 80.0]
	var expected_maxs: Array[float] = [40.0, 60.0, 80.0, 100.0]
	for i: int in keys.size():
		var band: Dictionary = table[keys[i]]
		assert_almost_eq(float(band["min"]), expected_mins[i], 0.001, "%s min 真源" % keys[i])
		assert_almost_eq(float(band["max"]), expected_maxs[i], 0.001, "%s max 真源" % keys[i])
		assert_true(float(band["max"]) <= 100.0, "%s max≤100（永不超玩家封顶）" % keys[i])
	# 相接不重叠：后带 min == 前带 max
	for i: int in keys.size() - 1:
		assert_almost_eq(
			float((table[keys[i + 1]] as Dictionary)["min"]),
			float((table[keys[i]] as Dictionary)["max"]),
			0.001,
			"%s.min == %s.max（区间相接无重叠）" % [keys[i + 1], keys[i]],
		)


func test_timeline_script_constraints() -> void:
	# 时间线脚本结构护栏（#144；rivals-spec D.2 频率护栏）：
	# - 动作周升序唯一；发版周间隔 ≥ rival_release_freq_min（表驱动 6）
	# - pricewar/poach 每 13 周季度 ≤ rival_pricewar_freq_per_quarter（1）
	# - 发版周 ∉ 季度大赏周 13n（time_ritual_no_overlap 错峰同标）
	# - release 动作带 score ∈[0,100]；paper 动作带 domain
	var table := DataLoader.load_json(RIVALS_PATH)
	var actors: Dictionary = table["rival_actors"]
	var order: Array = actors["_order"]
	assert_true(order.size() >= 1, "P0 至少 1 竞对（E6：包容器）")
	var min_gap := int(table["rival_release_freq_min"])
	var per_quarter := int(table["rival_pricewar_freq_per_quarter"])
	for actor_key: Variant in order:
		var actor: Dictionary = actors[str(actor_key)]
		var timeline: Array = actor["timeline"]
		var prev_week := -100
		var prev_release := -100
		var prev_pricewar := -100
		var prev_poach := -100
		var action_weeks: Dictionary = {}
		for entry_v: Variant in timeline:
			var entry: Dictionary = entry_v
			var week := int(entry["week"])
			var action := str(entry["action"])
			assert_true(week > prev_week, "%s 动作周升序" % str(actor_key))
			prev_week = week
			assert_false(action_weeks.has(week), "同周不重复动作（%d）" % week)
			action_weeks[week] = action
			match action:
				"release":
					assert_true(week - prev_release >= min_gap, "发版间隔 ≥%d（防骚扰）" % min_gap)
					prev_release = week
					assert_true(week % 13 != 0, "发版周 ∉ 季度大赏周 13n（错峰）")
					assert_true(
						float(entry["score"]) >= 0.0 and float(entry["score"]) <= 100.0,
						"发版分 ∈[0,100]"
					)
				"pricewar":
					assert_true(week - prev_pricewar >= 13 * per_quarter, "涨价 ≤1 次/季度")
					prev_pricewar = week
				"poach":
					assert_true(week - prev_poach >= 13 * per_quarter, "挖人 ≤1 次/季度")
					prev_poach = week
				"paper":
					assert_false(str(entry.get("domain", "")).is_empty(), "论文动作带 domain")
				_:
					assert_true(false, "未知动作 %s（四类：paper/release/pricewar/poach）" % action)
