class_name TargetCardPanel
extends ZPanel
## L3 目标卡详情 z1（批7.3 #190）：GoalCardBand 点击 → open（TARGET_CARD
## 栈位）→ 渲染目标句+详情句+周数提示（dashboard["goal_card"] view 同源，
## 零二次计算）。文案=goal_key/detail_key 透传 TextService；onb_week_hint
## 插值（<X> 周数）。硬约束：零业务计算；B.2 空态=全完成显示无目标句。

const WEEK_HINT_KEY: String = "onb_week_hint"

var _get_dashboard: Callable = Callable()
var _detail_label: Label
var _hint_label: Label


func bind(get_dashboard: Callable) -> void:
	_get_dashboard = get_dashboard


func _build_body(body_box: VBoxContainer) -> void:
	set_title(TextService.text("ui_more"))
	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", COLOR_INK3)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(280.0, 0.0)
	body_box.add_child(_detail_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", COLOR_ACCENT)
	body_box.add_child(_hint_label)


## 打开/刷新（目标卡 view 全量重读）
func refresh() -> void:
	if not _get_dashboard.is_valid():
		return
	var goal: Dictionary = _get_dashboard.call().get("goal_card", {})
	if bool(goal.get("all_done", false)):
		_detail_label.text = TextService.text("model_library_empty")
		_hint_label.text = ""
		return
	_detail_label.text = TextService.text(str(goal.get("detail_key", "")))
	var hint := int(goal.get("weeks_hint", -1))
	_hint_label.text = (TextService.format(WEEK_HINT_KEY, {"X": str(hint)}) if hint >= 0 else "")
