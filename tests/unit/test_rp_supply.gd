class_name TestRpSupply
extends GutTest

## #76（0.1.5-1e）RP 供给标定 + 翻雾供给源专项测试（DR-031 §2.9 / A1）：
## 1. [T] test_task_rp_supply_in_target_band —— 160 周单槽串行 Σrp_output ∈ [4910,6810)
## 2. [T] test_fog_supply_source_is_cumulative —— 点树消耗不影响翻雾进度（RK-04）
## 3. [T] test_grant_task_yields_both_money_and_rp —— 课题完成同时产 money 与 RP
## 4. [T] test_v6_supply_anchor_matches_task_scope —— 供给锚改判为任务口径供给带
## 5. [T] test_cum_influence_monotonic_and_persisted —— 累计计数器只增 + 读档还原
## 6. [T] test_tech_lit_advance_not_slowed_by_spending —— 同累计下点树与否进度一致
##
## 数值真源：src/data/tasks.json（rp_output）/ assertion_bounds.json（供给带）/
## techs.json（fog_gate / rp_cost）。Σrp_cost 维持 14210（A2 裁决，禁调表）。

## 单槽串行策略（钱优先）：与 tests/support/auto_task_policy.gd 同序，
## 唯一能撑满 160 周不破产的任务线（课题 35000/4 周 > 工资 6000/周）。
const PRIORITY_MONEY: PackedStringArray = [
	"task_grant_pilot",
	"task_reproduce_lingxi",
	"task_reproduce_paper_0",
	"task_research_basic",
]

const WEEKS: int = 160
## 单位时间供给带（rp_output / duration_weeks）：保证任何任务选择都落带。
const UNIT_SUPPLY_MIN: float = 31.0
const UNIT_SUPPLY_MAX: float = 42.0

var _bounds: Dictionary
var _tasks_cfg: Dictionary
var _techs_cfg: Dictionary


func before_each() -> void:
	_bounds = DataLoader.load_json("res://src/data/assertion_bounds.json")
	_tasks_cfg = DataLoader.load_json("res://src/data/tasks.json")
	_techs_cfg = DataLoader.load_json("res://src/data/techs.json")


func test_task_rp_supply_in_target_band() -> void:
	# [T] #76：160 周单槽串行策略跑完，Σrp_output 落在供给带 [4910, 6810)
	var v6: Dictionary = _bounds.get("v6_tech_lit_distribution", {})
	var band_min: int = int(v6.get("supply_band_rp_min", 0))
	var band_max: int = int(v6.get("supply_band_rp_max", 0))
	assert_gt(band_min, 0, "供给带下界必须来自 assertion_bounds.json")
	var acc: Dictionary = _run_supply(2026, PRIORITY_MONEY, WEEKS)
	var total_rp: int = int(acc.get("rp", 0))
	var completed: int = int(acc.get("count", 0))
	assert_gte(completed, 39, "160 周单槽应完成 ≥39 笔（实测 %d）" % completed)
	assert_between(
		total_rp,
		band_min,
		band_max - 1,
		"Σrp_output %d 应落在 [%d, %d)" % [total_rp, band_min, band_max]
	)
	# 任务选择无关性：单位时间供给（rp_output / duration）落带 ⇒ 任意策略均落带
	for task_id: String in _tasks_cfg:
		var task: Dictionary = _tasks_cfg[task_id]
		if not bool(task.get("enabled", false)):
			continue
		var duration: int = int(task.get("duration_weeks", 0))
		var rp_output: int = int(task.get("rp_output", 0))
		assert_gt(duration, 0, "任务 %s 必须有正时长" % task_id)
		var unit_supply: float = float(rp_output) / float(duration)
		assert_between(
			unit_supply,
			UNIT_SUPPLY_MIN,
			UNIT_SUPPLY_MAX,
			(
				"任务 %s 单位时间供给 %.2f RP/周 应落在 [%.0f, %.0f]"
				% [task_id, unit_supply, UNIT_SUPPLY_MIN, UNIT_SUPPLY_MAX]
			)
		)


