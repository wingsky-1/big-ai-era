class_name TestTaskQueue
extends GutTest

## TaskQueue 任务队列单元测试
## 覆盖设计与契约：
## 1. 入队校验（资金不足、未解锁谓词、禁用任务/deploy 占位行被拒绝）
## 2. 三类任务时长产出与 deploy 占位行拒绝
## 3. 排队预填与自动顶入顺序（T1 完成后 T2 自动顶入，T3 继续排队）
## 4. 刻级推进累积
## 5. 快照与存档恢复

var _task_queue: TaskQueue
var _config: Dictionary


func before_each() -> void:
	_task_queue = TaskQueue.new()
	_config = DataLoader.load_json("res://src/data/tasks.json")
	_task_queue.setup(_config)


func test_enqueue_validation_and_rejection() -> void:
	# 1. 禁用任务 / 占位行拒绝
	var ctx_rich: Dictionary = {"money": 100000, "lit_techs": ["silver_leash"]}
	var res_placeholder: Dictionary = _task_queue.can_enqueue("task_deploy_placeholder", ctx_rich)
	assert_false(bool(res_placeholder.get("ok", false)), "disabled task 应拒绝入队")
	assert_eq(
		str(res_placeholder.get("reason", "")),
		"disabled_or_not_found",
		"disabled 任务原因应为 disabled_or_not_found"
	)

	# 2. 不存在的 task_id
	var res_nonexistent: Dictionary = _task_queue.can_enqueue("non_existent_task", ctx_rich)
	assert_false(bool(res_nonexistent.get("ok", false)), "不存在的 task 应拒绝入队")
	assert_eq(
		str(res_nonexistent.get("reason", "")),
		"disabled_or_not_found",
		"不存在的任务原因应为 disabled_or_not_found"
	)

	# 3. 资金不足拒绝 (task_grant_pilot 需 cost 2000, min_money 2000)
	var ctx_poor: Dictionary = {"money": 500, "lit_techs": ["silver_leash"]}
	var res_poor: Dictionary = _task_queue.can_enqueue("task_grant_pilot", ctx_poor)
	assert_false(bool(res_poor.get("ok", false)), "资金不足应拒绝入队")
	assert_eq(str(res_poor.get("reason", "")), "insufficient_funds", "资金不足原因应为 insufficient_funds")

	# 4. min_money 谓词未满足拒绝 (若 cost 满足但 min_money 阈值未满足，这里两者都为 2000，构造特例或测未满足)
	var custom_config: Dictionary = {
		"task_special":
		{
			"duration_weeks": 2,
			"rp_output": 10,
			"income": 0,
			"cost": 100,
			"enabled": true,
			"unlock": {"predicate": "min_money", "params": {"amount": 5000}}
		},
		"task_never":
		{
			"duration_weeks": 2,
			"rp_output": 10,
			"income": 0,
			"cost": 0,
			"enabled": true,
			"unlock": {"predicate": "never", "params": {}}
		},
		"task_unknown":
		{
			"duration_weeks": 2,
			"rp_output": 10,
			"income": 0,
			"cost": 0,
			"enabled": true,
			"unlock": {"predicate": "alien_tech", "params": {}}
		}
	}
	var custom_queue := TaskQueue.new()
	custom_queue.setup(custom_config)

	var ctx_mid: Dictionary = {"money": 2000}
	var res_min_money: Dictionary = custom_queue.can_enqueue("task_special", ctx_mid)
	assert_false(bool(res_min_money.get("ok", false)), "min_money 未达到阈值应拒绝")
	assert_eq(
		str(res_min_money.get("reason", "")), "predicate_not_met", "未达到阈值原因 predicate_not_met"
	)

	var res_never: Dictionary = custom_queue.can_enqueue("task_never", ctx_rich)
	assert_false(bool(res_never.get("ok", false)), "never 谓词应拒绝")
	assert_eq(str(res_never.get("reason", "")), "never_unlocked", "never 谓词原因 never_unlocked")

	var res_unknown: Dictionary = custom_queue.can_enqueue("task_unknown", ctx_rich)
	assert_false(bool(res_unknown.get("ok", false)), "未知谓词应拒绝")
	assert_eq(str(res_unknown.get("reason", "")), "predicate_not_met", "未知谓词原因 predicate_not_met")

	# 5. tech_lit 科技前置未满足与满足测试 (task_reproduce_lingxi 需要 silver_leash)
	var ctx_no_tech: Dictionary = {"money": 50000, "lit_techs": []}
	var res_no_tech: Dictionary = _task_queue.can_enqueue("task_reproduce_lingxi", ctx_no_tech)
	assert_false(bool(res_no_tech.get("ok", false)), "前置科技未点亮应拒绝")
	assert_eq(
		str(res_no_tech.get("reason", "")), "predicate_not_met", "前置科技未点亮原因 predicate_not_met"
	)

	var ctx_with_tech: Dictionary = {"money": 50000, "lit_techs": ["silver_leash"]}
	var res_with_tech: Dictionary = _task_queue.can_enqueue("task_reproduce_lingxi", ctx_with_tech)
	assert_true(bool(res_with_tech.get("ok", false)), "前置科技已点亮应允许入队")
	assert_eq(str(res_with_tech.get("reason", "")), "", "通过校验 reason 为空")


