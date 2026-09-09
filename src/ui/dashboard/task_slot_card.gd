class_name TaskSlotCard
extends PanelContainer
## L3 任务槽卡（#146；ui-ux-spec B.2 ui_task_slot_card 行 + B.3 第一视觉）。
## 每槽一卡：类型色+图标（双通道）+标题+进度条主视觉（12px 横贯卡底、颜色随
## 类型）+预计结账 Wx+上桌位+协作角标；空槽=置灰空态句（A.5 空态≠禁用隐藏）；
## 完成=完成句+顶入动画（B.2「完成顶入/入槽动画；0.5s 刷新」）。
## 消费 DashboardPresenter.slot_card_view（view 字典→界面字段，零业务计算）；
## 本卡只做"字段→视觉"落位（颜色/图标/显隐/动画），零计算零读表。
## 数值零硬编码=ui.json 表 token 的 L3 镜像常量（GUT 断言镜像=表值，双源漂移
## 防线同 MainScene.MIN_TOUCH 惯例；颜色不建 .tres——#145 起新 UI 镜像常量，
## theme 文件批归 #147+ 统一收）；进度条=只读非交互（触屏纪律）。
## 硬约束：L3 禁读 L4/禁 import L2（仅注入 view 字典）；零业务计算（ADR-0016）。

## ---------- ui.json 镜像常量（GUT test_task_slot_card 断言与表值一致） ----------

const PROGRESS_BAR_H: float = 12.0  # ui_progress_visual（10-14 窗）
const FINISH_ANIM_DUR: float = 0.5  # ui_slot_finish_anim_dur（完成/入槽顶入动画）
const EMPTY_DIM: float = 0.55  # ui_slot_empty_dim（空槽置灰强度）
const TYPE_COLOR: Dictionary = {
	CoreEnums.ProjectType.PAPER: Color("#7C3AED"),
	CoreEnums.ProjectType.MODEL: Color("#2563EB"),
	CoreEnums.ProjectType.COMPUTE: Color("#0D9488"),
}
const TYPE_ICON: Dictionary = {
	CoreEnums.ProjectType.PAPER: "文",
	CoreEnums.ProjectType.MODEL: "训",
	CoreEnums.ProjectType.COMPUTE: "算",
}
const COLOR_INK_PANEL: Color = Color("#FFFFFF")
const COLOR_INK1: Color = Color("#1A1D24")
const COLOR_INK2: Color = Color("#4A5160")
const COLOR_INK3: Color = Color("#8A93A6")
const COLOR_INK_BG: Color = Color("#F7F8FA")
const COLOR_ACCENT: Color = Color("#2563EB")

var _type_chip: Label
var _title: Label
var _eta: Label
var _seat: Label
var _collab_badge: Label
var _state_text: Label
var _progress_bar: ProgressBar
var _fill_style: StyleBoxFlat
var _track_style: StyleBoxFlat
var _state: int = CoreEnums.ProjectState.EMPTY
var _type: int = DashboardPresenter.EMPTY_SLOT_TYPE
var _anim_state: String = "idle"


func _init() -> void:
	# 卡底：ink_panel + 8px 圆角 + 内边距（B.1 图形语言）
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_INK_PANEL
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel_style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	add_child(body)
	# 行1：类型 chip + 标题（拉伸占位）+ 协作角标
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	body.add_child(row1)
	_type_chip = _make_label(12, COLOR_INK2)
	row1.add_child(_type_chip)
	_title = _make_label(14, COLOR_INK1)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_title)
	_collab_badge = _make_label(12, COLOR_ACCENT)
	row1.add_child(_collab_badge)
	# 行2：上桌位 + 预计结账/状态句（右对齐）
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	body.add_child(row2)
	_seat = _make_label(12, COLOR_INK3)
	row2.add_child(_seat)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)
	_eta = _make_label(12, COLOR_INK2)
	row2.add_child(_eta)
	_state_text = _make_label(12, COLOR_INK3)
	row2.add_child(_state_text)
	# 卡底：进度条主视觉（12px 横贯，颜色随类型；轨道=ink_bg）
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0.0, PROGRESS_BAR_H)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.show_percentage = false
	_track_style = StyleBoxFlat.new()
	_track_style.bg_color = COLOR_INK_BG
	_track_style.set_corner_radius_all(6)
	_progress_bar.add_theme_stylebox_override("background", _track_style)
	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(6)
	_progress_bar.add_theme_stylebox_override("fill", _fill_style)
	body.add_child(_progress_bar)
	# 初始空态
	refresh({})


