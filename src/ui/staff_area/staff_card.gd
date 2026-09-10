class_name StaffCard
extends PanelContainer
## L3 员工卡（#147；staff-spec A.1 OP-STA-01/02 + ui-ux B.2 ui_staff_card 行）。
## 常显：名/岗位/状态色带+字样（色+文字双通道，色盲安全）/产出区间提示
## （状态数值带同源防两张皮）/在岗项目/协作角标（双人上桌 factor>1 浮现）。
## 卡可点=指派入口（OP-STA-01 ≤2 击；触屏纪律可点 ≥48px——横滑行单行卡高
## ≥48px 同源，staff-spec A.6/B.2）。消费 DashboardPresenter.staff_card_view
## （view 字典→界面字段，零业务计算）；本卡只做"字段→视觉"落位。
## 数值零硬编码=ui.json 表 token 的 L3 镜像常量（GUT 断言镜像=表值，双源漂移
## 防线同 #145/#146 惯例）；颜色不建 .tres（theme 文件批归 #147+ 统一收）。
## 硬约束：L3 禁读 L4/禁 import L2（仅注入适配字段）；零业务计算（ADR-0016）。

## 卡片点击（批7.3 #190：指派入口；装配方经 StaffAreaView 中继消费——
## headless 输入模拟不可用，测试经信号直发驱动）
signal card_clicked(staff_id: String)

## ---------- ui.json 镜像常量（GUT test_staff_card 断言与表值一致） ----------

const MIN_CARD_SIZE: float = 48.0  # ui_touch_min（可点目标/横滑行卡高下限）
const STATE_COLOR: Dictionary = {
	"focus": Color("#3B82F6"),
	"slacking": Color("#6B7280"),
	"inspired": Color("#D97706"),
}
const COLOR_INK_PANEL: Color = Color("#FFFFFF")
const COLOR_INK1: Color = Color("#1A1D24")
const COLOR_INK2: Color = Color("#4A5160")
const COLOR_INK3: Color = Color("#8A93A6")
const COLOR_ACCENT: Color = Color("#2563EB")

var _staff_id: String = ""
var _state_key: String = ""
var _name_label: Label
var _role_label: Label
var _state_band: ColorRect
var _state_label: Label
var _output_label: Label
var _assigned_label: Label
var _collab_badge: Label


func _init() -> void:
	custom_minimum_size = Vector2(0.0, MIN_CARD_SIZE)
	# Container 默认 PASS——卡本体需 STOP 吃点击（指派入口），防穿透空点
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	# 卡底：ink_panel + 8px 圆角 + 内边距（B.1 图形语言，同 #146 槽卡）
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_INK_PANEL
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel_style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	add_child(body)
	# 行1：姓名 + 协作角标
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	body.add_child(row1)
	_name_label = _make_label(14, COLOR_INK1)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_name_label)
	_collab_badge = _make_label(12, COLOR_ACCENT)
	row1.add_child(_collab_badge)
	# 行2：状态色带 + 状态字样（双通道）+ 岗位（右对齐）
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	body.add_child(row2)
	_state_band = ColorRect.new()
	_state_band.custom_minimum_size = Vector2(8.0, 8.0)
	row2.add_child(_state_band)
	_state_label = _make_label(12, COLOR_INK2)
	row2.add_child(_state_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)
	_role_label = _make_label(12, COLOR_INK3)
	row2.add_child(_role_label)
	# 行3：产出区间提示（状态数值带同源）
	_output_label = _make_label(12, COLOR_INK3)
	body.add_child(_output_label)
	# 行4：在岗项目
	_assigned_label = _make_label(12, COLOR_INK2)
	body.add_child(_assigned_label)


## 适配字段 → 卡面（presenter 单点适配；本卡只落位视觉）。
func refresh(fields: Dictionary) -> void:
	_staff_id = str(fields.get("id", ""))
	_state_key = str(fields.get("state_key", ""))
	_name_label.text = str(fields.get("name", ""))
	_role_label.text = str(fields.get("role_name", ""))
	# 状态带=色+文字双通道（色盲安全：专注=蓝+字样、摸鱼=灰、灵感=金）
	var state_color: Color = STATE_COLOR.get(_state_key, COLOR_INK2)
	_state_band.color = state_color
	_state_label.text = str(fields.get("state_name", ""))
	_state_label.add_theme_color_override("font_color", state_color)
	_output_label.text = str(fields.get("output_hint", ""))
	_output_label.visible = not str(fields.get("output_hint", "")).is_empty()
	_assigned_label.text = str(fields.get("assigned_text", ""))
	_assigned_label.visible = bool(fields.get("on_slot", false))
	_collab_badge.text = str(fields.get("collab_badge", ""))
	_collab_badge.visible = not str(fields.get("collab_badge", "")).is_empty()


## ---------- 数据面（测试/装配方读） ----------


func get_staff_id() -> String:
	return _staff_id


func get_name_text() -> String:
	return _name_label.text


func get_role_text() -> String:
	return _role_label.text


func get_state_key() -> String:
	return _state_key


func get_state_text() -> String:
	return _state_label.text


func get_state_color() -> Color:
	return _state_band.color


func get_output_hint_text() -> String:
	return _output_label.text


func get_assigned_text() -> String:
	return _assigned_label.text


func get_collab_badge_text() -> String:
	return _collab_badge.text


func get_card_height() -> float:
	return custom_minimum_size.y


## ---------- 私有 ----------


func _on_gui_input(event: InputEvent) -> void:
	# 左键/触摸按下即发射（Web/移动端触摸合成鼠标事件，双通道同入口）
	var is_click := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		is_click = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		is_click = (event as InputEventScreenTouch).pressed
	if is_click:
		card_clicked.emit(_staff_id)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
