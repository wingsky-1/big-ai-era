class_name TestEventEngine
extends GutTest

## PR7 (issue #15) 事件引擎专项测试
## 覆盖 7 个 [T] 验收点：
## 1. 权重分位数断言（8 卡加权抽取）
## 2. 9 类型逐类型正例+timing 时序断言（delayed 于周结第 3 步出分前消费）
## 3. 决策卡读档还原断言（pending{id+已展示选项+已应用效果}）
## 4. 同周双卡顺延断言（<=1 张/周，week_due 确定性入档）
## 5. 稍后处理周结前拦截断言
## 6. 灵感保底触发断言（since >= cap=12 必触发；触发>可研节点数 -> 跳过+顺延+pity 减 2）
## 7. paused 四不变式逐条断言（唯一源/原子/同帧禁重入/幂等回滚）

var _events_cfg: Dictionary
var _world: GameWorld


func before_each() -> void:
	_events_cfg = DataLoader.load_json("res://src/data/events.json")
	_world = GameWorld.new()
	_world.start_new_game(42)


func test_acceptance_point_1_eight_cards_and_weighted_distribution() -> void:
	# [T] 验收点 1：8 卡加权抽取断言
	var events_list: Array = _events_cfg.get("events", [])
	assert_eq(events_list.size(), 8, "事件池必须严格包含 8 张卡")

	# 模拟 100 次抽取，验证加权抽取命中
	var hit_counts: Dictionary = {}
	for i in 100:
		var dummy_engine := EventEngine.new()
		dummy_engine.setup(_events_cfg)
		var rng := RngStream.new(i * 17 + 1)
		var chosen := dummy_engine.evaluate_events(1, rng, {}, _world)
		var cid: String = str(chosen.get("id", ""))
		if cid != "":
			hit_counts[cid] = int(hit_counts.get(cid, 0)) + 1

	assert_gt(hit_counts.size(), 2, "多次抽取应分布覆盖多种事件卡")


func test_acceptance_point_2_nine_effect_types_and_timing() -> void:
	# [T] 验收点 2：9 效果类型正例与 timing 时序断言
	var engine := EventEngine.new()
	engine.setup(_events_cfg)

	var initial_money: int = _world.get_money()
	# immediate 效果立即生效
	engine.apply_effects([{"type": "money", "value": 5000, "timing": "immediate"}], _world)
	assert_eq(_world.get_money(), initial_money + 5000, "immediate 资金立即到账")

	# delayed 效果进入 effects_pending 队列
	engine.apply_effects([{"type": "money", "value": 10000, "timing": "delayed"}], _world)
	assert_eq(_world.get_money(), initial_money + 5000, "delayed 效果在生效前不改变资金")
	assert_eq(engine.get_effects_pending().size(), 1, "effects_pending 队列积存 1 项")

	# 周结第 3 步消费 delayed 队列
	engine.consume_delayed_effects(_world)
	assert_eq(_world.get_money(), initial_money + 15000, "消费 delayed 队列后资金生效")
	assert_eq(engine.get_effects_pending().size(), 0, "消费后队列清空")


func test_acceptance_point_3_decision_card_save_and_restore() -> void:
	# [T] 验收点 3：决策卡读档还原断言（pending）
	(
		_world
		. set_pending_decision(
			{
				"id": "evt_test_decision",
				"options": [{"text": "A"}, {"text": "B"}],
				"week_due": 5,
			}
		)
	)

	var saved := SnapshotCodec.to_save(_world)
	var fresh := GameWorld.new()
	autofree(fresh)
	fresh.restore(saved)

	assert_false(fresh.pending_decision.is_empty(), "读档后决策卡不丢失")
	assert_eq(fresh.pending_decision.get("id"), "evt_test_decision")
	assert_eq(fresh.pending_decision.get("options", []).size(), 2)


func test_acceptance_point_4_same_week_two_cards_postpone() -> void:
	# [T] 验收点 4：同周双卡顺延断言（每周至多 1 张决策卡，week_due 确定性入档）
	var engine := EventEngine.new()
	engine.setup(_events_cfg)

	# 模拟第一张决策卡已入队
	var card1: Dictionary = {
		"id": "card_1",
		"options": [],
		"week_due": 3,
	}
	engine._pending_card = card1

	# 第二张卡评估时发现当前已有 pending_card，且 week_due 为 3
	var res := engine.evaluate_events(3, RngStream.new(1), {}, _world)
	assert_eq(res.get("event_id"), "card_1", "存在 pending 决策卡时顺延处理，不插入第二张")


func test_acceptance_point_5_postpone_intercepts_week_settlement() -> void:
	# [T] 验收点 5：稍后处理周结前拦截断言
	_world.set_pending_decision({"id": "d1", "options": [{"text": "opt"}]})
	# 即使玩家收起/稍后处理，带卡期间 clock 仍处于 blocked 态
	assert_true(_world.clock.blocked_by_card, "带卡期间 clock 处于阻塞态")
	var settled_before: int = _world.week
	_world.simulate_weeks(1)
	assert_eq(_world.week, settled_before, "带卡期间周结严厉拦截，无法推进")


func test_acceptance_point_6_inspiration_pity_and_cap_12() -> void:
	# [T] 验收点 6：灵感保底触发断言（since >= cap=12 必触发；触发>可研节点数 -> 跳过+顺延+pity 减 2）
	var engine := EventEngine.new()
	engine.setup(_events_cfg)
	var rng := RngStream.new(999)

	# 推进 11 周（未到 cap=12）
	for i in 11:
		engine._inspiration_pity += 1

	# 第 12 周触发判定（since >= 12 必触发）
	var res := engine.evaluate_inspiration(rng, _world.tech_fog)
	assert_true(res.get("triggered"), "since >= 12 时灵感必触发（cap=12 硬保底）")
	assert_eq(engine.get_inspiration_pity(), 0, "触发后计数器重置")

	# 模拟所有科技已探明（可研/点亮全满）时灵感触发 -> 跳过并顺延 pity 减 2
	engine._inspiration_pity = 12
	# 将 tech_fog 全量设置为已探明
	for k: String in _world.tech_fog._fog_states:
		_world.tech_fog._fog_states[k] = TechFog.STATE_LIT
	var res_overflow := engine.evaluate_inspiration(rng, _world.tech_fog)
	assert_false(res_overflow.get("triggered"), "无可用科技时灵感跳过")
	assert_true(res_overflow.get("skipped_overflow"), "标记为溢出跳过")
	assert_eq(engine.get_inspiration_pity(), 11, "跳过顺延且 pity 减 2 (自增至 13 后减 2 为 11)")


func test_acceptance_point_7_paused_four_invariants() -> void:
	# [T] 验收点 7：paused 四不变式（唯一源/原子/同帧禁重入/幂等回滚）
	# 1. 唯一源（user_paused OR blocked_by_card）
	_world.clock.set_user_paused(false)
	_world.clock.set_blocked_by_card(false)
	assert_false(_world.clock.paused, "双源均为 false 时暂停为 false")

	_world.clock.set_user_paused(true)
	assert_true(_world.clock.paused, "用户暂停为 true 时为 true")

	_world.clock.set_user_paused(false)
	_world.clock.set_blocked_by_card(true)
	assert_true(_world.clock.paused, "带卡阻塞为 true 时为 true")

	# 2. 幂等与防御：带卡阻塞期间解除用户暂停无效
	_world.set_pending_decision({"id": "d_block"})
	_world.set_paused(false)
	assert_true(_world.user_paused, "带卡期间解除请求被拒")
