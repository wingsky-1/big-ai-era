class_name TestTechsData
extends GutTest

## PR5 (issue #8) techs.json 14 节点数据表完整性与数值区间断言
## 覆盖 issue #8 验收点：
## 1. 表完整性断言：14 节点全量/parents 边/fog_gate/domain 7 值枚举核对
## 2. 数值区间断言：Σ(rp_cost+域门槛)∈[10k,20k] 警戒带断言（早期 300–420/中继 550/后期 1300–2700/交叉 2400）
## issue #81 追加：每域可达性（RK-08 / M-2）——P50 供给带下每个可研域 ≥1 节点可点亮。

const ASSERTION_BOUNDS_PATH: String = "res://src/data/assertion_bounds.json"

var _techs_data: Dictionary


func before_each() -> void:
	_techs_data = DataLoader.load_json("res://src/data/techs.json")


func test_table_integrity_and_schema() -> void:
	# [T] 验收点 1：表完整性断言
	assert_false(_techs_data.is_empty(), "techs.json 不应为空")

	# 1. 验证 domain 7 值枚举
	var expected_domains: Array[String] = [
		"deep_thought",
		"dandelion",
		"long_memory",
		"synesthesia",
		"tool_use",
		"crossover",
		"elsewhere",
	]
	var domain_enum: Array = _techs_data.get("domain_enum", [])
	assert_eq(domain_enum.size(), 7, "域枚举必须包含 7 个值")
	for dom: String in expected_domains:
		assert_true(domain_enum.has(dom), "域枚举应包含 %s" % dom)

	# 2. 验证表级 fog_gate{rumored, visible}
	var fog_gate: Dictionary = _techs_data.get("fog_gate", {})
	assert_eq(int(fog_gate.get("rumored", 0)), 200, "fog_gate rumored 阈值为 200")
	assert_eq(int(fog_gate.get("visible", 0)), 600, "fog_gate visible 阈值为 600")

	# 3. 验证 14 节点总数与唯一 ID
	var nodes: Dictionary = _techs_data.get("nodes", {})
	assert_eq(nodes.size(), 14, "techs.json 节点总数必须严格等于 14")

	var expected_node_ids: Array[String] = [
		"silver_leash",
		"cot_sketch",
		"silent_chain",
		"distill_garden",
		"hand_tutor",
		"pocket_smart",
		"long_scroll",
		"outer_brain",
		"arm_will",
		"synesthesia_clip",
		"mirror_mind",
		"world",
		"symbol",
		"embodied",
	]
	for node_id: String in expected_node_ids:
		assert_true(nodes.has(node_id), "节点表必须包含节点 %s" % node_id)
		var node: Dictionary = nodes[node_id]
		assert_true(domain_enum.has(node.get("domain")), "节点域必须在 7 值枚举中")
		assert_true(node.has("name") and not str(node["name"]).is_empty(), "节点必须有中文展示名")
		assert_true(node.has("unlock"), "节点必须包含 unlock 字典")
		assert_true(node.has("parents"), "节点必须包含 parents 列表")
		assert_true(node.has("effect"), "节点必须包含 effect 字典")

	# 4. 验证 parents 依赖边有效性
	for node_id: String in nodes:
		var parents: Array = nodes[node_id].get("parents", [])
		for p_id: String in parents:
			assert_true(nodes.has(p_id), "节点 %s 的 parent %s 必须存在于节点表中" % [node_id, p_id])

	# pocket_smart 是 distill_garden 与 hand_tutor 的交叉支路
	var ps_parents: Array = nodes["pocket_smart"].get("parents", [])
	assert_true(
		ps_parents.has("distill_garden") and ps_parents.has("hand_tutor"), "pocket_smart 必须依赖两支路"
	)

	# 5. 通感线 min_week 锚后
	assert_true(
		int(nodes["synesthesia_clip"].get("min_week", 0)) >= 26, "通感线 min_week 必须锚后（>=26 周防穿越）"
	)


