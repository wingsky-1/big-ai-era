class_name RivalLightEntry
extends Button
## L3 竞对轻量入口（#148；OP-UX-04：右上角小图标，无数字无红点）。
## score<10 只显档位标签（ui_grade_0 起步档·榜外）；≥10 无标签不显数字（真值
## 在周报/曲线面板，周报恒显）；未出分（score<0）不渲染标签。可点 ≥48px（触屏
## 纪律）；按下=装配方接 pressed 信号开 RIVAL_CURVE 面板（面板批 #148+ 接）。
## 数据面注入=score_source（Callable→float，玩家当前最佳分数；-1=未出分）。
## 消费 DashboardPresenter.rival_light_view（档位分级=ui_score_grade_threshold
## 镜像，仅显示口径与 SOTA 守卫带不冲突）。
## 数值零硬编码=ui.json 表 token 的 L3 镜像常量（GUT 断言镜像=表值）。

## ---------- ui.json 镜像常量（GUT test_rival_light_entry 断言与表值一致） ----------

const MIN_TOUCH: float = 48.0  # ui_touch_min（可点目标）
const COLOR_INK2: Color = Color("#4A5160")
const ICON_TEXT: String = "竞"

var _icon_label: Label
var _grade_label: Label
var _score_source: Callable = Callable()
var _emitter: Object = null
var _signal_name: String = ""
var _grade_text: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_icon_label = Label.new()
	_icon_label.text = ICON_TEXT
	_icon_label.add_theme_font_size_override("font_size", 16)
	_icon_label.add_theme_color_override("font_color", COLOR_INK2)
	box.add_child(_icon_label)
	_grade_label = Label.new()
	_grade_label.add_theme_font_size_override("font_size", 12)
	_grade_label.add_theme_color_override("font_color", COLOR_INK2)
	box.add_child(_grade_label)


## 绑定分数源（装配方/测试调用；score_source 返回 float，-1=未出分）。
func bind(score_source: Callable, emitter: Object, signal_name: String) -> void:
	if _emitter != null and not _signal_name.is_empty():
		if _emitter.is_connected(_signal_name, _on_changed):
			_emitter.disconnect(_signal_name, _on_changed)
	_score_source = score_source
	_emitter = emitter
	_signal_name = signal_name
	if emitter != null and not signal_name.is_empty():
		if emitter.has_signal(signal_name):
			emitter.connect(signal_name, _on_changed)
	refresh_now()


## 立即按当前分数源刷新（同帧）。
func refresh_now() -> void:
	if not _score_source.is_valid():
		return
	var score := float(_score_source.call())
	var fields := DashboardPresenter.rival_light_view(score)
	_grade_text = str(fields["grade_text"])
	# 轻量入口=无数字无红点：<10 只显档位标签，≥10/未出分=纯图标
	_grade_label.text = _grade_text
	_grade_label.visible = bool(fields["show_badge"])


func _on_changed(_payload: Variant) -> void:
	refresh_now()


## ---------- 数据面（测试/装配方读） ----------


func get_grade_text() -> String:
	return _grade_text


func has_grade_badge() -> bool:
	return not _grade_text.is_empty() and _grade_label.visible


func get_icon_text() -> String:
	return _icon_label.text


## 当前可见文本（图标+档位标签；测试"无数字"断言语义：数字从不进入口文本）
func get_visible_text() -> String:
	return _icon_label.text + (_grade_label.text if _grade_label.visible else "")
