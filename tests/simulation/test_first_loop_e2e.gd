extends GutTest
## #153 教学节拍 W1-W13 端到端对齐（numerics-master §〇 唯一时钟）。
## - test_first_loop_full_run：新局种子 → 装配 L2 全链真实系统 → W1-W13 周结推进
##   → 六步目标卡全部达成且无空等（达成周 ≤ 节拍锚，护栏逐条复算）；
## - test_calendar_sync：W13 季度大赏与竞对首发不同周（time/rivals/onboarding 三表同源）。
## 装配纪律：全部真实表驱动（economy/papers/tech_tree/models/rivals/staff），零假表；
## Settlement 模型侧路由与 phase 7c/7 推进由本编排按 architecture §5.3 相位顺序显式
## 调用（World 装配批的先期等价物）；引导谓词只读世界数据面（PaperArchive/RivalPack
## 视图/ModelLibrary 计数/TaskBoard 槽位），零直接写玩法状态。
## RefCounted 全链；headless 可单测（tests/simulation/ 归档，ADR-0029 主链模拟方向）。

const ONBOARDING_PATH: String = "res://src/data/onboarding.json"
const PAPERS_PATH: String = "res://src/data/papers.json"
const ECONOMY_PATH: String = "res://src/data/economy.json"
const TECH_TREE_PATH: String = "res://src/data/tech_tree.json"
const MODELS_PATH: String = "res://src/data/models.json"
const TIME_PATH: String = "res://src/data/time.json"
const STAFF_PATH: String = "res://src/data/staff.json"
const RIVALS_PATH: String = "res://src/data/rivals.json"
## 教学节拍基准种子（rng 域登记制：固定种子=同局可复现，ADR-0008）
const START_SEED: int = 20260910
## 教学首节点（onboarding W1 点树锚：align 域解锁型=浅 2 周研究）
const FIRST_NODE_ID: String = "align_rlhf_align"

var _world: Dictionary = {}


func before_each() -> void:
	_world = _build_world()


func after_each() -> void:
	_world = {}


## ---------- 验收点 1：W1-W13 六步全达成且无空等 ----------


func test_first_loop_full_run() -> void:
	var machine: TutorialMachine = _world["machine"]
	var card: GoalCard = _world["card"]
	var expected := card.get_expected_weeks()
	watch_signals(machine)
	# 达成记录：{步序: 首次达成周}（信号载荷 step_index/week 双取）
	var step_weeks: Dictionary = {}
	var fired_order: Array[int] = []
	machine.step_advanced.connect(
		func(payload: Dictionary) -> void:
			var step_index := int(payload["step_index"])
			if not step_weeks.has(step_index):
				step_weeks[step_index] = int(payload["week"])
			fired_order.append(step_index)
	)
	var errors: Array[Dictionary] = []
	machine.onboarding_error.connect(func(payload: Dictionary) -> void: errors.append(payload))
	# W1..W13 推进（教学剧本：W1 接单+点树 / W4 排训练+指派 / 命名即时响应）
	for week: int in range(1, 14):
		_player_turn(week)
		_settle_week(week)
		machine.advance_check(week)
	# 六步全部达成（信号序=状态机扫描序，payload step_index 严格升序）
	assert_eq(machine.get_progress()["all_done"], true, "六步目标卡全部达成")
	assert_eq(machine.get_progress()["completed_count"], 6)
	assert_signal_emit_count(machine, "chain_completed", 1, "链完成恰一次")
	assert_eq(fired_order, [0, 1, 2, 3, 4, 5] as Array[int], "点亮顺序=六步序")
	# 无空等：每步达成周 ≤ 教学节拍锚（早于锚=提前达成，不算空等）
	for i: int in 6:
		assert_true(
			int(step_weeks[i]) <= expected[i],
			"步 %d 达成周 %d ≤ 锚 %d（无空等）" % [i, int(step_weeks[i]), expected[i]],
		)
	# 护栏复算（端到端实测值须落 numerics §〇 区间）
	var lit_week: int = int(step_weeks[1])
	assert_between(lit_week, 2, 4, "首节点 lit 周 ∈[W2,W4]（实测 W%d）" % lit_week)
	var rival_week: int = int(step_weeks[5])
	assert_true(rival_week >= expected[4] + 2, "首对手 ≥ 出分+2 周（先出分再守卫）")
	# 错误态零发生（引导自检全程健康）
	assert_eq(errors.size(), 0, "全程零 onboarding_error")
	# 资源链健康：全程不破产不透支
	var resources: Resources = _world["resources"]
	assert_true(resources.get_cash() > 0, "W13 末现金为正（防开局即死护栏）")


