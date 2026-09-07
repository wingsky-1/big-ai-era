class_name StaffRosterDialog
extends PanelContainer

## 员工详情与岗位调度弹窗（z1 层）：
## 展示员工能力值、当前在岗槽位，并提供指派与撤出调度。
## 仅经由 GameWorld.assign_staff / unassign_staff 操作，保持零写路径。

signal closed

var _world: GameWorld

@onready var title_label: Label = %TitleLabel
@onready var close_btn: Button = %CloseBtn
@onready var staff_list_vbox: VBoxContainer = %StaffListVBox


func setup(world: GameWorld) -> void:
	_world = world
	if is_inside_tree():
		_render()


func _ready() -> void:
	close_btn.pressed.connect(func() -> void: closed.emit())
	_render()


func _render() -> void:
	if _world == null or _world.roster == null:
		return

	for child in staff_list_vbox.get_children():
		child.queue_free()

	var staff_dict: Dictionary = _world.roster.get_all_staff()
	for staff_id: String in staff_dict:
		var info: Dictionary = staff_dict[staff_id]
		var card := PanelContainer.new()
		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		var assigned: String = str(info.get("assigned", ""))
		var assigned_str: String = "未分配" if assigned == "" else ("在岗: " + assigned)
		name_label.text = (
			"%s (科研: %d, 工程: %d) [%s]"
			% [
				str(info.get("name", staff_id)),
				int(info.get("research", 0)),
				int(info.get("engineering", 0)),
				assigned_str,
			]
		)
		card_vbox.add_child(name_label)

		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 8)

		var assign_task_btn := Button.new()
		assign_task_btn.custom_minimum_size = Vector2(48, 48)
		assign_task_btn.text = "指派常规任务"
		var sid: String = staff_id
		assign_task_btn.pressed.connect(
			func() -> void:
				_world.assign_staff(sid, StaffRoster.SLOT_TASK)
				_render()
		)
		btn_hbox.add_child(assign_task_btn)

		var assign_training_btn := Button.new()
		assign_training_btn.custom_minimum_size = Vector2(48, 48)
		assign_training_btn.text = "指派模型训练"
		assign_training_btn.pressed.connect(
			func() -> void:
				_world.assign_staff(sid, StaffRoster.SLOT_TRAINING)
				_render()
		)
		btn_hbox.add_child(assign_training_btn)

		var unassign_btn := Button.new()
		unassign_btn.custom_minimum_size = Vector2(48, 48)
		unassign_btn.text = "休假撤岗"
		unassign_btn.pressed.connect(
			func() -> void:
				_world.unassign_staff(sid)
				_render()
		)
		btn_hbox.add_child(unassign_btn)

		card_vbox.add_child(btn_hbox)
		card.add_child(card_vbox)
		staff_list_vbox.add_child(card)
