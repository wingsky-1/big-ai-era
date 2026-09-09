extends GutTest
## #142 rivals.json 守卫带块 schema 断言（#128 data_schema 框架挂载）：
## 键名/类型 + 结构自检（L1-L4 分数带 20-40/40-60/60-80/80-100、
## max≤100 封顶硬红线、带区间单调不重叠）。
## #142 只落守卫带块；#144 时间线/动作键同文件前缀分区追加（届时本文件
## 增量挂 schema 行）。

const RIVALS_PATH: String = "res://src/data/rivals.json"

const RIVALS_SCHEMA: Dictionary = {
	"rival_guard_L1": {"type": "dict"},
	"rival_guard_L2": {"type": "dict"},
	"rival_guard_L3": {"type": "dict"},
	"rival_guard_L4": {"type": "dict"},
}


func test_rivals_schema_valid() -> void:
	var table := DataLoader.load_json(RIVALS_PATH)
	assert_false(table.is_empty(), "rivals.json 可加载")
	var result := DataSchema.validate_table(table, RIVALS_SCHEMA)
	assert_true(result.ok, "rivals.json schema 校验全过: %s" % str(result.errors))


func test_rivals_key_spelling_matches_source() -> void:
	# 键名拼写自检（#128 机制）；真源=rivals-spec D.2 rival_guard_L1-L4
	var table := DataLoader.load_json(RIVALS_PATH)
	var expected: Array[String] = [
		"rival_guard_L1",
		"rival_guard_L2",
		"rival_guard_L3",
		"rival_guard_L4",
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
