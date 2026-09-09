extends GutTest
## #131 TaskBoard 任务槽容器 unit 测试（4 个 DoD 用例名逐字落盘 + 细化断言）。
## 被测对象=src/entities/task_board.gd + src/entities/projects/{project,paper_project,
## model_project}.gd，全部 RefCounted（零 Node/SceneTree，headless 毫秒级）。
## 真源：architecture-100 §4.1/§4.4（槽恒 4/三态/命令面/指派写点）+ §8（≤500 行）+
## ADR-0018 + papers-spec §0/验收点 1 + models-spec 六因（#131 侧=容器可判因）。
## 约定：
## - 三类项目=paper/model/compute：compute 以本文件内部类 ComputeStub（同接口
##   最小实例）代表（#131 无 src 改动面；P2 才建 ComputeProject，架构 E5）；
## - 员工=测试假名册（s1..s4 已知全可派、s6 不可派）+ 谓词注入（Roster 由 #130
##   装配；测试侧注入=Roster.assignable_filter 同款"装配方注入"方向，TaskBoard
##   不自持 Roster 引用防环）；
## - 断言全部带中文语义消息；错误分支按 GUT Error Tracker 纪律显式消费。

## 论文式标题键/训练式基座键（本批无真实数据表，#133/#140 起由表给键）
const TITLE_KEY_ALIGN: String = "paper_topic_align_demo"
const BASE_KEY_MINI: String = "model_base_mini_demo"


## 测试内最小算力实例：与 paper/model 同接口（#131 测试面；P2 建真实
## ComputeProject 后本桩可由真实类替换——本桩不入 src、不落改动面）。
class ComputeStub:
	extends Project

	func _init(
		title_key: String, duration_weeks: int, card_hours_per_week: int, seat_limit: int
	) -> void:
		_initialize(
			CoreEnums.ProjectType.COMPUTE,
			title_key,
			duration_weeks,
			card_hours_per_week,
			seat_limit,
		)

	func _on_week_tick() -> void:
		_progress = 1.0 - float(_weeks_remaining) / float(_duration_weeks)


var _known: Array[String] = []


func before_each() -> void:
	# 初始 4 员工已知且全可派（模拟装配 Roster 谓词注入到 TaskBoard）
	_known = ["s1", "s2", "s3", "s4"]


func test_shared_task_slots_three_types() -> void:
	# DoD：三类项目互斥占槽 ≤4、槽恒 4（papers-spec 验收点 1 落盘）
	var board := _make_board()
	assert_eq(board.get_slot_count(), 4, "槽恒 4（架构 §4.1 真源）")
	assert_eq(board.get_empty_slot_count(), 4, "初始 4 空槽")
	# 三型各占 1 槽（paper→0、model→1、compute→2），互斥共用同一批槽
	var paper := _make_paper(2, 1)
	var model := _make_model(3, 2)
	var compute := _make_compute(2, 1)
	assert_true(board.start_paper(paper, 0).ok, "论文入槽（指定槽 0）")
	assert_true(board.start_training(model, 1).ok, "训练入槽（指定槽 1）")
	assert_true(board.start_compute(compute, 2).ok, "算力入槽（指定槽 2，同接口占槽）")
	assert_eq(board.get_empty_slot_count(), 1, "三型各占 1 后剩 1 空槽")
	assert_eq(
		board.get_slot_view(0)["type"],
		CoreEnums.ProjectType.PAPER,
		"槽 0=论文（各槽单项目互斥）",
	)
	assert_eq(
		board.get_slot_view(1)["type"],
		CoreEnums.ProjectType.MODEL,
		"槽 1=训练（互斥）",
	)
	assert_eq(
		board.get_slot_view(2)["type"],
		CoreEnums.ProjectType.COMPUTE,
		"槽 2=算力（互斥）",
	)
	# 第 4 槽占满后，第 5 个项目（含满槽路径）被拒：互斥占槽 ≤4、槽恒 4
	board.start_paper(_make_paper(1, 1), 3)
	assert_eq(board.get_empty_slot_count(), 0, "4 槽全占（≤4 上限边界内）")
	var overflow := _make_paper(1, 1)
	var result: Dictionary = board.start_paper(overflow, 0)
	assert_false(result.ok, "第 5 个项目必须被拒（≤4 上限）")
	assert_eq(
		result["reason"],
		CoreEnums.SlotRejectReason.ALL_SLOTS_FULL,
		"满槽拒绝=单一原因枚举 ALL_SLOTS_FULL",
	)
	assert_eq(board.get_empty_slot_count(), 0, "满槽拒绝不破坏槽（仍 0 空）")
	assert_eq(board.get_slot_count(), 4, "任何时刻槽恒 4（拒绝不增减槽）")
	var views: Array = board.get_task_view()
	assert_eq(views.size(), 4, "任务板视图恒 4 槽")
	# 视图自检：4 槽全占且三型均至少 1（互斥=槽位独占，同型多槽合法）
	var type_seen: Dictionary = {}
	for view: Dictionary in views:
		var slot_type: int = int(view["type"])
		assert_true(
			(
				slot_type == CoreEnums.ProjectType.PAPER
				or (
					slot_type == CoreEnums.ProjectType.MODEL
					or slot_type == CoreEnums.ProjectType.COMPUTE
				)
			),
			"满槽后每槽都有真实项目类型（无空槽哨兵）",
		)
		type_seen[slot_type] = true
	assert_eq(type_seen.size(), 3, "论文/训练/算力三类同批共槽（互斥占槽语义）")


