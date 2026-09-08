class_name GameOverDialog
extends PanelContainer

## 游戏结束结算弹窗（z2 阻塞层）：
## 展示破产结算与三项 summary 结果。

signal restart_requested

var _summary_data: Dictionary = {}
var _freedom_label: Label

@onready var game_over_title: Label = %GameOverTitle
@onready var summary_vbox: VBoxContainer = %SummaryVBox
@onready var week_summary_label: Label = %WeekSummaryLabel
@onready var best_score_label: Label = %BestScoreLabel
@onready var rival_best_label: Label = %RivalBestLabel
@onready var restart_btn: Button = %RestartBtn


func setup(summary_data: Dictionary) -> void:
	_summary_data = summary_data
	if is_inside_tree():
		_render()


func _ready() -> void:
	ModalSizing.apply(self)
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	_render()


func _render() -> void:
	if _summary_data.is_empty():
		return
	week_summary_label.text = "存续周数: %d 周" % int(_summary_data.get("week", 0))
	best_score_label.text = "最佳模型分: %.2f" % float(_summary_data.get("best_score", 0.0))
	rival_best_label.text = "竞对最佳分: %.2f" % float(_summary_data.get("rival_best", 0.0))
	_render_freedom_lines()


## 三线终值行（#82 RF-03 破产终局边界：三线终值 + 已显示的「存续周数」即"在第 N 周倒下"）。
## 与终局收尾屏两套并存；本卡原有三项口径与 reason 语义不变。
func _render_freedom_lines() -> void:
	var lines: Array = _summary_data.get("freedom_lines", [])
	if lines.is_empty():
		return
	if _freedom_label == null:
		_freedom_label = Label.new()
		_freedom_label.name = "FreedomSummaryLabel"
		_freedom_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_vbox.add_child(_freedom_label)
	_freedom_label.text = "\n".join(lines)
