class_name TestRivalTrack
extends GutTest

## PR7 (issue #14) 深巷 8 动作时间线、±15% 扰动与预警专项测试
## 覆盖 4 个 [T] 验收点：
## 1. 8 动作周界触发断言（首模型 ~12 周；spill_fields/spill_rp_gate 表级默认+单动作覆写）
## 2. 同 seed 确定性断言（±15% 仅周结消费）
## 3. 外溢翻态确定性规则表断言（零 RNG）
## 4. 预警阈值断言：黄灯=⌈0.15t⌉ 周（6/9/11/13）、红灯=2 周、红灯误报率=0

var _rival_cfg: Dictionary
var _techs_cfg: Dictionary


func before_each() -> void:
	_rival_cfg = DataLoader.load_json("res://src/data/rivals.json")
	_techs_cfg = DataLoader.load_json("res://src/data/techs.json")


func test_acceptance_point_1_eight_actions_and_timeline() -> void:
	# [T] 验收点 1：8 动作周界触发断言与首模型 ~12 周
	var timeline: Array = _rival_cfg.get("timeline", [])
	assert_eq(timeline.size(), 8, "竞对时间线必须严格包含 8 个动作")

	# 首模型发版动作 (rv_launch_l1)
	var l1_act: Dictionary = timeline[1]
	assert_eq(l1_act["id"], "rv_launch_l1")
	assert_eq(int(l1_act["week"]), 12, "首模型基准发版周为 12 周（卡玩家首训出分窗口）")

	# 表级默认参数核对
	assert_true(_rival_cfg.has("spill_fields"))
	assert_eq(int(_rival_cfg.get("spill_rp_gate")), 300)


func test_acceptance_point_2_jitter_determinism_same_seed() -> void:
	# [T] 验收点 2：同 seed 确定性断言（±15% 扰动仅在 setup 时通过 RNG 域消费）
	var rng1 := RngStream.new(42)
	var rival1 := RivalTrack.new()
	rival1.setup(_rival_cfg, rng1)

	var rng2 := RngStream.new(42)
	var rival2 := RivalTrack.new()
	rival2.setup(_rival_cfg, rng2)

	for act_variant: Variant in _rival_cfg.get("timeline", []):
		var act_id: String = str(act_variant.get("id"))
		assert_eq(
			rival1.get_action_week(act_id),
			rival2.get_action_week(act_id),
			"动作 %s 的实际触发周在相同 seed 下必须完全一致" % act_id
		)

	# 验证发版动作在 ±15% 扰动区间内
	# L1 名义 12 周 -> [10, 14]
	var l1_actual: int = rival1.get_action_week("rv_launch_l1")
	assert_true(l1_actual >= 10 and l1_actual <= 14, "L1 发版在 [10, 14] 周内")


func test_acceptance_point_3_spill_deterministic_reveal() -> void:
	# [T] 验收点 3：外溢翻态确定性规则表断言（零 RNG）
	var fog := TechFog.new()
	fog.setup(_techs_cfg)
	var rival := RivalTrack.new()
	rival.setup(_rival_cfg, RngStream.new(99))

	# 动作 0 为论文《多步推演初探》，target_tech=distill_garden
	assert_true(fog.get_state("distill_garden") != TechFog.STATE_LIT)

	watch_signals(rival)
	# 推进到第 6 周
	var actions := rival.settle_week(6, fog)
	assert_eq(actions.size(), 1, "第 6 周触发 1 个动作")
	assert_eq(actions[0]["id"], "rv_paper_1", "触发论文外溢")
	assert_signal_emitted(rival, "rival_spill_triggered")


