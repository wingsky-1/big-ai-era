class_name TreeResearch
extends RefCounted
## L2 科技树研究状态机（#138 独立类——TechTree 迷雾状态机拆分方向
## architecture §8"按子状态机拆"）：研究点亮（成本/前置/周数）+ 升级 ★1-3 +
## 效果三型（解锁/乘子/降费）查询 + 树预算护栏。
## 设计：
## - TechTree（迷雾）与 TreeResearch（研究）组合：研究类经注入的 fog 谓词
##   读/推迷雾态（is_visible/is_lit/advance_to_lit/domain_of），不持有 fog 字典
##   ——单向依赖零环（TechTree 装配 TreeResearch 并注入自身谓词）；
## - 效果声明/成本/前置全读 tech_tree.json（#138 键：tree_node_effects/
##   tree_research_cost_by_node/tree_prereq_by_node/tree_research_weeks/顶层
##   成本曲线/预算键）；代码零硬编码；
## - 影响力消耗=注入谓词 spend_influence（装配方接 Resources；null=免费）；
## - G9 修正约束（DoD 验收）：数值型节点 ≤3、乘子单级 +2–3%、1 浅 1 深、
##   树预算全口径 ≤30%（is_tree_budget_ok 判定器）。
## RefCounted 零 Node；headless 可单测。

signal node_lit(payload: Dictionary)

## tech_tree.json 键（真源拼写；#138 键名前缀分区）
const TABLE_PATH: String = "res://src/data/tech_tree.json"

## 错误码/原因（中文消息随 reason 返回）
const ERR_RESEARCH: String = "research_failed"
const REASON_UNKNOWN_NODE: String = "未知节点"
const REASON_NOT_VISIBLE: String = "仅 visible 节点可开始研究"
const REASON_PREREQ: String = "前置节点未点亮（先研前置）"
const REASON_NO_INFLUENCE: String = "影响力不足"
const REASON_ALREADY_LIT: String = "lit 为终态不可重复研究"
const REASON_NOT_LIT: String = "仅 lit 节点可升级"
const REASON_MAX_LEVEL: String = "已达满级"
const REASON_NO_UPGRADE: String = "解锁型节点 1 级即满（仅数值/降费型可升）"

## 迷雾谓词注入（TechTree 装配注入；单向依赖零环）
## is_visible(node_id)->bool / is_lit(node_id)->bool / advance_to_lit(node_id)
var is_visible: Callable = func(_node_id: String) -> bool: return false
var is_lit: Callable = func(_node_id: String) -> bool: return false
var advance_to_lit: Callable = func(_node_id: String) -> bool: return false
var domain_of: Callable = func(_node_id: String) -> String: return ""

## 影响力消耗谓词注入（装配方接 Resources.spend_influence；默认=免费）
var spend_influence: Callable = func(_amount: int) -> bool: return true

var _table: Dictionary = {}
## 节点 → {researching, weeks_left, level}
var _research_state: Dictionary = {}


func _init(tree_table: Dictionary = {}) -> void:
	if tree_table.is_empty():
		tree_table = DataLoader.load_json(TABLE_PATH)
	_table = tree_table


## ---------- 研究命令 ----------


## 研究开始：visible + 前置满足 + 影响力足 → 研究中（研究周数由表定）。
func start_research(node_id: String) -> Dictionary:
	if (
		not _table.has("tree_node_effects")
		or not (_table["tree_node_effects"] as Dictionary).has(node_id)
	):
		return _fail(REASON_UNKNOWN_NODE)
	if not is_visible.call(node_id):
		return _fail(REASON_NOT_VISIBLE)
	if is_lit.call(node_id):
		return _fail(REASON_ALREADY_LIT)
	if not _prereq_met(node_id):
		return _fail(REASON_PREREQ)
	var cost := _research_cost(node_id)
	if cost > 0 and not spend_influence.call(cost):
		return _fail(REASON_NO_INFLUENCE)
	var weeks := _research_weeks_for(node_id)
	_research_state[node_id] = {"researching": true, "weeks_left": weeks, "level": 1}
	return {"ok": true, "node_id": node_id, "path": "research", "cost": cost, "weeks": weeks}


## 周结研究推进（Settlement phase 7c 调）：递减研究周数，归零 → lit。
func research_tick() -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for node_id: String in _research_state.keys():
		var state: Dictionary = _research_state[node_id]
		if not bool(state.get("researching", false)):
			continue
		var weeks_left: int = int(state.get("weeks_left", 0)) - 1
		if weeks_left > 0:
			state["weeks_left"] = weeks_left
			continue
		state["researching"] = false
		state["weeks_left"] = 0
		if advance_to_lit.call(node_id):
			(
				node_lit
				. emit(
					{
						"node_id": node_id,
						"effect": get_node_effect(node_id),
						"level": int(state.get("level", 1)),
					}
				)
			)
			(
				completed
				. append(
					{
						"node_id": node_id,
						"effect": get_node_effect(node_id),
						"level": int(state.get("level", 1)),
					}
				)
			)
	return completed