func test_train_blocked_single_reason_source() -> void:
	# DoD：满槽/六因拒绝各显单一原因（#131 侧=TaskBoard 容器可判因集；models-spec
	# 六因清单=无在岗/算力档/资金/上桌人数/本周卡时/槽满——装配侧全矩阵依赖
	# models.json+#139+#140，#140 用例同名收口；本批=容器可判因落盘，边界注释声明）
	var board := _make_board()
	board.start_training(_make_model(2, 2), 0)  # 训练：seat 2
	board.start_paper(_make_paper(2, 1), 1)
	# 上桌满员：s1/s2 坐满训练槽后，s3 被拒=单一原因 SEAT_LIMIT_REACHED
	assert_eq(board.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "s1 上桌训练槽成功")
	assert_eq(board.assign_staff("s2", 0), CoreEnums.SlotRejectReason.NONE, "s2 上桌成功（满 2 人）")
	assert_eq(
		board.assign_staff("s3", 0),
		CoreEnums.SlotRejectReason.SEAT_LIMIT_REACHED,
		"上桌人数超项目上限=单一原因 SEAT_LIMIT_REACHED（上限来自 Project 声明）",
	)
	# 上桌满员时其他可叠加因（如不可派）不掺入：只出满员因（单因不拼接）。
	# s6 已知但不可派（谓词 s6 恒 false）——满员槽已坐满 2 人时再派必满员；
	# 但 s6 不可派本身在校验序中先于满员命中 → 报 NOT_ASSIGNABLE（单因语义）。
	_known.append("s6")
	assert_eq(
		board.assign_staff("s6", 0),
		CoreEnums.SlotRejectReason.STAFF_NOT_ASSIGNABLE,
		"不可派员工先于满员校验命中=STAFF_NOT_ASSIGNABLE（校验序单因）",
	)
	# 全槽满后的训练入槽拒绝：满槽=单一原因 ALL_SLOTS_FULL（六因之一）
	board.start_paper(_make_paper(1, 1), 2)
	board.start_paper(_make_paper(1, 1), 3)
	var denied: Dictionary = board.start_training(_make_model(2, 2), 0)
	assert_false(denied.ok, "槽满时训练入槽被拒")
	assert_eq(
		denied["reason"],
		CoreEnums.SlotRejectReason.ALL_SLOTS_FULL,
		"满槽拒绝=单一原因枚举（六因之一）",
	)
	# 完成待结算槽不可指派（NO_RUNNING_PROJECT 单一因；先推完 1 周期项目）
	board.week_tick()
	assert_eq(
		board.assign_staff("s1", 3),
		CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT,
		"已完成槽不可指派=NO_RUNNING_PROJECT（FINISHED_PENDING 归 #143 仪式消费释放）",
	)


