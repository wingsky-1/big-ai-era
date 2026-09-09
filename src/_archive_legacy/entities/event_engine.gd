class_name EventEngine
extends RefCounted

## 事件与灵感引擎（L2 RefCounted，DR-001 / DR-012 / DR-021 M2 / DR-023 / DR-031 C2）：
## - 8 张事件卡（谓词触发 + 命中率门 + 冷却窗口 + 加权抽取，复用 RNG 域 event_roll）
## - 9 种效果枚举与显式 timing（immediate / delayed 于周结第 3 步消费）
## - 决策卡阻塞与 pending 入档（单周至多 1 张决策卡，双卡触发自动顺延入 week_due）
## - 命中率门 p_week / 单卡效果上限 / 总闸 / 冷却窗口全部来自 src/data/events.json
##   （ADR-0013 零默认值纪律：缺键 push_error 熔断，代码不留数值兜底）
## - 冷却窗口入档 events.cooldowns{}（开放容器加键零迁移；fired 数组语义不变）

signal event_triggered(event_data: Dictionary)
signal decision_pending_set(card: Dictionary)
signal effects_applied(effects: Array)

const EVENTS_PATH: String = "res://src/data/events.json"

var _events_cfg: Array = []
var _inspiration_spec: Dictionary = {}
var _event_spec: Dictionary = {}
var _fired_events: Dictionary = {}
var _cooldowns: Dictionary = {}
var _pending_card: Dictionary = {}
var _effects_pending: Array = []
var _inspiration_pity: int = 0
var _cum_money_gain: int = 0
var _cum_money_net: int = 0


func setup(config: Dictionary) -> void:
	_events_cfg = config.get("events", []).duplicate(true)
	_inspiration_spec = config.get("inspiration_spec", {}).duplicate(true)
	if _inspiration_spec.is_empty():
		push_error("EventEngine: 缺少 inspiration_spec（真源 %s）" % EVENTS_PATH)
	_event_spec = config.get("event_spec", {}).duplicate(true)
	if _event_spec.is_empty():
		push_error("EventEngine: 缺少 event_spec（真源 %s）" % EVENTS_PATH)
	_fired_events.clear()
	_cooldowns.clear()
	_pending_card.clear()
	_effects_pending.clear()
	_inspiration_pity = 0
	_cum_money_gain = 0
	_cum_money_net = 0


func get_pending_card() -> Dictionary:
	return _pending_card.duplicate(true)


func get_effects_pending() -> Array:
	return _effects_pending.duplicate(true)


func get_inspiration_pity() -> int:
	return _inspiration_pity


## 命中率门（REV-01 / DR-031 C2）：本周抽卡概率，真源 events.json.event_spec.p_week。
func get_p_week() -> float:
	var p_week_variant: Variant = DataLoader.require_key(_event_spec, "p_week", EVENTS_PATH)
	return float(p_week_variant) if p_week_variant != null else 0.0


## 冷却状态只读视图（{event_id: 最近抽中周}；入档 events.cooldowns{}）。
func get_cooldowns() -> Dictionary:
	return _cooldowns.duplicate(true)


## 事件累计 money 正项收入（V-sim「事件收入占比 ≤10%」口径；运行时统计不入档）。
func get_cum_money_gain() -> int:
	return _cum_money_gain


## 事件累计 money 净效果（含负向卡，V-sim「周均 ≤0.6k」口径；运行时统计不入档）。
func get_cum_money_net() -> int:
	return _cum_money_net


## 周结管线第 3 步：消费 delayed 效果队列（在出分前消费）
func consume_delayed_effects(world: RefCounted) -> void:
	var pending_copy: Array = _effects_pending.duplicate(true)
	_effects_pending.clear()
	for effect_variant: Variant in pending_copy:
		if effect_variant is Dictionary:
			_apply_single_effect(effect_variant, world)


