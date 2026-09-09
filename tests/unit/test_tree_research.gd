extends GutTest
## #138 研究点亮测试：研究命令/效果分层/数值节点 G9/预算护栏。
## DoD 用例名与 issue 逐字一致。

const NODE_ALIGN_A: String = "align_rlhf_align"
const NODE_ALIGN_B: String = "align_pref_opt"
const NODE_MULTI_A: String = "multimodal_vlm_base"
const NODE_MULTI_B: String = "multimodal_audio_base"
const NODE_CROSS_SCALE: String = "cross_scale_bridge"


## 造一棵可研究的树：把节点推进到 visible（研究入口态）
func _make_tree_with_visible(node_ids: Array[String]) -> TechTree:
	var tree := TechTree.new()
	autofree(tree)
	for node_id: String in node_ids:
		# hidden→rumored→visible（两档）
		tree.advance_fog(node_id)
		tree.advance_fog(node_id)
	return tree


func test_research_lightup_and_reject() -> void:
	# DoD 1：研究点亮——消耗影响力/前置校验/周结 lit，拒绝分支原因可见
	var tree := _make_tree_with_visible([NODE_ALIGN_A, NODE_ALIGN_B])
	var research := tree.get_research()
	assert_not_null(research, "研究组件已装配")
	# 影响力消耗谓词：记录调用并允许
	var spent: Array[int] = []
	research.spend_influence = func(amount: int) -> bool:
		spent.append(amount)
		return true
	# 研究 A（成本 30）
	var result := tree.start_research(NODE_ALIGN_A)
	assert_true(result.ok, "visible 节点可开始研究")
	assert_eq(int(result.cost), 30, "研究成本 30（表驱动）")
	assert_eq(spent[0], 30, "影响力消耗 30")
	assert_eq(tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.RESEARCHABLE, "研究中态")
	# 周结推进到 lit
	var completed := research.research_tick()
	# align_pref_opt 浅置 2 周
	assert_eq(completed.size(), 0, "第 1 周未完成")
	completed = research.research_tick()
	assert_eq(completed.size(), 1, "第 2 周完成 lit")
	assert_true(tree.is_node_lit(NODE_ALIGN_A), "A lit")
	assert_eq(str(completed[0]["effect"]["type"]), "unlock", "A 效果=unlock")
	# 拒绝分支：非 visible 不可研（B 前置=A 未... B 已 lit？B 前置 A——A 已 lit 所以 B 可研）
	# 未知节点拒绝
	var bad := tree.start_research("no_such_node")
	assert_false(bad.ok, "未知节点拒绝")
	assert_true(str(bad.reason).contains("未知"), "拒绝原因可见")
	# lit 节点不可重复研
	var again := tree.start_research(NODE_ALIGN_A)
	assert_false(again.ok, "lit 不可重复研究")


func test_research_prereq_and_influence_gate() -> void:
	# 前置校验：B（align_pref_opt）前置=A；A 未 lit 时 B 不可研
	var tree := _make_tree_with_visible([NODE_ALIGN_A, NODE_ALIGN_B])
	var research := tree.get_research()
	var spent: Array[int] = []
	research.spend_influence = func(amount: int) -> bool:
		spent.append(amount)
		return true
	# B 前置 A 未 lit → 拒绝（reason=前置）
	var b_result := tree.start_research(NODE_ALIGN_B)
	assert_false(b_result.ok, "前置未满足拒绝")
	assert_true(str(b_result.reason).contains("前置"), "拒绝原因=前置未点亮")
	# 影响力不足拒绝
	research.spend_influence = func(_amount: int) -> bool: return false
	var a_result := tree.start_research(NODE_ALIGN_A)
	assert_false(a_result.ok, "影响力不足拒绝")
	assert_true(str(a_result.reason).contains("影响力"), "拒绝原因=影响力不足")


func test_tree_effect_layer_ratio() -> void:
	# DoD 2：效果分层占比——数值型 ≤3/解锁为主/降费有上限
	var tree := TechTree.new()
	autofree(tree)
	var research := tree.get_research()
	var counts := research.get_effect_layer_counts()
	assert_true(int(counts["unlock"]) >= int(counts["mult"]) + int(counts["cost"]), "解锁为主")
	assert_true(int(counts["mult"]) <= 3, "数值型 ≤3（G9 防 uniform 回归）")
	# 降费单级 ≤12%（读表断言：cost amount_per_level ≤0.12）
	var effects: Dictionary = (
		DataLoader.load_json("res://src/data/tech_tree.json")["tree_node_effects"]
	)
	for node_id: Variant in effects.keys():
		var effect: Dictionary = effects[node_id]
		if str(effect.get("type", "")) == "cost":
			assert_true(float(effect.get("amount_per_level", 0.0)) <= 0.12, "降费单级≤12%（D.2 护栏）")


