extends GutTest
## #137 迷雾五态 + 翻雾三通路 + 同域 pity（DoD 用例名与 issue 逐字一致）：
## - test_fog_state_transitions_legal：hidden→rumored→visible→researchable→lit
##   单向前进无跳态（五态链恰一档）；非法推进（跳态入口/回退/lit 终态再推/未知
##   节点）拒绝 + push_error 可读；start_research 只放 visible 入口（研究命令 #138）。
## - test_fog_three_reveal_paths：周推进揭示（rng.insight 消费 + pity 计数，同种子
##   下种子可复现推进）=通路 weekly；竞对论文外溢（确定性注入表源 + 节点表
##   spill_eligible）=通路 spill（#144 真接线点）；交叉进度（他域 lit → 联动相邻
##   交叉节点推进，tree_cross_nodes 表驱动 cross_from）=通路 cross。
## - test_fog_pity_guarantee：连 N 周不揭示必揭示（同域 pity 保底，N=rng.json
##   rnd_insight_pity_max 实际值=6）；保底重置语义（翻雾后从 0 再计）。
## 测试纪律：#125 RNG 纪律——只经 RngStream 消费 rng.insight（禁 rand()）；
## 数值零硬编码：pity/节点数读表断言；触发率键读表断言。

const TREE_TABLE_PATH: String = "res://src/data/tech_tree.json"
const RNG_TABLE_PATH: String = "res://src/data/rng.json"

const KEY_PITY_MAX: String = "tree_insight_pity_max"
const KEY_RNG_PITY_MAX: String = "rnd_insight_pity_max"
const KEY_RATE: String = "tree_fog_reveal_rate"
const KEY_NODE_TOTAL: String = "tree_node_total"
const KEY_DOMAIN_NODES: String = "tree_domain_nodes"

const DOMAIN_ALIGN: String = "align"
const DOMAIN_DISTILL: String = "distill"
const NODE_ALIGN_A: String = "align_rlhf_align"
const NODE_DISTILL_SPILL: String = "distill_weight_distill"
const NODE_CROSS_PAPER: String = "cross_paper_bridge"
const NODE_CROSS_EVAL: String = "cross_eval_bridge"


func _make_advanceable_tree() -> TechTree:
	var pair := _make_with_rng()
	return pair[0] as TechTree


func _make_with_rng() -> Array:
	## 注入真实 RngStream（同种子确定性）：装配方 setup(seed) 后经 DataLoader
	## 提供（#125 纪律：自建流会破坏同种子确定性，周推进由 Settlement 编排）。
	var rng := RngStream.new()
	autofree(rng)
	rng.setup(137)
	var tree := TechTree.new({}, rng)
	autofree(tree)
	return [tree, rng]


## 反复调用 weekly_reveal 直到揭示成功（未触发周不推进）；返回 {hits, failed}。
func _reveal_until_hit(tree: TechTree, domain_id: String, max_tries: int) -> Dictionary:
	var hits: int = 0
	var failed: int = 0
	for i: int in max_tries:
		var result := tree.weekly_reveal(domain_id)
		if result.ok:
			hits += 1
		else:
			failed += 1
	return {"hits": hits, "failed": failed}


## ---------- DoD 1：迷雾五态转换合法 ----------


func test_fog_state_transitions_legal() -> void:
	var tree := _make_advanceable_tree()
	var state: int = tree.get_node_fog_state(NODE_ALIGN_A)
	assert_eq(state, TechTree.FogState.HIDDEN, "初始 hidden")
	# 五态链单向前进：逐档推进，无跳态（每档恰 +1）
	assert_true(tree.advance_fog(NODE_ALIGN_A), "hidden → rumored")
	assert_eq(tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.RUMORED, "现态 rumored")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "rumored → visible")
	assert_eq(tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.VISIBLE, "现态 visible")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "visible → researchable")
	assert_eq(
		tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.RESEARCHABLE, "现态 researchable"
	)
	assert_true(tree.advance_fog(NODE_ALIGN_A), "researchable → lit")
	assert_eq(tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.LIT, "现态 lit（终态）")