## ---------- 验收点 2：W13 季度大赏不撞竞对（三表日历同源） ----------


func test_calendar_sync() -> void:
	var time_table := DataLoader.load_json(TIME_PATH)
	var rivals_table := DataLoader.load_json(RIVALS_PATH)
	var onboarding := DataLoader.load_json(ONBOARDING_PATH)
	var clock := GameClock.new(time_table)
	assert_true(clock.is_config_ok(), "time.json 装配 GameClock 成功")
	# W13=首个季度大赏（日历行与表同源）
	var rows: Array = clock.get_ritual_rows_for_week(13)
	assert_false(rows.is_empty(), "W13 有仪式行")
	assert_eq(int(rows[0]["ritual"]), int(CoreEnums.RitualType.QUARTER_AWARD), "W13=季度大赏")
	# 大赏周=13 整除序列（time_week_per_quarter 派生同源）
	for award_week: Variant in time_table["time_ritual_no_overlap"]["quarter_award_weeks"]:
		assert_eq(
			int(award_week) % int(time_table["time_week_per_quarter"]),
			0,
			"大赏周 %s = 13 整除" % str(award_week),
		)
	# 深巷全时间线 ∩ 大赏周 = ∅（错峰；W13 季度大赏不撞竞对）
	var timeline: Array = (
		((rivals_table["rival_actors"] as Dictionary)["deep_alley"] as Dictionary)["timeline"]
		as Array
	)
	var award_weeks: Array = time_table["time_ritual_no_overlap"]["quarter_award_weeks"]
	for entry: Variant in timeline:
		assert_false(
			award_weeks.has(int((entry as Dictionary)["week"])),
			"竞对动作周 %s 不撞大赏周" % str((entry as Dictionary)["week"]),
		)
	# onboarding 镜像键 == rivals 真源（三表同源核对）
	assert_eq(
		int(onboarding["onb_first_rival_week"]),
		int((timeline[0] as Dictionary)["week"]),
		"首对手周镜像=深巷 timeline 首行",
	)
	# 端到端：竞对时间线 13 周推进——W10 首发论文触发、W13 大赏周零动作
	var pack: RivalPack = _world["pack"]
	var paper_week := 0
	var fired_w13: Array = []
	for week: int in range(1, 14):
		var fired: Array = pack.advance_all(week, false)
		if week == 13:
			fired_w13 = fired
		for payload: Variant in fired:
			if str((payload as Dictionary).get("action", "")) == "paper" and paper_week == 0:
				paper_week = week
	assert_eq(paper_week, 10, "首对手 paper 动作触发于 W10（timeline 表驱动）")
	assert_eq(fired_w13.size(), 0, "W13 大赏周零竞对动作")


## ---------- 世界装配（真实表全链；World 装配批的先期等价物） ----------


