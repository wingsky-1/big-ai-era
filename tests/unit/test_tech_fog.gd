class_name TestTechFog
extends GutTest

## PR5 (issue #9) TechFog 迷雾五态转移、三通路翻雾、域计数、保底断言测试

var _fog: TechFog


func before_each() -> void:
	_fog = TechFog.new()


func test_constants_and_initial_state() -> void:
	# 常量定义断言
	assert_eq(TechFog.STATE_HIDDEN, "hidden")
	assert_eq(TechFog.STATE_RUMORED, "rumored")
	assert_eq(TechFog.STATE_VISIBLE, "visible")
	assert_eq(TechFog.STATE_RESEARCHABLE, "researchable")
	assert_eq(TechFog.STATE_LIT, "lit")
	assert_eq(TechFog.TOTAL_NODES, 14)
	assert_eq(TechFog.PITY_THRESHOLD, 8)
	assert_eq(TechFog.PITY_CAP, 12)

	# 开局状态断言：
	# 1. 4 节点开局即 researchable
	var opening_researchable: Array[String] = [
		"silver_leash",
		"cot_sketch",
		"distill_garden",
		"hand_tutor",
	]
	for tech_id: String in opening_researchable:
		assert_eq(
			_fog.get_state(tech_id),
			TechFog.STATE_RESEARCHABLE,
			"开局节点 %s 必须为 researchable" % tech_id
		)

	# 2. 他者道路保持 rumored 传闻占位
	var elsewhere_nodes: Array[String] = ["world", "symbol", "embodied"]
	for tech_id: String in elsewhere_nodes:
		assert_eq(
			_fog.get_state(tech_id), TechFog.STATE_RUMORED, "他者道路节点 %s 开局必须为 rumored" % tech_id
		)

	# 3. 其余 7 节点初始为 hidden
	var other_nodes: Array[String] = [
		"silent_chain",
		"pocket_smart",
		"long_scroll",
		"outer_brain",
		"arm_will",
		"synesthesia_clip",
		"mirror_mind",
	]
	for tech_id: String in other_nodes:
		assert_eq(_fog.get_state(tech_id), TechFog.STATE_HIDDEN, "其余节点 %s 开局必须为 hidden" % tech_id)

	# 初始探明数：4 (researchable) + 3 (rumored) = 7
	assert_eq(_fog.get_discovered_count(), 7, "初始探明节点数应为 7")
	assert_eq(_fog.get_pity(), 0, "初始 pity 计数器为 0")
	assert_eq(_fog.get_crossover_progress(), 0, "初始 crossover_progress 为 0")


func test_five_state_transitions() -> void:
	# [T] 验收点 1：五态转移表覆盖
	# 1. hidden -> rumored (累积 RP 达到 rumored 门槛 200)
	assert_eq(_fog.get_state("silent_chain"), TechFog.STATE_HIDDEN)
	var changed: bool = _fog.advance(250)
	assert_true(changed, "RP 达到 250 应触发翻态")
	assert_eq(_fog.get_state("silent_chain"), TechFog.STATE_RUMORED)

	# 2. rumored -> visible (累积 RP 达到 visible 门槛 600)
	changed = _fog.advance(650)
	assert_true(changed, "RP 达到 650 应触发翻态至 visible")
	# 注意：silent_chain 的 parent 是 cot_sketch，此时 cot_sketch 尚未 lit，所以留在 visible
	assert_eq(_fog.get_state("silent_chain"), TechFog.STATE_VISIBLE)

	# 3. visible -> researchable (parents 均已 lit)
	# 点亮 cot_sketch
	_fog.set_lit("cot_sketch")
	assert_eq(_fog.get_state("cot_sketch"), TechFog.STATE_LIT)
	# cot_sketch 点亮后，silent_chain 的 parents 全满足，自动升为 researchable
	assert_eq(
		_fog.get_state("silent_chain"),
		TechFog.STATE_RESEARCHABLE,
		"parents 全 lit 后 visible 节点应升至 researchable"
	)

	# 4. researchable -> lit (研发完成)
	var lit_success: bool = _fog.set_lit("silent_chain")
	assert_true(lit_success)
	assert_eq(_fog.get_state("silent_chain"), TechFog.STATE_LIT)

	# 5. 他者道路不可升至 researchable 或 lit
	var elsewhere_spill: bool = _fog.spill_reveal("world", TechFog.STATE_RESEARCHABLE)
	assert_false(elsewhere_spill, "他者道路不可通过 spill_reveal 升至 researchable")
	assert_eq(_fog.get_state("world"), TechFog.STATE_RUMORED)

	var lit_elsewhere: bool = _fog.set_lit("world")
	assert_false(lit_elsewhere, "他者道路不可置为 lit")
	assert_push_error("他者道路不可置为 lit")
	assert_eq(_fog.get_state("world"), TechFog.STATE_RUMORED)


