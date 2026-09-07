class_name TestTechTreeAndStages
extends GutTest

## PR5 (issue #10) 谓词注册表、科技树研发与 Stages 阶段软门专项测试
## 覆盖 4 个 [T] 验收点：
## 1. 每谓词正反例断言（lit{tech_id} 等 4 类成对注册与 any_of 判定）
## 2. 资源不足拒绝断言（预扣 RP+结项资金原子校验）
## 3. 阶段晋级/维持分支断言（gate 谓词+expected_p50 占位）
## 4. economy_mod 修正后收支断言（挂钩 stage_depr）

var _techs_cfg: Dictionary
var _stages_cfg: Dictionary


func before_each() -> void:
	_techs_cfg = DataLoader.load_json("res://src/data/techs.json")
	_stages_cfg = DataLoader.load_json("res://src/data/stages.json")


func test_acceptance_point_1_predicate_registry_cases() -> void:
	# [T] 验收点 1：每谓词正反例断言（成对注册）
	var context: Dictionary = {
		"money": 50000,
		"influence": 500,
		"cumulative_rp": 1200,
		"lit_techs": ["silver_leash", "cot_sketch"],
		"crossover_count": 2,
	}

	# 1. none / never
	assert_true(PredicateRegistry.evaluate({"predicate": "none"}, context), "none 恒为 true")
	assert_false(PredicateRegistry.evaluate({"predicate": "never"}, context), "never 恒为 false")

	# 2. tech_lit 正反例
	var pred_lit_true: Dictionary = {
		"predicate": "tech_lit",
		"params": {"tech_id": "silver_leash"},
	}
	var pred_lit_false: Dictionary = {
		"predicate": "tech_lit",
		"params": {"tech_id": "silent_chain"},
	}
	assert_true(PredicateRegistry.evaluate(pred_lit_true, context), "已点亮科技判定为 true")
	assert_false(PredicateRegistry.evaluate(pred_lit_false, context), "未点亮科技判定为 false")

	# tech_ids 多前置全满足正反例
	var pred_lits_true: Dictionary = {
		"predicate": "tech_lit",
		"params": {"tech_ids": ["silver_leash", "cot_sketch"]},
	}
	var pred_lits_false: Dictionary = {
		"predicate": "tech_lit",
		"params": {"tech_ids": ["silver_leash", "silent_chain"]},
	}
	assert_true(PredicateRegistry.evaluate(pred_lits_true, context), "全部点亮返回 true")
	assert_false(PredicateRegistry.evaluate(pred_lits_false, context), "部分未点亮返回 false")

	# 3. rp_threshold 正反例
	var pred_rp_pass: Dictionary = {
		"predicate": "rp_threshold",
		"params": {"threshold": 1000},
	}
	var pred_rp_fail: Dictionary = {
		"predicate": "rp_threshold",
		"params": {"threshold": 2000},
	}
	assert_true(PredicateRegistry.evaluate(pred_rp_pass, context), "累积 RP 达标返回 true")
	assert_false(PredicateRegistry.evaluate(pred_rp_fail, context), "累积 RP 未达标返回 false")

	# 4. min_money 正反例
	var pred_money_pass: Dictionary = {
		"predicate": "min_money",
		"params": {"amount": 30000},
	}
	var pred_money_fail: Dictionary = {
		"predicate": "min_money",
		"params": {"amount": 60000},
	}
	assert_true(PredicateRegistry.evaluate(pred_money_pass, context), "资金充足返回 true")
	assert_false(PredicateRegistry.evaluate(pred_money_fail, context), "资金不足返回 false")

	# 5. crossover_count 正反例
	var pred_crossover_pass: Dictionary = {
		"predicate": "crossover_count",
		"params": {"required_lit_count": 2},
	}
	var pred_crossover_fail: Dictionary = {
		"predicate": "crossover_count",
		"params": {"required_lit_count": 3},
	}
	assert_true(PredicateRegistry.evaluate(pred_crossover_pass, context), "已点亮主干数达标")
	assert_false(PredicateRegistry.evaluate(pred_crossover_fail, context), "已点亮主干数未达标")

	# 6. 单层 any_of
	var pred_any_of_true: Dictionary = {
		"any_of": [pred_money_fail, pred_lit_true],
	}
	var pred_any_of_false: Dictionary = {
		"any_of": [pred_money_fail, pred_lit_false],
	}
	assert_true(PredicateRegistry.evaluate(pred_any_of_true, context), "any_of 任一满足为 true")
	assert_false(PredicateRegistry.evaluate(pred_any_of_false, context), "any_of 全不满足为 false")


