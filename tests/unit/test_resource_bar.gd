extends GutTest
## #148 资源栏+预警横幅+竞对轻量入口验收 GUT（用例名=issue body 逐字）：
## - test_resource_bar_forecast：三主资源+净流入预告副行（负值文本通道非单色）
## - test_warning_banner_relief：预警横幅"本周亏 X 还能撑 X 周"+救济三键同屏
## - test_rival_light_entry：右上角无数字无红点，<10 只显档位标签
## 被测=src/ui/resource_bar/{resource_bar_view,rival_light_entry}.gd +
## dashboard_presenter 资源栏/竞对适配。数据面=注入式（L3 禁 import L2；L2 侧
## resources_changed 信号未落，#148 以测试发射器验证信号刷新路径——装配方接
## 真实信号同接口）。
## 真源=ui-ux B.2 资源行/预警行/竞对入口行 + economy-spec A.1/D.2（net inflow/
## warning/solvency）+ ui.json（ui_score_grade_threshold/ui_danger*）。

const UI_PATH: String = "res://src/data/ui.json"


## 测试发射器（模拟 L2 广播；#148 L2 信号未落，验收刷新路径用）
class TestEmitter:
	extends RefCounted

	signal changed(payload: Dictionary)

	func emit_changed() -> void:
		changed.emit({})


var _sim_data: Dictionary = {}
var _sim_score: float = -1.0


func before_each() -> void:
	_sim_data = {}
	_sim_score = -1.0


func _sim_resource_data(
	cash: int,
	influence: int,
	card_used: int,
	card_supply: int,
	weekly_net: int,
	warning_line: int,
	solvency_weeks: int,
	relief: Dictionary = {},
) -> Dictionary:
	return {
		"cash": cash,
		"influence": influence,
		"card_hours_used": card_used,
		"card_hours_supply": card_supply,
		"weekly_net": weekly_net,
		"warning_line": warning_line,
		"solvency_weeks": solvency_weeks,
		"relief": relief,
	}


## ===== 验收点 1：三主资源 + 净流入预告副行（负值文本通道非单色） =====
func test_resource_bar_forecast() -> void:
	var view := ResourceBarView.new()
	add_child_autofree(view)
	await get_tree().process_frame
	var emitter := TestEmitter.new()
	view.bind(
		func() -> Dictionary: return _sim_data,
		emitter,
		"changed",
	)
	_sim_data = _sim_resource_data(1200, 80, 23, 32, -45, 500, 10, {})
	emitter.emit_changed()
	# 三主资源
	assert_eq(view.get_cash_text(), "¥1200", "现金 ¥1200")
	assert_eq(view.get_influence_text(), "80", "影响力 80")
	assert_eq(view.get_card_hours_text(), "23/32", "卡时 23/32")
	# 净流入预告副行（负值文本通道非单色）
	assert_eq(view.get_forecast_text(), "下周净流入 ~-¥45", "净流入预告 ~-¥45（周净同源）")
	assert_true(view.is_forecast_negative(), "负值文本通道（非单色）")
	# 正值 → +¥ 且非负通道（信号驱动随查随新）
	_sim_data = _sim_resource_data(1200, 80, 23, 32, 45, 500, 99, {})
	emitter.emit_changed()
	assert_eq(view.get_forecast_text(), "下周净流入 ~+¥45", "净流入预告 ~+¥45")
	assert_false(view.is_forecast_negative(), "正值非负通道")
	# 副行折叠（B.5 副行第一折叠）：竖屏 FOLD_SUBROW=隐藏，横屏=显示
	view.apply_shape(LayoutPolicy.FOLD_SUBROW)
	assert_false(view.is_forecast_visible(), "竖屏副行折叠（第一折叠）")
	view.apply_shape(LayoutPolicy.FOLD_NONE)
	assert_true(view.is_forecast_visible(), "横屏副行常显")
	assert_eq(view.get_forecast_text(), "下周净流入 ~+¥45", "横屏副行内容在")


