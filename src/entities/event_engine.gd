class_name EventEngine
extends RefCounted

## 事件与灵感引擎（L2 RefCounted，DR-001 / DR-012 / DR-021 M2 / DR-023）：
## - 8 张事件卡（谓词触发+加权抽取，RNG 域 event_roll）
## - 9 种效果枚举与显式 timing（immediate / delayed 于周结第 3 步消费）
## - 决策卡阻塞与 pending 入档（单周至多 1 张决策卡，双卡触发自动顺延入 week_due）
## - 灵感三键（base/pity/cap）与权重全部来自 src/data/events.json（ADR-0013 零默认值纪律）

signal event_triggered(event_data: Dictionary)
signal decision_pending_set(card: Dictionary)
signal effects_applied(effects: Array)

const EVENTS_PATH: String = "res://src/data/events.json"

var _events_cfg: Array = []
var _inspiration_spec: Dictionary = {}
var _fired_events: Dictionary = {}
var _pending_card: Dictionary = {}
var _effects_pending: Array = []
var _inspiration_pity: int = 0


func setup(config: Dictionary) -> void:
	_events_cfg = config.get("events", []).duplicate(true)
	_inspiration_spec = config.get("inspiration_spec", {}).duplicate(true)
	if _inspiration_spec.is_empty():
		push_error("EventEngine: 缺少 inspiration_spec（真源 %s）" % EVENTS_PATH)
	_fired_events.clear()
	_pending_card.clear()
	_effects_pending.clear()
	_inspiration_pity = 0


func get_pending_card() -> Dictionary:
	return _pending_card.duplicate(true)


func get_effects_pending() -> Array:
	return _effects_pending.duplicate(true)


func get_inspiration_pity() -> int:
	return _inspiration_pity


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
	# 检查是否有上一周顺延到本周的决策卡
	if not _pending_card.is_empty():
		var due_week: int = int(_pending_card.get("week_due", current_week))
		if current_week >= due_week:
			decision_pending_set.emit(_pending_card)
			return {"event_id": str(_pending_card.get("id", "")), "kind": "decision"}

	# 筛选符合条件的候选卡
	var candidates: Array[Dictionary] = []
	var total_weight: int = 0

	for ev_variant: Variant in _events_cfg:
		if ev_variant is Dictionary:
			var ev: Dictionary = ev_variant
			var ev_id: String = str(ev.get("id", ""))
			var trigger: Dictionary = ev.get("trigger", {})

			# once 检查
			if bool(trigger.get("once", false)) and _fired_events.has(ev_id):
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
		"pending": [_pending_card.duplicate(true)] if not _pending_card.is_empty() else [],
		"effects_pending": _effects_pending.duplicate(true),
		"inspiration_pity": _inspiration_pity,
	}


func restore(data: Dictionary) -> void:
	_fired_events.clear()
	for f: Variant in data.get("fired", []):
		_fired_events[str(f)] = true
	var pending_arr: Array = data.get("pending", [])
	if not pending_arr.is_empty():
		_pending_card = (pending_arr[0] as Dictionary).duplicate(true)
	else:
		_pending_card.clear()
	_effects_pending = data.get("effects_pending", []).duplicate(true)
	_inspiration_pity = int(data.get("inspiration_pity", 0))
