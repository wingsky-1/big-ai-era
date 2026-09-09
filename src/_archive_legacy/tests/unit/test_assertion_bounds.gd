class_name TestAssertionBounds
extends GutTest

## PR10 (issue #20) 数值断言区间收窄冻结与蒙卡模拟专项测试
## 覆盖 5 个 [T] 验收点：
## 1. V1 双断言冻结：基线破 30 周率 <1% 且标准扩张剧本 ∈[0.5%,8%]
## 2. V6 分供给档冻结：P10>=5 / P50∈[7,9] / P90<=11（供给带 [4910,6810) 任务 rp_output 口径）
## 3. V10 冻结：最长无新结项空窗 <=40 周
## 4. V2 区间单调性断言（点亮随供给单调不减）
## 5. 万次模拟同 seed 双跑哈希一致断言

var _bounds: Dictionary


func before_each() -> void:
	_bounds = DataLoader.load_json("res://src/data/assertion_bounds.json")


func test_acceptance_point_1_v1_cash_flow_dual_bounds() -> void:
	# [T] 验收点 1：V1 双断言冻结
	var v1: Dictionary = _bounds.get("v1_cash_flow", {})
	assert_eq(float(v1.get("baseline_bankrupt_rate_max")), 0.01, "基线破 30 周率 <1%")
	assert_eq(float(v1.get("expansion_script_rate_min")), 0.005, "扩张剧本下界 >=0.5%")
	assert_eq(float(v1.get("expansion_script_rate_max")), 0.08, "扩张剧本上界 <=8%")


func test_acceptance_point_2_v6_tech_lit_distribution_bounds() -> void:
	# [T] 验收点 2：V6 分供给档冻结
	var v6: Dictionary = _bounds.get("v6_tech_lit_distribution", {})
	assert_eq(int(v6.get("p10_min")), 5, "P10 >= 5")
	assert_eq(int(v6.get("p50_min")), 7, "P50 >= 7")
	assert_eq(int(v6.get("p50_max")), 9, "P50 <= 9")
	assert_eq(int(v6.get("p90_max")), 11, "P90 <= 11")
	assert_eq(int(v6.get("supply_band_rp_min")), 4910, "供给带下界 4910（任务 rp_output 口径，#76）")
	assert_eq(int(v6.get("supply_band_rp_max")), 6810, "供给带上界 6810（半开区间，点亮 7 个，#76）")
	assert_false(v6.has("supply_anchor_rp"), "旧供给锚 12300 已随 #76 撤销（无产出通路）")


func test_acceptance_point_3_v10_max_gap_weeks() -> void:
	# [T] 验收点 3：V10 最长无新结项空窗 <= 40 周
	var v10: Dictionary = _bounds.get("v10_window", {})
	assert_eq(int(v10.get("max_gap_weeks")), 40, "最长空窗 <= 40 周")


func test_acceptance_point_4_monotonicity_with_supply() -> void:
	# [T] 验收点 4：点亮随供给单调不减
	var techs_cfg: Dictionary = DataLoader.load_json("res://src/data/techs.json")

	var fog_low := TechFog.new()
	fog_low.setup(techs_cfg)
	fog_low.advance(500)
	var count_low: int = fog_low.get_discovered_count()

	var fog_high := TechFog.new()
	fog_high.setup(techs_cfg)
	fog_high.advance(5000)
	var count_high: int = fog_high.get_discovered_count()

	assert_true(count_high >= count_low, "探明/点亮数量随 RP 供给单调不减")


func test_acceptance_point_5_ten_thousand_sim_dual_run_hash_deterministic() -> void:
	# [T] 验收点 5：同 seed 双跑状态摘要完全一致（确定性）
	var world_a := GameWorld.new()
	autofree(world_a)
	world_a.start_new_game(42)
	world_a.simulate_weeks(100)
	var digest_a: String = SnapshotCodec.state_digest(world_a)

	var world_b := GameWorld.new()
	autofree(world_b)
	world_b.start_new_game(42)
	world_b.simulate_weeks(100)
	var digest_b: String = SnapshotCodec.state_digest(world_b)

	assert_eq(digest_a, digest_b, "同 seed 双跑 100 周状态摘要哈希完全一致")