func test_fog_supply_source_is_cumulative() -> void:
	# [T] #76 / RK-04：翻雾供给源 = 累计获得影响力（不读当前余额）
	var fog := TechFog.new()
	fog.setup(_techs_cfg)
	var fog_gate: Dictionary = _techs_cfg.get("fog_gate", {})
	var visible_gate: int = int(fog_gate.get("visible", 0))
	assert_gt(visible_gate, 0, "fog_gate.visible 必须来自 techs.json")
	# 累计达到 visible 门 → 可研域 hidden 节点全部翻态
	fog.advance_with_context({"cum_influence": visible_gate})
	for node_id: String in _techs_cfg.get("nodes", {}):
		var domain: String = str(_techs_cfg["nodes"][node_id].get("domain", ""))
		var researchable: bool = bool(
			(_techs_cfg.get("domain_flags", {}).get(domain, {}) as Dictionary).get(
				"researchable", true
			)
		)
		if researchable:
			assert_ne(
				fog.get_state(node_id), TechFog.STATE_HIDDEN, "累计达门后 %s 不应仍为 hidden" % node_id
			)


func test_tech_lit_advance_not_slowed_by_spending() -> void:
	# [T] #76：同 cum_influence 下，无论是否点树（余额高低），翻雾进度完全一致
	var world_ref := _world_with_influence(7, 700, 0)
	var world_spent := _world_with_influence(7, 700, -600)
	assert_eq(
		world_spent.tech_fog.get_fog_states(),
		world_ref.tech_fog.get_fog_states(),
		"点树消耗影响力不得拖慢翻雾（供给源为累计计数器）"
	)
	assert_eq(
		world_spent.tech_fog.get_discovered_count(),
		world_ref.tech_fog.get_discovered_count(),
		"探明数亦不受消耗影响"
	)


func test_grant_task_yields_both_money_and_rp() -> void:
	# [T] #76：课题完成时 money 与 influence 两者都变化（改造前 rp_output=0 → RP 恒 0）
	var world := GameWorld.new()
	world.start_new_game(11)
	world.economy.init_resources(100000, 0, 1, 40.0)
	world.enqueue_task("task_grant_pilot")
	assert_eq(
		str(world.task_queue.get_active_task().get("task_id", "")), "task_grant_pilot", "课题应成功接单"
	)
	var rp_before: int = world.get_influence()
	var cum_before: int = world.economy.get_cum_influence()
	var duration: int = int(_tasks_cfg["task_grant_pilot"].get("duration_weeks", 0))
	var expected_rp: int = int(_tasks_cfg["task_grant_pilot"].get("rp_output", 0))
	for _i: int in range(duration):
		world.simulate_weeks(1)
	assert_gt(world.cum_income, 0, "课题完成应计入 cum_income（money 侧）")
	assert_gte(world.get_influence() - rp_before, expected_rp, "课题完成至少产 %d RP" % expected_rp)
	assert_gte(world.economy.get_cum_influence() - cum_before, expected_rp, "累计影响力随之增加（翻雾供给源同步）")


func test_v6_supply_anchor_matches_task_scope() -> void:
	# [T] #76：供给锚口径改判（12300 → 任务口径供给带），且与 Σrp_cost 实算自洽
	var v6: Dictionary = _bounds.get("v6_tech_lit_distribution", {})
	assert_false(v6.has("supply_anchor_rp"), "旧锚 12300 已撤销（无产出通路的连续模型）")
	var band_min: int = int(v6.get("supply_band_rp_min", 0))
	var band_max: int = int(v6.get("supply_band_rp_max", 0))
	assert_eq(band_min, 4910, "供给带下界 = C(7)")
	assert_eq(band_max, 6810, "供给带上界 = C(8)（半开区间）")
	var total_rp: int = int(_run_supply(2026, PRIORITY_MONEY, WEEKS).get("rp", 0))
	assert_between(total_rp, band_min, band_max - 1, "实跑供给 %d 应落带" % total_rp)
	# 点亮数：贪心从小到大点亮，Σrp_cost 维持 14210（禁调表）
	var rp_costs: Array[int] = _researchable_rp_costs()
	var total_cost: int = 0
	for cost: int in rp_costs:
		total_cost += cost
	assert_eq(total_cost, 14210, "Σrp_cost 必须维持 14210（A2 裁决禁调表）")
	var lit: int = 0
	var spent: int = 0
	for cost: int in rp_costs:
		if spent + cost <= total_rp:
			spent += cost
			lit += 1
	assert_eq(lit, 7, "供给落带 ⇒ V6 点亮 7 个（P50=7）")