func _build_world() -> Dictionary:
	var world := {}
	var rng := RngStream.new()
	rng.setup(START_SEED)
	world["rng"] = rng
	var economy_table := DataLoader.load_json(ECONOMY_PATH)
	var resources := Resources.new(
		int(economy_table["eco_startup_cash"]), int(economy_table["eco_startup_influence"])
	)
	# 周卡时供给=T0 档位（chips.json 表驱动；World 装配批接 ChipYard 前的等价注入）
	var chips_table := DataLoader.load_json("res://src/data/chips.json")
	var t0_supply := int(((chips_table["chip_tiers"] as Dictionary)["t0"] as Dictionary)["supply"])
	resources.weekly_supply_provider = func() -> int: return t0_supply
	world["resources"] = resources
	world["ledger"] = Ledger.new(1)
	world["economy"] = Economy.new()
	var roster := Roster.new(DataLoader.load_json(STAFF_PATH), rng)
	world["roster"] = roster
	var board := TaskBoard.new()
	board.is_staff_known = func(staff_id: String) -> bool: return roster.is_assignable(staff_id)
	board.is_staff_assignable = func(staff_id: String) -> bool:
		return roster.is_assignable(staff_id)
	board.get_staff_role_key = func(staff_id: String) -> String:
		return Staff.role_to_key(roster.get_staff(staff_id).get_role())
	board.staff_table = DataLoader.load_json(STAFF_PATH)
	board.tier_met = func(_tier: String) -> bool: return true
	board.budget_met = func(hours: int) -> bool:
		return resources.get_card_hours_remaining() >= hours
	board.consume_card_hours = func(hours: int) -> bool:
		return bool(resources.consume_card_hours(hours).get("ok", false))
	world["board"] = board
	world["archive"] = PaperArchive.new()
	world["library"] = ModelLibrary.new()
	world["sota"] = SotaBoard.new()
	var ceremony := ModelCeremony.new(world["library"], world["sota"])
	ceremony.release_slot = func(slot: int) -> void: board.release_finished_slot(slot)
	world["ceremony"] = ceremony
	var tree := TechTree.new(DataLoader.load_json(TECH_TREE_PATH), rng)
	var research := tree.get_research()
	research.spend_influence = func(amount: int) -> bool: return resources.spend_influence(amount)
	world["tree"] = tree
	world["pool"] = PaperPool.new()
	world["pack"] = RivalPack.new()
	world["fired_by_week"] = {}
	world["rival_paper_week"] = 0
	var machine := TutorialMachine.new()
	machine.is_task_started = func() -> bool: return _task_started(world)
	machine.is_tree_lit = func() -> bool: return _node_lit(world)
	machine.is_influence_stocked = func() -> bool: return _influence_stocked(world)
	machine.is_train_started = func() -> bool: return _train_started(world)
	machine.is_score_named = func() -> bool: return world["library"].count() >= 1
	machine.is_rival_arrived = func() -> bool: return _rival_seen(world)
	world["machine"] = machine
	world["card"] = GoalCard.new(machine)
	return world


## 引导谓词=只读世界数据面（禁写玩法状态）
func _task_started(world: Dictionary) -> bool:
	var board: TaskBoard = world["board"]
	for slot: int in board.get_slot_count():
		var project := board.get_project(slot)
		if project != null and project.get_type() == CoreEnums.ProjectType.PAPER:
			return true
	return world["archive"].count() > 0


func _node_lit(world: Dictionary) -> bool:
	return bool(world["tree"].get_research().is_lit.call(FIRST_NODE_ID))


func _influence_stocked(world: Dictionary) -> bool:
	# 攒够影响力=首任务影响力产出已入台账（papers.json 表驱动阈值）
	var papers_table := DataLoader.load_json(PAPERS_PATH)
	var threshold := int((papers_table["paper_influence"] as Dictionary)["repro"])
	var total := 0
	for entry: Dictionary in (world["archive"] as PaperArchive).get_all_entries():
		total += int(entry["influence"])
	return total >= threshold


func _train_started(world: Dictionary) -> bool:
	var board: TaskBoard = world["board"]
	for slot: int in board.get_slot_count():
		var project := board.get_project(slot)
		if project != null and project.get_type() == CoreEnums.ProjectType.MODEL:
			return true
	return false


func _rival_seen(world: Dictionary) -> bool:
	var view: Dictionary = (world["pack"] as RivalPack).get_rival_view("deep_alley")
	return int(view.get("timeline_consumed", 0)) > 0


## ---------- 周推进（architecture §5.3 相位顺序的编排等价物） ----------


