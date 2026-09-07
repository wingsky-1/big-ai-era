class_name GameOverDialog
extends PanelContainer

## 游戏结束结算弹窗（z2 阻塞层）：
## 展示破产结算与三项 summary 结果。

signal restart_requested

var _summary_data: Dictionary = {}

@onready var game_over_title: Label = %GameOverTitle
@onready var week_summary_label: Label = %WeekSummaryLabel
@onready var best_score_label: Label = %BestScoreLabel
@onready var rival_best_label: Label = %RivalBestLabel
@onready var restart_btn: Button = %RestartBtn


func setup(summary_data: Dictionary) -> void:
	_summary_data = summary_data
	if is_inside_tree():
		_render()


func _ready() -> void:
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	_render()


func _render() -> void:
	if _summary_data.is_empty():
		return
	week_summary_label.text = "存续周数: %d 周" % int(_summary_data.get("week", 0))
	best_score_label.text = "最佳模型分: %.2f" % float(_summary_data.get("best_score", 0.0))
	rival_best_label.text = "竞对最佳分: %.2f" % float(_summary_data.get("rival_best", 0.0))
