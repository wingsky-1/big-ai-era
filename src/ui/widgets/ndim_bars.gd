class_name NdimBars
extends VBoxContainer
## L3 n 维条形图（#150；ui-ux B.1「n 维画像=条形图（竖屏主形态，P1 定稿条形）」
## + B.2 论文/模型 n 维揭晓「0.2s/维串行动效」+ G14 条形主形态）。
## 数值+条形双通道（色盲友好：数值文本永远可见，条形=占比）；逐条揭晓=
## reveal_next() 每维 0.2s（ui_ndim_reveal_dur 镜像；时序由装配方/测试驱动，
## 本控件只提供确定性揭晓状态机）。
## 消费注入的条形数据（Array[{label, value}]，presenter 由 L2 ndim 视图转换；
## L3 禁读 L4/禁 import L2，零业务计算（ADR-0016））。
## 数值零硬编码=ui.json 表 token 的 L3 镜像常量（GUT 断言镜像=表值）。

## ---------- ui.json 镜像常量（GUT test_ndim_bars_reveal 断言与表值一致） ----------

const REVEAL_DUR: float = 0.2  # ui_ndim_reveal_dur（逐条揭晓 0.2s/维串行）
const COLOR_ACCENT: Color = Color("#2563EB")
const COLOR_INK1: Color = Color("#1A1D24")
const COLOR_INK2: Color = Color("#4A5160")
const MAX_BAR_RATIO: float = 1.0  # 条形占比上限（值域归一由 L2 出数）

var _bar_rows: Array = []  # [{label, value, bar, value_label}]
var _revealed_count: int = 0


func _init() -> void:
	add_theme_constant_override("separation", 6)


## 装载条形数据（重置揭晓态；bars=Array[{label:String, value:float}]）。
func set_bars(bars: Array) -> void:
	_bar_rows = []
	var max_value := 0.0
	for bar_variant: Variant in bars:
		var bar: Dictionary = bar_variant
		max_value = maxf(max_value, float(bar.get("value", 0.0)))
	for bar_variant: Variant in bars:
		var bar: Dictionary = bar_variant
		var label := str(bar.get("label", ""))
		var value := float(bar.get("value", 0.0))
		var ratio := 0.0
		if max_value > 0.0:
			ratio = clampf(value / max_value, 0.0, MAX_BAR_RATIO)
		_bar_rows.append({"label": label, "value": value, "ratio": ratio})
	_revealed_count = 0
	_rebuild()


## 揭晓一步（逐条跳动；0.2s/维——时序由装配方按 REVEAL_DUR 驱动）。
func reveal_next() -> bool:
	if _revealed_count >= _bar_rows.size():
		return false
	_revealed_count += 1
	_rebuild()  # 重建行（后续批可换 tween 过渡：本控件只保证状态机确定性）
	return true


## ---------- 数据面（测试/装配方读） ----------


func get_bar_count() -> int:
	return _bar_rows.size()


func get_bar_label(index: int) -> String:
	if index < 0 or index >= _bar_rows.size():
		return ""
	return str(_bar_rows[index]["label"])


func get_bar_value(index: int) -> float:
	if index < 0 or index >= _bar_rows.size():
		return 0.0
	return float(_bar_rows[index]["value"])


func is_bar_revealed(index: int) -> bool:
	return index < _revealed_count


func get_revealed_count() -> int:
	return _revealed_count


func get_reveal_duration() -> float:
	return REVEAL_DUR


## ---------- 私有 ----------


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	for i: int in _bar_rows.size():
		var row: Dictionary = _bar_rows[i]
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		add_child(box)
		var label := Label.new()
		label.text = str(row["label"])
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", COLOR_INK2)
		label.custom_minimum_size = Vector2(72.0, 0.0)
		box.add_child(label)
		var track := ProgressBar.new()
		track.custom_minimum_size = Vector2(0.0, 10.0)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLOR_ACCENT
		fill.set_corner_radius_all(5)
		track.add_theme_stylebox_override("fill", fill)
		track.value = float(row["ratio"]) * 100.0
		box.add_child(track)
		var value_label := Label.new()
		value_label.text = str(round(float(row["value"])))
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", COLOR_INK1)
		box.add_child(value_label)
		var revealed := i < _revealed_count
		box.visible = revealed