func test_project_polymorphic_interface() -> void:
	# DoD：Project 抽象基类：论文/训练/算力同接口（进度/周耗/上桌/协作/结算）
	var paper: Project = _make_paper(3, 1)
	var model: Project = _make_model(3, 2)
	var compute: Project = _make_compute(3, 1)
	var projects: Array[Project] = [paper, model, compute]
	# 接口三件套 + 结算声明接口，三型逐一同构断言（多态=统一句柄驱动）
	for project: Project in projects:
		var type_key: String = Project.type_to_key(project.get_type())
		assert_true(project.is_running(), "新项目=IN_PROGRESS（%s）" % type_key)
		assert_eq(project.get_weeks_remaining(), 3, "工期周定值=构造注入（%s）" % type_key)
		assert_true(project.get_card_hours_per_week() >= 1, "周耗卡时接口有值（%s）" % type_key)
		assert_true(project.get_seat_limit() >= 1, "上桌上限接口有值（%s）" % type_key)
		assert_eq(project.get_collab_factor(), 1.0, "协作系数接口=默认 1.0（%s）" % type_key)
		assert_almost_eq(project.get_progress(), 0.0, 0.001, "初始进度 0（%s）" % type_key)
		assert_true(
			project.produce_settlement_declaration() is Dictionary,
			"结算声明接口=产出对象（本批空声明体，#135 Settlement 按型路由）",
		)
	# 统一推进（多态核心）：三类全经 week_tick() 同一钩子推进到完成
	var runners: Array[Project] = projects.duplicate()
	var ticks: int = 0
	while not runners.is_empty():
		ticks += 1
		var still: Array[Project] = []
		for project: Project in runners:
			assert_true(project.week_tick(), "周结推进钩子可调用（第 %d 周）" % ticks)
			if project.is_running():
				still.append(project)
			else:
				assert_true(project.is_finished_pending(), "完成→FINISHED_PENDING")
				assert_almost_eq(project.get_progress(), 1.0, 0.001, "完成时进度冻结 1.0")
		runners = still
	assert_eq(ticks, 3, "工期=3 周定值：恰好 3 次推进全部完成（零多推）")
	for project: Project in projects:
		assert_false(project.week_tick(), "已完成项目不再推进（零多余推进）")
	# 抽象基类防线：直接 new Project=不可用实例（伪 abstract 语义）
	var raw_project := Project.new()
	assert_false(raw_project.is_running(), "直接实例化抽象基类=不可用实例")
	assert_push_error(
		"Project: 抽象基类不可直接实例化（子类经 _initialize() 初始化）",
		"直接 new Project 必须有构造错误（Error Tracker 消费）",
	)