func test_three_pathways() -> void:
	# [T] 验收点 2：三通路各自触发断言
	# 通路 1：周 RP 累积揭示
	assert_eq(_fog.get_state("long_scroll"), TechFog.STATE_HIDDEN)
	_fog.advance(200)
	assert_eq(_fog.get_state("long_scroll"), TechFog.STATE_RUMORED)
	_fog.advance(600)
	# long_scroll 无 parents，达到 visible 且无 parents 约束直接升 researchable
	assert_eq(
		_fog.get_state("long_scroll"),
		TechFog.STATE_RESEARCHABLE,
		"无 parents 节点达到 visible 后直接升 researchable"
	)

	# 通路 2：竞对论文/事件外溢 (spill_reveal)
	_fog.reset()
	assert_eq(_fog.get_state("distill_garden"), TechFog.STATE_RESEARCHABLE)
	# 模拟 evt_open_source_rumor 使某个 hidden 节点变 visible
	assert_eq(_fog.get_state("arm_will"), TechFog.STATE_HIDDEN)
	var spill_res: bool = _fog.spill_reveal("arm_will", TechFog.STATE_VISIBLE)
	assert_true(spill_res)
	# arm_will parents 为空，升为 visible 后自动满足 researchable
	assert_eq(_fog.get_state("arm_will"), TechFog.STATE_RESEARCHABLE)

	# 测试 spill_reveal 针对有 parent 的节点（outer_brain 的 parent 是 long_scroll）
	assert_eq(_fog.get_state("outer_brain"), TechFog.STATE_HIDDEN)
	_fog.spill_reveal("outer_brain", TechFog.STATE_VISIBLE)
	assert_eq(
		_fog.get_state("outer_brain"),
		TechFog.STATE_VISIBLE,
		"parent 未 lit 时 spill_reveal 至 visible 保持 visible"
	)

	# 通路 3：交叉进度与 parents 全点亮
	# pocket_smart parents=[distill_garden, hand_tutor]
	_fog.spill_reveal("pocket_smart", TechFog.STATE_VISIBLE)
	assert_eq(_fog.get_state("pocket_smart"), TechFog.STATE_VISIBLE)
	_fog.set_lit("distill_garden")
	assert_eq(_fog.get_state("pocket_smart"), TechFog.STATE_VISIBLE, "仅点亮一个 parent 仍保持 visible")
	_fog.set_lit("hand_tutor")
	assert_eq(
		_fog.get_state("pocket_smart"), TechFog.STATE_RESEARCHABLE, "两个 parents 全点亮后升为 researchable"
	)

	# mirror_mind: crossover 节点，主干点亮数达到 6 升 researchable
	_fog.spill_reveal("mirror_mind", TechFog.STATE_VISIBLE)
	assert_eq(_fog.get_state("mirror_mind"), TechFog.STATE_VISIBLE)
	# 当前已点亮: distill_garden, hand_tutor (2个主干)
	assert_eq(_fog.get_crossover_progress(), 2)
	_fog.set_lit("silver_leash")  # 3
	_fog.set_lit("cot_sketch")  # 4
	_fog.set_lit("silent_chain")  # 5
	assert_eq(_fog.get_state("mirror_mind"), TechFog.STATE_VISIBLE, "主干亮 5 个时不满足 mirror_mind")
	_fog.set_lit("pocket_smart")  # 6 (pocket_smart domain 为 dandelion，算主干)
	assert_eq(_fog.get_crossover_progress(), 6)
	assert_eq(
		_fog.get_state("mirror_mind"), TechFog.STATE_RESEARCHABLE, "主干点亮数>=6 自动升为 researchable"
	)