func test_acceptance_point_2_resource_shortage_rejection() -> void:
	# [T] 验收点 2：资源不足拒绝断言（预扣 RP+结项资金原子检查）
	var fog := TechFog.new()
	fog.setup(_techs_cfg)
	var tree := TechTree.new()
	tree.setup(_techs_cfg, fog)

	# silver_leash 开局处于 researchable，rp_cost=300, cost=0
	var context_poor_rp: Dictionary = {
		"influence": 200,
		"money": 50000,
	}
	var check_rp: Dictionary = tree.can_research("silver_leash", context_poor_rp)
	assert_false(check_rp["ok"], "RP 不足时 can_research 应返回 false")
	assert_eq(check_rp["reason"], "insufficient_rp")

	var res_fail: Dictionary = tree.start_research("silver_leash", context_poor_rp)
	assert_false(res_fail["ok"], "RP 不足启动研发失败")
	assert_eq(fog.get_state("silver_leash"), TechFog.STATE_RESEARCHABLE, "失败未改变迷雾态")
	assert_eq(context_poor_rp["influence"], 200, "失败不得扣除 RP")

	# 测试资金不足（silent_chain, cost=5000, rp_cost=550）
	# 先翻雾至 visible，再点亮前置 cot_sketch
	fog.spill_reveal("silent_chain", TechFog.STATE_VISIBLE)
	fog.set_lit("cot_sketch")
	assert_eq(fog.get_state("silent_chain"), TechFog.STATE_RESEARCHABLE, "前置点亮后 silent_chain 可研")

	var context_poor_money: Dictionary = {
		"influence": 1000,
		"money": 3000,
	}
	var check_money: Dictionary = tree.can_research("silent_chain", context_poor_money)
	assert_false(check_money["ok"], "资金不足时 can_research 应返回 false")
	assert_eq(check_money["reason"], "insufficient_money")

	# 充足资源下成功研发点亮与原子扣除
	var context_rich: Dictionary = {
		"influence": 1000,
		"money": 10000,
	}
	var res_ok: Dictionary = tree.start_research("silent_chain", context_rich)
	assert_true(res_ok["ok"], "资源充足研发成功")
	assert_eq(context_rich["influence"], 1000 - 550, "原子扣除 550 RP")
	assert_eq(context_rich["money"], 10000 - 5000, "原子扣除 5000 资金")
	assert_eq(fog.get_state("silent_chain"), TechFog.STATE_LIT, "科技状态成功置为 lit")
	assert_true(tree.get_tech_bonus() > 0.0, "成功重算 tech_bonus")


func test_acceptance_point_3_stages_advance_and_maintenance() -> void:
	# [T] 验收点 3：阶段晋级/维持分支断言（gate 谓词+expected_p50 占位）
	var stages := Stages.new()
	stages.setup(_stages_cfg)
	assert_eq(stages.get_current_stage(), 0, "初始阶段为 stage_0 (实验室期)")

	# stage_1 的 gate 为 crossover_count >= 3
	var context_stay: Dictionary = {
		"crossover_count": 2,
	}
	var res_stay: Dictionary = stages.reevaluate(context_stay)
	assert_false(res_stay["advanced"], "条件不满足维持当前阶段")
	assert_eq(stages.get_current_stage(), 0, "阶段保持为 0")

	# 条件满足，触发单步跃迁
	var context_up: Dictionary = {
		"crossover_count": 3,
	}
	var res_up: Dictionary = stages.reevaluate(context_up)
	assert_true(res_up["advanced"], "满足 gate 晋升下一阶段")
	assert_eq(stages.get_current_stage(), 1, "阶段晋升为 1 (自由探索期)")
	assert_eq(res_up["old_stage"], 0)
	assert_eq(res_up["new_stage"], 1)

	# 下一阶段 stage_2 为 enabled: false，即使提供任何 context 也拒绝晋升
	var res_blocked: Dictionary = stages.reevaluate({"crossover_count": 99})
	assert_false(res_blocked["advanced"], "未启用阶段 enabled: false 阻断晋升")
	assert_eq(stages.get_current_stage(), 1, "维持在自由探索期")


func test_acceptance_point_4_economy_mod_and_stage_depr_link() -> void:
	# [T] 验收点 4：economy_mod 修正后收支断言（挂钩 stage_depr）
	var economy := Economy.new()
	var economy_cfg: Dictionary = DataLoader.load_json("res://src/data/economy.json")
	economy.setup(economy_cfg)

	# 初始 stage_0 参数
	var p0: Dictionary = economy.get_stage_depr_params()
	assert_eq(float(p0["reproduce_factor"]), 1.0)
	assert_eq(int(p0["grant_interval_add_weeks"]), 0)

	# 模拟 stages 晋升至 stage_1 并应用 economy_mod
	var stages := Stages.new()
	stages.setup(_stages_cfg)
	var up_res: Dictionary = stages.reevaluate({"crossover_count": 3})
	assert_true(up_res["advanced"])

	var mod: Dictionary = up_res.get("economy_mod", {})
	economy.set_stage_depr(
		float(mod.get("reproduce_factor", 1.0)), int(mod.get("grant_interval_add_weeks", 0))
	)

	# 验证 economy 参数已更新
	var p1: Dictionary = economy.get_stage_depr_params()
	assert_eq(float(p1["reproduce_factor"]), 0.85, "复现衰减系数更新为 0.85")
	assert_eq(int(p1["grant_interval_add_weeks"]), 1, "课题间隔周数更新为 1")