## ===== 验收点 2：现金<警告线"还能撑 X 周"+救济三键同屏 =====
func test_warning_banner_relief() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_eq(ResourceBarView.MIN_TOUCH, float(table["ui_touch_min"]), "可点下限镜像=表值")
	var view := ResourceBarView.new()
	add_child_autofree(view)
	await get_tree().process_frame
	var emitter := TestEmitter.new()
	view.bind(func() -> Dictionary: return _sim_data, emitter, "changed")
	_sim_data = _sim_resource_data(
		200,
		80,
		23,
		32,
		-45,
		500,
		4,
		{"loan_reason": "", "sell_reason": "没有可出售的设备", "job_reason": ""},
	)
	emitter.emit_changed()
	# 现金<警告线且周净为负 → 横幅亮 + 文案插值
	assert_true(view.is_warning_active(), "现金<警告线且亏钱=横幅亮")
	assert_eq(view.get_warning_text(), "本周亏 ¥45，还能撑 4 周", "横幅文案：本周亏 X 还能撑 X 周")
	assert_eq(view.get_relief_button_count(), 3, "救济三键同屏")
	for i: int in view.get_relief_button_count():
		var button: Button = view.get_relief_button(i)
		assert_true(
			button.custom_minimum_size.x >= 48.0 and button.custom_minimum_size.y >= 48.0,
			"救济键 %d 触控 ≥48×48" % i,
		)
	# 救济可用性：reason 空=启用；非空=置灰+原因
	assert_false(view.get_relief_button(0).disabled, "贷款键可用")
	assert_true(view.get_relief_button(1).disabled, "出售键置灰（无设备）")
	assert_eq(view.get_relief_reason(1), "没有可出售的设备", "置灰原因可查")
	# 非濒死（现金充足）→ 横幅隐（信号驱动）
	_sim_data = _sim_resource_data(5000, 80, 23, 32, 45, 500, 99, {})
	emitter.emit_changed()
	assert_false(view.is_warning_active(), "非濒死=横幅隐（不遮工作区）")


## ===== 验收点 3：竞对轻量入口——无数字无红点，<10 只显档位标签 =====
func test_rival_light_entry() -> void:
	var entry := RivalLightEntry.new()
	add_child_autofree(entry)
	await get_tree().process_frame
	var emitter := TestEmitter.new()
	entry.bind(func() -> float: return _sim_score, emitter, "changed")
	# 未出分（score<0）：纯图标（无数字无红点）
	_sim_score = -1.0
	emitter.emit_changed()
	assert_false(entry.has_grade_badge(), "未出分=纯图标（无数字无红点）")
	# <10：只显档位标签（起步档·榜外）
	_sim_score = 5.0
	emitter.emit_changed()
	assert_true(entry.has_grade_badge(), "<10 显档位标签")
	assert_eq(entry.get_grade_text(), TextService.text("ui_grade_0"), "5 分=起步档·榜外")
	# ≥10：不显数字不显标签（真值在周报/曲线面板）
	_sim_score = 50.0
	emitter.emit_changed()
	assert_false(entry.has_grade_badge(), "≥10 不显档位标签（轻量入口无数字）")
	assert_false(entry.get_visible_text().contains("50"), "入口可见文本零数字（无数字）")
	# 可点 ≥48px（触屏纪律）
	assert_true(
		entry.custom_minimum_size.x >= 48.0 and entry.custom_minimum_size.y >= 48.0,
		"入口触控 ≥48×48",
	)


## ===== 补充：presenter 档位分级纯适配 =====
func test_presenter_grade_tiering() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var thresholds: Array = table["ui_score_grade_threshold"]
	assert_eq(DashboardPresenter.GRADE_THRESHOLD.size(), thresholds.size(), "阈值镜像=表值")
	for i: int in thresholds.size():
		assert_almost_eq(
			float(DashboardPresenter.GRADE_THRESHOLD[i]),
			float(thresholds[i]),
			0.001,
			"阈值 %d 镜像=表值" % i,
		)
	# 分档边界：5→起步档榜外 / 10→新星档 / 30→中坚档 / 60→第一梯队 / 85→登顶档
	assert_eq(
		DashboardPresenter.rival_light_view(5.0)["grade_index"],
		0,
		"5 分=起步档·榜外（<10）",
	)
	assert_eq(
		DashboardPresenter.rival_light_view(10.0)["grade_index"],
		1,
		"10 分=新星档（边界 10 归新星）",
	)
	assert_eq(
		DashboardPresenter.rival_light_view(30.0)["grade_index"],
		2,
		"30 分=中坚档",
	)
	assert_eq(
		DashboardPresenter.rival_light_view(60.0)["grade_index"],
		3,
		"60 分=第一梯队",
	)
	assert_eq(
		DashboardPresenter.rival_light_view(85.0)["grade_index"],
		4,
		"85 分=登顶档",
	)
	assert_true(
		not DashboardPresenter.rival_light_view(-1.0)["show_badge"],
		"未出分不显档位标签",
	)
