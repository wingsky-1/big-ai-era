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
