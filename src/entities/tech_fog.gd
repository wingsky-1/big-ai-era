class_name TechFog
extends RefCounted

## 科技树迷雾系统（L2 纯逻辑，RefCounted，无 Node 依赖）
## 依据：
## - docs/adr/0009-tech-fog-standalone-pure-function.md
## - docs/gdd/gdd.md §8.2
## - docs/discussion/decision-log.md DR-003 / DR-023 / DR-027⑤（pity=8, cap=12 硬保底）

signal fog_changed(payload: Dictionary)

const STATE_HIDDEN: String = "hidden"
const STATE_RUMORED: String = "rumored"
const STATE_VISIBLE: String = "visible"
const STATE_RESEARCHABLE: String = "researchable"
const STATE_LIT: String = "lit"

const TOTAL_NODES: int = 14
const PITY_THRESHOLD: int = 8
const PITY_CAP: int = 12

const DEFAULT_TECHS_PATH: String = "res://src/data/techs.json"

const OPENING_RESEARCHABLE_NODES: Array[String] = [
	"silver_leash",
	"cot_sketch",
	"distill_garden",
	"hand_tutor",
]

var _nodes_data: Dictionary = {}
var _domain_enum: Array = []
var _fog_gate_rumored: int = 200
var _fog_gate_visible: int = 600

# 状态字典：tech_id -> 状态字符串
var _fog_states: Dictionary = {}
var _pity_counter: int = 0
var _crossover_progress: int = 0


func _init(techs_path: String = DEFAULT_TECHS_PATH) -> void:
	_load_config(techs_path)
	reset()


## 允许外部传入字典配置重置（对齐其他实体 setup 约定）
func setup(config: Dictionary) -> void:
	_fog_gate_rumored = int(config.get("fog_gate", {}).get("rumored", 200))
	_fog_gate_visible = int(config.get("fog_gate", {}).get("visible", 600))
	_nodes_data = config.get("nodes", {}).duplicate(true)
	reset()


## 获取所有已点亮科技 ID 列表
func get_lit_techs() -> Array[String]:
	var lit_list: Array[String] = []
	for node_id: String in _fog_states:
		if _fog_states[node_id] == STATE_LIT:
			lit_list.append(node_id)
	return lit_list


func reset() -> void:
	_fog_states.clear()
	_pity_counter = 0
	_crossover_progress = 0

	for node_id: String in _nodes_data:
		var node: Dictionary = _nodes_data[node_id]
		var domain: String = str(node.get("domain", ""))
		if domain == "elsewhere":
			# 他者道路开局保持 rumored 传闻占位
			_fog_states[node_id] = STATE_RUMORED
		elif OPENING_RESEARCHABLE_NODES.has(node_id):
			_fog_states[node_id] = STATE_RESEARCHABLE
		else:
			_fog_states[node_id] = STATE_HIDDEN

	_update_crossover_progress()
	_emit_fog_changed()


func advance(cumulative_rp: int) -> bool:
	var any_revealed: bool = false

	# 通路 1: 周 RP 累积达到 fog_gate.rumored 与 visible 揭示翻态
	for node_id: String in _nodes_data:
		var node: Dictionary = _nodes_data[node_id]
		var domain: String = str(node.get("domain", ""))
		if domain == "elsewhere":
			continue

		var current_state: String = get_state(node_id)
		if current_state == STATE_HIDDEN and cumulative_rp >= _fog_gate_rumored:
			if cumulative_rp >= _fog_gate_visible:
				_fog_states[node_id] = STATE_VISIBLE
			else:
				_fog_states[node_id] = STATE_RUMORED
			any_revealed = true
		elif current_state == STATE_RUMORED and cumulative_rp >= _fog_gate_visible:
			_fog_states[node_id] = STATE_VISIBLE
			any_revealed = true

	# 通路 3: 检查 visible -> researchable 转移（含 parents 全 lit 与交叉节点条件）
	var unlocked_to_researchable: bool = _evaluate_researchable_transitions()
	if unlocked_to_researchable:
		any_revealed = true

	# 保底逻辑（Pity 计数器与 cap=12 硬保底）
	if any_revealed:
		_pity_counter = 0
	else:
		_pity_counter += 1
		# 硬保底：连续无翻雾达到 cap=12 周，必触发翻雾
		if _pity_counter >= PITY_CAP:
			var pity_revealed: bool = _trigger_pity_reveal()
			if pity_revealed:
				any_revealed = true
				_pity_counter = 0

	_update_crossover_progress()
	if any_revealed:
		_emit_fog_changed()

	return any_revealed


