extends GutTest
## #128 验收点 1：每表 schema 断言（键名/类型/必需键/护栏跟键）。
## time.json 为 #128 种子真表（time-spec D.2 键名）；其余表随建表 issue 挂载。

const TIME_PATH: String = "res://src/data/time.json"

## time.json schema 描述（键名真源 time-spec D.2；护栏=同表 _bounds 内嵌）
## time_ritual_no_overlap=节拍错峰日历容器（#127，dict 非数值键，不占数值护栏行）
const TIME_SCHEMA: Dictionary = {
	"time_wall_clock_1x": {"type": "int"},
	"time_wall_clock_2x": {"type": "int"},
	"time_wall_clock_4x": {"type": "int"},
	"time_week_per_quarter": {"type": "int"},
	"time_week_per_year": {"type": "int"},
	"time_quarters_in_game": {"type": "int"},
	"time_ritual_density": {"type": "int"},
	"time_ritual_no_overlap": {"type": "dict"},
	"time_autosave_point": {"type": "int"},
	"time_manual_save": {"type": "int"},
	"time_focus_loss_pause": {"type": "float"},
	"time_settle_seq_dur": {"type": "float"},
	"time_bland_threshold": {"type": "int"},
}

const TIME_NUMERIC_KEYS: Array[String] = [
	"time_wall_clock_1x",
	"time_wall_clock_2x",
	"time_wall_clock_4x",
	"time_week_per_quarter",
	"time_week_per_year",
	"time_quarters_in_game",
	"time_ritual_density",
	"time_autosave_point",
	"time_manual_save",
	"time_focus_loss_pause",
	"time_settle_seq_dur",
	"time_bland_threshold",
]


func test_time_table_loads_and_validates() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	assert_false(table.is_empty(), "time.json 可加载")
	var result := DataSchema.validate_table(table, TIME_SCHEMA)
	assert_true(result.ok, "time.json schema 校验全过: %s" % str(result.errors))


func test_time_table_inline_bounds_present() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var result := DataSchema.validate_inline_bounds(table, TIME_NUMERIC_KEYS)
	assert_true(result.ok, "time.json 数值键全部带内嵌护栏: %s" % str(result.errors))


func test_time_table_required_keys_all_present() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var expected: Array[String] = [
		"time_wall_clock_1x",
		"time_wall_clock_2x",
		"time_wall_clock_4x",
		"time_week_per_quarter",
		"time_week_per_year",
		"time_quarters_in_game",
	]
	for key: String in expected:
		assert_true(table.has(key), "time.json 缺必需键 %s" % key)


func test_bounds_read_runtime() -> void:
	# 护栏运行时读键（防改数不改护栏）：bound 值确实约束数值键
	var table := DataLoader.load_json(TIME_PATH)
	var bounds: Dictionary = table[DataSchema.BOUNDS_KEY]
	assert_almost_eq(
		float(bounds["time_week_per_quarter"][0]),
		13.0,
		0.001,
		"季度长护栏下限=13（52/13 整除对齐）",
	)
	assert_almost_eq(
		float(bounds["time_week_per_year"][0]),
		52.0,
		0.001,
		"年度长护栏下限=52",
	)
