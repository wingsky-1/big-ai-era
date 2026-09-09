extends GutTest
## #145 ui.json schema 断言（#128 data_schema 框架挂载）+ #146 增量
## （类型色/图标/0.5s 槽卡键/主题色板 token/空槽置灰强度）。
## 真源=ui-ux-spec.md D.2（ui_touch_min/ui_progress_visual/ui_anim_l1_dur
## 行护栏 + #146 新增行）；#149/#150 同文件增量显示分级/金框/toast 键。

const UI_PATH: String = "res://src/data/ui.json"

## 数值键全表（内嵌护栏 _bounds 声明检查；颜色/图标为字符串 token 无护栏）
const UI_NUMERIC_KEYS: Array[String] = [
	"ui_touch_min",
	"ui_touch_min_dot",
	"ui_progress_visual",
	"ui_anim_l1_dur",
	"ui_slot_refresh_dur",
	"ui_slot_finish_anim_dur",
	"ui_slot_empty_dim",
]

const UI_SCHEMA: Dictionary = {
	"ui_touch_min": {"type": "number"},
	"ui_touch_min_dot": {"type": "number"},
	"ui_progress_visual": {"type": "number"},
	"ui_anim_l1_dur": {"type": "number"},
	"ui_slot_refresh_dur": {"type": "number"},
	"ui_slot_finish_anim_dur": {"type": "number"},
	"ui_slot_empty_dim": {"type": "number"},
	"ui_ink_bg": {"type": "string"},
	"ui_ink_panel": {"type": "string"},
	"ui_ink1": {"type": "string"},
	"ui_ink2": {"type": "string"},
	"ui_ink3": {"type": "string"},
	"ui_accent": {"type": "string"},
	"ui_type_colors": {"type": "dict"},
	"ui_type_icons": {"type": "dict"},
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
		"ui_slot_refresh_dur",
		"ui_slot_finish_anim_dur",
		"ui_slot_empty_dim",
		"ui_ink_bg",
		"ui_ink_panel",
		"ui_ink1",
		"ui_ink2",
		"ui_ink3",
		"ui_accent",
		"ui_type_colors",
		"ui_type_icons",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "ui.json 键名拼写与真源一致: %s" % str(result.errors))


func test_ui_numeric_bounds_inline() -> void:
	# 内嵌护栏跟键走（architecture D6/ADR-0022）：数值键必带 _bounds 声明
	var table := DataLoader.load_json(UI_PATH)
	var result := DataSchema.validate_inline_bounds(table, UI_NUMERIC_KEYS)
	assert_true(result.ok, "ui.json 数值键全带内嵌护栏: %s" % str(result.errors))


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


func test_ui_slot_tokens_guardrails() -> void:
	# #146 槽卡 token（ui-ux B.2「完成顶入/入槽动画；0.5s 刷新」）：
	# 刷新/完成动画在 L1 轻量预算窗内（0.3–0.6s）；空槽置灰强度 ∈[0.3,0.8]
	var table := DataLoader.load_json(UI_PATH)
	assert_true(
		float(table["ui_slot_refresh_dur"]) >= 0.3 and float(table["ui_slot_refresh_dur"]) <= 0.6,
		"槽卡刷新预算 0.3–0.6s（L1 窗）",
	)
	assert_true(
		(
			float(table["ui_slot_finish_anim_dur"]) >= 0.3
			and float(table["ui_slot_finish_anim_dur"]) <= 0.6
		),
		"完成/入槽动画 0.3–0.6s（L1 窗）",
	)
	assert_true(
		float(table["ui_slot_empty_dim"]) >= 0.3 and float(table["ui_slot_empty_dim"]) <= 0.8,
		"空槽置灰强度 0.3–0.8（空态可见可辨）",
	)
	# 类型 token 双通道完整性：三类键齐、色为 hex、图标非空
	var colors: Dictionary = table["ui_type_colors"]
	var icons: Dictionary = table["ui_type_icons"]
	for type_key: String in ["paper", "model", "compute"]:
		assert_true(colors.has(type_key), "类型色 token 缺 %s" % type_key)
		assert_true(icons.has(type_key), "类型图标 token 缺 %s" % type_key)
		var color_text: String = str(colors[type_key])
		assert_true(color_text.begins_with("#"), "%s 类型色须为 hex 字符串" % type_key)
		assert_false(str(icons[type_key]).is_empty(), "%s 图标字非空" % type_key)
