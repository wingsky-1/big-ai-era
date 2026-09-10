class_name AssignSheetPanel
extends ZPanel
## L3 指派面板 z1（批7.3 #190 最小落点；补 #189 验收点 4 诚实债）：
## 员工卡点击 → 本面板 open（栈语义 STAFF_DETAIL）→ 列"可上桌项目"行
## （运行中槽）→ 点行=指派（WorldCommands.assign_staff）。信源=STAFF
## roster view（dashboard["staff"]）+ 槽 view（dashboard["tasks"]）——
## "运行中槽可指派"谓词=零计算（读槽 state/seat 上限与已上桌数比较，
## 纯展示比较非业务规则——业务校验收口仍在 L2 TaskBoard，拒绝以单因回显）。
## 文案=既有 onb_bubble_assign/staff_role_* 键零新键。硬约束：零业务计算；
## 触控行 ≥48px；OP-STA-04 指派 ≤2 击（员工卡 1 击→槽行 1 击）。

const KEY_ASSIGN_CONFIRM: String = "ui_accept"

## 单因拒绝→既有文案键（枚举值键控；缺键因=通用兜底，后批补专属文案）
const REJECT_TEXT_KEYS: Dictionary = {
	CoreEnums.SlotRejectReason.SEAT_LIMIT_REACHED: "paper_slot_full_reason",
	CoreEnums.SlotRejectReason.STAFF_ALREADY_ASSIGNED: "staff_assign_disabled_reason",
	CoreEnums.SlotRejectReason.STAFF_ON_OTHER_SLOT: "staff_assign_disabled_reason",
	CoreEnums.SlotRejectReason.STAFF_NOT_ASSIGNABLE: "staff_assign_disabled_reason",
	CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT: "ui_task_slot_empty",
	CoreEnums.SlotRejectReason.ALL_SLOTS_FULL: "paper_slot_full_reason",
}
const REJECT_FALLBACK_KEY: String = "ui_error_fallback"

var _get_dashboard: Callable = Callable()
var _commands: Object = null
var _staff_id: String = ""
var _staff_name: String = ""
var _slot_rows_box: VBoxContainer


## 注入数据面与命令面（装配方调用）
func bind(get_dashboard: Callable, commands: Object) -> void:
	_get_dashboard = get_dashboard
	_commands = commands


func _build_body(body_box: VBoxContainer) -> void:
	set_title(TextService.text("onb_bubble_assign"))
	body_box.add_child(make_section_label(""))
	_slot_rows_box = VBoxContainer.new()
	_slot_rows_box.add_theme_constant_override("separation", 4)
	body_box.add_child(_slot_rows_box)


## 打开（装配方在员工卡点击后调用）：换人+重刷行
func open_for(staff_id: String, staff_name: String) -> void:
	_staff_id = staff_id
	_staff_name = staff_name
	set_title(staff_name if not staff_name.is_empty() else TextService.text("onb_bubble_assign"))
	clear_footer()
	refresh()


func get_staff_id() -> String:
	return _staff_id


## 全量刷新：可上桌槽行（运行中且有空位）；无 World=防御空转
func refresh() -> void:
	if not _get_dashboard.is_valid():
		return
	_clear_box(_slot_rows_box)
	if _staff_id.is_empty():
		return
	var dashboard: Dictionary = _get_dashboard.call()
	var seat_used := _seat_used_of(dashboard, _staff_id)
	for task: Dictionary in dashboard.get("tasks", []):
		if not _slot_assignable(task, seat_used):
			continue
		var slot_index := int(task.get("slot_index", -1))
		var title_key := str(task.get("title_key", ""))
		var title := (
			TextService.text(title_key)
			if not title_key.is_empty()
			else TextService.text("ui_task_slot_empty")
		)
		var row := make_button(
			(
				"%s · %d/%d ｜ %s"
				% [
					title,
					int(task.get("assigned_count", 0)),
					int(task.get("seat_limit", 0)),
					TextService.text(KEY_ASSIGN_CONFIRM),
				]
			)
		)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(_on_assign_pressed.bind(slot_index))
		_slot_rows_box.add_child(row)
	if _slot_rows_box.get_child_count() == 0:
		_slot_rows_box.add_child(
			make_section_label(TextService.text("staff_assign_disabled_reason"))
		)


## ---------- 私有 ----------


## 员工已在槽（身位比较；上桌空位=seat_limit − 已上桌数，展示口径）
func _slot_assignable(task: Dictionary, seat_used_of_staff: int) -> bool:
	if int(task.get("state", CoreEnums.ProjectState.EMPTY)) != CoreEnums.ProjectState.IN_PROGRESS:
		return false
	if seat_used_of_staff >= 0:
		return false
	var assigned := int(task.get("assigned_count", 0))
	var limit := int(task.get("seat_limit", 0))
	return limit > assigned


func _seat_used_of(dashboard: Dictionary, staff_id: String) -> int:
	for task: Dictionary in dashboard.get("tasks", []):
		for member_id: String in task.get("assigned_staff", []):
			if member_id == staff_id:
				return int(task.get("slot_index", -1))
	return -1


func _on_assign_pressed(slot_index: int) -> void:
	if _commands == null or _staff_id.is_empty():
		return
	var reason: int = _commands.assign_staff(_staff_id, slot_index)
	if int(reason) == int(CoreEnums.SlotRejectReason.NONE):
		set_footer(TextService.text(KEY_ASSIGN_CONFIRM), true)
	else:
		set_footer(_reject_text(reason), false)
	refresh()


func _reject_text(reason: int) -> String:
	var key := str(REJECT_TEXT_KEYS.get(reason, REJECT_FALLBACK_KEY))
	return TextService.text(key)


func _clear_box(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
