class_name TestTechsData
extends GutTest

## PR5 (issue #8) techs.json 14 节点数据表完整性与数值区间断言
## 覆盖 issue #8 验收点：
## 1. 表完整性断言：14 节点全量/parents 边/fog_gate/domain 7 值枚举核对
## 2. 数值区间断言：Σ(rp_cost+域门槛)∈[10k,20k] 警戒带断言（早期 300–420/中继 550/后期 1300–2700/交叉 2400）

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