func test_rp_cost_and_threshold_alert_band() -> void:
	# [T] 验收点 2：Σ(rp_cost+域门槛)∈[10k,20k] 警戒带断言与梯次分布
	var nodes: Dictionary = _techs_data.get("nodes", {})
	var total_rp_cost: int = 0
	var playable_count: int = 0

	for node_id: String in nodes:
		var node: Dictionary = nodes[node_id]
		var domain: String = node.get("domain", "")
		if domain != "elsewhere":
			playable_count += 1
			total_rp_cost += int(node.get("rp_cost", 0))

	assert_eq(playable_count, 11, "MVP 可研可玩节点数必须为 11 个")

	# 警戒带断言：总 RP 消耗在 [10k, 20k] 范围内（刻意配平供需比 1.0–1.3:1）
	assert_true(total_rp_cost >= 10000, "全树可研 RP 消耗下限 >= 10000")
	assert_true(total_rp_cost <= 20000, "全树可研 RP 消耗上限 <= 20000")

	# 早期门槛分布：300–420
	assert_eq(int(nodes["silver_leash"]["rp_cost"]), 300, "silver_leash rp_cost=300")
	assert_eq(int(nodes["cot_sketch"]["rp_cost"]), 360, "cot_sketch rp_cost=360")
	assert_eq(int(nodes["hand_tutor"]["rp_cost"]), 380, "hand_tutor rp_cost=380")
	assert_eq(int(nodes["distill_garden"]["rp_cost"]), 420, "distill_garden rp_cost=420")

	# 中继门槛分布：550
	assert_eq(int(nodes["silent_chain"]["rp_cost"]), 550, "silent_chain rp_cost=550")

	# 后期门槛分布：1300–2700
	assert_true(int(nodes["pocket_smart"]["rp_cost"]) >= 1300, "pocket_smart >= 1300")
	assert_true(int(nodes["synesthesia_clip"]["rp_cost"]) <= 2700, "synesthesia_clip <= 2700")

	# 交叉门槛：2400
	assert_eq(int(nodes["mirror_mind"]["rp_cost"]), 2400, "mirror_mind rp_cost=2400")


func test_each_domain_has_reachable_node() -> void:
	# [T] #81 验收点 4（RK-08 硬约束 / DR-031 M-2）：P50 供给带下每个可研域 ≥1 节点可点亮。
	# 口径：节点的"点亮成本"= 其依赖闭包（parents 全 lit 的传递闭包）rp_cost 之和
	# + 交叉节点的主干前置（crossover_count 最省主干集），预算 = P50 供给带上界
	# （读 assertion_bounds.json，禁硬编码）。判定后用 TechFog 真跑一遍交叉验证。
	var nodes: Dictionary = _techs_data.get("nodes", {})
	var budget: int = _p50_supply_max()
	assert_true(budget > 0, "P50 供给带上界必须就位且为正")

	var checked_domains: int = 0
	for domain_variant: Variant in _techs_data.get("domain_enum", []):
		var domain: String = str(domain_variant)
		if not _domain_researchable(domain):
			continue
		checked_domains += 1

		var best_id: String = ""
		var best_cost: int = -1
		var best_plan: Dictionary = {}
		for node_id: String in nodes:
			if str(nodes[node_id].get("domain", "")) != domain:
				continue
			var plan: Dictionary = _lit_plan(nodes, node_id)
			var cost: int = _plan_cost(nodes, plan) + int(nodes[node_id].get("rp_cost", 0))
			if best_id == "" or cost < best_cost:
				best_id = node_id
				best_cost = cost
				best_plan = plan

		assert_ne(best_id, "", "可研域 %s 必须至少 1 个节点" % domain)
		assert_true(
			best_cost <= budget,
			"域 %s 最省点亮成本 %d 必须 ≤ P50 供给上界 %d（否则该域不可达）" % [domain, best_cost, budget]
		)

		# 行为交叉验证：按最省计划点亮前置后，TechFog 必须真的把该节点升为 researchable。
		var fog: TechFog = TechFog.new()
		fog.advance_with_context({"cum_influence": budget})
		for lit_id: String in best_plan:
			fog.set_lit(lit_id)
		assert_eq(
			fog.get_state(best_id),
			TechFog.STATE_RESEARCHABLE,
			"域 %s 节点 %s 在 P50 供给内必须真的可研" % [domain, best_id]
		)

	assert_eq(checked_domains, 6, "可研域应为 6 个（深思/蒲公英/长忆/通感/器用/交叉）")

	# elsewhere（他者道路）：显示但不可研——unlock=never + domain_flags.researchable=false。
	var flags: Dictionary = _techs_data.get("domain_flags", {})
	var elsewhere_flags: Variant = flags.get("elsewhere", {})
	assert_true(elsewhere_flags is Dictionary, "elsewhere 必须有域标志行")
	assert_false(
		bool((elsewhere_flags as Dictionary).get("researchable", true)), "elsewhere 域必须不可研"
	)
	var elsewhere_nodes: int = 0
	for node_id: String in nodes:
		if str(nodes[node_id].get("domain", "")) != "elsewhere":
			continue
		elsewhere_nodes += 1
		assert_eq(
			str(nodes[node_id].get("unlock", {}).get("predicate", "")),
			"never",
			"elsewhere 节点 %s 解锁谓词必须为 never" % node_id
		)
	assert_eq(elsewhere_nodes, 3, "elsewhere 占位节点必须为 3（DR-031/D-1：14 = 11 + 3）")