func test_tree_numeric_node_placement() -> void:
	# DoD 3：数值节点单级 +2–3% 且 1 浅置（W20–40 可达）+1 深置
	var tree := TechTree.new()
	autofree(tree)
	var research := tree.get_research()
	var placements := research.get_mult_placements()
	assert_eq(placements["shallow"].size(), 1, "恰 1 浅置数值节点")
	assert_eq(placements["deep"].size(), 1, "恰 1 深置数值节点")
	# 单级 +2–3%（读表断言：mult amount_per_level ∈[0.02, 0.03]）
	var effects: Dictionary = (
		DataLoader.load_json("res://src/data/tech_tree.json")["tree_node_effects"]
	)
	var all_mult: Array = []
	all_mult.append_array(placements["shallow"])
	all_mult.append_array(placements["deep"])
	for node_id: Variant in all_mult:
		var effect: Dictionary = effects[node_id]
		var per_level := float(effect.get("amount_per_level", 0.0))
		assert_true(
			per_level >= 0.02 and per_level <= 0.03,
			"乘子单级 +2–3%%: %s=%s" % [str(node_id), str(per_level)]
		)


func test_tree_budget_guardrails() -> void:
	# DoD 4：树贡献预算护栏——全口径 score ≤30%
	var tree := TechTree.new()
	autofree(tree)
	var research := tree.get_research()
	assert_almost_eq(research.get_tree_budget(), 0.3, 0.001, "预算=30%（表驱动）")
	# 树贡献 20% → ok；35% → 拒绝
	assert_true(research.is_tree_budget_ok(100.0, 80.0), "树贡献 20% 在预算内")
	assert_false(research.is_tree_budget_ok(100.0, 65.0), "树贡献 35% 超预算（护栏拦截）")
	# 边界 30% → ok（≤）
	assert_true(research.is_tree_budget_ok(100.0, 70.0), "树贡献 30% 边界内")


func test_upgrade_numeric_node() -> void:
	# 升级：数值/降费型可升（★2/★3），解锁型 1 级即满
	var tree := _make_tree_with_visible([NODE_MULTI_A, NODE_MULTI_B])
	var research := tree.get_research()
	research.spend_influence = func(_amount: int) -> bool: return true
	# 前置链：先研 A（unlock 浅 2 周）→ lit，再研 B（深置 4 周）→ lit
	assert_true(tree.start_research(NODE_MULTI_A).ok, "A 可研（前置空）")
	for i: int in 2:
		research.research_tick()
	assert_true(tree.is_node_lit(NODE_MULTI_A), "A lit（解锁型 2 周）")
	assert_true(tree.start_research(NODE_MULTI_B).ok, "B 前置满足可研（深置）")
	for i: int in 4:
		research.research_tick()
	assert_true(tree.is_node_lit(NODE_MULTI_B), "深置节点 lit（4 周）")
	# mult 节点可升级
	var up1 := tree.upgrade_node(NODE_MULTI_B)
	assert_true(up1.ok, "mult 节点可升级 ★2")
	assert_eq(int(up1.level), 2, "升级到 ★2")
	var up2 := tree.upgrade_node(NODE_MULTI_B)
	assert_true(up2.ok, "可升级 ★3")
	var up3 := tree.upgrade_node(NODE_MULTI_B)
	assert_false(up3.ok, "满级拒绝（tree_upgrade_max=3）")
	assert_true(str(up3.reason).contains("满级"), "拒绝原因=满级")
	# 解锁型 1 级即满（A 是 unlock——先研 A 并 lit）
	var tree2 := _make_tree_with_visible([NODE_ALIGN_A])
	var r2 := tree2.get_research()
	r2.spend_influence = func(_amount: int) -> bool: return true
	tree2.start_research(NODE_ALIGN_A)
	for i: int in 2:
		r2.research_tick()
	var unlock_up := tree2.upgrade_node(NODE_ALIGN_A)
	assert_false(unlock_up.ok, "解锁型不可升级")
	assert_true(str(unlock_up.reason).contains("解锁型"), "拒绝原因=解锁型 1 级即满")
