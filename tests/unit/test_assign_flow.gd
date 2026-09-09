extends GutTest
## #132 指派流/上桌协作 unit 测试（DoD 用例名逐字落盘 + 细化断言）。
## 被测对象=src/entities/task_board.gd（指派命令写点=槽成员 id 列表 + 0.5s
## 刷新语义=信号发射+视图随查随新）+ src/entities/projects/project.gd +
## src/entities/collab.gd。真源=architecture-100 §4.1（指派写点/防双真源）
## + §5.2（task_board_changed 信号载荷；staff_assigned 由装配广播）+ staff-spec
## A.1/OP-STA-01（点员工→点项目 ≤2 击；0.5s 内卡翻新+项目卡头像角标；重复/
## 满员拒绝原因）。
## 约定：员工=假名册 s1..s4（岗位=初始名册真源 research/eval/data/engineering，
## 本文件 s1=research/s2=eval/s3=data/s4=engineering），谓词+角色键+staff.json
## 注入（#131/#132 同款"装配方注入"方向，TaskBoard 不自持 Roster 引用防环）。

const STAFF_TABLE_PATH: String = "res://src/data/staff.json"


func _load_staff_table() -> Dictionary:
	var table := DataLoader.load_json(STAFF_TABLE_PATH)
	assert_false(table.is_empty(), "staff.json 可加载（%s）" % STAFF_TABLE_PATH)
	return table


func test_assign_flow_refresh() -> void:
	# DoD：指派 ≤2 击语义——点员工→点项目 0.5s 内卡翻新+头像角标
	# （0.5s 刷新=task_board_changed 信号发射+视图随查随新；卡翻新=员工视图
	# "在岗"由槽成员反查聚合、槽视图成员+角标=数据面同源）
	var table := _load_staff_table()
	var board := _make_board(table)
	var model := ModelProject.new("base_demo", "base_demo", 3, 2, 2)
	assert_true(board.start_training(model, 0).ok, "项目入槽（指派目标就位）")
	# ≤2 击语义=两次命令完成指派（点员工卡→点项目卡；本层=assign_staff 一命令
	# 即落位，L3 两层点按消费同一命令面；槽成员即时生效）
	assert_eq(board.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "点员工→点项目=指派成功（≤2 击语义）")
	# 0.5s 内卡翻新语义=信号发射+视图随查随新（载荷含被指派员工/槽/角标数据）
	var received: Array = []
	board.task_board_changed.connect(func(change: Dictionary) -> void: received.append(change))
	board.assign_staff("s4", 0)
	assert_eq(received.size(), 1, "指派即发 task_board_changed（0.5s 刷新信号源）")
	var change: Dictionary = received[0]
	assert_eq(str(change["kind"]), "assigned", "信号载荷 kind=assigned")
	assert_eq(int(change["slot_index"]), 0, "载荷槽号=0")
	assert_eq(str(change["staff_id"]), "s4", "载荷含被指派员工 id")
	assert_true(
		change.has("collab_factor") and change.has("collab_kind"),
		"载荷含协作角标数据（新上桌者角色即时可见）",
	)
	assert_almost_eq(float(change["collab_factor"]), 1.18, 0.0001, "双人互补角标系数即时可读")
	# 员工卡翻新数据面："在岗"由槽成员反查（架构 §4.1：Roster 不写岗，反查唯一）
	assert_eq(board.get_slot_of_staff("s1"), 0, "s1 反查在岗槽=0")
	assert_eq(board.get_slot_of_staff("s4"), 0, "s4 反查在岗槽=0")
	assert_eq(board.get_all_assigned_staff(), ["s1", "s4"], "全槽聚合成员=指派产物（卡翻新数据源）")
	# 项目卡头像角标：槽视图成员+协作角标同源随查随新
	var view: Dictionary = board.get_slot_view(0)
	assert_eq(view["assigned_count"], 2, "项目卡头像角标数据=2 头像")
	assert_eq(view["assigned_staff"], ["s1", "s4"], "角标头像 id 列表同源")
	assert_eq(view["collab_kind"], CollabFactor.KIND_COMPLEMENT, "项目卡组合角标=互补")
	assert_almost_eq(float(view["collab_factor"]), 1.18, 0.0001, "组合角标系数=×1.18")
	# 二次指派后视图仍随查随新（发射点数=命令数，防信号风暴之外无死信号）
	var view_again: Dictionary = board.get_slot_view(0)
	assert_almost_eq(float(view_again["collab_factor"]), 1.18, 0.0001, "重复查询不重算不漂移")