func test_cum_influence_monotonic_and_persisted() -> void:
	# [T] #76：cum_influence 只增不减 + 入档 flags 读档还原（零迁移）
	var world := GameWorld.new()
	world.start_new_game(2026)
	world.economy.apply_delta("influence", 300, "test_gain")
	var cum_before: int = world.economy.get_cum_influence()
	assert_eq(cum_before, 300, "累计计数器吃正向过账")
	world.economy.apply_delta("influence", -500, "tech_research_rp")
	assert_eq(world.economy.get_cum_influence(), cum_before, "消耗不减少累计（只增不减）")
	var saved: Dictionary = SnapshotCodec.to_save(world)
	assert_eq(
		int((saved.get("flags", {}) as Dictionary).get("cum_influence", -1)),
		cum_before,
		"入档 flags.cum_influence（开放容器零迁移）"
	)
	var fresh := GameWorld.new()
	autofree(fresh)
	fresh.restore(saved)
	assert_eq(fresh.economy.get_cum_influence(), cum_before, "读档还原累计计数器")
	# 旧档缺键兜底为 0（不坏档）
	var legacy: Dictionary = saved.duplicate(true)
	(legacy.get("flags", {}) as Dictionary).erase("cum_influence")
	var legacy_world := GameWorld.new()
	autofree(legacy_world)
	legacy_world.restore(legacy)
	assert_eq(legacy_world.economy.get_cum_influence(), 0, "旧档缺 cum_influence 键应兜底为 0")


## ============ 辅助 ============


## 跑 weeks 周单槽串行策略，返回 {rp: Σrp_output, count: 完成笔数}。
func _run_supply(seed_value: int, priority: PackedStringArray, weeks: int) -> Dictionary:
	var world := GameWorld.new()
	world.start_new_game(seed_value)
	var acc: Dictionary = {"rp": 0, "count": 0}
	world.task_state_changed.connect(
		func(task_id: String, state: String) -> void:
			if state == "completed":
				acc["rp"] = (
					int(acc["rp"])
					+ int((_tasks_cfg.get(task_id, {}) as Dictionary).get("rp_output", 0))
				)
				acc["count"] = int(acc["count"]) + 1
	)
	for _i: int in range(weeks):
		_fill_task(world, priority)
		world.simulate_weeks(1)
		if world.game_over_flag:
			break
	return acc


func _fill_task(world: GameWorld, priority: PackedStringArray) -> void:
	if not world.task_queue.get_active_task().is_empty():
		return
	for task_id: String in priority:
		world.enqueue_task(task_id)
		if not world.task_queue.get_active_task().is_empty():
			return


## 构造对照世界：注入 influence_gain 后周结一次，再施加 spend（负数=点树消耗）后周结一次。
func _world_with_influence(seed_value: int, gain: int, spend: int) -> GameWorld:
	var world := GameWorld.new()
	world.start_new_game(seed_value)
	world.economy.apply_delta("influence", gain, "test_gain")
	world.settle_week()
	if spend != 0:
		world.economy.apply_delta("influence", spend, "tech_research_rp")
		world.settle_week()
	return world


## 可研节点 rp_cost 升序（贪心点亮口径）。
func _researchable_rp_costs() -> Array[int]:
	var costs: Array[int] = []
	for node_id: String in _techs_cfg.get("nodes", {}):
		var node: Dictionary = _techs_cfg["nodes"][node_id]
		var domain: String = str(node.get("domain", ""))
		var flags: Dictionary = _techs_cfg.get("domain_flags", {}).get(domain, {})
		if not bool(flags.get("researchable", true)):
			continue
		costs.append(int(node.get("rp_cost", 0)))
	costs.sort()
	return costs