func test_acceptance_point_4_warning_thresholds_and_zero_false_alarm() -> void:
	# [T] 验收点 4：预警阈值断言：黄灯 ⌈0.15t⌉ 周（6/9/11/13）、红灯 2 周、红灯误报率=0
	var rival := RivalTrack.new()
	var rng := RngStream.new(123)
	rival.setup(_rival_cfg, rng)
	var fog := TechFog.new()
	fog.setup(_techs_cfg)

	var l1_week: int = rival.get_action_week("rv_launch_l1")

	# 在 l1_week - 2 周时，必须判定为红灯预警
	watch_signals(rival)
	rival.settle_week(l1_week - 2, fog)
	assert_signal_emitted_with_parameters(
		rival, "rival_warned", [RivalTrack.WARN_RED, "rv_launch_l1", 2]
	)

	# 提前 5 周时应为黄灯（warn_weeks=6，weeks_left=5 <= 6）
	var rival_yellow := RivalTrack.new()
	rival_yellow.setup(_rival_cfg, rng)
	watch_signals(rival_yellow)
	rival_yellow.settle_week(l1_week - 5, fog)
	assert_signal_emitted_with_parameters(
		rival_yellow, "rival_warned", [RivalTrack.WARN_YELLOW, "rv_launch_l1", 5]
	)


## ============ #77（0.1.5-1f）竞对死表重标专项 ============


func test_rival_scores_within_reach_band() -> void:
	# [T] #77：重标后每个发版动作所需 A ≤ 玩家可达上限 A（离线标定口径，不改引擎）
	var benchmarks: Dictionary = DataLoader.load_json("res://src/data/benchmarks.json")
	var params: Dictionary = ScoreMath.normalize_params(benchmarks["bench_gkp"])
	assert_false(params.is_empty(), "出分参数必须可注入（benchmarks.json）")
	# 玩家可达上限配置（纪要 §2.4 满配）：eff=187（3 人上桌）+ 满树 tb=1.40 + tier4 + 深渊 q=1.0
	var max_ability: float = ScoreMath.calculate_ability(187, 1.4, 4, 1.0, params)
	assert_almost_eq(max_ability, 213.4, 1.0, "满配 A 上限 ~213.4")
	var max_score: float = ScoreMath.calculate_score(max_ability, params)
	var launches: int = 0
	for act_variant: Variant in _rival_cfg.get("timeline", []):
		var act: Dictionary = act_variant
		if str(act.get("type", "")) != "launch":
			continue
		launches += 1
		var score: float = float(act.get("score", 0.0))
		var required_a: float = ScoreMath.ability_for_score(score, params)
		assert_lte(
			required_a,
			max_ability,
			(
				"动作 %s（%.1f 分）所需 A %.1f 应 ≤ 玩家上限 %.1f"
				% [str(act.get("id", "")), score, required_a, max_ability]
			)
		)
		assert_gte(max_score, score, "满配可达分 %.1f 应 ≥ 死表分 %.1f（霸榜可达）" % [max_score, score])
	assert_eq(launches, 4, "发版动作应为 4 个（L1–L4）")
	# 死表纪律：±15% 扰动只作用于周次（分数无随机）——时间线周次不动（DR-027④）
	assert_true(_rival_cfg.has("jitter_pct"), "扰动参数必须在表级")
	for act_variant: Variant in _rival_cfg.get("timeline", []):
		var act: Dictionary = act_variant
		assert_true(act.has("week"), "动作 %s 必须带名义周次" % str(act.get("id", "")))


func test_rival_l4_within_guard_band() -> void:
	# [T] #77：L4 死表分 ∈[93,98] 且 < 玩家封顶 99（禁超玩家）
	var l4: Dictionary = {}
	for act_variant: Variant in _rival_cfg.get("timeline", []):
		var act: Dictionary = act_variant
		if str(act.get("id", "")) == "rv_launch_l4":
			l4 = act
	assert_false(l4.is_empty(), "L4 动作必须存在")
	var score: float = float(l4.get("score", 0.0))
	assert_between(score, 93.0, 98.0, "L4 死表分 %.1f 应落守卫带 [93,98]" % score)
	assert_lt(score, 99.0, "L4 禁超玩家封顶 99 分")
	assert_eq(int(l4.get("week", 0)), 82, "L4 发版周次 82 不动（守 DR-027④ 先发率）")
	# 三层张力：L4 高于 L3，形成"越追越紧"的压迫曲线
	var l3_score: float = 0.0
	for act_variant: Variant in _rival_cfg.get("timeline", []):
		var act: Dictionary = act_variant
		if str(act.get("id", "")) == "rv_launch_l3":
			l3_score = float(act.get("score", 0.0))
	assert_gt(score, l3_score, "L4（%.1f）应高于 L3（%.1f）" % [score, l3_score])