func spill_reveal(tech_id: String, target_state: String = STATE_VISIBLE) -> bool:
	# 通路 2: 竞对论文/事件外溢翻态
	if not _nodes_data.has(tech_id):
		push_error("TechFog.spill_reveal: 未知科技 ID '%s'" % tech_id)
		return false

	var node: Dictionary = _nodes_data[tech_id]
	var domain: String = str(node.get("domain", ""))
	if domain == "elsewhere" and target_state == STATE_RESEARCHABLE:
		push_warning("TechFog.spill_reveal: 他者道路不允许提升为 researchable")
		return false

	var current_state: String = get_state(tech_id)
	if current_state == STATE_LIT:
		return false

	# 状态单向推进：hidden -> rumored -> visible -> researchable -> lit
	var state_order: Dictionary = {
		STATE_HIDDEN: 0,
		STATE_RUMORED: 1,
		STATE_VISIBLE: 2,
		STATE_RESEARCHABLE: 3,
		STATE_LIT: 4,
	}

	var current_val: int = state_order.get(current_state, 0)
	var target_val: int = state_order.get(target_state, 0)

	if target_val > current_val:
		_fog_states[tech_id] = target_state
		_pity_counter = 0
		_evaluate_researchable_transitions()
		_update_crossover_progress()
		_emit_fog_changed()
		return true

	return false


func set_lit(tech_id: String) -> bool:
	# 玩家/世界完成该科技研发时置为 lit
	if not _nodes_data.has(tech_id):
		push_error("TechFog.set_lit: 未知科技 ID '%s'" % tech_id)
		return false

	var node: Dictionary = _nodes_data[tech_id]
	var domain: String = str(node.get("domain", ""))
	if domain == "elsewhere":
		push_error("TechFog.set_lit: 他者道路不可置为 lit")
		return false

	var current_state: String = get_state(tech_id)
	if current_state == STATE_LIT:
		return false

	_fog_states[tech_id] = STATE_LIT
	_pity_counter = 0

	# 点亮后可能触发依赖它的子节点或交叉节点提升为 researchable
	_evaluate_researchable_transitions()
	_update_crossover_progress()
	_emit_fog_changed()
	return true


func adjust_pity(delta: int) -> void:
	# 灵感触发 > 可研节点数时"跳过顺延 pity 减 2"兜底
	_pity_counter = maxi(0, _pity_counter + delta)


func get_pity() -> int:
	return _pity_counter


func set_pity(val: int) -> void:
	_pity_counter = maxi(0, val)


func get_state(tech_id: String) -> String:
	return str(_fog_states.get(tech_id, STATE_HIDDEN))


func get_fog_states() -> Dictionary:
	return _fog_states.duplicate()


func get_discovered_count() -> int:
	# 已探明数（已离开 hidden 态的节点数，即 rumored + visible + researchable + lit）
	var count: int = 0
	for node_id: String in _fog_states:
		if _fog_states[node_id] != STATE_HIDDEN:
			count += 1
	return count


func get_domain_counts() -> Dictionary:
	# 各域探明数字典：domain -> 已探明节点数
	var counts: Dictionary = {}
	for dom: Variant in _domain_enum:
		counts[str(dom)] = 0

	for node_id: String in _fog_states:
		if _fog_states[node_id] != STATE_HIDDEN and _nodes_data.has(node_id):
			var domain: String = str(_nodes_data[node_id].get("domain", ""))
			counts[domain] = counts.get(domain, 0) + 1
	return counts


func get_crossover_progress() -> int:
	return _crossover_progress


func to_snapshot() -> Dictionary:
	return {
		"fog_states": _fog_states.duplicate(),
		"crossover_progress": _crossover_progress,
		"pity": _pity_counter,
	}


func to_save() -> Dictionary:
	return {
		"fog_visibility": _fog_states.duplicate(),
		"crossover_progress": _crossover_progress,
		"pity": _pity_counter,
	}


