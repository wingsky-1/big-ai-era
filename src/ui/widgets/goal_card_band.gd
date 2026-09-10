class_name GoalCardBand
extends Control
## L3 目标卡带（批7.2 #189；onboarding-spec B.1/B.2 目标卡行 + ui-ux A.1 主台
## 顶部固定带 + architecture §2.1 widgets/goal_card_view.gd 落位）。
## 只画 L2 下发 view（GameWorld.dashboard["goal_card"]），零业务计算/零读表
## （ADR-0016）：6 点进度 + 目标句 + "约再跑 X 周"。
## 全完成=空态收带（all_done=隐藏内容，B.2 空态"无未读目标卡"）。
## 触控：整带可点（≥48px 高），L3 消费 PanelStack.TARGET_CARD 详情弹层
## （z1，批7.2 最小=点击带即 open，详情渲染后续批）。

## 带体点击（#190：展开目标详情 z1 TARGET_CARD；装配方消费）
signal band_clicked

const MIN_BAND_HEIGHT: float = 48.0
## 周提示文案键（texts.json onb_week_hint="约再跑 X 周"；TextService 插值）
const WEEK_HINT_KEY: String = "onb_week_hint"

var _goal_key: String = ""
var _dot_container: HBoxContainer = null
var _dots: Array[Label] = []
var _sentence_label: Label = null
var _hint_label: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(0, MIN_BAND_HEIGHT)
	gui_input.connect(_on_gui_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_dot_container = HBoxContainer.new()
	_dot_container.add_theme_constant_override("separation", 4)
	row.add_child(_dot_container)
	_sentence_label = _make_label(16)
	row.add_child(_sentence_label)
	_hint_label = _make_label(14)
	row.add_child(_hint_label)


## 数据面刷新（装配方每周结/信号驱动调用；view=GameWorld dashboard goal_card）
func refresh(view: Dictionary) -> void:
	var all_done := bool(view.get("all_done", false))
	_goal_key = str(view.get("goal_key", ""))
	var total := int(view.get("total_steps", 6))
	# 6 点进度条（点亮=已完成格；L3 只画不解释）
	while _dots.size() < total:
		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 12)
		_dot_container.add_child(dot)
		_dots.append(dot)
	for i: int in _dots.size():
		_dots[i].visible = i < total
		if i < total:
			_dots[i].modulate = (
				Color(1, 1, 1) if i < int(view.get("completed_count", 0)) else Color(0.4, 0.4, 0.4)
			)
	# 空态（全完成）=隐藏内容只留带框（B.2 空态）
	_dot_container.visible = not all_done
	_sentence_label.visible = not all_done
	_hint_label.visible = not all_done
	if all_done:
		return
	# 文案经 TextService 翻译（键引用下发，L3 禁读表文件——ADR-0016）
	var goal_key := str(view.get("goal_key", ""))
	_sentence_label.text = TextService.text(goal_key) if not goal_key.is_empty() else ""
	var hint := int(view.get("weeks_hint", -1))
	_hint_label.text = (TextService.format(WEEK_HINT_KEY, {"X": str(hint)}) if hint >= 0 else "")


func get_goal_key() -> String:
	return _goal_key


func _on_gui_input(event: InputEvent) -> void:
	# 左键/触摸按下即开详情（整带可点 ≥48px；B.1 触控纪律）
	var is_click := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		is_click = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		is_click = (event as InputEventScreenTouch).pressed
	if is_click:
		band_clicked.emit()


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	return label
