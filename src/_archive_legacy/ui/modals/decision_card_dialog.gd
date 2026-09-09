class_name DecisionCardDialog
extends PanelContainer

## 决策卡弹窗（z2 阻塞层）：
## 仅经由 GameWorld.choose_decision(event_id, option_idx) 提交选择，保持零写路径。

signal option_selected(option_idx: int)

var _event_data: Dictionary = {}

@onready var header_label: Label = %HeaderLabel
@onready var desc_label: Label = %DescLabel
@onready var options_vbox: VBoxContainer = %OptionsVBox


func setup(event_data: Dictionary) -> void:
	_event_data = event_data
	if is_inside_tree():
		_render()


func _ready() -> void:
	ModalSizing.apply(self)
	_render()


func _render() -> void:
	if _event_data.is_empty():
		return
	var title: String = str(_event_data.get("title", "决策事件"))
	var desc: String = str(_event_data.get("desc", ""))
	header_label.text = title
	desc_label.text = desc

	for child in options_vbox.get_children():
		child.queue_free()

	var options: Array = _event_data.get("options", [])
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 48)  # num-ok: 触控最小热区（表现层）
		btn.text = str(opt.get("text", "选项 %d" % (i + 1)))
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_option_clicked(idx))
		options_vbox.add_child(btn)


func _on_option_clicked(idx: int) -> void:
	option_selected.emit(idx)
