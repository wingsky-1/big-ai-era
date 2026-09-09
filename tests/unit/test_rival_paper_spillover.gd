extends GutTest
## #144 验收点 4：外溢翻雾——竞对论文→确定性表驱动迷雾揭示
## （GUT：`test_rival_paper_spillover`）。
## 真源=rivals-spec D.2 rival_paper_effect（论文→迷雾外溢：确定性表驱动
## 揭示；外溢不产生死路 tech-tree 同标）。接线：#137 已实现 spill_reveal
## （注入名单 ∩ spill_eligible 声明 ∩ 待揭 → 恰一档）；#144=Rival 论文
## 动作载荷（domain）→ 编排方把该域可外溢节点注入 weekly_spill_nodes →
## spill_reveal（确定性；零 rng.insight 消费，tech-tree 头注"#144 真接线点"）。

const NODE_DISTILL_SPILL: String = "distill_weight_distill"
const NODE_MEMORY_SPILL: String = "memory_ctx_longmem"


func _make_tree() -> TechTree:
	var table := DataLoader.load_json("res://src/data/tech_tree.json")
	var tree := TechTree.new(table)
	autofree(tree)
	return tree


## 编排方接线模拟：论文 domain → 收集该域 spill_eligible 节点注入名单
func _wire_paper_domain(tree: TechTree, domain: String) -> void:
	var table := DataLoader.load_json("res://src/data/tech_tree.json")
	var nodes: Dictionary = table["tree_nodes"]
	var spill_nodes: Array[String] = []
	if nodes.has(domain):
		for row_v: Variant in nodes[domain]:
			var row: Dictionary = row_v
			if bool(row.get("spill_eligible", false)):
				spill_nodes.append(str(row["id"]))
	tree.weekly_spill_nodes = func() -> Array: return spill_nodes


func test_rival_paper_spillover() -> void:
	# 深巷 W10 首发论文（distill 域）→ 动作载荷含 domain（外溢翻雾输入）
	var pack := RivalPack.new()
	autofree(pack)
	var fired: Array = []
	for w: int in range(1, 11):
		fired = pack.advance_all(w)
	assert_eq(fired.size(), 1, "W10 触发 1 动作（首发论文）")
	var paper: Dictionary = fired[0]
	assert_eq(str(paper["action"]), Rival.ACTION_PAPER, "动作=paper")
	assert_eq(str(paper["domain"]), "distill", "论文域=distill")
	assert_eq(int(paper["week"]), 10, "首发论文 W10（onboarding 同源）")
	# 编排方接线：distill 论文 → 注入 distill spill 节点 → spill_reveal 翻雾
	var tree := _make_tree()
	_wire_paper_domain(tree, str(paper["domain"]))
	var spill: Dictionary = tree.spill_reveal()
	assert_true(bool(spill.get("ok", false)), "外溢翻雾成功（确定性表驱动）")
	assert_eq(str(spill.get("path", "")), "spill", "翻雾路径=外溢")
	assert_eq(str(spill.get("node_id", "")), NODE_DISTILL_SPILL, "翻雾节点=表内声明 spill 节点")
	# 外溢=每篇论文推进恰一档（tech_tree 多档语义：HIDDEN→RUMORED→VISIBLE
	# →RESEARCHABLE；_has_reveal_target_for=HIDDEN|RUMORED 均待揭）——
	# 第二次外溢（下篇论文）=推进第二档 RUMORED→VISIBLE（确定性表驱动）
	var again: Dictionary = tree.spill_reveal()
	assert_true(bool(again.get("ok", false)), "二度外溢仍可触发（每论文恰一档）")
	assert_eq(str(again.get("node_id", "")), NODE_DISTILL_SPILL, "二度外溢同节点")
	assert_eq(
		tree.get_node_fog_state(NODE_DISTILL_SPILL),
		TechTree.FogState.VISIBLE,
		"两次外溢后节点=VISIBLE（两档）",
	)
	# 第三次外溢 → 空转失败：外溢只对"待揭"节点（HIDDEN|RUMORED）生效，
	# VISIBLE 不在待揭集=外溢至多两档（HIDDEN→RUMORED→VISIBLE）；后续论文
	# 外溢不再推进该节点（确定性边界，tech_tree 同标；VISIBLE 后可走研究命令）
	var third: Dictionary = tree.spill_reveal()
	assert_false(bool(third.get("ok", false)), "VISIBLE 后外溢空转（外溢至多两档）")


func test_paper_domains_sequence() -> void:
	# 论文动作跨周推进（W10 distill/W30 memory）——编排方逐周消费即可接线
	var pack := RivalPack.new()
	autofree(pack)
	var paper_domains: Array[String] = []
	for w: int in range(1, 31):
		var fired := pack.advance_all(w)
		for payload_v: Variant in fired:
			var payload: Dictionary = payload_v
			if str(payload["action"]) == Rival.ACTION_PAPER:
				paper_domains.append(str(payload["domain"]))
	assert_eq(paper_domains, ["distill", "memory"], "W10/W30 论文域序=distill/memory")
	# memory 域同样可外溢（表驱动）
	var tree := _make_tree()
	_wire_paper_domain(tree, "memory")
	var spill: Dictionary = tree.spill_reveal()
	assert_true(bool(spill.get("ok", false)), "memory 域外溢可触发")
	assert_eq(str(spill.get("node_id", "")), NODE_MEMORY_SPILL, "memory 翻雾节点=表声明")
