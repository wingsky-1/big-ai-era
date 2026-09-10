class_name ZPanel
extends PanelContainer
## L3 面板统一壳（批7.3 #190）：标题行+关闭钮+内容区+页脚反馈行的样板收口，
## 六个 z1/z2 面板实体继承本类只填 _build_body（ui-ux A.2 z1 面板最小形态，
## 防每面板重复标题/关闭/反馈三件套）。文案经 TextService 键引用（L3 禁读
## 表文件，ADR-0016）；零业务计算；触控下限对齐 MIN_TOUCH（可点目标 ≥48px）。

## 关闭请求（装配方消费：栈回退+遮罩收起；z2 阻塞面板隐藏关闭钮不发射）
signal close_requested

## ---------- 颜色镜像（同 staff_card 图形语言；theme 收口归 #147+ 批） ----------

const COLOR_INK_PANEL: Color = Color("#FFFFFF")
const COLOR_INK1: Color = Color("#1A1D24")
const COLOR_INK3: Color = Color("#8A93A6")
const COLOR_ACCENT: Color = Color("#2563EB")
const COLOR_DANGER: Color = Color("#DC2626")
const COLOR_OK: Color = Color("#16A34A")

## 可点目标下限（ui_touch_min 48 镜像；与 MainScene.MIN_TOUCH 同源口径）
const MIN_TOUCH: float = 48.0

var _title_label: Label
var _close_button: Button
var _body: VBoxContainer
var _footer_label: Label


func _init() -> void:
	# 面板根 STOP：面板内点击不穿透到遮罩（防"点面板=点外"误关）
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INK_PANEL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(340.0, 0.0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	vbox.add_child(_build_header())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	vbox.add_child(_body)
	_footer_label = _make_label(13, COLOR_DANGER)
	_footer_label.visible = false
	vbox.add_child(_footer_label)
	_build_body(_body)


## 子类唯一扩展点：往内容区填控件（标题/关闭/页脚由壳统一持有）
func _build_body(_body_box: VBoxContainer) -> void:
	pass


func set_title(text: String) -> void:
	_title_label.text = text


## 页脚反馈（拒绝原因/结果提示；danger=红色警示，否则绿色成功）
func set_footer(text: String, ok: bool = false) -> void:
	_footer_label.text = text
	_footer_label.add_theme_color_override("font_color", COLOR_OK if ok else COLOR_DANGER)
	_footer_label.visible = not text.is_empty()


func clear_footer() -> void:
	_footer_label.visible = false


## 关闭钮显隐（z2 阻塞面板=无关闭路径，强迫处理）
func set_close_visible(visible_now: bool) -> void:
	_close_button.visible = visible_now


func get_body() -> VBoxContainer:
	return _body


## ---------- 子类共享控件工厂 ----------


## 统一按钮（触控 ≥48 高 + 字号 14；面板行/确认钮同款防两套规格）
func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	button.add_theme_font_size_override("font_size", 14)
	return button


## 域小节标题（灰字小号）
func make_section_label(text: String) -> Label:
	var label := _make_label(13, COLOR_INK3)
	label.text = text
	return label


## ---------- 私有 ----------


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_title_label = _make_label(16, COLOR_INK1)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title_label)
	_close_button = make_button("×")
	_close_button.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_close_button)
	return row


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
