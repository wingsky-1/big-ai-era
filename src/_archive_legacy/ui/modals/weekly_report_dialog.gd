class_name WeeklyReportDialog
extends PanelContainer

## 周报弹窗（支持自动弹 z2 阻塞与重看 z1 常规双挂载）

signal confirmed

var _report_data: Dictionary = {}

@onready var title_label: Label = %TitleLabel
@onready var rows_vbox: VBoxContainer = %RowsVBox
@onready var confirm_btn: Button = %ConfirmBtn


func setup(report_data: Dictionary) -> void:
	_report_data = report_data
	if is_inside_tree():
		_render()


func _ready() -> void:
	ModalSizing.apply(self)
	confirm_btn.pressed.connect(func() -> void: confirmed.emit())
	_render()


func _render() -> void:
	var week_num: int = int(_report_data.get("week", 1))
	title_label.text = "第 %d 周 周报" % week_num

	for child in rows_vbox.get_children():
		child.queue_free()

	var rows: Array = _report_data.get("rows", [])
	if rows.is_empty():
		var lbl := Label.new()
		lbl.text = TextService.text("report_quiet_week")
		rows_vbox.add_child(lbl)
	else:
		for row_text in rows:
			var lbl := Label.new()
			lbl.text = str(row_text)
			rows_vbox.add_child(lbl)
