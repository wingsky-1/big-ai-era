class_name TestTaskRosterIntegration
extends GutTest

## PR4 (issue #7) 名册与任务队列专项验收测试
## 验证全部 5 个 [T] 验收点：
## 1. research_eff=Σ 组合断言（90+63=153 求和口径）
## 2. 分配状态机断言（单槽独占/空槽重算 eff/unassign 回退）
## 3. 三类任务时长/产出断言（deploy 占位行不接逻辑）
## 4. 排队预填顶替顺序断言（真空三件套：完成自动顶入队首）
## 5. 入队拒绝分支断言（unlock 谓词+资金校验）

var _world: GameWorld


func before_each() -> void:
	_world = GameWorld.new()
	_world.start_new_game(42)


func test_acceptance_point_1_research_eff_sum_aggregate() -> void:
	# [T] 验收点 1：research_eff=Σ 组合断言（90+63=153 求和口径，严禁均值 76.5）
	var roster := _world.roster
	var eff_sum := (
		roster
		. calculate_aggregate_research(
			[
				{"research": 90},
				{"research": 63},
			]
		)
	)
	assert_eq(eff_sum, 153, "DR-005R 求和版：90 + 63 应严格等于 153")
	assert_ne(eff_sum, 76, "严禁均值聚合惩罚弱者（非 76）")

	# 真实名册员工分配到训练位
	# 林拾光 (r_lin, research=70)
	assert_eq(_world.research_eff, 0, "开局未分配训练位，research_eff=0")
	_world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	assert_eq(_world.research_eff, 70, "分配林拾光后，训练研究力为 70")

	# 白鹿鸣 (r_bai, research=62) 上桌：多人槽下 Σ 累加（批 1b #73）
	_world.assign_staff("r_bai", StaffRoster.SLOT_TRAINING)
	assert_eq(_world.research_eff, 70 + 62, "白鹿鸣入槽后 Σeff = 70 + 62 = 132")


