class_name ResourceBarView
extends VBoxContainer
## L3 资源栏（#148；ui-ux A.1 资源栏 + B.2 资源行/预警行 + economy-spec A.1）。
## 三主资源（现金/影响力/卡时）+净流入预告副行（负值文本通道非单色）+
## 预警横幅（现金<警告线且周净为负："本周亏 X 还能撑 X 周"+救济三键 ≥48px 同屏）。
## 数据面注入=data_source（Callable→资源栏聚合 dict，装配方组 L2 视图）+变更
## 信号（Object 鸭子连接，L3 禁 import L2）；副行折叠=apply_shape(FOLD_SUBROW)
## （B.5「副行第一折叠」：竖屏单行折叠副行；判定由 MainScene 按 LayoutPolicy 下发）。
## 消费 DashboardPresenter.resource_bar_view（零业务计算，ADR-0016）。
## 数值零硬编码=ui.json 表 token 的 L3 镜像常量（GUT 断言镜像=表值）。

## ---------- ui.json 镜像常量（GUT test_resource_bar 断言与表值一致） ----------

const MIN_TOUCH: float = 48.0  # ui_touch_min（救济三键可点/横幅同屏）
const COLOR_INK1: Color = Color("#1A1D24")
const COLOR_INK2: Color = Color("#4A5160")
const COLOR_INK3: Color = Color("#8A93A6")
const COLOR_DANGER: Color = Color("#DC2626")  # ui_danger（负值/预警文本通道）
const COLOR_DANGER_BG: Color = Color("#FEF2F2")  # ui_danger_bg（预警横幅浅底）
## 救济三键文案键（economy-spec 救济行；标题键复用为按键标签）
const RELIEF_BUTTON_KEYS: Array[String] = [
	"eco_loan_title",
	"eco_sell_title",
	"eco_job_title",
]
const RELIEF_REASON_KEYS: Array[String] = [
	"loan_reason",
	"sell_reason",
	"job_reason",
]

var _cash_label: Label
var _influence_label: Label
var _card_hours_label: Label
var _forecast_label: Label
var _banner: PanelContainer
var _warning_label: Label
var _relief_buttons: Array[Button] = []
var _data_source: Callable = Callable()
var _emitter: Object = null
var _signal_name: String = ""
var _forecast_negative: bool = false
var _last_relief: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 4)
	# 行1：三主资源（资金 ¥X · 影响力 X · 卡时 23/32）
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	add_child(row1)
	_cash_label = _make_value_label(COLOR_INK1)
	row1.add_child(_cash_label)
	_influence_label = _make_value_label(COLOR_INK1)
	row1.add_child(_influence_label)
	_card_hours_label = _make_value_label(COLOR_INK1)
	row1.add_child(_card_hours_label)
	var row1_spacer := Control.new()
	row1_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(row1_spacer)
	# 行2：净流入预告副行（副行第一折叠，B.5）
	_forecast_label = _make_value_label(COLOR_INK3)
	add_child(_forecast_label)
	# 行3：预警横幅（通栏于资源栏下，不遮工作区）+ 救济三键
	_banner = PanelContainer.new()
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = COLOR_DANGER_BG  # 危险浅底（B.1 danger 语义浅通道）
	banner_style.set_corner_radius_all(6)
	banner_style.set_content_margin_all(6)
	_banner.add_theme_stylebox_override("panel", banner_style)
	add_child(_banner)
	var banner_box := VBoxContainer.new()
	banner_box.add_theme_constant_override("separation", 4)
	_banner.add_child(banner_box)
	_warning_label = _make_value_label(COLOR_DANGER)
	banner_box.add_child(_warning_label)
	var relief_row := HBoxContainer.new()
	relief_row.add_theme_constant_override("separation", 8)
	banner_box.add_child(relief_row)
	for i: int in RELIEF_BUTTON_KEYS.size():
		var button := Button.new()
		button.text = TextService.text(RELIEF_BUTTON_KEYS[i])
		button.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
		_relief_buttons.append(button)
		relief_row.add_child(button)


## 绑定数据面（装配方/测试调用；重复绑定=先断开旧信号）。
func bind(data_source: Callable, emitter: Object, signal_name: String) -> void:
	if _emitter != null and not _signal_name.is_empty():
		if _emitter.is_connected(_signal_name, _on_changed):
			_emitter.disconnect(_signal_name, _on_changed)
	_data_source = data_source
	_emitter = emitter
	_signal_name = signal_name
	if emitter != null and not signal_name.is_empty():
		if emitter.has_signal(signal_name):
			emitter.connect(signal_name, _on_changed)
	refresh_now()


## 立即按当前数据源刷新（同帧；信号驱动随查随新）。
func refresh_now() -> void:
	if not _data_source.is_valid():
		return
	var data: Dictionary = _data_source.call()
	var fields := DashboardPresenter.resource_bar_view(data)
	_cash_label.text = str(fields["cash_text"])
	_influence_label.text = str(fields["influence_text"])
	_card_hours_label.text = str(fields["card_hours_text"])
	_forecast_label.text = str(fields["forecast_text"])
	# 负值文本通道（非单色）：净流入为负=危险红
	_forecast_negative = bool(fields["forecast_negative"])
	_forecast_label.add_theme_color_override(
		"font_color", COLOR_DANGER if _forecast_negative else COLOR_INK3
	)
	var warning_active: bool = bool(fields["warning_active"])
	_banner.visible = warning_active
	if warning_active:
		_warning_label.text = str(fields["warning_text"])
	_last_relief = data.get("relief", {}) if data.has("relief") else {}
	for i: int in _relief_buttons.size():
		var reason: String = str(_last_relief.get(RELIEF_REASON_KEYS[i], ""))
		_relief_buttons[i].disabled = not reason.is_empty()


func _on_changed(_payload: Variant) -> void:
	refresh_now()


## 副行折叠形态下发（B.5：副行第一折叠；判定在 MainScene/LayoutPolicy）。
func apply_shape(fold: String) -> void:
	_forecast_label.visible = fold != LayoutPolicy.FOLD_SUBROW


## ---------- 数据面（测试/装配方读） ----------


func get_cash_text() -> String:
	return _cash_label.text


func get_influence_text() -> String:
	return _influence_label.text


func get_card_hours_text() -> String:
	return _card_hours_label.text


func get_forecast_text() -> String:
	return _forecast_label.text


func is_forecast_visible() -> bool:
	return _forecast_label.visible


func is_forecast_negative() -> bool:
	return _forecast_negative


func is_warning_active() -> bool:
	return _banner.visible


func get_warning_text() -> String:
	return _warning_label.text


func get_relief_button(index: int) -> Button:
	if index < 0 or index >= _relief_buttons.size():
		return null
	return _relief_buttons[index]


func get_relief_reason(index: int) -> String:
	if index < 0 or index >= RELIEF_REASON_KEYS.size():
		return ""
	return str(_last_relief.get(RELIEF_REASON_KEYS[index], ""))


func get_relief_button_count() -> int:
	return _relief_buttons.size()


## ---------- 私有 ----------


func _make_value_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	return label
