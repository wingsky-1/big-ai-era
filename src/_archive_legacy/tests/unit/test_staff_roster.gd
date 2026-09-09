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


func test_multi_slot_occupants_coexist() -> void:
	# 批 1b（#73）：单槽独占 → 多人槽；上桌人数上限由 model_bases.max_staff 校验
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)

	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TASK))
	assert_true(roster.assign_staff("r_wen", StaffRoster.SLOT_TASK))

	assert_eq(roster.get_slot_count(StaffRoster.SLOT_TASK), 2, "task 槽应有 2 人（多人槽）")
	assert_eq(roster.get_staff("r_lin").get("assigned"), StaffRoster.SLOT_TASK, "lin 仍在槽内")
	assert_eq(roster.get_staff("r_wen").get("assigned"), StaffRoster.SLOT_TASK)
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin", "单人语义返回首个上桌者")

	# 幂等：重复指派不产生重复占位
	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TASK), "重复指派应幂等成功")
	assert_eq(roster.get_slot_count(StaffRoster.SLOT_TASK), 2, "幂等指派不应重复计数")


func test_research_eff_sums_all_assigned() -> void:
	# [T] #73 验收点 1：两人同槽 → eff = 两者 research 之和（严禁均值）
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)
	assert_eq(roster.get_research_eff(StaffRoster.SLOT_TRAINING), 0, "空槽 eff=0")

	assert_true(roster.assign_staff("r_lin", StaffRoster.SLOT_TRAINING))
	assert_eq(roster.get_research_eff(StaffRoster.SLOT_TRAINING), 70, "单人 eff=70")

	assert_true(roster.assign_staff("r_wen", StaffRoster.SLOT_TRAINING))
	assert_eq(
		roster.get_research_eff(StaffRoster.SLOT_TRAINING),
		70 + 55,
		"两人同槽 eff = 70 + 55 = 125（Σ，严禁均值）"
	)

	assert_true(roster.assign_staff("r_bai", StaffRoster.SLOT_TRAINING))
	assert_eq(roster.get_research_eff(StaffRoster.SLOT_TRAINING), 70 + 55 + 62, "三人同槽 eff = 187")

	assert_true(roster.unassign_staff("r_wen"))
	assert_eq(roster.get_research_eff(StaffRoster.SLOT_TRAINING), 70 + 62, "撤一人后 Σ 同步")


func test_multi_assign_save_restore_roundtrip() -> void:
	# [T] #73 验收点 3：多人同槽经 to_save/restore 往返一致，且形状仍为 staff→slot
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)
	roster.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	roster.assign_staff("r_wen", StaffRoster.SLOT_TRAINING)
	roster.assign_staff("r_bai", StaffRoster.SLOT_TASK)

	var assigned: Dictionary = roster.to_save()["assigned"]
	assert_eq(assigned["r_lin"], StaffRoster.SLOT_TRAINING, "存档形状保持 staff→slot")
	assert_eq(assigned["r_wen"], StaffRoster.SLOT_TRAINING, "多人同槽 = 多对一映射")
	assert_eq(assigned["r_bai"], StaffRoster.SLOT_TASK)
	assert_true(assigned["r_lin"] is String, "值必须是字符串 slot_id（禁改 slot→数组）")

	var restored := StaffRoster.new()
	restored.setup(_staff_data, _opening_data)
	restored.restore(roster.to_save())
	assert_eq(restored.get_slot_count(StaffRoster.SLOT_TRAINING), 2, "往返后 training 槽 2 人")
	assert_eq(restored.get_research_eff(StaffRoster.SLOT_TRAINING), 125, "往返后 Σeff 一致")
	assert_eq(restored.get_staff("r_bai")["assigned"], StaffRoster.SLOT_TASK)


func test_single_occupant_api_preserved() -> void:
	# [T] #73 验收点 4：get_slot_occupant 仍返回单值（restore/测试依赖），新增聚合方法
	var roster := StaffRoster.new()
	roster.setup(_staff_data, _opening_data)
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "", "空槽返回空串")

	roster.assign_staff("r_lin", StaffRoster.SLOT_TASK)
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin")
	assert_eq(roster.get_slot_occupants(StaffRoster.SLOT_TASK).size(), 1, "单人也走聚合方法")

	roster.assign_staff("r_wen", StaffRoster.SLOT_TASK)
	assert_eq(roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin", "多人时返回首个上桌者（单值语义）")
	var occupants: Array[String] = roster.get_slot_occupants(StaffRoster.SLOT_TASK)
	assert_eq(occupants.size(), 2, "get_slot_occupants 返回全部")
	assert_eq(occupants[0], "r_lin")
	assert_eq(occupants[1], "r_wen")


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
