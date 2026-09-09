class_name TrainingDialog
extends PanelContainer

## 训练基座选择弹层（z1 常规层，issue #104 PR-B / 需求 §3.3、§8.3 + DR-031/B2）：
## - **常显**：全部基座（名称 / 工期·成本·质量·所需算力档·上桌上限·每周卡时 / 状态文案）；
## - **拒绝分支可见**：不可启动者按钮置灰并显原因（算力档不足 / 资金不足 / 上桌超限 /
##   本周卡时不足 / 已有训练中），对应 ui-state-visual-mapping「禁用表现」列；
## - **开始训练**：只发 `start_requested(base_id)`，由 AppShell 调契约命令 `start_training`；
## - **纯表现层**：不碰 GameWorld 子系统、不读数据表、不自算数值（ADR-0016 R1/R2/R3）。

signal closed
signal start_requested(base_id: String)

var _view: Dictionary = {}

@onready var title_label: Label = %TrainingTitle
@onready var active_label: Label = %TrainingActive
@onready var eff_summary_label: Label = %EffSummaryLabel
@onready var rows_vbox: VBoxContainer = %TrainingRows
@onready var close_btn: Button = %TrainingCloseBtn


func setup(view: Dictionary) -> void:
	_view = view
	if is_inside_tree():
		_render()


func _ready() -> void:
	ModalSizing.apply(self)
	close_btn.pressed.connect(func() -> void: closed.emit())
	_render()


func _render() -> void:
	if _view.is_empty():
		return
	title_label.text = str(_view.get("title", ""))
	close_btn.text = str(_view.get("close_label", ""))
	active_label.text = _active_text()
	# 研发力分布摘要（#116）：L2 已拼装 eff_summary 文案，本处只透传显隐。
	var eff_text: String = str(_view.get("eff_summary", ""))
	eff_summary_label.text = eff_text
	eff_summary_label.visible = not eff_text.is_empty()
	for child: Node in rows_vbox.get_children():
		child.queue_free()
	for row_variant: Variant in _view.get("rows", []):
		var row: Dictionary = row_variant
		rows_vbox.add_child(_build_row(row))


## 进行中训练行（文案全部来自 L2，本处只做拼接）。
func _active_text() -> String:
	var active: Dictionary = _view.get("active", {})
	if active.is_empty():
		return str(_view.get("empty_active", ""))
	return "%s · %s" % [str(active.get("name", "")), str(active.get("progress_text", ""))]


## 单行：名称 + 元信息 + 状态/原因 + 开始训练按钮（不可启动则置灰）。
func _build_row(row: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)  # num-ok: 布局间距（表现层）
	var name_label := Label.new()
	name_label.text = str(row.get("name", ""))
	box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = str(row.get("meta_text", ""))
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta_label)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)  # num-ok: 布局间距（表现层）
	var state_label := Label.new()
	state_label.text = str(row.get("state_text", ""))
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(state_label)
	var start_btn := Button.new()
	start_btn.custom_minimum_size = Vector2(48, 48)  # num-ok: 触控最小热区（表现层）
	start_btn.text = str(_view.get("start_label", ""))
	start_btn.disabled = not bool(row.get("available", false))
	var base_id: String = str(row.get("base_id", ""))
	start_btn.pressed.connect(func() -> void: start_requested.emit(base_id))
	hbox.add_child(start_btn)
	box.add_child(hbox)
	return box
