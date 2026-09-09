class_name FinaleDialog
extends PanelContainer

## 终局收尾屏（z2 阻塞层，#82 RF-03 / Q-R3）：
## - 触发：走满 `clock.json` 的 `run_weeks` 当周自动弹（非破产专属）；
## - 形态：金框六项结算 + 三线终值 + 关键决策回溯 3 条 + 一句话评价，一屏内可截图；
## - 并存：不替代破产 Game Over 卡（`game_over_dialog`），玩家点「继续自由期」可继续刷三线。
## - 数据面：全部来自 L2（GameWorld.get_finale_summary 经周结载荷 finale 段透传），
##   L3 只渲染文本行，零业务计算（ADR-0016）。

signal continue_requested

var _summary: Dictionary = {}

@onready var title_label: Label = %FinaleTitle
@onready var verdict_label: Label = %FinaleVerdict
@onready var rows_vbox: VBoxContainer = %FinaleRowsVBox
@onready var review_title_label: Label = %FinaleReviewTitle
@onready var review_vbox: VBoxContainer = %FinaleReviewVBox
@onready var continue_btn: Button = %FinaleContinueBtn


func setup(summary: Dictionary) -> void:
	_summary = summary
	if is_inside_tree():
		_render()


func _ready() -> void:
	ModalSizing.apply(self)
	continue_btn.pressed.connect(func() -> void: continue_requested.emit())
	_render()


func _render() -> void:
	if _summary.is_empty():
		return
	var display: Dictionary = _summary.get("display", {})
	title_label.text = str(display.get("title", ""))
	review_title_label.text = str(display.get("review_title", ""))
	continue_btn.text = str(display.get("continue_label", ""))
	verdict_label.text = str(_summary.get("verdict", ""))
	_fill_rows(rows_vbox, _summary.get("rows", []))
	_fill_rows(review_vbox, _summary.get("review", []))


## 逐行渲染（行数固定为 6 + 3，清空重建即可，不做复用池）。
func _fill_rows(host: VBoxContainer, rows: Array) -> void:
	for child: Node in host.get_children():
		child.queue_free()
	for row_variant: Variant in rows:
		var label := Label.new()
		label.text = str(row_variant)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host.add_child(label)