func _player_turn(week: int) -> void:
	var world := _world
	var board: TaskBoard = world["board"]
	# W1 接单：align 域首题入槽（教学第一课=复现）
	if week == 1:
		var pool: PaperPool = world["pool"]
		var topics := pool.get_topics_in_domain("align")
		assert_false(topics.is_empty(), "align 域有题可接")
		assert_eq(board.start_paper(PaperProject.from_topic(topics[0]))["ok"], true, "首任务入槽")
		# W1 点树（OP-ONB-04）：目标卡高亮首节点行=引导期翻雾两档（hidden→rumored→
		# visible）+研究启动。教学兜底翻雾=新手直开语义（rng 翻雾通路节奏 0.25/pity6
		# 无法保底 W1，引导期保底归 World 装配批裁决——本单锁定节拍可走通）
		var tree: TechTree = world["tree"]
		assert_eq(tree.advance_fog(FIRST_NODE_ID), true, "翻雾 hidden→rumored")
		assert_eq(tree.advance_fog(FIRST_NODE_ID), true, "翻雾 rumored→visible")
		var start_result: Dictionary = tree.start_research(FIRST_NODE_ID)
		assert_eq(bool(start_result.get("ok", false)), true, "W1 研究启动（开局即够研究首节点）")
	# W4 排训练：首任务结算释放槽（W3 完成）后迷你基座入槽+指派研究员
	if week == 4:
		var models_table := DataLoader.load_json(MODELS_PATH)
		var mini: Dictionary = (models_table["model_bases"] as Dictionary)["mini"]
		var project := ModelProject.from_base(mini)
		var start_result: Dictionary = board.start_training(project)
		assert_eq(bool(start_result.get("ok", false)), true, "首训练入槽（迷你基座）")
		if bool(start_result.get("ok", false)):
			var roster: Roster = world["roster"]
			assert_eq(
				board.assign_staff(roster.get_staff_ids()[0], int(start_result["slot_index"])),
				CoreEnums.SlotRejectReason.NONE,
				"首指派上桌",
			)


func _settle_week(week: int) -> void:
	var world := _world
	var settlement: Settlement = world.get("settlement")
	if settlement == null:
		settlement = Settlement.new(
			world["ledger"], world["resources"], world["economy"], world["board"], world["archive"]
		)
		world["settlement"] = settlement
	var result: Dictionary = settlement.run_settle(week)
	assert_false(bool(result.get("bankrupt", false)), "W%d 结算不破产" % week)
	# 模型完成路由（architecture §5.3：Settlement 留 FINISHED_PENDING，仪式批
	# 扫描完成槽消费——模型载荷不携 project/slot，扫描=装配方唯一正确姿势）
	var board: TaskBoard = world["board"]
	for slot: int in board.get_slot_count():
		if board.get_slot_state(slot) != CoreEnums.ProjectState.FINISHED_PENDING:
			continue
		var project := board.get_project(slot)
		if project != null and project.get_type() == CoreEnums.ProjectType.MODEL:
			_route_model_finished(project as ModelProject, slot, week)
	# phase 7c 研究推进（周结点亮）
	var tree: TechTree = world["tree"]
	tree.research_tick()
	# phase 7 竞对推进（时间线按周消费；载荷按周归档）
	var fired: Array = (world["pack"] as RivalPack).advance_all(week, false)
	var by_week: Dictionary = world["fired_by_week"]
	by_week[week] = fired
	for payload: Variant in fired:
		if str((payload as Dictionary).get("action", "")) == "paper":
			world["rival_paper_week"] = week
	# 仪式命名（首模型=署名仪式，pending 即响应）
	var ceremony: ModelCeremony = world["ceremony"]
	if ceremony.has_pending():
		assert_eq(bool(ceremony.submit_name("测试一号").get("ok", false)), true, "命名入册")


func _route_model_finished(project: ModelProject, slot_index: int, week: int) -> void:
	# 出分载荷：基座画像经 NDims 表驱动合成（员工/树源 0=未接线保守值；节拍断言
	# 不依赖分数值，出分生产链归 #141 World 装配批）
	var models_table := DataLoader.load_json(MODELS_PATH)
	var base_id := project.get_base_id()
	var profile: Dictionary = (
		((models_table["model_bases"] as Dictionary)[base_id] as Dictionary)["ndim_profile"]
		as Dictionary
	)
	var weights: Dictionary = models_table["model_ndim_weight"]
	var score := NDims.weighted_sum(profile, weights)
	var ceremony: ModelCeremony = _world["ceremony"]
	var result: Dictionary = ceremony.settle_finished(
		{
			"project": project,
			"score": score,
			"ndim": profile,
			"week": week,
			"slot_index": slot_index
		}
	)
	assert_eq(bool(result.get("ok", false)), true, "出分仪式进入待命名")