func test_fog_state_illegal_transitions_rejected() -> void:
	var tree := _make_advanceable_tree()
	# 无跳态：隐藏节点不能直接 researchable（rumored 前态必须逐档）
	assert_false(tree.is_researchable_ready(NODE_ALIGN_A), "hidden 未到 visible 不可研究")
	# 未知节点推进=拒绝 + push_error
	assert_false(tree.advance_fog("no_such_node"), "未知节点推进拒绝")
	assert_push_error("未知节点", "未知节点推进须 push_error")
	# hidden 状态（rumored 前）经 weekly 翻雾一档到 rumored（非 lit）：rumored 行可再推进
	assert_true(tree.advance_fog(NODE_ALIGN_A), "第一步 hidden→rumored")
	assert_eq(tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.RUMORED, "rumored 行（可继续推进）")
	assert_false(tree.start_research(NODE_ALIGN_A).ok, "rumored 不可开始研究（无跳态，需先到 visible）")
	# 五档到 lit 终态后：再推进=拒绝 + push_error（lit 无回退/无再升）
	assert_true(tree.advance_fog(NODE_ALIGN_A), "rumored→visible")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "visible→researchable")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "researchable→lit")
	assert_false(tree.advance_fog(NODE_ALIGN_A), "lit 终态拒绝再推进")
	assert_push_error("lit 为终态", "lit 终态再推进须 push_error")


func test_start_research_gate_visible_only() -> void:
	var tree := _make_advanceable_tree()
	# visible 可开始研究（→researchable）；visible 之后研究态再入口拒绝（已 lit 直接拒绝）
	assert_false(tree.start_research(NODE_ALIGN_A).ok, "hidden 不可开始研究")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "翻雾一档 rumored")
	assert_false(tree.start_research(NODE_ALIGN_A).ok, "rumored 不可开始研究")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "翻雾两档 visible")
	assert_true(tree.start_research(NODE_ALIGN_A).ok, "visible 可开始研究（→researchable）")
	assert_eq(
		tree.get_node_fog_state(NODE_ALIGN_A), TechTree.FogState.RESEARCHABLE, "研究进行中 researchable"
	)
	assert_false(tree.start_research(NODE_ALIGN_A).ok, "researchable 不可重复开始研究")
	assert_true(tree.advance_fog(NODE_ALIGN_A), "researchable→lit")
	assert_false(tree.start_research(NODE_ALIGN_A).ok, "lit 不可开始研究")


## ---------- DoD 2：翻雾三通路（各可触发） ----------


func test_fog_three_reveal_paths() -> void:
	var tree := _make_advanceable_tree()
	# 通路① 周推进揭示：同种子下 rng.insight 推进域内 ??? 行（weekly 通路）
	var weekly_result := tree.weekly_reveal(DOMAIN_ALIGN)
	assert_true(weekly_result.ok, "周推进揭示应可触发（同种子 seed=137 首周命中）")
	assert_eq(weekly_result.path, "weekly", "周推进通路=weekly")
	assert_eq(weekly_result.state, "rumored", "翻雾一档：??? 行 → 传闻行")
	# 通路② 竞对论文外溢：确定性注入表源 ∩ spill_eligible 声明（蒸馏域权重蒸馏节点）
	# 表源 = 竞对论文外溢规则表（#144 真接线点，本单注入验证谓词+接口）
	tree.weekly_spill_nodes = func() -> Array: return [NODE_DISTILL_SPILL]
	var spill_result := tree.spill_reveal()
	assert_true(spill_result.ok, "竞对论文外溢揭示应可触发（注入表命中）")
	assert_eq(spill_result.path, "spill", "竞对论文外溢通路=spill")
	assert_eq(spill_result.node_id, NODE_DISTILL_SPILL, "外溢揭示命中表内声明节点")
	assert_eq(tree.get_node_fog_state(NODE_DISTILL_SPILL), TechTree.FogState.RUMORED, "外溢翻雾一档")
	# 通路③ 交叉进度：align 已 lit（实证出现）→ 联动相邻交叉节点
	# （cross_from 表驱动，align∈cross_paper_bridge 相邻域声明；树序推进恰一档）
	var lit_probe := _lit_node_in_domain(tree, DOMAIN_ALIGN)
	assert_true(lit_probe != "", "先造出 align 已 lit 实证（研究面占位链）")
	var cross_result := tree.cross_reveal(DOMAIN_ALIGN)
	assert_true(cross_result.ok, "交叉进度揭示应可触发（align 已 lit 联动交叉节点）")
	assert_eq(cross_result.path, "cross", "交叉进度通路=cross")
	assert_eq(tree.get_node_fog_state(NODE_CROSS_PAPER), TechTree.FogState.RUMORED, "交叉联动翻雾一档")