## ---------- 细化断言（规则完备性；非 DoD 名，契约面/防御面） ----------


func test_assign_view_roles_and_rejections_reachable() -> void:
	# 槽视图协作数据面完备性：双人上桌含角色键/角标；拒绝路径=既有枚举单因
	var table := _load_staff_table()
	var board := _make_board(table)
	board.start_paper(PaperProject.new("topic_demo", 2, 1, 2), 0)
	board.assign_staff("s1", 0)
	board.assign_staff("s2", 0)
	var view: Dictionary = board.get_slot_view(0)
	assert_eq(view["assigned_roles"], {"s1": "research", "s2": "eval"}, "槽视图含上桌者角色键")
	assert_eq(view["collab_kind"], CollabFactor.KIND_ADJACENT, "研究×评测=相邻（角标分类同源）")
	assert_almost_eq(float(view["collab_factor"]), 1.08, 0.0001, "相邻系数 ×1.08")
	# 满员/重复拒绝=既有枚举（禁新字符串；staff-spec A.1 边界语义）
	assert_eq(
		board.assign_staff("s3", 0),
		CoreEnums.SlotRejectReason.SEAT_LIMIT_REACHED,
		"满员拒绝=SEAT_LIMIT_REACHED（上限=Project 声明值）",
	)
	assert_eq(
		board.assign_staff("s1", 0),
		CoreEnums.SlotRejectReason.STAFF_ALREADY_ASSIGNED,
		"重复派同一人=STAFF_ALREADY_ASSIGNED",
	)
	# 三人上限项目（seat=3）多人时=最弱配对保守下限（真源 #140/#141 收口前
	# 不发明叠乘：研究×评测×数据 → 相邻 1.08 + 互补 1.18 取弱=相邻 ×1.08）
	var board3 := _make_board(table)
	board3.start_training(ModelProject.new("base_demo", "base_demo", 4, 2, 3), 0)
	board3.assign_staff("s1", 0)
	board3.assign_staff("s2", 0)
	assert_almost_eq(float(board3.get_slot_view(0)["collab_factor"]), 1.08, 0.0001, "双人=相邻 ×1.08")
	board3.assign_staff("s3", 0)
	var view3: Dictionary = board3.get_slot_view(0)
	assert_eq(view3["assigned_count"], 3, "三人上桌成功（上限 3）")
	assert_almost_eq(float(view3["collab_factor"]), 1.08, 0.0001, "三人=最弱配对保守下限 ×1.08")
	assert_eq(view3["collab_kind"], CollabFactor.KIND_ADJACENT, "三人角标=最弱档相邻")


## ---------- 夹具 ----------


## TaskBoard 夹具：员工全已知可派；岗位键=初始名册真源同源映射
func _make_board(staff_table: Dictionary) -> TaskBoard:
	var board := TaskBoard.new()
	board.is_staff_known = func(staff_id: String) -> bool: return _role_of(staff_id) != ""
	board.is_staff_assignable = func(staff_id: String) -> bool: return _role_of(staff_id) != ""
	board.get_staff_role_key = func(staff_id: String) -> String: return _role_of(staff_id)
	board.staff_table = staff_table
	return board


## 员工→岗位映射（与 staff.json staff_initial_roster 同源；测试夹具行内直存）
func _role_of(staff_id: String) -> String:
	match staff_id:
		"s1":
			return "research"
		"s2":
			return "eval"
		"s3":
			return "data"
		_:
			return "engineering"
