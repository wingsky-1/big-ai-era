extends GutTest
## #130 Roster 名册 unit 测试：装配（表驱动）/谓词（is_idle/is_assignable 注入过滤）/
## 信号（staff_state_rolled 可达，架构 §5.2 信号"发射点+消费点"纪律）/视图深拷贝。

const STAFF_TABLE_PATH: String = "res://src/data/staff.json"
const TEST_SEED: int = 130130


func _load_staff_table() -> Dictionary:
	var table := DataLoader.load_json(STAFF_TABLE_PATH)
	assert_false(table.is_empty(), "staff.json 可加载（%s）" % STAFF_TABLE_PATH)
	return table


func _make_roster(seed: int = TEST_SEED) -> Roster:
	var rng := RngStream.new()
	rng.setup(seed)
	return Roster.new(_load_staff_table(), rng)


func test_roster_assembles_four_from_table() -> void:
	# 装配=表驱动（staff_initial_roster._order 全行），不写死 4 循环
	var roster := _make_roster()
	assert_eq(roster.get_staff_count(), 4, "初始名册 4 人")
	assert_eq(roster.get_staff_ids(), ["s1", "s2", "s3", "s4"], "装配序=表 _order")
	assert_eq(roster.get_initial_count_target(), 4, "staff_start_count=4（表驱动目标）")
	for staff_id: String in roster.get_staff_ids():
		var view := roster.get_staff_view(staff_id)
		assert_false(view.is_empty(), "员工视图非空（%s）" % staff_id)
		assert_true(roster.get_staff(staff_id) is Staff, "内部对象访问可用（L2 装配用）")
	assert_eq(roster.get_staff_view("no_such"), {}, "未知 id 视图返回空 dict")


func test_roster_assignable_filter_injected() -> void:
	# 谓词=装配方注入过滤（架构 §3/§4.1：Roster 只出谓词，不写"在岗项目"字段）
	var roster := _make_roster()
	assert_true(roster.is_idle("s1"), "默认全员空闲（无 TaskBoard 阶段真实语义）")
	assert_true(roster.is_assignable("s1"), "默认全员可派")
	assert_false(roster.is_idle("no_such"), "未知 id 非空闲")
	assert_eq(roster.get_assignable_ids().size(), 4, "默认可派名单=4 人")
	# 注入过滤器模拟"不在任何任务槽成员"（TaskBoard 落位后由装配方注入）
	roster.assignable_filter = func(staff_id: String) -> bool: return staff_id != "s2"
	assert_false(roster.is_idle("s2"), "过滤器拦截后 s2 非空闲")
	assert_true(roster.is_idle("s1"), "过滤器放行 s1 空闲")
	var ids: Array[String] = roster.get_assignable_ids()
	assert_eq(ids.size(), 3, "可派名单=过滤后 3 人")
	assert_false(ids.has("s2"), "s2 不在可派名单")
	assert_true(ids.has("s1") and ids.has("s3") and ids.has("s4"), "其余三人可派")


func test_roster_staff_state_rolled_signal_reachable() -> void:
	# staff_state_rolled 信号有真实发射点（架构 §5.2 纪律：每信号至少一发射点+消费点）
	var roster := _make_roster()
	var received: Array = []
	roster.staff_state_rolled.connect(func(payload: Dictionary) -> void: received.append(payload))
	var results: Array = roster.roll_weekly_states()
	assert_eq(results.size(), 4, "掷点返回 4 载荷")
	assert_eq(received.size(), 4, "信号发射 4 次（每员工一次）")
	var expected_order: Array = roster.get_staff_ids()
	for i: int in received.size():
		var payload: Dictionary = received[i]
		assert_true(payload.has("staff_id"), "载荷含 staff_id")
		assert_true(payload.has("state"), "载荷含 state（enum）")
		assert_true(payload.has("state_key"), "载荷含 state_key（稳定字符串）")
		assert_true(payload.has("modifier"), "载荷含 modifier（周产出乘数）")
		assert_eq(
			str(payload["staff_id"]),
			str(expected_order[i]),
			"信号按名册序逐人发射（%s）" % str(expected_order[i]),
		)


func test_roster_view_is_deep_copy() -> void:
	# 数据面深拷贝：改外部返回 dict 不影响内部状态（ADR-0016 防越权）
	var roster := _make_roster()
	var view := roster.get_roster_view()
	assert_eq(int(view["staff_count"]), 4, "名册视图总数 4")
	assert_eq((view["staff"] as Array).size(), 4, "名册视图员工数组 4")
	var staff_views: Array = view["staff"]
	var first: Dictionary = staff_views[0]
	var attrs: Dictionary = first["attrs"]
	attrs["theory"] = 999.0
	var view_again := roster.get_roster_view()
	var again_first: Dictionary = (view_again["staff"] as Array)[0]
	assert_almost_eq(
		float((again_first["attrs"] as Dictionary)["theory"]),
		56.0,
		0.001,
		"篡改外部视图不影响内部（s1 theory 仍 56）",
	)


func test_roster_extend_table_driven_e1() -> void:
	# E1 表驱动预留：初始员工表加行=扩容（扩编批激活新行，本类装配零改、不写死 4）
	var table := _load_staff_table()
	var rng := RngStream.new()
	rng.setup(TEST_SEED)
	var extended_table := table.duplicate(true)
	var roster_def: Dictionary = extended_table["staff_initial_roster"].duplicate(true)
	var order: Array = roster_def["_order"].duplicate()
	order.append("s9")
	roster_def["_order"] = order
	roster_def["s9"] = {
		"name": "测试员",
		"role": "research",
		"attrs": {"theory": 50, "engineering": 50, "data": 50, "communication": 50},
		"observation_pool_index": 4,
	}
	extended_table["staff_initial_roster"] = roster_def
	extended_table["staff_start_count"] = 5
	var extended_roster := Roster.new(extended_table, rng)
	assert_eq(extended_roster.get_staff_count(), 5, "表加行后装配 5 人（代码零改）")
	assert_true(extended_roster.get_staff_ids().has("s9"), "新行被表驱动装配")
	var new_view := extended_roster.get_staff_view("s9")
	assert_eq(str(new_view["name"]), "测试员", "新员工定义走表")
