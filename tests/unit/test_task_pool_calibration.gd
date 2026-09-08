class_name TestTaskPoolCalibration
extends GutTest

## #80（0.1.5-2）任务池参数联标专项测试（DR-031/C3 / GDD §6.2·§6.4）：
## 1. [T] test_lab_gate_reachable_within_24_weeks —— 教学链 2 笔 + 课题 4 笔 → 24 周 cum_income ≥250k
## 2. [T] test_lab_weekly_expense_matches_gdd_64 —— lab 周支出 ∈[~8k,~10k]（工资 6k + 运维 3k）
## 3. [T] test_reproduce_task_not_instant_death —— 纯复现 24 周不触破产线
## 4. [T] test_no_dead_economy_params —— economy.json 无死参数（duration_min/max 禁复活）
##
## 数值真源：src/data/tasks.json（income/rp_output）、economy.json（wage_per_staff/upkeep_weekly）。

const ECONOMY_PATH: String = "res://src/data/economy.json"

var _tasks_cfg: Dictionary
var _economy_cfg: Dictionary


func before_each() -> void:
	_tasks_cfg = DataLoader.load_json("res://src/data/tasks.json")
	_economy_cfg = DataLoader.load_json(ECONOMY_PATH)


func test_lab_gate_reachable_within_24_weeks() -> void:
	# [T] #80：教学链 2 笔 + 课题 4 笔（含占槽 7 周）→ 24 周 cum_income ≥250k
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(2026)
	var weeks: int = 0
	weeks += _run_task(world, "task_reproduce_paper_0")
	# 教学链第二笔的前置 silver_leash：RP 解锁节奏属 #76 供给口径，此处按需求 §2.3
	# 口径显式满足（走真实 start_research 链路，仅 RP 由测试注入）。
	world.economy.apply_delta("influence", 300, "test_grant")
	world.start_research("silver_leash")
	assert_eq(
		world.tech_fog.get_state("silver_leash"),
		TechFog.STATE_LIT,
		"攒够 300 RP 后应能点亮 silver_leash（教学链第二笔前置）"
	)
	weeks += _run_task(world, "task_reproduce_lingxi")
	for _i: int in range(4):
		weeks += _run_task(world, "task_grant_pilot")
	assert_lte(weeks, 24, "教学链 2 笔 + 课题 4 笔 = %d 周，应 ≤24（占槽实算 3+4+16）" % weeks)
	assert_gte(world.cum_income, 250000, "24 周累计经营收入 %d 应 ≥250k（gate 不动）" % world.cum_income)
	# 反例护栏：课题 income 若退回 50k/笔，24 周收入不足
	var grant_income: int = int(_tasks_cfg["task_grant_pilot"].get("income", 0))
	assert_gte(grant_income, 55000, "课题 income %d 须 ≥55k（否则 4 笔 + 教学链不足 250k）" % grant_income)


func test_lab_weekly_expense_matches_gdd_64() -> void:
	# [T] #80：lab 期周支出 ∈[~8k,~10k]（工资 3×2k + 固定运维 3k）
	var economy := Economy.new()
	autofree(economy)
	economy.setup(_economy_cfg)
	economy.init_resources(50000, 0, 1, 8.0)
	economy.reset_week_ledger()
	economy.accrue_fixed_expense(3)
	var weekly_expense: int = int(economy.get_week_ledger()["expense"])
	assert_between(weekly_expense, 8000, 10000, "lab 周支出 %d 应 ∈[~8k,~10k]" % weekly_expense)
	var fixed: Dictionary = economy.get_weekly_fixed_expense(3)
	assert_eq(int(fixed["wage"]), 6000, "3 人工资 = 3 × wage_per_staff")
	assert_eq(int(fixed["upkeep"]), 3000, "固定运维 upkeep_weekly（#80 新增键）")
	assert_eq(int(fixed["total"]), weekly_expense, "周结扣款与分解口径必须一致（单真源）")


func test_reproduce_task_not_instant_death() -> void:
	# [T] #80：纯复现策略 24 周不触破产线（避免"非课题任务立即致死"）。
	# 口径说明：复现 15k/3 周（5k/周）< 固定支出 9k/周 → 长期必亏；本用例只验"不立即致死"。
	# 实测资金约第 15 周转负，此后 `can_enqueue` 的 `money < cost` 门会拒绝零成本任务
	# （死亡螺旋，见 PR 风险③）→ 24 周内完成 5 笔、cum_income 75k。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(2026)
	var policy := AutoDecisionPolicy.new()
	for week_idx: int in range(24):
		if world.task_queue.get_active_task().is_empty():
			world.enqueue_task("task_reproduce_paper_0")
		world.simulate_weeks(1, policy)
		assert_false(world.game_over_flag, "纯复现策略第 %d 周不得破产" % (week_idx + 1))
		assert_eq(world.week, week_idx + 1, "第 %d 周应正常推进（无卡死）" % (week_idx + 1))
	assert_gt(world.get_money(), -200000, "24 周后资金 %d 应高于破产线" % world.get_money())
	assert_gte(world.cum_income, 75000, "24 周内至少完成 5 笔复现 → cum_income ≥75k")


func test_no_dead_economy_params() -> void:
	# [T] #80：死参数清理（duration_min/max 随 #72 删除，禁复活）
	assert_false(_economy_cfg.has("duration_min"), "死参数 duration_min 不得复活（#72 已删）")
	assert_false(_economy_cfg.has("duration_max"), "死参数 duration_max 不得复活（#72 已删）")
	# 其余键必须有消费方或明确登记（防新增死键）
	var consumed: PackedStringArray = [
		"wage_per_staff",
		"upkeep_weekly",
		"warn_line",
		"bankruptcy_line",
		"stage_depr",
		"training_cost_per_compute_hour",
		"compute_tiers",
		"sources",
	]
	for key: String in _economy_cfg:
		if key.begins_with("_"):
			continue
		assert_true(consumed.has(key), "economy.json 键 '%s' 必须有消费方或登记" % key)


## 接单并推进到完成，返回占用的周数（每周期结 1 次，与真实周结同路径）。
func _run_task(world: GameWorld, task_id: String) -> int:
	world.enqueue_task(task_id)
	assert_eq(
		str(world.task_queue.get_active_task().get("task_id", "")),
		task_id,
		"任务 %s 应成功接单（unlock 谓词已满足）" % task_id
	)
	var duration: int = int((_tasks_cfg.get(task_id, {}) as Dictionary).get("duration_weeks", 0))
	assert_gt(duration, 0, "任务 %s 必须有正时长" % task_id)
	var policy := AutoDecisionPolicy.new()
	for _i: int in range(duration):
		world.simulate_weeks(1, policy)
	return duration
