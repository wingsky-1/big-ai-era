extends GutTest
## #128：DataLoader.load_validated 集成行为（读表 + schema 校验入口）。
## 错误分支显式消费 push_error（GUT 错误追踪纪律）。

const TIME_PATH: String = "res://src/data/time.json"

const TIME_SCHEMA: Dictionary = {
	"time_wall_clock_1x": {"type": "int"},
	"time_week_per_quarter": {"type": "int"},
	"time_week_per_year": {"type": "int"},
}


func test_load_validated_ok() -> void:
	var table := DataLoader.load_validated(TIME_PATH, TIME_SCHEMA)
	assert_false(table.is_empty(), "合法表 load_validated 返回数据")
	assert_true(table.has("time_wall_clock_1x"), "返回表含数值键")


func test_load_validated_rejects_broken_table() -> void:
	# 缺必需键 → 校验失败 → 返回空表 + push_error
	var broken_schema := {
		"time_week_per_year": {"type": "int"},
		"nonexistent_key_xyz": {"type": "int"},
	}
	var table := DataLoader.load_validated(TIME_PATH, broken_schema)
	assert_true(table.is_empty(), "schema 不过时返回空表（熔断防脏数据入玩法）")
	assert_push_error("缺必需键", "应有明确缺失键错误")


func test_load_json_missing_file_errors() -> void:
	var table := DataLoader.load_json("res://src/data/不存在.json")
	assert_true(table.is_empty(), "缺文件返回空字典")
	assert_push_error("文件不存在", "缺文件须报错（消费错误分支）")