## 周结管线第 8 步：灵感判定与触发（RNG 域 inspiration）
func evaluate_inspiration(rng: RngStream, fog: TechFog) -> Dictionary:
	_inspiration_pity += 1
	var cap_variant: Variant = DataLoader.require_key(_inspiration_spec, "cap", EVENTS_PATH)
	var base_variant: Variant = DataLoader.require_key(_inspiration_spec, "base", EVENTS_PATH)
	var pity_variant: Variant = DataLoader.require_key(_inspiration_spec, "pity", EVENTS_PATH)
	var boost_variant: Variant = DataLoader.require_key(
		_inspiration_spec, "pity_boost_factor", EVENTS_PATH
	)
	var skip_variant: Variant = DataLoader.require_key(
		_inspiration_spec, "pity_skip_step", EVENTS_PATH
	)
	if (
		cap_variant == null
		or base_variant == null
		or pity_variant == null
		or boost_variant == null
		or skip_variant == null
	):
		return {"triggered": false}
	var cap: int = int(cap_variant)
	var base: float = float(base_variant)
	var pity: int = int(pity_variant)
	var pity_boost: float = float(boost_variant)
	var pity_skip: int = int(skip_variant)

	var hit: bool = false
	# cap 硬保底：since >= cap 必触发
	if _inspiration_pity >= cap:
		hit = true
	elif _inspiration_pity >= pity:
		hit = rng.hit_domain(RngStream.DOMAIN_INSPIRATION, base * pity_boost)
	else:
		hit = rng.hit_domain(RngStream.DOMAIN_INSPIRATION, base)

	if not hit:
		return {"triggered": false}

	# 检查当前是否有可研/可揭示节点
	# 若触发但无可用目标或触发>可研节点数：跳过并顺延 pity
	if fog != null and fog.get_discovered_count() >= fog.get_total_nodes():
		_inspiration_pity = maxi(0, _inspiration_pity - pity_skip)
		return {"triggered": false, "skipped_overflow": true}

	# 灵感成功触发，重置计数器
	_inspiration_pity = 0
	return {
		"triggered": true,
		"title": "灵光一闪",
		"description": "研究员在深夜迸发出突破性灵感！",
	}


## 周结管线第 9 步：事件抽取与判定（RNG 域 event_roll）
func evaluate_events(
	current_week: int, rng: RngStream, context: Dictionary, world: RefCounted
) -> Dictionary:
	# 检查是否有上一周顺延到本周的决策卡（顺延不消耗 RNG、不参与命中率门）
	if not _pending_card.is_empty():
		var due_week: int = int(_pending_card.get("week_due", current_week))
		if current_week >= due_week:
			decision_pending_set.emit(_pending_card)
			return {"event_id": str(_pending_card.get("id", "")), "kind": "decision"}

	# 命中率门（REV-01 / DR-031 C2）：复用 event_roll 域；未过门则通知层静默（本周不抽）
	var p_week_variant: Variant = DataLoader.require_key(_event_spec, "p_week", EVENTS_PATH)
	if p_week_variant == null:
		return {}
	if not rng.hit_domain(RngStream.DOMAIN_EVENT_ROLL, float(p_week_variant)):
		return {}

	# 筛选符合条件的候选卡（once 永久排除 + 冷却窗口未到 + 谓词）
	var candidates: Array[Dictionary] = []
	var total_weight: int = 0

	for ev_variant: Variant in _events_cfg:
		if ev_variant is Dictionary:
			var ev: Dictionary = ev_variant
			var ev_id: String = str(ev.get("id", ""))
			var trigger: Dictionary = ev.get("trigger", {})

			# once 检查（fired 数组语义不变：抽中即登记，once 卡永久排除）
			if bool(trigger.get("once", false)) and _fired_events.has(ev_id):
				continue

			# 冷却检查（REV-03：同卡 N 周内不重复；非 once 卡专属）
			if _is_on_cooldown(ev_id, trigger, current_week):
				continue

			# 谓词检查
			if not PredicateRegistry.evaluate(trigger, context):
				continue

			candidates.append(ev)
			var weight_variant: Variant = DataLoader.require_key(trigger, "weight", EVENTS_PATH)
			if weight_variant == null:
				continue
			total_weight += int(weight_variant)

	if candidates.is_empty() or total_weight <= 0:
		return {}

	# 加权随机抽取
	var roll: int = rng.randi_range_domain(RngStream.DOMAIN_EVENT_ROLL, 1, total_weight)
	var accumulated: int = 0
	var chosen: Dictionary = candidates[0]
	for cand: Dictionary in candidates:
		var w: int = int(cand["trigger"]["weight"])
		accumulated += w
		if roll <= accumulated:
			chosen = cand
			break

	var chosen_id: String = str(chosen.get("id", ""))
	var kind: String = str(chosen.get("kind", "notice"))
	_fired_events[chosen_id] = true
	_record_cooldown(chosen_id, chosen, current_week)

	if kind == "decision":
		var pending_data: Dictionary = {
			"id": chosen_id,
			"title": chosen.get("title", ""),
			"description": chosen.get("description", ""),
			"options": chosen.get("options", []),
			"week_due": current_week,
		}
		_pending_card = pending_data
		decision_pending_set.emit(_pending_card)
	else:
		# 通知卡直接应用 immediate 效果
		apply_effects(chosen.get("effects", []), world)
		event_triggered.emit(chosen)

	return chosen