func test_assign_single_write_point() -> void:
	# DoD：指派写点=槽成员（防双真源）：指派只经 TaskBoard
	# 三个断言面（架构 §4.1/ADR-0018 + #130 Roster 无在岗字段 + 双向一致性）：
	# A) 指派命令只经 TaskBoard（容器侧唯一写点）
	# B) Staff/Roster 无在岗写点：员工定义/视图无"在岗项目"字段，只出谓词
	# C) 槽成员 id 列表只读面=深拷贝；反查/聚合与槽成员一致
	var board := _make_board()
	var model := _make_model(2, 2)
	board.start_training(model, 0)
	board.start_paper(_make_paper(2, 1), 1)
	# A：指派命令走 TaskBoard.assign_staff（成员列表=唯一写点）
	assert_eq(board.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "指派命令在 TaskBoard 上执行成功")
	# B：员工视图/定义无在岗字段（防双真源：#130 Staff 只有属性/状态，无指派写点；
	# "在岗：<项目>"=World 遍历槽反查，架构 §4.1）
	var definition: Dictionary = _staff_definition()
	assert_false(
		definition.has("assigned_slot") or definition.has("current_project"),
		"员工定义无在岗项目字段（指派写点不在员工侧）",
	)
	# C1：槽成员只读面=深拷贝（防篡改内部）
	assert_eq(board.get_assigned_staff(0), ["s1"], "槽 0 成员列表=唯一写点产物")
	var tampered: Array = board.get_assigned_staff(0)
	tampered.clear()
	tampered.append("s9")
	assert_eq(board.get_assigned_staff(0), ["s1"], "篡改外部拷贝不影响槽成员")
	# C2：反查/聚合同源（World 聚合 view=遍历槽反查，无 Roster 第二份）
	assert_eq(board.get_slot_of_staff("s1"), 0, "s1 所在槽=0（反查）")
	assert_eq(
		board.get_slot_of_staff("s2"),
		TaskBoard.INVALID_SLOT_INDEX,
		"未上桌员工反查为空",
	)
	assert_eq(board.get_all_assigned_staff(), ["s1"], "全槽成员聚合=各槽成员并集")
	# C3：双向一致性断言（ADR-0018 后果）：每员工至多在一槽
	board.assign_staff("s2", 0)
	board.assign_staff("s3", 1)
	assert_eq(
		board.assign_staff("s3", 0),
		CoreEnums.SlotRejectReason.STAFF_ON_OTHER_SLOT,
		"跨槽重复指派被拒（每员工至多一槽断言）",
	)
	assert_eq(
		board.assign_staff("s1", 0),
		CoreEnums.SlotRejectReason.STAFF_ALREADY_ASSIGNED,
		"同槽重复指派被拒",
	)
	# 撤派=唯一写点反向操作（成员删除）
	assert_eq(
		board.unassign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "撤派命令在 TaskBoard 上执行成功"
	)
	assert_eq(board.get_assigned_staff(0), ["s2"], "撤派后槽成员=剩余成员（写点单一）")
	assert_eq(
		board.unassign_staff("s1", 0),
		CoreEnums.SlotRejectReason.UNASSIGN_NOT_ON_TABLE,
		"撤派不在桌员工=UNASSIGN_NOT_ON_TABLE",
	)


## ---------- 细化断言（规则完备性；非 DoD 名，契约面/防御面） ----------


func test_task_board_week_tick_advances_and_pins_finished() -> void:
	# 周结推进：TaskBoard.week_tick 逐槽驱动；完成→FINISHED_PENDING 且槽不自动
	# 释放（显式 release_finished_slot 归消费方：#143 模型仪式/#149 论文批）——
	# 架构 §5.3 phase 2 落点
	var board := _make_board()
	board.start_training(_make_model(2, 1), 0)
	board.start_paper(_make_paper(3, 1), 1)
	var finished: Array = board.week_tick()
	assert_true(finished.is_empty(), "第 1 周无项目完成")
	assert_eq(board.get_slot_view(0)["weeks_left"], 1, "训练剩 1 周")
	assert_eq(board.get_slot_view(1)["weeks_left"], 2, "论文剩 2 周")
	assert_eq(board.get_slot_view(0)["eta_weeks"], 1, "预计结账 Wx=剩余周（数据面同源）")
	finished = board.week_tick()
	assert_eq(finished.size(), 1, "第 2 周训练完成 1 件")
	var first: Dictionary = finished[0]
	assert_eq(int(first["slot_index"]), 0, "完成槽=0")
	assert_eq(int(first["type"]), CoreEnums.ProjectType.MODEL, "完成类型=训练")
	var completed: Project = first["project"]
	assert_true(completed.is_finished_pending(), "完成项目=FINISHED_PENDING")
	assert_eq(
		board.get_slot_state(0),
		CoreEnums.ProjectState.FINISHED_PENDING,
		"完成槽状态=FINISHED_PENDING（未释放，等待仪式消费 #143）",
	)
	assert_false(board.is_slot_empty(0), "FINISHED_PENDING 槽不可复用（防结算前覆写）")
	assert_true(
		(board.get_slot_view(0)["assigned_staff"] as Array).is_empty(),
		"本批完成槽成员为空（无指派发生；载荷透出由仪式批 #143 接）",
	)
	assert_eq(board.get_empty_slot_count(), 2, "推进不增减槽（恒 4：2 跑 1 完 1 空）")
	assert_eq(board.get_slot_count(), 4, "周推进后槽恒 4")