func test_domain_counts_and_signals() -> void:
	# [T] 验收点 3：域计数一致性与 fog_changed 信号
	watch_signals(_fog)

	var domain_counts: Dictionary = _fog.get_domain_counts()
	# 开局：
	# deep_thought: silver_leash, cot_sketch = 2
	# dandelion: distill_garden, hand_tutor = 2
	# elsewhere: world, symbol, embodied = 3
	assert_eq(domain_counts.get("deep_thought", 0), 2)
	assert_eq(domain_counts.get("dandelion", 0), 2)
	assert_eq(domain_counts.get("elsewhere", 0), 3)
	assert_eq(domain_counts.get("long_memory", 0), 0)
	assert_eq(domain_counts.get("tool_use", 0), 0)
	assert_eq(domain_counts.get("synesthesia", 0), 0)
	assert_eq(domain_counts.get("crossover", 0), 0)

	# 触发翻态测试信号
	_fog.advance(200)
	assert_signal_emitted(_fog, "fog_changed")

	var last_params: Array = get_signal_parameters(_fog, "fog_changed")
	assert_false(last_params.is_empty())
	var payload: Dictionary = last_params[0]
	assert_eq(payload.get("total_nodes"), 14)
	assert_true(payload.has("discovered_count"))
	assert_true(payload.has("fog_states"))
	assert_true(payload.has("domain_counts"))
	assert_true(payload.has("crossover_progress"))
	assert_true(payload.has("pity"))


func test_pity_counter_and_cap_12_hard_guarantee() -> void:
	# [T] 验收点 4：连续无雾 pity=8 触发保底与 cap=12 硬保底断言
	# 初始状态：累积 RP 为 0，不产生任何翻雾
	assert_eq(_fog.get_pity(), 0)

	# 前 7 周无翻态，pity 逐周 +1
	for i: int in range(1, 8):
		var revealed: bool = _fog.advance(0)
		assert_false(revealed, "RP=0 且未达保底时不应翻态")
		assert_eq(_fog.get_pity(), i, "第 %d 周 pity 应为 %d" % [i, i])

	# 第 8 周 (pity=8)：达到 PITY_THRESHOLD，但未到硬保底 cap=12
	var revealed_8: bool = _fog.advance(0)
	assert_false(revealed_8)
	assert_eq(_fog.get_pity(), 8)

	# 持续推进到第 11 周 (pity=11)
	for i: int in range(9, 12):
		_fog.advance(0)
		assert_eq(_fog.get_pity(), i)

	# 第 12 周：达到 PITY_CAP = 12，硬保底触发！
	# 必须从处于 hidden 态的节点中挑选第一个表序节点翻为 visible (或 rumored)
	# 初始 hidden 列表中第一个表序节点是 silent_chain
	assert_eq(_fog.get_state("silent_chain"), TechFog.STATE_HIDDEN)
	var revealed_12: bool = _fog.advance(0)
	assert_true(revealed_12, "pity 达到 12 必须触发硬保底翻态")
	assert_eq(
		_fog.get_state("silent_chain"), TechFog.STATE_VISIBLE, "硬保底翻雾应将首个 hidden 节点翻为 visible"
	)
	assert_eq(_fog.get_pity(), 0, "触发保底后 pity 计数器重置为 0")

	# 测试 adjust_pity 兜底逻辑：灵感触发 > 可研节点数时顺延 pity 减 2
	_fog.set_pity(5)
	_fog.adjust_pity(-2)
	assert_eq(_fog.get_pity(), 3, "adjust_pity(-2) 应使 pity 变为 3")
	_fog.adjust_pity(-10)
	assert_eq(_fog.get_pity(), 0, "adjust_pity 不能小于 0")


func test_snapshot_save_and_restore() -> void:
	# [T] 验收点 5：状态导出、快照与存档
	_fog.advance(300)
	_fog.set_lit("silver_leash")
	_fog.set_pity(7)

	var snap: Dictionary = _fog.to_snapshot()
	assert_true(snap.has("fog_states"))
	assert_true(snap.has("crossover_progress"))
	assert_true(snap.has("pity"))
	assert_eq(snap["pity"], 7)
	assert_eq(snap["crossover_progress"], 1)
	assert_eq(snap["fog_states"]["silver_leash"], TechFog.STATE_LIT)

	var save_dict: Dictionary = _fog.to_save()
	assert_true(save_dict.has("fog_visibility"))
	assert_true(save_dict.has("crossover_progress"))
	assert_true(save_dict.has("pity"))
	assert_eq(save_dict["pity"], 7)

	# 新建实例并还原
	var new_fog: TechFog = TechFog.new()
	new_fog.restore(save_dict)
	assert_eq(new_fog.get_pity(), 7)
	assert_eq(new_fog.get_crossover_progress(), 1)
	assert_eq(new_fog.get_state("silver_leash"), TechFog.STATE_LIT)
	assert_eq(new_fog.to_snapshot(), snap)