## 应用选项/事件效果（支持 9 种效果类型与 timing 时序）
func apply_effects(effects: Array, world: RefCounted) -> void:
	for eff_variant: Variant in effects:
		if eff_variant is Dictionary:
			var eff: Dictionary = eff_variant
			var timing: String = str(eff.get("timing", "immediate"))
			if timing == "delayed":
				_effects_pending.append(eff.duplicate(true))
			else:
				_apply_single_effect(eff, world)
	effects_applied.emit(effects)


func _apply_single_effect(eff: Dictionary, world: RefCounted) -> void:
	var eff_type: String = str(eff.get("type", ""))
	var val: Variant = eff.get("value")
	var target: String = str(eff.get("target", ""))

	match eff_type:
		"money":
			world.economy.apply_delta("money", int(val), "event_money")
			_cum_money_net += int(val)
			if int(val) > 0:
				_cum_money_gain += int(val)
		"compute":
			world.economy.apply_delta("compute", int(val), "event_compute")
		"influence":
			world.economy.apply_delta("influence", int(val), "event_influence")
		"rp_grant":
			world.economy.apply_delta("influence", int(val), "event_rp_grant")
		"fog_reveal":
			if world.tech_fog != null and target != "":
				world.tech_fog.spill_reveal(target, str(val))
		"inject_task":
			if world.task_queue != null and target != "":
				world.enqueue_task(target)
		"start_training":
			if world.training != null and target != "":
				world.start_training(target)
		"flag_set":
			world.set_meta(StringName(target), val)
		"delay_training":
			if world.training != null and world.training.is_training():
				var cur: Dictionary = world.training.get_active_training()
				cur["weeks_left"] = int(cur.get("weeks_left", 0)) + int(val)
				world.training.restore(cur)


## 玩家做出决策卡选择
func choose_decision_option(option_idx: int, world: RefCounted) -> bool:
	if _pending_card.is_empty():
		return false

	var options: Array = _pending_card.get("options", [])
	if option_idx < 0 or option_idx >= options.size():
		return false

	var chosen_opt: Dictionary = options[option_idx]
	apply_effects(chosen_opt.get("effects", []), world)
	_pending_card.clear()
	return true


func to_snapshot() -> Dictionary:
	return {
		"pending": _pending_card.duplicate(true),
	}


func to_save() -> Dictionary:
	return {
		"fired": _fired_events.keys(),
		"cooldowns": _cooldowns.duplicate(true),
		"pending": [_pending_card.duplicate(true)] if not _pending_card.is_empty() else [],
		"effects_pending": _effects_pending.duplicate(true),
		"inspiration_pity": _inspiration_pity,
	}


func restore(data: Dictionary) -> void:
	_fired_events.clear()
	for f: Variant in data.get("fired", []):
		_fired_events[str(f)] = true
	_cooldowns.clear()
	var cooldowns_data: Variant = data.get("cooldowns", {})
	if cooldowns_data is Dictionary:
		for cd_key: Variant in cooldowns_data:
			_cooldowns[str(cd_key)] = int(cooldowns_data[cd_key])
	var pending_arr: Array = data.get("pending", [])
	if not pending_arr.is_empty():
		_pending_card = (pending_arr[0] as Dictionary).duplicate(true)
	else:
		_pending_card.clear()
	_effects_pending = data.get("effects_pending", []).duplicate(true)
	_inspiration_pity = int(data.get("inspiration_pity", 0))


## ============ 冷却与预算闸（DR-031/C2）============


## 单卡冷却窗口（周）：非 once 卡必填 trigger.cooldown_weeks；once 卡走 fired 永久排除。
## 缺键 push_error 并返回 0（不熔断抽取流程；数据表级断言 test_event_card_effect_caps 兜底）。
func _cooldown_weeks_of(trigger: Dictionary) -> int:
	if bool(trigger.get("once", false)):
		return 0
	var window_variant: Variant = DataLoader.require_key(trigger, "cooldown_weeks", EVENTS_PATH)
	if window_variant == null:
		return 0
	return int(window_variant)


func _is_on_cooldown(ev_id: String, trigger: Dictionary, current_week: int) -> bool:
	if not _cooldowns.has(ev_id):
		return false
	var window: int = _cooldown_weeks_of(trigger)
	if window <= 0:
		return false
	return current_week - int(_cooldowns[ev_id]) < window


func _record_cooldown(ev_id: String, event_data: Dictionary, current_week: int) -> void:
	if _cooldown_weeks_of(event_data.get("trigger", {})) <= 0:
		return
	_cooldowns[ev_id] = current_week