func test_cancel_and_prefer_slot_semantics() -> void:
	# 取消=EMPTY 可复用；指定被占槽时自动落首空槽（防覆写）；越界=防御拒绝
	var board := _make_board()
	board.start_paper(_make_paper(2, 1), 0)
	assert_eq(board.cancel_project(0), CoreEnums.SlotRejectReason.NONE, "取消进行中项目成功")
	assert_true(board.is_slot_empty(0), "取消后槽回 EMPTY 可复用")
	assert_eq(
		board.cancel_project(0),
		CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT,
		"空槽无可取消=NO_RUNNING_PROJECT",
	)
	board.start_paper(_make_paper(2, 1), 0)
	# 指定已被占用的槽 → 不覆写，自动回落首空槽（防占槽事故）
	var second := _make_paper(2, 1)
	var result: Dictionary = board.start_paper(second, 0)
	assert_true(result.ok, "指定槽被占时自动取空槽（不被拒）")
	assert_eq(int(result["slot_index"]), 1, "自动落首空槽 1")
	board.start_paper(_make_paper(2, 1), 1)
	assert_eq(board.get_empty_slot_count(), 1, "三槽占后剩 1")
	# 越界/非法槽=防御性拒绝（返回码/空视图，不抛错）
	assert_eq(
		board.assign_staff("s1", 9),
		CoreEnums.SlotRejectReason.SLOT_OUT_OF_RANGE,
		"越界槽指派=SLOT_OUT_OF_RANGE",
	)
	assert_eq(
		board.cancel_project(-1),
		CoreEnums.SlotRejectReason.SLOT_OUT_OF_RANGE,
		"越界槽取消=SLOT_OUT_OF_RANGE",
	)
	assert_true(board.get_slot_view(9).is_empty(), "越界槽视图=空 dict")
	assert_eq(board.get_assigned_staff(9), [] as Array[String], "越界槽成员=空数组")
	assert_eq(
		board.get_slot_of_staff("s1"),
		TaskBoard.INVALID_SLOT_INDEX,
		"s1 未上过任何槽→反查空（防'取消隐含撤派'误解）",
	)


func test_reject_reason_is_single_source_code() -> void:
	# 拒绝原因=enum 单一源：不出现字符串原因/拼接；各路径恰返回一码
	var board := _make_board()
	board.start_paper(_make_paper(2, 2), 0)
	board.start_paper(_make_paper(2, 1), 1)
	assert_eq(
		board.assign_staff("ghost", 0),
		CoreEnums.SlotRejectReason.STAFF_UNKNOWN,
		"未知员工=STAFF_UNKNOWN（谓词注入防线）",
	)
	# s6 已知但不可派 → STAFF_NOT_ASSIGNABLE（存在性先过，可派性单因）
	_known.append("s6")
	assert_eq(
		board.assign_staff("s6", 0),
		CoreEnums.SlotRejectReason.STAFF_NOT_ASSIGNABLE,
		"不可派员工=STAFF_NOT_ASSIGNABLE（谓词注入防线）",
	)
	assert_eq(
		board.assign_staff("s1", 0),
		CoreEnums.SlotRejectReason.NONE,
		"正常指派=通过（NONE）",
	)
	assert_eq(
		board.assign_staff("s1", 0),
		CoreEnums.SlotRejectReason.STAFF_ALREADY_ASSIGNED,
		"同槽重复=STAFF_ALREADY_ASSIGNED（先于满员校验的单因）",
	)
	# 完成槽不可指派（NO_RUNNING_PROJECT）
	board.start_paper(_make_paper(1, 1), 2)
	board.start_paper(_make_paper(1, 1), 3)
	board.week_tick()
	board.week_tick()
	assert_eq(
		board.assign_staff("s2", 2),
		CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT,
		"完成待结算槽不可指派（FINSHED_PENDING 槽由 #135 释放）",
	)


