class_name TechTree
extends RefCounted

## 科技树管理（L2 RefCounted）：
## - 依赖 TechFog（迷雾态）与 PredicateRegistry（前置谓词校验）。
## - 负责科技点亮研发（预扣 RP 与结项资金原子检查）、tech_bonus 聚合重算。

signal tech_researched(tech_id: String, bonus: float)

var _nodes: Dictionary = {}
var _fog: TechFog
var _tech_bonus: float = 0.0


func setup(techs_config: Dictionary, fog: TechFog) -> void:
	_nodes = techs_config.get("nodes", {}).duplicate(true)
	_fog = fog
	_recalculate_tech_bonus()


func get_tech_bonus() -> float:
	return _tech_bonus


## 前置条件与资源预检
func can_research(tech_id: String, context: Dictionary) -> Dictionary:
	if not _nodes.has(tech_id):
		return {"ok": false, "reason": "not_found", "rp_cost": 0, "cost": 0}

	if _fog == null:
		return {"ok": false, "reason": "fog_not_set", "rp_cost": 0, "cost": 0}

	var state: String = _fog.get_state(tech_id)
	if state != TechFog.STATE_RESEARCHABLE:
		return {"ok": false, "reason": "not_researchable", "rp_cost": 0, "cost": 0}

	var node_data: Dictionary = _nodes[tech_id]
	var rp_cost: int = int(node_data.get("rp_cost", 0))
	var cost: int = int(node_data.get("cost", 0))

	# 检查可用 RP
	var available_rp: int = int(context.get("influence", context.get("rp", 0)))
	if available_rp < rp_cost:
		return {"ok": false, "reason": "insufficient_rp", "rp_cost": rp_cost, "cost": cost}

	# 检查可用资金
	var available_money: int = int(context.get("money", 0))
	if available_money < cost:
		return {"ok": false, "reason": "insufficient_money", "rp_cost": rp_cost, "cost": cost}

	return {"ok": true, "reason": "", "rp_cost": rp_cost, "cost": cost}


## 研发点亮科技（原子双扣 + 点亮 + 重算 tech_bonus）
func start_research(tech_id: String, context: Dictionary) -> Dictionary:
	var check: Dictionary = can_research(tech_id, context)
	if not check.get("ok", false):
		return check

	var rp_cost: int = int(check.get("rp_cost", 0))
	var cost: int = int(check.get("cost", 0))

	# 资源扣减
	var economy: Economy = context.get("economy")
	if economy != null:
		if rp_cost > 0:
			economy.apply_delta("influence", -rp_cost, "tech_research_rp")
		if cost > 0:
			economy.apply_delta("money", -cost, "tech_research_cost")
	else:
		if context.has("influence"):
			context["influence"] = int(context["influence"]) - rp_cost
		if context.has("money"):
			context["money"] = int(context["money"]) - cost

	# 点亮科技
	_fog.set_lit(tech_id)
	_recalculate_tech_bonus()
	tech_researched.emit(tech_id, _tech_bonus)

	return {
		"ok": true,
		"tech_id": tech_id,
		"rp_cost": rp_cost,
		"cost": cost,
		"tech_bonus": _tech_bonus,
	}


func _recalculate_tech_bonus() -> void:
	if _fog == null:
		_tech_bonus = 0.0
		return

	var total_bonus: float = 0.0
	for tech_id: String in _nodes:
		if _fog.get_state(tech_id) == TechFog.STATE_LIT:
			var node: Dictionary = _nodes[tech_id]
			var effect: Dictionary = node.get("effect", {})
			if str(effect.get("type", "")) == "tech_bonus" and bool(effect.get("enabled", false)):
				total_bonus += float(effect.get("value", 0.0))

	_tech_bonus = total_bonus


func to_snapshot() -> Dictionary:
	return {
		"lit": _fog.get_lit_techs() if _fog != null else [],
		"tech_bonus": _tech_bonus,
	}


func to_save() -> Dictionary:
	return {
		"lit": _fog.get_lit_techs() if _fog != null else [],
	}


func restore(data: Dictionary) -> void:
	var lit_list: Array = data.get("lit", [])
	if _fog != null:
		for tech_id_variant: Variant in lit_list:
			_fog.set_lit(str(tech_id_variant))
	_recalculate_tech_bonus()