## 槽 view → 卡面刷新（字段经 presenter 单点适配；本卡只落位视觉）。
func refresh(view: Dictionary) -> void:
	var fields := DashboardPresenter.slot_card_view(view)
	_state = int(fields["state"])
	_type = int(fields["type"])
	var has_project: bool = _state != CoreEnums.ProjectState.EMPTY
	var type_color: Color = TYPE_COLOR.get(_type, COLOR_INK2)
	var type_icon: String = str(TYPE_ICON.get(_type, ""))
	var type_label: String = str(fields["type_label"])
	_type_chip.text = "%s%s" % [type_icon, type_label]
	_type_chip.add_theme_color_override("font_color", type_color)
	_type_chip.visible = has_project and not type_label.is_empty()
	_title.text = str(fields["title_text"])
	_title.visible = has_project
	_seat.text = str(fields["seat_text"])
	_seat.visible = not str(fields["seat_text"]).is_empty()
	_eta.text = str(fields["eta_text"])
	_eta.visible = not str(fields["eta_text"]).is_empty()
	_state_text.text = str(fields["state_text"])
	_state_text.visible = not str(fields["state_text"]).is_empty()
	_collab_badge.text = str(fields["collab_badge"])
	_collab_badge.visible = not str(fields["collab_badge"]).is_empty()
	_fill_style.bg_color = type_color
	_progress_bar.value = float(fields["progress"]) * 100.0
	_progress_bar.visible = has_project
	# 空槽置灰（A.5 空态可见可辨）；有项目=全亮
	modulate.a = EMPTY_DIM if not has_project else 1.0


## 完成顶入动画（0.5s：缩放弹入，透明度不动——完成卡保持全亮）。
func play_finish_anim() -> void:
	_run_pop(false)


## 入槽动画（0.5s：缩放弹入 + 淡入——空槽置灰→全亮过渡）。
func play_pop_anim() -> void:
	_run_pop(true)


func _run_pop(fade_in: bool) -> void:
	_anim_state = "finish" if not fade_in else "pop"
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, FINISH_ANIM_DUR).from(Vector2(0.9, 0.9))
	if fade_in:
		tween.parallel().tween_property(self, "modulate:a", 1.0, FINISH_ANIM_DUR).from(0.0)
	tween.finished.connect(_on_pop_finished)


func _on_pop_finished() -> void:
	_anim_state = "idle"
	scale = Vector2.ONE


## ---------- 数据面（测试/装配方读：当前卡面呈现状态） ----------


func get_state() -> int:
	return _state


func get_type_chip_text() -> String:
	return _type_chip.text


func get_type_color() -> Color:
	var value: Variant = TYPE_COLOR.get(_type)
	return value as Color if value is Color else COLOR_INK2


func get_type_icon_text() -> String:
	return str(TYPE_ICON.get(_type, ""))


func get_eta_text() -> String:
	return _eta.text


func get_seat_text() -> String:
	return _seat.text


func get_collab_badge_text() -> String:
	return _collab_badge.text


func get_state_text() -> String:
	return _state_text.text


func get_progress_value() -> float:
	return float(_progress_bar.value) / 100.0


func get_progress_bar_height() -> float:
	return _progress_bar.custom_minimum_size.y


func is_progress_full_width() -> bool:
	return _progress_bar.size_flags_horizontal == Control.SIZE_EXPAND_FILL


func get_anim_duration() -> float:
	return FINISH_ANIM_DUR


func get_anim_state() -> String:
	return _anim_state


## ---------- 私有 ----------


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
