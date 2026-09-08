extends GutTest

## 批 1a/1c 周结管线验收用例（#72 收入口径/破产步序/账期/确定性 + #74 买卡与周预算）：
## 1. test_weekly_ledger_includes_task_income —— 周报收入含 task_reward 且收支闭合
## 2. test_bankruptcy_checked_after_task_settlement —— 破产判定在任务结算之后
## 3. test_same_seed_replay_after_load —— 读档续跑与直跑同 seed 摘要一致
## 4. test_compute_upgrade_command_and_entry —— 买卡命令三态与过账
## 5. test_training_cost_not_double_charged —— base.cost 一次性，卡时不过账 money
## 6. test_training_rejected_when_weekly_compute_insufficient —— 周预算不足拒绝且无副作用

const BASES_PATH: String = "res://src/data/model_bases.json"


func test_weekly_ledger_includes_task_income() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(7)
	var policy := AutoDecisionPolicy.new()
	# task_reproduce_paper_0：3 周、income 8000、cost 0
	assert_true(
		world.task_queue.enqueue(
			"task_reproduce_paper_0", {"money": world.get_money(), "lit_techs": []}
		)
	)
	var reports: Array[Dictionary] = []
	for i: int in range(3):
		reports.append_array(world.simulate_weeks(1, policy))

	for report: Dictionary in reports:
		var money_row: Dictionary = report["money_row"]
		var income_text: String = str(money_row["income"])
		var expense_text: String = str(money_row["expense"])
		var net_text: String = str(money_row["net"])
		assert_true(income_text != "" and expense_text != "" and net_text != "", "收支行三值不应为空")

	var completion: Dictionary = reports[2]
	assert_eq(
		str(completion["money_row"]["income"]),
		Formatter.format_money(8000),
		"任务完成周的收入必须含 task_reward 8000（D-11 裂缝修复）"
	)
	assert_eq(
		str(completion["money_row"]["expense"]),
		Formatter.format_money(6000),
		"任务完成周支出 = 当周工资 6000（账期契约：每周独立结算）"
	)
	assert_eq(
		str(completion["money_row"]["net"]),
		Formatter.format_delta(8000 - 6000),
		"income - expense == net 必须闭合"
	)
	# 前两周无任务结算：收入 0、支出当周工资
	for idx: int in range(2):
		assert_eq(str(reports[idx]["money_row"]["income"]), Formatter.format_money(0), "未结算周无收入")
		assert_eq(
			str(reports[idx]["money_row"]["expense"]), Formatter.format_money(6000), "未结算周支出=工资"
		)


func test_bankruptcy_checked_after_task_settlement() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(7)
	var policy := AutoDecisionPolicy.new()
	world.enqueue_task("task_grant_pilot")  # 4 周、income 35000、cost 2000
	world.simulate_weeks(3, policy)
	assert_false(world.game_over_flag, "前 3 周不应破产")

	# 第 4 周结算前压到破产线以下；本周任务 +35000 与工资 -6000 会把它拉回线上
	world.economy.apply_delta("money", -250000, "test_setup")
	assert_lt(world.get_money(), -200000, "构造：结算前低于破产线")
	world.simulate_weeks(1, policy)
	assert_false(world.game_over_flag, "任务结算后回到破产线之上，不应触发 Game Over")
	assert_gt(world.get_money(), -200000, "结算后资金应高于破产线")

	# 反向例：无任务收入时短路仍生效
	var bare := GameWorld.new()
	autofree(bare)
	bare.start_new_game(7)
	bare.economy.apply_delta("money", -250000, "test_setup")
	bare.simulate_weeks(1, policy)
	assert_true(bare.game_over_flag, "无任务收入时破产短路仍生效")


func test_same_seed_replay_after_load() -> void:
	var direct := GameWorld.new()
	autofree(direct)
	direct.start_new_game(42)
	_simulate_with_tasks(direct, 40)
	var direct_digest: String = SnapshotCodec.state_digest(direct)

	var first := GameWorld.new()
	autofree(first)
	first.start_new_game(42)
	_simulate_with_tasks(first, 20)
	var saved: Dictionary = SnapshotCodec.to_save(first)

	var restored := GameWorld.new()
	autofree(restored)
	restored.restore(saved)
	_simulate_with_tasks(restored, 20)

	assert_eq(
		SnapshotCodec.state_digest(restored),
		direct_digest,
		"读档续跑 20 周应与直跑 40 周摘要一致（RNG 消费点回到 3 处 + 读档不漂移）"
	)


