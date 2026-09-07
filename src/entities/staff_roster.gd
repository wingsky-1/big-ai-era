class_name StaffRoster
extends RefCounted

## 员工花名册与槽位分配管理（L2 纯逻辑，无 Node 依赖）
##
## 管理员工状态与工位/槽位分配：
## - 单人单槽：一名员工同一时刻至多分配到一个槽位
## - 单槽独占：一个槽位同一时刻至多容纳一名员工
## - DR-005R：科研效率采用加总计算（禁止均值）

const SLOT_NONE: String = ""
const SLOT_TASK: String = "task"
const SLOT_TRAINING: String = "training"
const VALID_SLOTS: Array[String] = [SLOT_TASK, SLOT_TRAINING]

var _staff: Dictionary = {}
var _slots: Dictionary = {
	SLOT_TASK: "",
	SLOT_TRAINING: "",
}


## 数据加载：从 staff_data 读取 opening_data["staff_ids"] 中的员工并初始化状态
func setup(staff_data: Dictionary, opening_data: Dictionary) -> void:
	_staff = {}
	_slots = {
		SLOT_TASK: "",
		SLOT_TRAINING: "",
	}
	var staff_ids: Array = opening_data.get("staff_ids", [])
	for staff_id_variant: Variant in staff_ids:
		var staff_id: String = str(staff_id_variant)
		if staff_data.has(staff_id):
			var raw_info: Dictionary = staff_data[staff_id]
			_staff[staff_id] = {
				"staff_id": staff_id,
				"name": str(raw_info.get("name", "")),
				"research": int(raw_info.get("research", 0)),
				"engineering": int(raw_info.get("engineering", 0)),
				"wage": int(raw_info.get("wage", 0)),
				"assigned": "",
			}


## 槽位分配：将员工指派到目标槽位（保证单人单槽与单槽独占）
func assign_staff(staff_id: String, slot_id: String) -> bool:
	if not _staff.has(staff_id):
		return false
	if not VALID_SLOTS.has(slot_id):
		return false

	# 单人单槽：若原先在其他槽位，清理原槽位
	var current_slot: String = str(_staff[staff_id].get("assigned", ""))
	if current_slot != "" and _slots.has(current_slot):
		_slots[current_slot] = ""

	# 单槽独占：若目标槽位已被他人占用，解除其分配
	var current_occupant: String = str(_slots.get(slot_id, ""))
	if current_occupant != "" and current_occupant != staff_id and _staff.has(current_occupant):
		_staff[current_occupant]["assigned"] = ""

	# 设置新分配关系
	_slots[slot_id] = staff_id
	_staff[staff_id]["assigned"] = slot_id
	return true


## 解除分配：清空指定员工的槽位占用
func unassign_staff(staff_id: String) -> bool:
	if not _staff.has(staff_id):
		return false
	var current_slot: String = str(_staff[staff_id].get("assigned", ""))
	if current_slot == "":
		return false

	if _slots.has(current_slot) and _slots[current_slot] == staff_id:
		_slots[current_slot] = ""
	_staff[staff_id]["assigned"] = ""
	return true


## 查询单个员工信息（返回字典副本以防外部直接修改内部状态）
func get_staff(staff_id: String) -> Dictionary:
	if _staff.has(staff_id):
		return (_staff[staff_id] as Dictionary).duplicate(true)
	return {}


## 查询全部员工信息
func get_all_staff() -> Dictionary:
	return _staff.duplicate(true)


## 查询槽位当前占用者 ID（空槽返回 ""）
func get_slot_occupant(slot_id: String) -> String:
	return str(_slots.get(slot_id, ""))


## 获取员工总数
func get_staff_count() -> int:
	return _staff.size()


## 获取全员月薪总和
func get_total_wage() -> int:
	var total: int = 0
	for staff_info: Dictionary in _staff.values():
		total += int(staff_info.get("wage", 0))
	return total


## 求和版 research_eff（DR-005R）：若 slot_id 不为空，计算该槽位占用的员工的 research 之和
func get_research_eff(slot_id: String = SLOT_TRAINING) -> int:
	if slot_id == "":
		return 0
	var occupant_id: String = get_slot_occupant(slot_id)
	if occupant_id == "" or not _staff.has(occupant_id):
		return 0
	return int(_staff[occupant_id].get("research", 0))


## 对传入员工（staff_id 列表或包含 research 字段的字典列表）的 research 属性做求和（用于验收点 90 + 63 = 153 的组合断言，严格禁止均值）
func calculate_aggregate_research(staff_list: Array) -> int:
	var total: int = 0
	for item_variant: Variant in staff_list:
		if item_variant is Dictionary:
			total += int(item_variant.get("research", 0))
		else:
			var staff_id: String = str(item_variant)
			if _staff.has(staff_id):
				total += int(_staff[staff_id].get("research", 0))
	return total


## 快照导出：返回员工列表，每项包含 staff_id, name, research, engineering, wage, assigned
func to_snapshot() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for staff_id: String in _staff.keys():
		list.append((_staff[staff_id] as Dictionary).duplicate(true))
	return list


## 存盘导出：返回 {"assigned": {staff_id: slot_id}, "condition": []}
func to_save() -> Dictionary:
	var assigned_dict: Dictionary = {}
	for staff_id: String in _staff.keys():
		var slot_id: String = str(_staff[staff_id].get("assigned", ""))
		if slot_id != "":
			assigned_dict[staff_id] = slot_id
	return {
		"assigned": assigned_dict,
		"condition": [],
	}


## 存盘恢复：恢复 assigned 分配状态
func restore(saved_staff: Dictionary) -> void:
	# 清空现有分配
	for slot_id: String in _slots.keys():
		_slots[slot_id] = ""
	for staff_info: Dictionary in _staff.values():
		staff_info["assigned"] = ""

	var assigned_dict: Dictionary = saved_staff.get("assigned", {})
	for staff_id_variant: Variant in assigned_dict.keys():
		var staff_id: String = str(staff_id_variant)
		var slot_id: String = str(assigned_dict[staff_id_variant])
		if _staff.has(staff_id) and VALID_SLOTS.has(slot_id):
			assign_staff(staff_id, slot_id)
