class_name WeeklyReportDialog
extends PanelContainer
## L3 周报弹层/归档同构渲染器（#149；ui-ux B.2 ui_report_dual 行 + A.3
## OP-UX-03「归档重看=同构渲染」）。同一 render(view) 供 z2 自动弹（弹层）与
## z1 归档重看（同数据源同构）：行序=RowKind 秩（账本→事件→竞对→仪式），
## 显著行=强调高亮（A.3「显著行瞬时高亮」），平淡周=无数字无色无音效（灰点
## 语义由 ReportDual 承载，本渲染器只画 view 内容）。
## 消费注入的 report view 字典（L2 出数，L3 只画，ADR-0016）；零业务计算。
## 硬约束：L3 禁读 L4/禁 import L2——本类不引 WeeklyReport，行文本已在 L2
## 格式化完毕（view.rows[].text），本类只落位显示。
const KEY_REPORT_TITLE: String = "ui_report_title"

const COLOR_INK1: Color = Color("#1A1D24")
const COLOR_INK2: Color = Color("#4A5160")
const COLOR_ACCENT: Color = Color("#2563EB")

var _title_label: Label
var _rows_box: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(300.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#FFFFFF")
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", panel_style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", COLOR_INK1)
	body.add_child(_title_label)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	body.add_child(_rows_box)


## 渲染周报 view（自动弹/归档共用；重复 render=清旧行重建）。
func render(report_view: Dictionary) -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.free()
	var week: int = int(report_view.get("week", 0))
	_title_label.text = TextService.format(KEY_REPORT_TITLE, {"周数": str(week)})
	var rows: Array = report_view.get("rows", [])
	for row_variant: Variant in rows:
		var row: Dictionary = row_variant
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		var significant := bool(row.get("significant", false))
		# 显著行=强调高亮（A.3「显著行瞬时高亮」）；平淡行=次级色
		label.add_theme_color_override("font_color", COLOR_ACCENT if significant else COLOR_INK2)
		label.text = str(row.get("text", ""))
		label.set_meta("significant", significant)
		_rows_box.add_child(label)


## ---------- 数据面（测试/归档同构断言用） ----------


func get_title_text() -> String:
	return _title_label.text


func get_row_count() -> int:
	return _rows_box.get_child_count()


func get_row_text(index: int) -> String:
	var label := _rows_box.get_child(index) as Label
	return label.text if label != null else ""


func get_row_significant(index: int) -> bool:
	var label := _rows_box.get_child(index) as Label
	if label == null:
		return false
	return bool(label.get_meta("significant", false))