func test_acceptance_point_2_staff_assignment_state_machine() -> void:
	# [T] 验收点 2：分配状态机断言（多人槽共存/单人单槽转移/空槽重算 eff/unassign 回退）
	# 1. 单人分配任务槽
	_world.assign_staff("r_lin", StaffRoster.SLOT_TASK)
	assert_eq(_world.roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin", "任务槽为 r_lin")
	assert_eq(_world.roster.get_staff("r_lin")["assigned"], StaffRoster.SLOT_TASK, "r_lin 标记在任务槽")

	# 2. 多人槽（批 1b #73）：r_wen 加入同一 SLOT_TASK，两人共存
	_world.assign_staff("r_wen", StaffRoster.SLOT_TASK)
	assert_eq(_world.roster.get_slot_count(StaffRoster.SLOT_TASK), 2, "任务槽容纳两人")
	assert_eq(_world.roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin", "单人语义返回首个上桌者")
	assert_eq(_world.roster.get_staff("r_wen")["assigned"], StaffRoster.SLOT_TASK, "r_wen 也在任务槽")
	assert_eq(_world.roster.get_staff("r_lin")["assigned"], StaffRoster.SLOT_TASK, "r_lin 仍在槽内")

	# 3. 单人单槽转移：r_wen 从 SLOT_TASK 换到 SLOT_TRAINING
	_world.assign_staff("r_wen", StaffRoster.SLOT_TRAINING)
	assert_eq(_world.roster.get_slot_count(StaffRoster.SLOT_TASK), 1, "r_wen 离开后任务槽剩 1 人")
	assert_eq(_world.roster.get_slot_occupant(StaffRoster.SLOT_TASK), "r_lin", "任务槽剩 r_lin")
	assert_eq(_world.roster.get_slot_occupant(StaffRoster.SLOT_TRAINING), "r_wen", "新训练位为 r_wen")
	assert_eq(_world.research_eff, 55, "训练研究力更新为 r_wen 的 55")

	# 4. unassign 回退与空槽重算
	_world.unassign_staff("r_wen")
	assert_eq(_world.roster.get_slot_occupant(StaffRoster.SLOT_TRAINING), "", "训练位清空")
	assert_eq(_world.roster.get_staff("r_wen")["assigned"], "", "员工解除分配")
	assert_eq(_world.research_eff, 0, "空槽重算，research_eff 回退为 0")


func test_acceptance_point_3_three_task_types_and_deploy_placeholder() -> void:
	# [T] 验收点 3：三类任务时长/产出断言（deploy 占位行不接逻辑）
	var tasks_config: Dictionary = DataLoader.load_json("res://src/data/tasks.json")

	# 1. 复现类：经典论文复现
	var rep_cfg: Dictionary = tasks_config["task_reproduce_paper_0"]
	assert_eq(int(rep_cfg["duration_weeks"]), 3, "复现任务时长 3 周")
	assert_eq(int(rep_cfg["rp_output"]), 50, "复现任务产出 50 RP")
	assert_eq(int(rep_cfg["income"]), 8000, "复现任务产出 8000 资金")

	# 2. 研究类：基础架构探究
	var res_cfg: Dictionary = tasks_config["task_research_basic"]
	assert_eq(int(res_cfg["duration_weeks"]), 4, "研究任务时长 4 周")
	assert_eq(int(res_cfg["rp_output"]), 150, "研究任务产出 150 RP")
	assert_eq(int(res_cfg["income"]), 0, "研究任务无资金收入")

	# 3. 课题类：先导课题申报
	var grant_cfg: Dictionary = tasks_config["task_grant_pilot"]
	assert_eq(int(grant_cfg["duration_weeks"]), 4, "课题任务时长 4 周")
	assert_eq(int(grant_cfg["rp_output"]), 0, "课题任务不产出 RP")
	assert_eq(int(grant_cfg["income"]), 35000, "课题任务产出 35000 资金")

	# 4. deploy 占位行：enabled: false，拒绝入队
	var deploy_cfg: Dictionary = tasks_config["task_deploy_placeholder"]
	assert_false(bool(deploy_cfg["enabled"]), "deploy 占位行必须 enabled: false")
	_world.enqueue_task("task_deploy_placeholder")
	assert_true(_world.task_queue.get_active_task().is_empty(), "deploy 占位行入队必须被拒绝")
	assert_eq(_world.task_queue.get_queue().size(), 0, "队列保持为空")


func test_acceptance_point_4_auto_fill_and_queue_order() -> void:
	# [T] 验收点 4：排队预填顶替顺序断言（真空三件套：完成自动顶入队首）
	watch_signals(_world)

	# 入队任务 1 (task_reproduce_paper_0, 3 周) -> 立即激活
	_world.enqueue_task("task_reproduce_paper_0")
	var active1 := _world.task_queue.get_active_task()
	assert_eq(active1.get("task_id", ""), "task_reproduce_paper_0", "T1 立即激活")
	assert_eq(int(active1.get("weeks_left", 0)), 3, "T1 初始剩余 3 周")

	# 排队入队任务 2 (task_research_basic, 4 周)
	_world.enqueue_task("task_research_basic")
	assert_eq(_world.task_queue.get_queue(), ["task_research_basic"], "T2 进待办队列队首")

	# 推进 2 周，T1 剩余 1 周
	_world.settle_week()
	_world.settle_week()
	var active_w2 := _world.task_queue.get_active_task()
	assert_eq(active_w2.get("task_id", ""), "task_reproduce_paper_0")
	assert_eq(int(active_w2.get("weeks_left", 0)), 1)

	# 第 3 周结算：T1 完成，T2 自动无缝顶入队首激活（Auto-fill）
	_world.settle_week()
	var active2 := _world.task_queue.get_active_task()
	assert_eq(active2.get("task_id", ""), "task_research_basic", "T1 完成后 T2 自动顶入 active_task")
	assert_eq(int(active2.get("weeks_left", 0)), 4, "T2 初始 4 周")
	assert_eq(_world.task_queue.get_queue().size(), 0, "原排队任务已出队")


func test_acceptance_point_5_enqueue_rejection_branch() -> void:
	# [T] 验收点 5：入队拒绝分支断言（unlock 谓词+资金校验）
	# 1. 资金不足拒绝课题任务（task_grant_pilot 需 cost=2000）
	# 将世界资金设为 1000
	_world.economy.init_resources(1000, 0, 1, 40.0)
	_world.enqueue_task("task_grant_pilot")
	assert_true(_world.task_queue.get_active_task().is_empty(), "资金不足 2000 应拒绝入队")
	assert_eq(_world.get_money(), 1000, "拒绝入队不得扣款")

	# 2. 谓词未解锁拒绝（task_reproduce_lingxi 依赖 tech_lit: silver_leash）
	_world.enqueue_task("task_reproduce_lingxi")
	assert_true(_world.task_queue.get_active_task().is_empty(), "科技未点亮应拒绝入队")

	# 3. 不存在的任务 ID 拒绝
	_world.enqueue_task("task_invalid_xyz")
	assert_true(_world.task_queue.get_active_task().is_empty(), "非法任务拒绝入队")

	# 4. 充裕资金下合法入队成功并扣除 cost
	_world.economy.init_resources(50000, 0, 1, 40.0)
	_world.enqueue_task("task_grant_pilot")
	assert_eq(_world.task_queue.get_active_task().get("task_id", ""), "task_grant_pilot", "合法入队成功")
	assert_eq(_world.get_money(), 50000 - 2000, "入队成功扣除 2000 成本")


func test_progress_ticked_signal_emitted_on_clock_ticks() -> void:
	# 刻级信号（M7）测试：值变才发
	watch_signals(_world)
	_world.enqueue_task("task_reproduce_paper_0")
	var driver := GameLoopDriver.new()
	autofree(driver)
	driver.setup(_world.clock)
	# 驱动 advance
	_world.clock.advance(_world.clock.tick_seconds * 2.0)
	assert_signal_emitted(_world, "progress_ticked", "有活跃任务且刻数步进时应发射 progress_ticked")