## 节点升级（数值/降费型可升；解锁型 1 级即满）：成本×growth^level 递增。
func upgrade_node(node_id: String) -> Dictionary:
	var state: Dictionary = _research_state.get(node_id, {})
	if not is_lit.call(node_id):
		return _fail(REASON_NOT_LIT)
	var level: int = int(state.get("level", 1))
	var upgrade_max := int(_table.get("tree_upgrade_max", 3))
	if level >= upgrade_max:
		return _fail(REASON_MAX_LEVEL)
	var effect := get_node_effect(node_id)
	var eff_type := str(effect.get("type", ""))
	if eff_type == "unlock" or eff_type == "rumor":
		return _fail(REASON_NO_UPGRADE)
	var cost := _upgrade_cost(node_id, level)
	if cost > 0 and not spend_influence.call(cost):
		return _fail(REASON_NO_INFLUENCE)
	state["level"] = level + 1
	state["researching"] = true
	state["weeks_left"] = _research_weeks_for(node_id)
	_research_state[node_id] = state
	return {"ok": true, "node_id": node_id, "level": int(state["level"]), "cost": cost}


## ---------- 效果查询（L2 出数 L3 只画） ----------


## 节点效果声明（tree_node_effects 读表；未知=空）
func get_node_effect(node_id: String) -> Dictionary:
	var effects: Variant = _table.get("tree_node_effects", {})
	if effects is Dictionary and (effects as Dictionary).has(node_id):
		var effect: Variant = (effects as Dictionary)[node_id]
		if effect is Dictionary:
			return (effect as Dictionary).duplicate()
	return {}


## 效果分层统计（DoD：数值型 ≤3/解锁为主/降费有上限）
func get_effect_layer_counts() -> Dictionary:
	var counts := {"unlock": 0, "mult": 0, "cost": 0, "rumor": 0}
	var effects: Variant = _table.get("tree_node_effects", {})
	if effects is Dictionary:
		for node_id: Variant in (effects as Dictionary).keys():
			var effect: Dictionary = get_node_effect(str(node_id))
			var eff_type := str(effect.get("type", ""))
			if counts.has(eff_type):
				counts[eff_type] = int(counts[eff_type]) + 1
	return counts


## 数值节点乘子（单级 +2–3%；level 从研究状态读）
func get_multiplier(node_id: String) -> float:
	var effect := get_node_effect(node_id)
	if str(effect.get("type", "")) != "mult":
		return 1.0
	var per_level := float(effect.get("amount_per_level", 0.0))
	var level := _level_of(node_id)
	return 1.0 + per_level * float(level)


## 降费效果（单级 -5~-12%；返回折扣率 0.08=省 8%）
func get_cost_discount(node_id: String) -> float:
	var effect := get_node_effect(node_id)
	if str(effect.get("type", "")) != "cost":
		return 0.0
	var per_level := float(effect.get("amount_per_level", 0.0))
	return per_level * float(_level_of(node_id))


## 树预算护栏判定器（DoD：全口径 score ≤30%）。
func is_tree_budget_ok(current_score: float, no_tree_score: float) -> bool:
	var budget := float(_table.get("tree_tb_budget", 0.3))
	if current_score <= 0.0:
		return true
	var tree_share := 0.0
	if no_tree_score > 0.0:
		tree_share = (current_score - no_tree_score) / current_score
	return tree_share <= budget


func get_tree_budget() -> float:
	return float(_table.get("tree_tb_budget", 0.3))


## 数值节点浅深置（DoD：1 浅置 W20–40 可达 +1 深置）
func get_mult_placements() -> Dictionary:
	var result := {"shallow": [], "deep": []}
	var effects: Variant = _table.get("tree_node_effects", {})
	if effects is Dictionary:
		for node_id: Variant in (effects as Dictionary).keys():
			var effect := get_node_effect(str(node_id))
			if str(effect.get("type", "")) != "mult":
				continue
			var placement := str(effect.get("placement", "deep"))
			if result.has(placement):
				(result[placement] as Array).append(str(node_id))
	return result


## 节点研究状态视图（L3 迷雾面板行：研究中/剩余周/级别）
func get_research_view(node_id: String) -> Dictionary:
	var state: Dictionary = _research_state.get(node_id, {})
	return {
		"researching": bool(state.get("researching", false)),
		"weeks_left": int(state.get("weeks_left", 0)),
		"level": int(state.get("level", 1)),
	}


## ---------- 私有 ----------


func _prereq_met(node_id: String) -> bool:
	var prereq: Variant = _table.get("tree_prereq_by_node", {}).get(node_id, [])
	if prereq is not Array:
		return true
	for req: Variant in prereq as Array:
		if not is_lit.call(str(req)):
			return false
	return true


func _research_cost(node_id: String) -> int:
	var costs: Variant = _table.get("tree_research_cost_by_node", {})
	if costs is Dictionary and (costs as Dictionary).has(node_id):
		return int((costs as Dictionary)[node_id])
	return 0


func _upgrade_cost(node_id: String, level: int) -> int:
	var base := _research_cost(node_id)
	if base <= 0:
		base = int(_table.get("tree_research_cost_base", 30))
	var growth := float(_table.get("tree_research_cost_growth", 1.6))
	return int(roundf(float(base) * pow(growth, float(level))))


func _research_weeks_for(node_id: String) -> int:
	var effect := get_node_effect(node_id)
	var placement := str(effect.get("placement", "shallow"))
	var weeks_cfg: Variant = _table.get("tree_research_weeks", {"shallow": 2, "deep": 4})
	if placement == "deep":
		return int((weeks_cfg as Dictionary).get("deep", 4))
	return int((weeks_cfg as Dictionary).get("shallow", 2))


func _level_of(node_id: String) -> int:
	var state: Dictionary = _research_state.get(node_id, {})
	return int(state.get("level", 1))


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "code": ERR_RESEARCH, "reason": reason}
