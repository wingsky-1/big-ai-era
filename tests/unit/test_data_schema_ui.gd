extends GutTest
## #145 ui.json schema 断言（#128 data_schema 框架挂载）：键名/类型 +
## 结构自检（触控 48/24 硬约束、进度条主视觉高 10-14、L1 动画 ≤0.6s）。
## 真源=ui-ux-spec.md D.2（ui_touch_min/ui_progress_visual/ui_anim_l1_dur
## 行护栏）；#149/#150 同文件增量显示分级/金框/toast 键。

const UI_PATH: String = "res://src/data/ui.json"

const UI_SCHEMA: Dictionary = {
	"ui_touch_min": {"type": "number"},
	"ui_touch_min_dot": {"type": "number"},
	"ui_progress_visual": {"type": "number"},
	"ui_anim_l1_dur": {"type": "number"},
}


func test_ui_schema_valid() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_false(table.is_empty(), "ui.json 可加载")
	var result := DataSchema.validate_table(table, UI_SCHEMA)
	assert_true(result.ok, "ui.json schema 校验全过: %s" % str(result.errors))


func test_ui_key_spelling_matches_source() -> void:
	# 键名拼写自检（#128 机制）；真源=ui-ux-spec D.2
	var table := DataLoader.load_json(UI_PATH)
	var expected: Array[String] = [
		"ui_touch_min",
		"ui_touch_min_dot",
		"ui_progress_visual",
		"ui_anim_l1_dur",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "ui.json 键名拼写与真源一致: %s" % str(result.errors))


func test_ui_touch_guardrails() -> void:
	# 触控纪律（ui-ux B.5/触屏纪律）：可点 ≥48px；灰点例外 ≥24px
	var table := DataLoader.load_json(UI_PATH)
	assert_true(float(table["ui_touch_min"]) >= 48.0, "ui_touch_min ≥48（可点目标硬约束）")
	assert_true(
		float(table["ui_touch_min_dot"]) < float(table["ui_touch_min"]),
		"灰点触区 < 常规可点（24<48 例外语义）",
	)
	assert_true(float(table["ui_touch_min_dot"]) >= 24.0, "灰点触区 ≥24（例外下限）")
	# 进度条主视觉高 ∈[10,14]（第一视觉规格）
	var bar_h := float(table["ui_progress_visual"])
	assert_true(bar_h >= 10.0 and bar_h <= 14.0, "进度条主视觉高 10-14")
	# L1 动画 ≤0.6s（反馈不拖沓）
	assert_true(float(table["ui_anim_l1_dur"]) <= 0.6, "L1 动画 ≤0.6s")