func test_compute_upgrade_command_and_entry() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(1)
	assert_true(GameWorld.CONTRACT_COMMANDS.has("upgrade_compute"), "命令面应含买卡命令")

	# 钱不足：置灰 + 原因，命令返回 false
	world.economy.init_resources(1000, 0, 1, 8.0)
	var view_low: Dictionary = world.get_compute_upgrade_view()
	assert_false(bool(view_low["available"]), "钱不足应置灰")
	assert_eq(str(view_low["reason"]), "insufficient_money", "原因应为 insufficient_money")
	assert_false(world.upgrade_compute(2), "钱不足买卡应返回 false")
	assert_eq(int(world.get_compute()["tier"]), 1, "失败不应改档")

	# 钱够：tier+1、扣价、发信号、本周预算升档
	world.economy.init_resources(100000, 0, 1, 8.0)
	watch_signals(world.economy)
	assert_true(world.upgrade_compute(2), "满足条件买卡成功")
	assert_eq(int(world.get_compute()["tier"]), 2, "档位 +1")
	assert_eq(world.get_money(), 100000 - 19000, "价格经 apply_delta 扣除")
	assert_signal_emitted(world.economy, "compute_upgraded", "应发射 compute_upgraded")
	assert_eq(int(world.get_compute()["hours_remaining"]), 16, "本周预算重置为新档供给 16")

	# 顶档：置灰 + 原因
	world.economy.init_resources(999999, 0, 4, 64.0)
	var view_max: Dictionary = world.get_compute_upgrade_view()
	assert_false(bool(view_max["available"]), "顶档应置灰")
	assert_eq(str(view_max["reason"]), "max_tier", "原因应为 max_tier")
	assert_false(world.upgrade_compute(5), "顶档买卡应返回 false")


func test_training_cost_not_double_charged() -> void:
	# 1. training_cost() 是纯校验/显示口径，不产生过账
	var economy := Economy.new()
	autofree(economy)
	economy.setup(DataLoader.load_json("res://src/data/economy.json"))
	economy.init_resources(50000, 0, 1, 8.0)
	var money_before: int = economy.get_money()
	assert_eq(economy.training_cost(6), 900, "6 卡时 × 150 = 900")
	assert_eq(economy.get_money(), money_before, "training_cost() 不得产生 apply_delta 过账")

	# 2. 开训仅扣 base.cost 一次；全程卡时只占用本周预算
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(1)
	world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	world.economy.init_resources(200000, 0, 1, 8.0)
	var before: int = world.get_money()
	world.start_training("base_pushi_1b")
	assert_true(world.training.is_training(), "训练应启动")
	assert_eq(world.get_money(), before - 9000, "开训仅扣 base.cost 9000 一次")

	var policy := AutoDecisionPolicy.new()
	var tasks := AutoTaskPolicy.new()
	for i: int in range(10):
		tasks.fill(world)
		world.simulate_weeks(1, policy)
	assert_false(world.training.is_training(), "10 周后训练应完成出分")
	assert_eq(
		int(world.get_compute()["hours_remaining"]),
		world.economy.get_compute_supply() - 6,
		"训练每周占用 6 卡时（周预算口径，不过账 money）"
	)


func test_training_rejected_when_weekly_compute_insufficient() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(1)
	world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	world.economy.init_resources(200000, 0, 1, 8.0)

	# tier1 周供给 8 < 深渊 70b 的 hours_per_week 30 → 拒绝
	var bases: Dictionary = DataLoader.load_json(BASES_PATH)
	var res: Dictionary = (
		world
		. training
		. start_training(
			"base_shenyuan_70b",
			{
				"research_eff": world.research_eff,
				"compute_tier": 3,
				"money": world.get_money(),
				"economy": world.economy,
			}
		)
	)
	assert_false(bool(res["ok"]), "周预算不足应拒绝开训")
	assert_eq(str(res["reason"]), "insufficient_weekly_compute", "原因应为 insufficient_weekly_compute")
	assert_eq(world.get_money(), 200000, "拒绝分支不留副作用（未扣款）")
	assert_false(world.training.is_training(), "拒绝后不应有训练在跑")
	assert_eq(int(bases["base_shenyuan_70b"]["hours_per_week"]), 30, "深渊 70b 每周需 30 卡时（数据键）")


func _simulate_with_tasks(world: GameWorld, weeks: int) -> void:
	var policy := AutoDecisionPolicy.new()
	var tasks := AutoTaskPolicy.new()
	for i: int in range(weeks):
		tasks.fill(world)
		world.simulate_weeks(1, policy)
