class_name TaskManageDialog
extends PanelContainer

## 任务板弹层（z1 常规层，issue #104 / 需求 §2.3 RT-01）：
## - **常显**：全部 enabled 任务（名称 / 工期·收入·声望·成本 / 状态文案）；
## - **拒绝分支可见**：不可接者按钮置灰并显原因（资金不足 / 未解锁 / 已在队列），
##   对应 ui-state-visual-mapping「禁用表现」列（置灰 + 原因可查）；
## - **接单**：只发 `accept_requested(task_id)`，由 AppShell 调契约命令 `enqueue_task`；
## - **纯表现层**：不碰 GameWorld 子系统、不读数据表、不自算数值（ADR-0016 R1/R2/R3）。

signal closed
signal accept_requested(task_id: String)

var _view: Dictionary = {}

@onready var title_label: Label = %TaskBoardTitle
@onready var active_label: Label = %TaskBoardActive
@onready var rows_vbox: VBoxContainer = %TaskBoardRows
@onready var close_btn: Button = %TaskBoardCloseBtn


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
	for child: Node in rows_vbox.get_children():
		child.queue_free()
	for row_variant: Variant in _view.get("rows", []):
		var row: Dictionary = row_variant
		rows_vbox.add_child(_build_row(row))


## 进行中/排队行（文案全部来自 L2，本处只做拼接分隔符）。
func _active_text() -> String:
	var active: Dictionary = _view.get("active", {})
	var parts: Array[String] = []
	if active.is_empty():
		parts.append(str(_view.get("empty_active", "")))
	else:
		parts.append(
			"%s · %s" % [str(active.get("name", "")), str(active.get("progress_text", ""))]
		)
	var queue_names: Array = _view.get("queue_names", [])
	if queue_names.is_empty():
		parts.append(str(_view.get("empty_queue", "")))
	else:
		parts.append(str(_view.get("queue_label", "")) + ": " + ", ".join(queue_names))
	return " ｜ ".join(parts)


## 单行：名称 + 元信息 + 状态/原因 + 接单按钮（不可接则置灰）。
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
	var accept_btn := Button.new()
	accept_btn.custom_minimum_size = Vector2(48, 48)  # num-ok: 触控最小热区（表现层）
	accept_btn.text = str(_view.get("accept_label", ""))
	accept_btn.disabled = not bool(row.get("available", false))
	var task_id: String = str(row.get("task_id", ""))
	accept_btn.pressed.connect(func() -> void: accept_requested.emit(task_id))
	hbox.add_child(accept_btn)
	box.add_child(hbox)
	return box
