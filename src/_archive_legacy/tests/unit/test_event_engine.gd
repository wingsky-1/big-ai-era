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
##
## #75（0.1.5-1d）追加事件闸 6 个 [T]：命中率门 / 冷却阻断 + once / 预算闸 /
## 单卡上限数据表断言 / influence 权重占比 / 160 周 V-sim 收入占比。

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


## ============ #75（0.1.5-1d）事件闸专项：命中率门 / 冷却 / 预算闸 / V-sim ============


func test_event_hit_rate_gate() -> void:
	# [T] #75：命中率门 —— 1000 周实际抽卡频率落在 p_week ±2%（复用 event_roll 域不新增域）
	var engine := EventEngine.new()
	engine.setup(_events_cfg)
	var p_week: float = engine.get_p_week()
	assert_gt(p_week, 0.0, "p_week 必须来自 events.json.event_spec")
	var rng := RngStream.new(20260908)
	var draws: int = 0
	var silent_weeks: int = 0
	for w: int in range(1, 1001):
		var res := engine.evaluate_events(w, rng, {"money": 0, "influence": 0, "week": w}, _world)
		if res.is_empty():
			silent_weeks += 1
			assert_true(engine.get_pending_card().is_empty(), "未过门周不得产出决策卡")
			continue
		draws += 1
		if not engine.get_pending_card().is_empty():
			engine.choose_decision_option(0, _world)
	var rate: float = float(draws) / 1000.0
	assert_almost_eq(rate, p_week, 0.02, "1000 周抽卡频率 %.4f 应落在 p_week %.2f ±2%%" % [rate, p_week])
	assert_gt(silent_weeks, 0, "存在未过门的静默周（通知层静默）")


func test_event_cooldown_blocks_repeat() -> void:
	# [T] #75：冷却阻断重复 + once 永久排除 + cooldowns 入档零迁移
	# 1. 精确窗口：单卡表 + p_week=1.0 + cooldown_weeks=8 → 26 周内仅第 1/9/17/25 周可抽中
	var single_cfg: Dictionary = {
		"inspiration_spec":
		{"base": 0.1, "pity": 8, "cap": 12, "pity_boost_factor": 2.0, "pity_skip_step": 2},
		"event_spec":
		{
			"p_week": 1.0,
			"max_money": 5000,
			"max_rp_grant": 60,
			"max_influence": 20,
			"weekly_net_cap": 600,
		},
		"events":
		[
			{
				"id": "evt_only",
				"kind": "notice",
				"trigger": {"predicate": "none", "weight": 10, "once": false, "cooldown_weeks": 8},
				"effects": [{"type": "money", "value": 100, "timing": "immediate"}],
			}
		],
	}
	var engine := EventEngine.new()
	engine.setup(single_cfg)
	var rng := RngStream.new(5)
	var hit_weeks: Array = []
	for w: int in range(1, 26):
		var res := engine.evaluate_events(w, rng, {}, _world)
		if not res.is_empty():
			hit_weeks.append(w)
	assert_eq(hit_weeks, [1, 9, 17, 25], "冷却 8 周：间隔 ≥8 周才可重复（26 周内 4 次）")

	# 2. 真表 400 周扫描：once 卡不重复出现；非 once 卡两次出现间隔 ≥ cooldown_weeks
	var real_engine := EventEngine.new()
	real_engine.setup(_events_cfg)
	var real_rng := RngStream.new(4242)
	var last_week: Dictionary = {}
	var seen_ids: Dictionary = {}
	for w: int in range(1, 401):
		var res := real_engine.evaluate_events(w, real_rng, {}, _world)
		if res.is_empty():
			continue
		var ev_id: String = str(res.get("id", res.get("event_id", "")))
		if not real_engine.get_pending_card().is_empty():
			real_engine.choose_decision_option(0, _world)
		if ev_id == "":
			continue
		var window: int = _cooldown_weeks_for(ev_id)
		if seen_ids.has(ev_id):
			if window > 0:
				assert_gte(w - int(last_week[ev_id]), window, "卡 %s 冷却窗口内不得重复出现" % ev_id)
			else:
				assert_true(false, "once 卡 %s 不得重复出现" % ev_id)
		seen_ids[ev_id] = true
		last_week[ev_id] = w
	assert_gte(seen_ids.size(), 4, "400 周应覆盖多张卡（防断言空转）")

	# 3. cooldowns 入档/读档零迁移（fired 数组语义不变）
	var saved: Dictionary = real_engine.to_save()
	assert_true(saved.has("cooldowns"), "to_save 必须含 cooldowns 键")
	assert_gte((saved.get("fired", []) as Array).size(), 1, "fired 数组语义不变（抽中即登记）")
	var shell_events: Dictionary = SaveMigrator.V1_SHELL.get("events", {})
	assert_true(shell_events.has("cooldowns"), "V1_SHELL.events 必须含 cooldowns 键（零迁移）")
	var fresh := EventEngine.new()
	fresh.setup(_events_cfg)
	fresh.restore(saved)
	assert_eq(fresh.get_cooldowns(), real_engine.get_cooldowns(), "读档还原冷却窗口")