func restore(data: Dictionary) -> void:
	if data.has("fog_states") and data["fog_states"] is Dictionary:
		for k: String in data["fog_states"]:
			_fog_states[k] = str(data["fog_states"][k])
	elif data.has("fog_visibility") and data["fog_visibility"] is Dictionary:
		for k: String in data["fog_visibility"]:
			_fog_states[k] = str(data["fog_visibility"][k])

	if data.has("pity"):
		_pity_counter = int(data["pity"])
	if data.has("crossover_progress"):
		_crossover_progress = int(data["crossover_progress"])

	_update_crossover_progress()
	_emit_fog_changed()


func _load_config(path: String) -> void:
	var data: Dictionary = DataLoader.load_json(path)
	if data.is_empty():
		push_error("TechFog: 无法从 '%s' 加载科技数据" % path)
		return

	_domain_enum = data.get("domain_enum", [])
	var fog_gate: Dictionary = data.get("fog_gate", {})
	_fog_gate_rumored = int(fog_gate.get("rumored", 200))
	_fog_gate_visible = int(fog_gate.get("visible", 600))
	_nodes_data = data.get("nodes", {})


func _evaluate_researchable_transitions() -> bool:
	var changed: bool = false
	var keep_checking: bool = true

	# 依赖可能形成多层拓扑链，循环直到无新节点晋级
	while keep_checking:
		keep_checking = false
		for node_id: String in _nodes_data:
			var node: Dictionary = _nodes_data[node_id]
			var domain: String = str(node.get("domain", ""))
			if domain == "elsewhere":
				continue

			var current_state: String = get_state(node_id)
			# 必须先达到 visible 态以上才能升至 researchable（开局 researchable 除外已预设）
			if current_state != STATE_VISIBLE:
				continue

			if _can_become_researchable(node_id, node):
				_fog_states[node_id] = STATE_RESEARCHABLE
				changed = true
				keep_checking = true

	return changed


func _can_become_researchable(node_id: String, node: Dictionary) -> bool:
	var parents: Array = node.get("parents", [])
	var domain: String = str(node.get("domain", ""))

	# 特殊交叉节点条件：mirror_mind
	if node_id == "mirror_mind":
		var unlock: Dictionary = node.get("unlock", {})
		var req_count: int = int(unlock.get("params", {}).get("required_lit_count", 6))
		return _count_lit_mainline_nodes() >= req_count

	# 通用条件：parents 必须全部已点亮 (lit)
	if parents.is_empty():
		return true

	for p_id: Variant in parents:
		if get_state(str(p_id)) != STATE_LIT:
			return false

	return true


func _count_lit_mainline_nodes() -> int:
	var count: int = 0
	for node_id: String in _nodes_data:
		var node: Dictionary = _nodes_data[node_id]
		var domain: String = str(node.get("domain", ""))
		# 主干节点排除 elsewhere 和 crossover
		if domain != "elsewhere" and domain != "crossover":
			if get_state(node_id) == STATE_LIT:
				count += 1
	return count


func _update_crossover_progress() -> void:
	# 交叉进度统计：已点亮的主干节点数
	_crossover_progress = _count_lit_mainline_nodes()


func _trigger_pity_reveal() -> bool:
	# 硬保底：从处于 hidden 态的节点中挑选第一个表序节点翻为 visible (或 rumored)
	for node_id: String in _nodes_data:
		var node: Dictionary = _nodes_data[node_id]
		var domain: String = str(node.get("domain", ""))
		if domain == "elsewhere":
			continue

		if get_state(node_id) == STATE_HIDDEN:
			# 保底将 hidden 翻为 visible
			_fog_states[node_id] = STATE_VISIBLE
			_evaluate_researchable_transitions()
			return true

	return false


func _emit_fog_changed() -> void:
	var payload: Dictionary = {
		"discovered_count": get_discovered_count(),
		"total_nodes": TOTAL_NODES,
		"fog_states": _fog_states.duplicate(),
		"domain_counts": get_domain_counts(),
		"crossover_progress": _crossover_progress,
		"pity": _pity_counter,
	}
	fog_changed.emit(payload)