## P50 供给带上界（assertion_bounds.json.v6_tech_lit_distribution.supply_band_rp_max）。
func _p50_supply_max() -> int:
	var bounds: Dictionary = DataLoader.load_json(ASSERTION_BOUNDS_PATH)
	var band: Variant = DataLoader.require_key(
		bounds, "v6_tech_lit_distribution", ASSERTION_BOUNDS_PATH
	)
	assert_true(band is Dictionary, "assertion_bounds 应含 v6_tech_lit_distribution")
	if not (band is Dictionary):
		return 0
	var supply_max: Variant = DataLoader.require_key(
		band, "supply_band_rp_max", ASSERTION_BOUNDS_PATH
	)
	assert_true(supply_max != null, "供给带上界缺键（ADR-0013 零默认值纪律）")
	return int(supply_max) if supply_max != null else 0


## 域是否可研（domain_flags.researchable；未标注域默认可研）。
func _domain_researchable(domain: String) -> bool:
	var flags: Dictionary = _techs_data.get("domain_flags", {})
	var row: Variant = flags.get(domain)
	if row is Dictionary:
		return bool((row as Dictionary).get("researchable", true))
	return true


## 域是否计入主干（domain_flags.counts_mainline；未标注域默认计入）。
func _is_mainline_domain(domain: String) -> bool:
	var flags: Dictionary = _techs_data.get("domain_flags", {})
	var row: Variant = flags.get(domain)
	if row is Dictionary:
		return bool((row as Dictionary).get("counts_mainline", true))
	return true


## 点亮 node_id 所需的前置集合（不含 node_id 自身）：parents 闭包 + 交叉主干前置。
func _lit_plan(nodes: Dictionary, node_id: String) -> Dictionary:
	var plan: Dictionary = {}
	for parent: Variant in nodes[node_id].get("parents", []):
		_add_parent_closure(nodes, str(parent), plan)

	var unlock: Dictionary = nodes[node_id].get("unlock", {})
	if str(unlock.get("predicate", "")) == "crossover_count":
		var params: Dictionary = unlock.get("params", {})
		var required: int = int(params.get("required_lit_count", 0))
		while _mainline_count(nodes, plan) < required:
			var pick: String = _cheapest_mainline_marginal(nodes, plan)
			if pick == "":
				break
			_add_parent_closure(nodes, pick, plan)
	return plan


func _add_parent_closure(nodes: Dictionary, node_id: String, acc: Dictionary) -> void:
	if acc.has(node_id) or not nodes.has(node_id):
		return
	acc[node_id] = true
	for parent: Variant in nodes[node_id].get("parents", []):
		_add_parent_closure(nodes, str(parent), acc)


func _plan_cost(nodes: Dictionary, plan: Dictionary) -> int:
	var total: int = 0
	for node_id: String in plan:
		total += int(nodes[node_id].get("rp_cost", 0))
	return total


func _mainline_count(nodes: Dictionary, acc: Dictionary) -> int:
	var count: int = 0
	for node_id: String in acc:
		if _is_mainline_domain(str(nodes[node_id].get("domain", ""))):
			count += 1
	return count


## 当前未点亮集合中，使主干数 +1 且边际成本最小的节点（构造性上界，不求全局最优）。
func _cheapest_mainline_marginal(nodes: Dictionary, acc: Dictionary) -> String:
	var best_id: String = ""
	var best_cost: int = -1
	for node_id: String in nodes:
		if acc.has(node_id):
			continue
		if not _is_mainline_domain(str(nodes[node_id].get("domain", ""))):
			continue
		var probe: Dictionary = acc.duplicate()
		_add_parent_closure(nodes, node_id, probe)
		var marginal: int = _plan_cost(nodes, probe) - _plan_cost(nodes, acc)
		if best_id == "" or marginal < best_cost:
			best_id = node_id
			best_cost = marginal
	return best_id