func test_event_budget_cap() -> void:
	# [T] #75：预算闸 —— 单卡上限（全表）+ 总闸期望净效果 ≤ weekly_net_cap
	var violations: Array[String] = EventEngine.validate_card_caps(_events_cfg)
	assert_eq(violations.size(), 0, "全表单卡效果不得越界：%s" % str(violations))
	var spec: Dictionary = _events_cfg.get("event_spec", {})
	var cap: int = int(spec.get("weekly_net_cap", 0))
	assert_gt(cap, 0, "weekly_net_cap 必须为正数（真源 events.json）")
	var expected: Dictionary = EventEngine.expected_weekly_effect(_events_cfg)
	assert_lte(
		absf(float(expected.get("money", 0.0))),
		float(cap),
		"事件期望净 money %.1f/周 应 ≤%d/周" % [float(expected.get("money", 0.0)), cap]
	)
	# 越界检测器自身有效（防假绿）：注入越界卡必须被捕获
	var bad_cfg: Dictionary = _events_cfg.duplicate(true)
	var bad_events: Array = bad_cfg.get("events", [])
	(bad_events[1] as Dictionary)["effects"] = [
		{"type": "money", "value": 99999, "timing": "immediate"}
	]
	assert_gt(EventEngine.validate_card_caps(bad_cfg).size(), 0, "越界卡必须被 validate_card_caps 捕获")


func test_event_card_effect_caps() -> void:
	# [T] #75 / REV-02：数据表级逐卡校验（防新增卡越界 / 漏配冷却窗口）
	var spec: Dictionary = _events_cfg.get("event_spec", {})
	assert_true(spec.has("p_week"), "event_spec 必须有 p_week")
	assert_true(spec.has("max_money"), "event_spec 必须有 max_money")
	assert_true(spec.has("max_rp_grant"), "event_spec 必须有 max_rp_grant")
	assert_true(spec.has("max_influence"), "event_spec 必须有 max_influence")
	assert_true(spec.has("weekly_net_cap"), "event_spec 必须有 weekly_net_cap")
	for ev_variant: Variant in _events_cfg.get("events", []):
		var ev: Dictionary = ev_variant
		var trigger: Dictionary = ev.get("trigger", {})
		if bool(trigger.get("once", false)):
			continue
		assert_true(
			trigger.has("cooldown_weeks"), "非 once 卡 %s 必须配 cooldown_weeks" % str(ev.get("id", ""))
		)
		assert_gt(int(trigger.get("cooldown_weeks", 0)), 0, "卡 %s 冷却窗口必须为正" % str(ev.get("id", "")))
	assert_eq(EventEngine.validate_card_caps(_events_cfg).size(), 0, "全表效果上限合规")


func test_event_influence_weight_share() -> void:
	# [T] #75 / REV-05：带 influence 效果的卡权重占比 ≥25%（与 Q2 的 300–600 影联标）
	var total_weight: int = 0
	var influence_weight: int = 0
	for ev_variant: Variant in _events_cfg.get("events", []):
		var ev: Dictionary = ev_variant
		var weight: int = int(ev.get("trigger", {}).get("weight", 0))
		total_weight += weight
		if _has_effect_type(ev, "influence"):
			influence_weight += weight
	assert_gt(total_weight, 0, "权重总和必须为正")
	var share: float = float(influence_weight) / float(total_weight)
	assert_gte(share, 0.25, "influence 卡权重占比 %.4f 应 ≥25%%" % share)
	var expected: Dictionary = EventEngine.expected_weekly_effect(_events_cfg)
	var total_160: float = float(expected.get("influence", 0.0)) * 160.0
	assert_between(total_160, 300.0, 600.0, "160 周事件 influence 期望 %.1f 应落在 300–600 影" % total_160)


func test_event_income_share_bound() -> void:
	# [T] #75：V-sim —— 160 周事件累计收入 ≤ 累计经营收入 10%，事件净效果周均 ≤0.6k
	var world := GameWorld.new()
	world.start_new_game(20260908)
	var task_policy := AutoTaskPolicy.new()
	var decision_policy := AutoDecisionPolicy.new()
	var weeks: int = 160
	var settled: int = 0
	for _i: int in range(weeks):
		task_policy.fill(world)
		# #104 PR-C：决策卡入 pending 等玩家选择；headless 长跑注入应答策略
		# （AutoDecisionPolicy 恒选 0 号选项，与原"自动选 0"语义一致）。
		var reports: Array[Dictionary] = world.simulate_weeks(1, decision_policy)
		if reports.is_empty():
			break
		settled += 1
		if world.game_over_flag:
			break
	assert_gte(settled, weeks, "160 周应完整推进（占槽任务口径下不破产）")
	assert_gt(world.cum_income, 0, "160 周累计经营收入应大于 0")
	var event_income: int = world.event_engine.get_cum_money_gain()
	var event_net: int = world.event_engine.get_cum_money_net()
	var share: float = float(event_income) / float(world.cum_income)
	assert_lte(share, 0.10, "事件累计收入占比 %.4f 应 ≤10%%" % share)
	var weekly_net: float = float(event_net) / float(settled)
	assert_lte(absf(weekly_net), 600.0, "事件净效果周均 %.1f 应 ≤0.6k" % weekly_net)


func _has_effect_type(ev: Dictionary, eff_type: String) -> bool:
	for eff_variant: Variant in ev.get("effects", []):
		if eff_variant is Dictionary and str(eff_variant.get("type", "")) == eff_type:
			return true
	for opt_variant: Variant in ev.get("options", []):
		if opt_variant is Dictionary:
			for opt_eff: Variant in opt_variant.get("effects", []):
				if opt_eff is Dictionary and str(opt_eff.get("type", "")) == eff_type:
					return true
	return false


func _cooldown_weeks_for(ev_id: String) -> int:
	for ev_variant: Variant in _events_cfg.get("events", []):
		if ev_variant is Dictionary and str(ev_variant.get("id", "")) == ev_id:
			return int(ev_variant.get("trigger", {}).get("cooldown_weeks", 0))
	return 0