func test_three_task_types_and_placeholder_refusal() -> void:
	# 验证 tasks.json 真实配置中的基础三类任务：
	# 1. 论文复现：task_reproduce_paper_0 (3周, 50 RP, 8000 income)
	# 2. 基础科研：task_research_basic (4周, 150 RP, 0 income)
	# 3. 横向课题：task_grant_pilot (4周, 0 RP, 35000 income, 2000 cost)
	# 4. deploy 占位行拒绝：task_deploy_placeholder
	var ctx: Dictionary = {"money": 10000, "lit_techs": []}

	# deploy 占位行直接拒绝 enqueue
	assert_false(_task_queue.enqueue("task_deploy_placeholder", ctx), "deploy 占位行入队必须返回 false")
	assert_true(_task_queue.get_active_task().is_empty(), "当前不应有激活任务")

	# 1. 论文复现
	assert_true(_task_queue.enqueue("task_reproduce_paper_0", ctx), "论文复现入队成功")
	var active: Dictionary = _task_queue.get_active_task()
	assert_eq(str(active.get("task_id", "")), "task_reproduce_paper_0")
	assert_eq(int(active.get("duration_weeks", 0)), 3)
	assert_eq(int(active.get("weeks_left", 0)), 3)

	# 推进 2 周，未完成
	var s1: Dictionary = _task_queue.settle_week()
	assert_false(bool(s1.get("completed", false)))
	assert_eq(int(s1.get("weeks_left", 0)), 2)
	var s2: Dictionary = _task_queue.settle_week()
	assert_false(bool(s2.get("completed", false)))
	assert_eq(int(s2.get("weeks_left", 0)), 1)

	# 第 3 周结算完成
	var s3: Dictionary = _task_queue.settle_week()
	assert_true(bool(s3.get("completed", false)))
	assert_eq(str(s3.get("task_id", "")), "task_reproduce_paper_0")
	assert_eq(int(s3.get("rp_output", 0)), 110)
	assert_eq(int(s3.get("income", 0)), 8000)
	assert_true(_task_queue.get_active_task().is_empty(), "任务完成后队列为空，无激活任务")

	# 2. 基础科研
	assert_true(_task_queue.enqueue("task_research_basic", ctx), "基础科研入队成功")
	for i in 3:
		_task_queue.settle_week()
	var s_res: Dictionary = _task_queue.settle_week()
	assert_true(bool(s_res.get("completed", false)))
	assert_eq(str(s_res.get("task_id", "")), "task_research_basic")
	assert_eq(int(s_res.get("rp_output", 0)), 150)
	assert_eq(int(s_res.get("income", 0)), 0)

	# 3. 横向课题
	assert_true(_task_queue.enqueue("task_grant_pilot", ctx), "横向课题入队成功")
	for i in 3:
		_task_queue.settle_week()
	var s_grant: Dictionary = _task_queue.settle_week()
	assert_true(bool(s_grant.get("completed", false)))
	assert_eq(str(s_grant.get("task_id", "")), "task_grant_pilot")
	assert_eq(int(s_grant.get("rp_output", 0)), 150)
	assert_eq(int(s_grant.get("income", 0)), 35000)