## 单卡效果上限校验（REV-02 / DR-031 C2）：返回违规描述列表（空=全表合规）。
## 覆盖 effects 与决策卡 options[*].effects；money 取绝对值（负向卡同样受上限约束）。
static func validate_card_caps(config: Dictionary) -> Array[String]:
	var spec: Dictionary = config.get("event_spec", {})
	var violations: Array[String] = []
	var max_money_variant: Variant = DataLoader.require_key(spec, "max_money", EVENTS_PATH)
	var max_rp_variant: Variant = DataLoader.require_key(spec, "max_rp_grant", EVENTS_PATH)
	var max_influence_variant: Variant = DataLoader.require_key(spec, "max_influence", EVENTS_PATH)
	if max_money_variant == null or max_rp_variant == null or max_influence_variant == null:
		violations.append("event_spec 缺上限键（max_money/max_rp_grant/max_influence）")
		return violations
	var max_money: int = int(max_money_variant)
	var max_rp: int = int(max_rp_variant)
	var max_influence: int = int(max_influence_variant)
	for ev_variant: Variant in config.get("events", []):
		if not ev_variant is Dictionary:
			continue
		var ev: Dictionary = ev_variant
		var ev_id: String = str(ev.get("id", ""))
		_collect_cap_violations(
			ev_id, ev.get("effects", []), max_money, max_rp, max_influence, violations
		)
		for opt_variant: Variant in ev.get("options", []):
			if opt_variant is Dictionary:
				var opt: Dictionary = opt_variant
				_collect_cap_violations(
					ev_id, opt.get("effects", []), max_money, max_rp, max_influence, violations
				)
	return violations


static func _collect_cap_violations(
	ev_id: String,
	effects: Array,
	max_money: int,
	max_rp: int,
	max_influence: int,
	violations: Array[String]
) -> void:
	for eff_variant: Variant in effects:
		if not eff_variant is Dictionary:
			continue
		var eff: Dictionary = eff_variant
		var eff_type: String = str(eff.get("type", ""))
		var value: int = int(eff.get("value", 0))
		match eff_type:
			"money":
				if absi(value) > max_money:
					violations.append("%s money %d 超上限 %d" % [ev_id, value, max_money])
			"rp_grant":
				if value > max_rp:
					violations.append("%s rp_grant %d 超上限 %d" % [ev_id, value, max_rp])
			"influence":
				if value > max_influence:
					violations.append("%s influence %d 超上限 %d" % [ev_id, value, max_influence])


## 事件期望周效果（总闸口径 REV-04 / DR-031 C2）：
## 逐卡 = p_week × 权重占比 × 单次效果期望（决策卡取全部选项均值）。
## 返回 {money, rp_grant, influence}（单位：每周）。
static func expected_weekly_effect(config: Dictionary) -> Dictionary:
	var spec: Dictionary = config.get("event_spec", {})
	var p_week_variant: Variant = DataLoader.require_key(spec, "p_week", EVENTS_PATH)
	var p_week: float = float(p_week_variant) if p_week_variant != null else 0.0
	var events: Array = config.get("events", [])
	var total_weight: int = 0
	for ev_variant: Variant in events:
		if not ev_variant is Dictionary:
			continue
		var weight_variant: Variant = DataLoader.require_key(
			ev_variant.get("trigger", {}), "weight", EVENTS_PATH
		)
		if weight_variant != null:
			total_weight += int(weight_variant)
	var out: Dictionary = {"money": 0.0, "rp_grant": 0.0, "influence": 0.0}
	if total_weight <= 0:
		return out
	for ev_variant: Variant in events:
		if not ev_variant is Dictionary:
			continue
		var ev: Dictionary = ev_variant
		var weight_variant: Variant = DataLoader.require_key(
			ev.get("trigger", {}), "weight", EVENTS_PATH
		)
		if weight_variant == null:
			continue
		var weight_ratio: float = float(int(weight_variant)) / float(total_weight)
		var per_draw: Dictionary = _expected_effect_per_draw(ev)
		for key: String in out:
			out[key] = float(out[key]) + p_week * weight_ratio * float(per_draw.get(key, 0.0))
	return out


static func _expected_effect_per_draw(ev: Dictionary) -> Dictionary:
	var totals: Dictionary = {"money": 0.0, "rp_grant": 0.0, "influence": 0.0}
	var options: Array = ev.get("options", [])
	if options.is_empty():
		_accumulate_effects(ev.get("effects", []), 1.0, totals)
	else:
		var share: float = 1.0 / float(options.size())
		for opt_variant: Variant in options:
			if opt_variant is Dictionary:
				_accumulate_effects(opt_variant.get("effects", []), share, totals)
	return totals


static func _accumulate_effects(effects: Array, factor: float, totals: Dictionary) -> void:
	for eff_variant: Variant in effects:
		if not eff_variant is Dictionary:
			continue
		var eff: Dictionary = eff_variant
		var eff_type: String = str(eff.get("type", ""))
		if not totals.has(eff_type):
			continue
		totals[eff_type] = float(totals[eff_type]) + factor * float(int(eff.get("value", 0)))
