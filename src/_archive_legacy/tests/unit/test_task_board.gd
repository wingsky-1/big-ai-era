extends GutTest

## #104（P0 玩家入口）任务板专项测试（需求 §2.3 RT-01 / §1.3；issue #101 一并覆盖）：
## 1. test_task_rows_match_tasks_json        —— 行 = enabled 任务，名称/数值取自数据表（L3 零硬编码）
## 2. test_blocked_reason_single_source      —— 可接性/原因与 TaskQueue.can_enqueue 单点一致（ADR-0014）
## 3. test_zero_cost_task_allowed_when_money_negative —— #101：资金转负仍可接零成本任务
## 4. test_enqueue_rejects_duplicate         —— 去重：进行中/已排队不可重复入队
## 5. test_enqueue_charges_once              —— 连点接单只扣一次成本（刷钱漏洞封堵）
## 6. test_workspace_active_task_visible     —— 接单后工作区显示任务名/进度（P0-4 修复）
## 7. test_tasks_json_has_display_name       —— 数据契约：每个任务必须有 name（显示名真源）

const TASKS_PATH: String = "res://src/data/tasks.json"
const SEED: int = 104


func test_tasks_json_has_display_name() -> void:
	var tasks_cfg: Dictionary = DataLoader.load_json(TASKS_PATH)
	for task_id: String in tasks_cfg:
		assert_true(tasks_cfg[task_id].has("name"), "tasks.json %s 必须有 name（显示名真源）" % task_id)
		assert_false(
			str(tasks_cfg[task_id]["name"]).is_empty(), "tasks.json %s name 不得为空" % task_id
		)


func test_task_rows_match_tasks_json() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var view: Dictionary = world.get_task_board_view()
	var tasks_cfg: Dictionary = DataLoader.load_json(TASKS_PATH)
	var enabled_count: int = 0
	for task_id: String in tasks_cfg:
		if bool(tasks_cfg[task_id].get("enabled", false)):
			enabled_count += 1
	assert_gt(enabled_count, 0, "tasks.json 应有 enabled 任务")
	assert_eq((view["rows"] as Array).size(), enabled_count, "任务板行数 = enabled 任务数")
	for row_variant: Variant in view["rows"]:
		var row: Dictionary = row_variant
		var cfg: Dictionary = tasks_cfg[str(row["task_id"])]
		assert_eq(str(row["name"]), str(cfg["name"]), "任务名取自 tasks.json.name（L3 不硬编码）")
		assert_true(
			str(row["meta_text"]).contains(str(int(cfg["duration_weeks"]))),
			"元信息应含工期（%s）" % str(row["task_id"])
		)
		assert_false(str(row["state_text"]).is_empty(), "每行必须有状态/原因文案")
	assert_false(str(view["entry_label"]).is_empty(), "入口按钮文案由 L2 出数")
	assert_false(str(view["close_label"]).is_empty(), "关闭按钮文案由 L2 出数")


func test_blocked_reason_single_source() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	# 资金不足：task_grant_pilot 有 cost（数据表真源）
	var pilot_cost: int = int(DataLoader.load_json(TASKS_PATH)["task_grant_pilot"]["cost"])
	assert_gt(pilot_cost, 0, "task_grant_pilot 应有成本（资金门用例前提）")
	world.economy.init_resources(0, 0, 1, 0.0)
	var view: Dictionary = world.get_task_board_view()
	var pilot_row: Dictionary = _row_of(view, "task_grant_pilot")
	assert_false(bool(pilot_row["available"]), "资金不足应不可接")
	assert_eq(str(pilot_row["reason"]), TaskQueue.REASON_INSUFFICIENT_FUNDS, "原因取自 TaskQueue 单点常量")
	assert_false(str(pilot_row["state_text"]).is_empty(), "不可接必须给出原因文案（拒绝分支可见）")
	# 未解锁：task_reproduce_lingxi 需 silver_leash 点亮
	var lingxi_row: Dictionary = _row_of(view, "task_reproduce_lingxi")
	assert_eq(str(lingxi_row["reason"]), TaskQueue.REASON_PREDICATE_NOT_MET, "tech_lit 未满足应给谓词原因")
	# 逐行与 can_enqueue 一致（单点真源）
	var context := {"money": world.get_money(), "lit_techs": world.tech_fog.get_lit_techs()}
	for row_variant: Variant in view["rows"]:
		var row: Dictionary = row_variant
		var check: Dictionary = world.task_queue.can_enqueue(str(row["task_id"]), context)
		assert_eq(
			bool(row["available"]),
			bool(check["ok"]),
			"%s 可接性必须与 can_enqueue 一致" % str(row["task_id"])
		)
		assert_eq(
			str(row["reason"]),
			str(check["reason"]),
			"%s 原因必须与 can_enqueue 一致（单点真源）" % str(row["task_id"])
		)


