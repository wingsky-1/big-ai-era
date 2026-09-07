extends GutTest

## StaffRoster 单元测试（验收点 DR-005R、单人单槽、单槽独占、快照存盘等）

var _staff_data: Dictionary = {}
var _opening_data: Dictionary = {}


func before_each() -> void:
	_staff_data = {
		"r_lin":
		{
			"name": "林拾光",
			"research": 70,
			"engineering": 55,
			"wage": 2000,
		},
		"r_wen":
		{
			"name": "温若愚",
			"research": 55,
			"engineering": 70,
			"wage": 2000,
		},
		"r_bai":
		{
			"name": "白鹿鸣",
			"research": 62,
			"engineering": 62,
			"wage": 2000,
		},
	}
	_opening_data = {
		"staff_ids": ["r_lin", "r_wen", "r_bai"],
	}


func test_setup_loads_staff_from_opening() -> void:
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)

	assert_eq(roster.get_staff_count(), 3, "员工总数应为 3")
	assert_eq(roster.get_total_wage(), 6000, "薪资总额应为 6000")

	var lin: Dictionary = roster.get_staff("r_lin")
	assert_eq(lin.get("name"), "林拾光")
	assert_eq(lin.get("research"), 70)
	assert_eq(lin.get("engineering"), 55)
	assert_eq(lin.get("wage"), 2000)
	assert_eq(lin.get("assigned"), "")


func test_assign_and_unassign_basic() -> void:
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)

	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TASK), "应成功分配到 task")
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin")
	assert_eq(roster.get_staff("r_lin").get("assigned"), StaffRoster.SLOT_TASK)

	assert_true(roster.unassign_staff("r_lin"), "应成功解除分配")
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "")
	assert_eq(roster.get_staff("r_lin").get("assigned"), "")
	assert_false(roster.unassign_staff("r_lin"), "未分配状态再次 unassign 应返回 false")


func test_single_staff_single_slot() -> void:
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)

	# 先分配到 task，再改分到 training
	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TASK))
	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TRAINING))

	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "", "原 task 槽位应被清空（单人单槽）")
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TRAINING), "r_lin")
	assert_eq(roster.get_staff("r_lin").get("assigned"), StaffRoster.SLOT_TRAINING)


func test_single_slot_exclusive() -> void:
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)

	# lin 先占 task，wen 随后也分到 task
	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TASK))
	assert_true(roster.assign_staff("r_wen", StaffRoster.SLOT_TASK))

	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_wen", "task 槽位应被 wen 独占")
	assert_eq(roster.get_staff("r_lin").get("assigned"), "", "lin 的 assigned 应被重置为空")
	assert_eq(roster.get_staff("r_wen").get("assigned"), StaffRoster.SLOT_TASK)


func test_research_eff_and_dr005r_aggregate() -> void:
	var roster := StaffRoster.new()
	var custom_staff_data: Dictionary = {
		"s1": {"name": "专家甲", "research": 90, "engineering": 50, "wage": 3000},
		"s2": {"name": "专家乙", "research": 63, "engineering": 40, "wage": 2500},
	}
	var custom_opening: Dictionary = {"staff_ids": ["s1", "s2"]}
	roster.setup(custom_staff_data, custom_opening)

	# 验收点 DR-005R：90 + 63 = 153 的组合断言，严格禁止均值
	var sum_val: int = roster.calculate_aggregate_research(["s1", "s2"])
	assert_eq(sum_val, 153, "calculate_aggregate_research 必须为 90 + 63 = 153（禁止均值）")

	assert_eq(roster.get_research_eff(StaffRoster.SLOT_TRAINING), 0, "未分配时 research_eff 为 0")
	roster.assign_staff("s1", StaffRoster.SLOT_TRAINING)
	assert_eq(roster.get_research_eff(StaffRoster.SLOT_TRAINING), 90)


func test_snapshot_and_save_restore() -> void:
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)

	roster.assign_staff("r_lin", StaffRoster.SLOT_TASK)
	roster.assign_staff("r_wen", StaffRoster.SLOT_TRAINING)

	var snapshot: Array[Dictionary] = roster.to_snapshot()
	assert_eq(snapshot.size(), 3)

	var saved: Dictionary = roster.to_save()
	assert_eq(saved.get("condition"), [])
	var assigned: Dictionary = saved.get("assigned", {})
	assert_eq(assigned.get("r_lin"), StaffRoster.SLOT_TASK)
	assert_eq(assigned.get("r_wen"), StaffRoster.SLOT_TRAINING)

	# 创建新 roster 恢复状态
	var new_roster := StaffRoster.new()
	new_roster.setup(_staff_data, _opening_data)
	assert_eq(new_roster.get_slot_occupant(StaffRoster.SLOT_TASK), "")
	new_roster.restore(saved)

	assert_eq(new_roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin")
	assert_eq(new_roster.get_slot_occupant(StaffRoster.SLOT_TRAINING), "r_wen")
	assert_eq(new_roster.get_staff("r_lin").get("assigned"), StaffRoster.SLOT_TASK)
	assert_eq(new_roster.get_staff("r_wen").get("assigned"), StaffRoster.SLOT_TRAINING)