func test_task_board_changed_signal_reachable() -> void:
	# task_board_changed 真实发射点（架构 §5.2：每信号至少一发射点+消费点）
	var board := _make_board()
	var changes: Array = []
	board.task_board_changed.connect(func(change: Dictionary) -> void: changes.append(change))
	board.start_paper(_make_paper(2, 1), 0)
	board.assign_staff("s1", 0)
	board.week_tick()
	board.unassign_staff("s1", 0)
	board.cancel_project(0)
	assert_true(changes.size() >= 5, "入槽/指派/推进/撤派/取消各发一次（发射点可达）")
	var kinds: Array = []
	for change: Dictionary in changes:
		kinds.append(change["kind"])
	assert_true(kinds.has("started"), "载荷含入槽事件")
	assert_true(kinds.has("assigned"), "载荷含指派事件")
	assert_true(kinds.has("progressed"), "载荷含周推进事件")
	assert_true(kinds.has("unassigned"), "载荷含撤派事件")
	assert_true(kinds.has("cancelled"), "载荷含取消事件")


func test_task_view_is_deep_copy() -> void:
	# 数据面深拷贝：篡改外部 view 不影响内部状态（ADR-0016 防越权）
	var board := _make_board()
	board.start_paper(_make_paper(2, 1), 0)
	board.assign_staff("s1", 0)
	var view: Array = board.get_task_view()
	var slot0: Dictionary = view[0]
	var tampered: Array = slot0["assigned_staff"]
	tampered.clear()
	tampered.append("s9")
	var again: Array = board.get_task_view()
	assert_eq(again[0]["assigned_staff"], ["s1"], "篡改外部视图成员不影响内部")


## ---------- 夹具 ----------


func _make_board() -> TaskBoard:
	var board := TaskBoard.new()
	# 装配注入=名册谓词（#130 同款方向：Roster 只出谓词不写状态；TaskBoard 不自持
	# Roster 引用防环）。默认 4 员工全可派；s6=不可派示例员工。
	board.is_staff_known = func(staff_id: String) -> bool: return _known.has(staff_id)
	board.is_staff_assignable = func(staff_id: String) -> bool: return staff_id != "s6"
	return board


func _make_paper(duration_weeks: int, card_hours_per_week: int) -> PaperProject:
	# 论文默认 seat 2（协作语义 #132 用）；标题键=表占位（#133 起真实选题池键）
	return PaperProject.new(TITLE_KEY_ALIGN, duration_weeks, card_hours_per_week, 2)


func _make_model(duration_weeks: int, seat_limit: int) -> ModelProject:
	# 训练式=基座型项目：周耗取 2（#140 起 models.json 基座表驱动）
	return ModelProject.new(BASE_KEY_MINI, BASE_KEY_MINI, duration_weeks, 2, seat_limit)


func _make_compute(duration_weeks: int, card_hours_per_week: int) -> ComputeStub:
	return ComputeStub.new("compute_demo", duration_weeks, card_hours_per_week, 2)


func test_release_finished_slot_only_after_settle() -> void:
	# #143 release_finished_slot：完成槽经结算消费后回 EMPTY 可复用（防 4 槽
	# 死局）；运行中/空槽拒绝释放（防结算前覆写语义=cancel 区分）
	var board := _make_board()
	board.start_training(_make_model(2, 1), 0)
	# 运行中槽=拒绝释放（release 只对 FINISHED_PENDING）
	assert_false(board.release_finished_slot(0), "运行中槽拒绝释放")
	board.week_tick()
	board.week_tick()
	assert_eq(
		board.get_slot_state(0), CoreEnums.ProjectState.FINISHED_PENDING, "完成后=FINISHED_PENDING"
	)
	# 空槽释放=拒绝
	assert_false(board.release_finished_slot(2), "空槽拒绝释放")
	assert_false(board.release_finished_slot(9), "越界槽拒绝释放")
	# 完成槽释放成功=回 EMPTY 可复用
	assert_true(board.release_finished_slot(0), "完成槽释放成功")
	assert_true(board.is_slot_empty(0), "释放后槽回 EMPTY 可复用")
	assert_eq(board.get_empty_slot_count(), 4, "释放后空槽恢复 4（防死局）")
	# 再释放已完成释放的槽=拒绝（非 FINISHED_PENDING）
	assert_false(board.release_finished_slot(0), "已释放槽再释放=拒绝")


func _staff_definition() -> Dictionary:
	return {
		"id": "s1",
		"name": "测试员",
		"role": "research",
		"attrs": {"theory": 50, "engineering": 50, "data": 50, "communication": 50},
		"state": "focus",
	}