func test_zero_cost_task_allowed_when_money_negative() -> void:
	# #101：资金转负后零成本任务仍可接（防"无法再开新项目"的死亡螺旋）；
	# 有成本任务仍受资金门拒绝。
	var queue := TaskQueue.new()
	autofree(queue)
	queue.setup(DataLoader.load_json(TASKS_PATH))
	var context := {"money": -50000, "lit_techs": ["silver_leash"]}
	for free_task: String in ["task_reproduce_paper_0", "task_research_basic"]:
		assert_true(
			bool(queue.can_enqueue(free_task, context)["ok"]), "%s 成本为 0，负资金下应可接（#101）" % free_task
		)
	assert_false(bool(queue.can_enqueue("task_grant_pilot", context)["ok"]), "有成本任务在负资金下仍应拒绝")
	assert_eq(
		str(queue.can_enqueue("task_grant_pilot", context)["reason"]),
		TaskQueue.REASON_INSUFFICIENT_FUNDS,
		"有成本任务拒绝原因应为资金不足"
	)


func test_enqueue_rejects_duplicate() -> void:
	var queue := TaskQueue.new()
	autofree(queue)
	queue.setup(DataLoader.load_json(TASKS_PATH))
	var context := {"money": 100000, "lit_techs": ["silver_leash"]}
	assert_true(queue.enqueue("task_reproduce_paper_0", context), "首次入队应成功")
	var dup_active: Dictionary = queue.can_enqueue("task_reproduce_paper_0", context)
	assert_false(bool(dup_active["ok"]), "进行中任务不可重复入队")
	assert_eq(str(dup_active["reason"]), TaskQueue.REASON_ALREADY_ACTIVE, "重复原因应可辨识")
	assert_true(queue.enqueue("task_research_basic", context), "另一任务应可入队（进队列）")
	var dup_queued: Dictionary = queue.can_enqueue("task_research_basic", context)
	assert_false(bool(dup_queued["ok"]), "已排队任务不可重复入队")
	assert_eq(str(dup_queued["reason"]), TaskQueue.REASON_ALREADY_ACTIVE, "排队重复原因应可辨识")
	assert_eq(queue.get_queue().size(), 1, "队列只应累积一次")


func test_enqueue_charges_once() -> void:
	# 连点接单：只扣一次成本、只入一次队（#104 刷钱漏洞封堵）。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var cost: int = int(DataLoader.load_json(TASKS_PATH)["task_grant_pilot"]["cost"])
	var money_before: int = world.get_money()
	assert_true(world.enqueue_task("task_grant_pilot"), "首次接单应成功")
	var money_after: int = world.get_money()
	assert_eq(money_before - money_after, cost, "首次接单扣一次成本")
	assert_false(world.enqueue_task("task_grant_pilot"), "重复接单应被拒（返回 false）")
	assert_eq(world.get_money(), money_after, "重复接单不得再扣款")
	assert_eq(world.task_queue.get_queue().size(), 0, "队列不应重复累积")


func test_workspace_active_task_visible() -> void:
	# P0-4：接单后工作区必须显示任务名与进度（此前读不存在的 title/progress 键）。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var stack := PanelStack.new()
	var presenter := DashboardPresenter.new()
	presenter.setup(world, stack)
	assert_true(
		(presenter.get_workspace_view()["active_task"] as Dictionary).is_empty(), "开局无进行中任务"
	)
	assert_true(world.enqueue_task("task_reproduce_paper_0"), "接单应成功")
	var active: Dictionary = presenter.get_workspace_view()["active_task"]
	assert_false(active.is_empty(), "接单后工作区应有 active_task（P0-4）")
	var cfg: Dictionary = DataLoader.load_json(TASKS_PATH)["task_reproduce_paper_0"]
	assert_eq(str(active["name"]), str(cfg["name"]), "任务名来自数据表")
	assert_almost_eq(float(active["progress"]), 0.0, 0.001, "刚接单进度为 0")
	assert_eq(int(active["weeks_left"]), int(cfg["duration_weeks"]), "剩余周数来自数据表")
	world.settle_week()
	var active_after: Dictionary = presenter.get_workspace_view()["active_task"]
	assert_false(active_after.is_empty(), "周结后任务仍在进行中")
	assert_almost_eq(
		float(active_after["progress"]), 1.0 / float(int(cfg["duration_weeks"])), 0.001, "周结后进度前进一周"
	)
	assert_true(str(active_after["progress_text"]).contains("2"), "剩余周数文案由 L2 出数")


func _row_of(view: Dictionary, task_id: String) -> Dictionary:
	for row_variant: Variant in view.get("rows", []):
		var row: Dictionary = row_variant
		if str(row.get("task_id", "")) == task_id:
			return row
	return {}
