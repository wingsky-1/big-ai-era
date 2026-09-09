extends GutTest
## #128 验收点 3：键名拼写自检（与 texts-keys/numerics-master/time-spec D.2 真源一致）。
## 机制：data_schema.validate_key_spelling 精确比对（缺/多余键都报）。

const TIME_PATH: String = "res://src/data/time.json"

## 真源键集合（time-spec D.2 公式与参数表行 + _bounds 内嵌护栏块）
const SOURCE_KEYS: Array[String] = [
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


func test_key_spelling_matches_source() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var result := DataSchema.validate_key_spelling(table, SOURCE_KEYS)
	assert_true(
		result.ok,
		"time.json 键名拼写与真源一致: %s" % str(result.errors),
	)


func test_spelling_detects_missing_key() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var broken := table.duplicate()
	broken.erase("time_wall_clock_1x")
	var result := DataSchema.validate_key_spelling(broken, SOURCE_KEYS)
	assert_false(result.ok, "删真源键必须被拼写自检发现")
	assert_true(str(result.errors).contains("time_wall_clock_1x"), "报错须指明缺的键")


func test_spelling_detects_typo_key() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var broken := table.duplicate()
	broken.erase("time_ritual_density")
	broken["time_ritual_densiti"] = 10  # 模拟键名拼错
	var result := DataSchema.validate_key_spelling(broken, SOURCE_KEYS)
	assert_false(result.ok, "键名拼错必须被拼写自检发现")
	assert_true(str(result.errors).contains("time_ritual_densiti"), "报错须指明多余键")