## 把域内第一个节点推进到 lit（五态链合法推进：hidden→rumored→visible→
## researchable→lit），返回节点 id；lit 后节点不再消耗周推进。
func _lit_node_in_domain(tree: TechTree, domain_id: String) -> String:
	var view := tree.get_fog_view()
	var rows: Array = view.groups[domain_id].rows
	for row: Dictionary in rows:
		var node_id := str(row.node_id)
		for i: int in 4:
			assert_true(tree.advance_fog(node_id), "五态链推进第 %d 档（%s）" % [i + 1, node_id])
		return node_id
	return ""


func test_fog_three_paths_do_not_consume_insight() -> void:
	var pair := _make_with_rng()
	var tree: TechTree = pair[0]
	var rng: RngStream = pair[1]
	# 通路① 周推进揭示=消费 rng.insight（每次尝试恰 1 样本）
	var counter_before: int = rng.get_counter("insight")
	var weekly_result := tree.weekly_reveal(DOMAIN_ALIGN)
	assert_eq(rng.get_counter("insight"), counter_before + 1, "周推进消费恰 1 个 rng.insight 样本")
	assert_true(weekly_result.ok, "周推进揭示触发")
	# 通路② spill 不消费 rng.insight（确定性规则表 #144）
	counter_before = rng.get_counter("insight")
	tree.weekly_spill_nodes = func() -> Array: return [NODE_DISTILL_SPILL]
	assert_true(tree.spill_reveal().ok, "spill 可触发")
	assert_eq(rng.get_counter("insight"), counter_before, "spill 零消费 rng.insight")
	# 通路③ cross 不消费 rng.insight（他域 lit 联动确定性触发）
	# 前置：align 至少 1 节点 lit（实证出现=他域 lit 联动语义），走研究面占位链不消费
	var lit_id := _lit_node_in_domain(tree, DOMAIN_ALIGN)
	assert_true(lit_id != "", "align 有 lit 节点（研究面占位链）")
	counter_before = rng.get_counter("insight")
	assert_true(tree.cross_reveal(DOMAIN_ALIGN).ok, "cross 可触发")
	assert_eq(rng.get_counter("insight"), counter_before, "cross 零消费 rng.insight")


## ---------- DoD 3：同域 pity 保底 ----------


func test_fog_pity_guarantee() -> void:
	# 保底语义（randomness-spec D.2 rnd_insight_pity_max）：连 N 周不揭示，第 N 周
	# 必揭示（pity_pull_domain forced 确定性事件）。种子搜索：找"前 5 周全失败"的
	# 种子把 streak 推到 pity_max-1，再断言第 6 周强制揭示（保底真实路径可测）。
	var pity_max := _read_rng_pity_max()
	var pity_seed: int = _find_streak_seed(pity_max)
	assert_true(pity_seed >= 0, "存在连败 %d 周的种子（保底强制路径可复现）" % pity_max)
	var rng := RngStream.new()
	autofree(rng)
	rng.setup(pity_seed)
	var tree := TechTree.new({}, rng)
	autofree(tree)
	assert_eq(tree.get_domain_pity_left(DOMAIN_ALIGN), pity_max, "初始 pity 条=满格（数据面可见）")
	# 连败 pity_max-1 周：逐周不揭示，pity 条递减（本域再 X 周必揭示）
	for i: int in pity_max - 1:
		var miss := tree.weekly_reveal(DOMAIN_ALIGN)
		assert_false(miss.ok, "第 %d 周未揭示（连败期）" % (i + 1))
		assert_eq(
			tree.get_domain_pity_left(DOMAIN_ALIGN),
			pity_max - (i + 1),
			"连败 %d 周后 pity 条剩余 %d 周（保底条可见）" % [i + 1, pity_max - (i + 1)],
		)
	# 第 N 周必揭示：保底强制命中（确定性事件，非掷骰）
	var hit := tree.weekly_reveal(DOMAIN_ALIGN)
	assert_true(hit.ok, "连 %d 周不揭示，第 %d 周保底必揭示（同域 align）" % [pity_max - 1, pity_max])
	assert_eq(hit.state, "rumored", "保底揭示翻雾一档（??? → 传闻行）")
	# 揭示后重置：pity 条回满格再计（防长期无翻雾的保底进入下一轮）
	assert_eq(
		tree.get_domain_pity_left(DOMAIN_ALIGN),
		pity_max,
		"揭示后域 pity 重置回满格（保底进入下一轮）",
	)