func test_queue_fifo_and_auto_fill() -> void:
	# 验证排队预填与自动顶入顺序：
	# 空队列入 T1 -> T1 立即激活为 active
	# 入 T2 -> T2 进 queue
	# 入 T3 -> T3 进 queue
	# T1 结项 -> T2 自动顶入 active，T3 继续排队
	# T2 结项 -> T3 自动顶入 active，queue 为空
	var ctx: Dictionary = {"money": 50000, "lit_techs": []}

	assert_true(_task_queue.enqueue("task_reproduce_paper_0", ctx))  # 3 周
	assert_true(_task_queue.enqueue("task_research_basic", ctx))  # 4 周
	assert_true(_task_queue.enqueue("task_grant_pilot", ctx))  # 4 周

	# 检查状态
	var active1: Dictionary = _task_queue.get_active_task()
	assert_eq(str(active1.get("task_id", "")), "task_reproduce_paper_0")
	var q1: Array[String] = _task_queue.get_queue()
	assert_eq(q1.size(), 2)
	assert_eq(q1[0], "task_research_basic")
	assert_eq(q1[1], "task_grant_pilot")

	# 结算 3 周让 T1 完成
	_task_queue.settle_week()
	_task_queue.settle_week()
	var r1: Dictionary = _task_queue.settle_week()
	assert_true(bool(r1.get("completed", false)))
	assert_eq(str(r1.get("task_id", "")), "task_reproduce_paper_0")

	# T2 自动顶入激活，T3 继续排队
	var active2: Dictionary = _task_queue.get_active_task()
	assert_eq(str(active2.get("task_id", "")), "task_research_basic")
	assert_eq(int(active2.get("weeks_left", 0)), 4)
	assert_eq(int(active2.get("duration_weeks", 0)), 4)
	var q2: Array[String] = _task_queue.get_queue()
	assert_eq(q2.size(), 1)
	assert_eq(q2[0], "task_grant_pilot")

	# 结算 4 周让 T2 完成
	for i in 3:
		_task_queue.settle_week()
	var r2: Dictionary = _task_queue.settle_week()
	assert_true(bool(r2.get("completed", false)))
	assert_eq(str(r2.get("task_id", "")), "task_research_basic")

	# T3 自动顶入激活，队列变空
	var active3: Dictionary = _task_queue.get_active_task()
	assert_eq(str(active3.get("task_id", "")), "task_grant_pilot")
	assert_eq(int(active3.get("weeks_left", 0)), 4)
	var q3: Array[String] = _task_queue.get_queue()
	assert_true(q3.is_empty())


func test_advance_tick() -> void:
	var ctx: Dictionary = {"money": 50000, "lit_techs": []}
	_task_queue.enqueue("task_reproduce_paper_0", ctx)

	_task_queue.advance_tick(1)
	assert_eq(int(_task_queue.get_active_task().get("ticks_accumulated", 0)), 1)
	_task_queue.advance_tick(5)
	assert_eq(int(_task_queue.get_active_task().get("ticks_accumulated", 0)), 6)


func test_snapshot_and_restore() -> void:
	var ctx: Dictionary = {"money": 50000, "lit_techs": []}
	_task_queue.enqueue("task_reproduce_paper_0", ctx)
	_task_queue.enqueue("task_research_basic", ctx)
	_task_queue.advance_tick(10)
	_task_queue.settle_week()  # weeks_left 变 2

	var snapshot: Dictionary = _task_queue.to_snapshot()
	assert_eq(snapshot.get("queue", []).size(), 1)
	assert_eq(snapshot["queue"][0], "task_research_basic")
	assert_eq(int(snapshot["active"]["weeks_left"]), 2)
	assert_eq(int(snapshot["active"]["ticks_accumulated"]), 10)

	var new_queue := TaskQueue.new()
	new_queue.setup(_config)
	new_queue.restore(snapshot)

	var restored_active: Dictionary = new_queue.get_active_task()
	assert_eq(str(restored_active.get("task_id", "")), "task_reproduce_paper_0")
	assert_eq(int(restored_active.get("weeks_left", 0)), 2)
	assert_eq(int(restored_active.get("ticks_accumulated", 0)), 10)
	var restored_q: Array[String] = new_queue.get_queue()
	assert_eq(restored_q.size(), 1)
	assert_eq(restored_q[0], "task_research_basic")
