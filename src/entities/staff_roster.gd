class_name StaffRoster
extends RefCounted

## 员工花名册与槽位分配管理（L2 纯逻辑，无 Node 依赖）
##
## 管理员工状态与工位/槽位分配：
## - 单人单槽：一名员工同一时刻至多分配到一个槽位
## - **多人槽**：一个槽位可容纳多名员工（上桌人数上限由 model_bases.max_staff 在
##   TrainingProject 侧校验；本类只管"槽内集合"）
## - DR-005R：科研效率 = **Σ 槽内全部员工的 research**（严禁均值）

const SLOT_NONE: String = ""
const SLOT_TASK: String = "task"
const SLOT_TRAINING: String = "training"
const VALID_SLOTS: Array[String] = [SLOT_TASK, SLOT_TRAINING]

var _staff: Dictionary = {}
## 槽位 -> 占用者 ID 数组（顺序 = 上桌顺序；存档仍导出 staff→slot 的映射）
var _slots: Dictionary = {
	SLOT_TASK: [],
	SLOT_TRAINING: [],
}


## 数据加载：从 staff_data 读取 opening_data["staff_ids"] 中的员工并初始化状态
func setup(staff_data: Dictionary, opening_data: Dictionary) -> void:
	_staff = {}
	_slots = {
		SLOT_TASK: [],
		SLOT_TRAINING: [],
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


## 槽位分配：把员工加入目标槽（单人单槽；已在槽内则幂等返回 true）
func assign_staff(staff_id: String, slot_id: String) -> bool:
	if not _staff.has(staff_id):
		return false
	if not VALID_SLOTS.has(slot_id):
		return false

	# 单人单槽：若原先在其他槽位，先从原槽位移除
	var current_slot: String = str(_staff[staff_id].get("assigned", ""))
	if current_slot != "" and current_slot != slot_id and _slots.has(current_slot):
		_remove_from_slot(current_slot, staff_id)

	var occupants: Array = _slots.get(slot_id, [])
	if not occupants.has(staff_id):
		occupants.append(staff_id)
	_slots[slot_id] = occupants
	_staff[staff_id]["assigned"] = slot_id
	return true


## 解除分配：把员工从其槽位移除
func unassign_staff(staff_id: String) -> bool:
	if not _staff.has(staff_id):
		return false
	var current_slot: String = str(_staff[staff_id].get("assigned", ""))
	if current_slot == "":
		return false

	_remove_from_slot(current_slot, staff_id)
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


## 查询槽位当前占用者 ID（**单人语义保留**：返回首个上桌者，空槽返回 ""）
func get_slot_occupant(slot_id: String) -> String:
	var occupants: Array[String] = get_slot_occupants(slot_id)
	return occupants[0] if not occupants.is_empty() else ""


## 查询槽位全部占用者（多人槽；顺序 = 上桌顺序）
func get_slot_occupants(slot_id: String) -> Array[String]:
	var result: Array[String] = []
	for occupant_variant: Variant in _slots.get(slot_id, []):
		result.append(str(occupant_variant))
	return result


## 槽位当前人数（上桌人数校验用）
func get_slot_count(slot_id: String) -> int:
	var occupants: Array = _slots.get(slot_id, [])
	return occupants.size()


## 获取员工总数
func get_staff_count() -> int:
	return _staff.size()


## 获取全员月薪总和
func get_total_wage() -> int:
	var total: int = 0
	for staff_info: Dictionary in _staff.values():
		total += int(staff_info.get("wage", 0))
	return total


## 求和版 research_eff（DR-005R）：Σ 槽内全部员工的 research（严禁均值）
func get_research_eff(slot_id: String = SLOT_TRAINING) -> int:
	var total: int = 0
	for staff_id: String in get_slot_occupants(slot_id):
		if _staff.has(staff_id):
			total += int(_staff[staff_id].get("research", 0))
	return total


## 对传入员工（staff_id 列表或包含 research 字段的字典列表）的 research 属性做求和
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
## **形状不变**（staff→slot 多对一）：多人同槽也只是一张映射表，零迁移。
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


## 存盘恢复：恢复 assigned 分配状态（按 staff_id 排序保证多人槽顺序确定）
func restore(saved_staff: Dictionary) -> void:
	for slot_id: String in _slots.keys():
		_slots[slot_id] = []
	for staff_info: Dictionary in _staff.values():
		staff_info["assigned"] = ""

	var assigned_dict: Dictionary = saved_staff.get("assigned", {})
	var staff_ids: Array = assigned_dict.keys()
	staff_ids.sort()
	for staff_id_variant: Variant in staff_ids:
		var staff_id: String = str(staff_id_variant)
		var slot_id: String = str(assigned_dict[staff_id_variant])
		if _staff.has(staff_id) and VALID_SLOTS.has(slot_id):
			assign_staff(staff_id, slot_id)


func _remove_from_slot(slot_id: String, staff_id: String) -> void:
	if not _slots.has(slot_id):
		return
	var occupants: Array = _slots[slot_id]
	occupants.erase(staff_id)
	_slots[slot_id] = occupants
