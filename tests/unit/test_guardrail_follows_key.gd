extends GutTest
## #128 验收点 2：表内嵌 bound 块断言运行时读键（防改数不改护栏）。
## 模拟"改坏一个数值键/删一个护栏" → 校验必须变红。

const TIME_PATH: String = "res://src/data/time.json"

## 与 test_data_schema_time 同源的 schema 描述
const TIME_SCHEMA: Dictionary = {
	"time_wall_clock_1x": {"type": "int"},
	"time_week_per_quarter": {"type": "int"},
	"time_week_per_year": {"type": "int"},
}


func test_broken_numeric_key_fails_validation() -> void:
	# 把季度长改坏成字符串：类型断言必须红
	var table := DataLoader.load_json(TIME_PATH)
	var broken := table.duplicate()
	broken["time_week_per_quarter"] = "十三"
	var result := DataSchema.validate_table(broken, TIME_SCHEMA)
	assert_false(result.ok, "类型被改坏后校验必须失败")
	assert_true(
		str(result.errors).contains("time_week_per_quarter"),
		"错误信息须指明具体键",
	)


func test_out_of_bounds_value_fails() -> void:
	# 把 1x 墙钟时长改成 100（超 bound 18–30）：护栏必须拦下
	var table := DataLoader.load_json(TIME_PATH)
	var broken := table.duplicate()
	broken["time_wall_clock_1x"] = 100
	var schema_with_bounds := {
		"time_wall_clock_1x": {"type": "int", "bounds": [18, 30]},
	}
	var result := DataSchema.validate_table(broken, schema_with_bounds)
	assert_false(result.ok, "数值越界必须被 bound 拦下")
	assert_true(
		str(result.errors).contains("越界"),
		"越界错误须含 '越界' 字样",
	)


func test_missing_guardrail_fails() -> void:
	# 删掉一个数值键的护栏声明：validate_inline_bounds 必须红
	var table := DataLoader.load_json(TIME_PATH)
	var stripped := table.duplicate()
	var bounds: Dictionary = stripped[DataSchema.BOUNDS_KEY]
	bounds.erase("time_wall_clock_1x")
	stripped[DataSchema.BOUNDS_KEY] = bounds
	var result := (
		DataSchema
		. validate_inline_bounds(
			stripped,
			["time_wall_clock_1x", "time_week_per_year"],
		)
	)
	assert_false(result.ok, "数值键缺护栏声明必须失败（防改数不改护栏）")
	assert_true(
		str(result.errors).contains("time_wall_clock_1x"),
		"缺护栏错误须指明具体键",
	)


func test_missing_table_bounds_block_fails() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var stripped := table.duplicate()
	stripped.erase(DataSchema.BOUNDS_KEY)
	var result := DataSchema.validate_inline_bounds(stripped, ["time_week_per_year"])
	assert_false(result.ok, "整块 _bounds 缺失必须失败")