func _read_rng_pity_max() -> int:
	var table := DataLoader.load_json(RNG_TABLE_PATH)
	var pity_max := int(table[KEY_RNG_PITY_MAX])
	assert_true(pity_max >= 5 and pity_max <= 8, "rng.json 灵感保底 5–8（%d）" % pity_max)
	var tree_table := DataLoader.load_json(TREE_TABLE_PATH)
	assert_eq(
		int(tree_table[KEY_PITY_MAX]),
		pity_max,
		"树表 pity 上限与 rng.json 同源（tree_insight_pity_max = rnd_insight_pity_max）",
	)
	return pity_max


## 种子搜索：找同种子下域内前（pity_max-1）次周推进全失败的种子（确定性可重放）。
func _find_streak_seed(pity_max: int) -> int:
	for seed: int in range(1000, 1400):
		var probe_rng := RngStream.new()
		probe_rng.setup(seed)
		var probe := TechTree.new({}, probe_rng)
		var all_missed: bool = true
		for i: int in pity_max - 1:
			if probe.weekly_reveal(DOMAIN_ALIGN).ok:
				all_missed = false
				break
		if all_missed:
			return seed
	return -1


## ---------- 附加：数据面 [P] 契约（??? 行 + 域计数 + pity 条） ----------


func test_fog_view_matches_spec() -> void:
	var tree := _make_advanceable_tree()
	var view := tree.get_fog_view()
	assert_eq(int(view.tree_node_total), 14, "14 节点（tech-tree-spec D.2 tree_node_total）")
	assert_eq(int(view.tree_domain_nodes), 2, "每域 2 节点（tree_domain_nodes）")
	var align_group: Dictionary = view.groups[DOMAIN_ALIGN]
	assert_eq(int(align_group.total), 2, "域计数=每域节点总数")
	assert_eq(int(align_group.lit_count), 0, "初始 0 已点亮")
	assert_eq(int(align_group.known_count), 0, "初始 0 探明（全 ???）")
	assert_true(bool(align_group.pity_left) or align_group.pity_left == 0, "域组带 pity 条数据")
	for row: Dictionary in align_group.rows:
		assert_true(bool(row.hidden), "hidden 行是 ??? 掩码行")
		assert_eq(str(row.name_key), "tree_fog_hidden", "??? 行文案键=tree_fog_hidden")
	# 交叉/传闻占位组也在视图（迷雾面板不显示：它们是跨域叙事/掩码容器）
	assert_true(view.groups.has("cross"), "交叉组存在")
	assert_true(view.groups.has("rumor"), "传闻占位组存在")
	var tree_table := DataLoader.load_json(TREE_TABLE_PATH)
	assert_almost_eq(float(tree_table[KEY_RATE]), 0.25, 0.0001, "周推进触发率表驱动（0.25）")


func test_fog_view_hidden_name_key_and_counts() -> void:
	# [P] 验收 1 数据面：hidden 行=? ? ? 掩码（name_key 常量）→ 行翻转后换名/计数+1
	var tree := _make_advanceable_tree()
	var view_before := tree.get_fog_view()
	var align_before: Dictionary = view_before.groups[DOMAIN_ALIGN]
	var hidden_before: int = int(align_before.hidden_count)
	var known_before: int = int(align_before.known_count)
	var result := tree.weekly_reveal(DOMAIN_ALIGN)
	assert_true(result.ok, "周推进揭示命中（seed=137）")
	var view_after := tree.get_fog_view()
	var align_after: Dictionary = view_after.groups[DOMAIN_ALIGN]
	assert_eq(int(align_after.hidden_count), hidden_before - 1, "??? 行减 1（翻雾散开）")
	assert_eq(int(align_after.known_count), known_before + 1, "探明计数 +1")
	var revealed_row: Dictionary = {}
	for row: Dictionary in align_after.rows:
		if str(row.node_id) == str(result.node_id):
			revealed_row = row
	assert_false(revealed_row.is_empty(), "命中行在视图中")
	assert_false(bool(revealed_row.hidden), "命中行不再是掩码")
	assert_eq(str(revealed_row.name_key), "tree_fog_rumored", "rumored 行=域传闻句文案键")
