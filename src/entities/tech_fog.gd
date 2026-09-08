class_name TechFog
extends RefCounted

## 科技树迷雾系统（L2 纯逻辑，RefCounted，无 Node 依赖）
## 依据：
## - docs/adr/0009-tech-fog-standalone-pure-function.md
## - docs/gdd/gdd.md §8.2
## - docs/discussion/decision-log.md DR-003 / DR-023 / DR-027⑤（pity=8, cap=12 硬保底）
##
## 数值真源：src/data/techs.json —— `total_nodes` / `pity.{threshold,cap}` / `fog_gate`
## / `domain_flags` / 节点级 `opening_researchable`；ADR-0013 零默认值纪律，
## 缺键即 push_error 熔断（禁止代码默认值兜底）。

signal fog_changed(payload: Dictionary)

const STATE_HIDDEN: String = "hidden"
const STATE_RUMORED: String = "rumored"
const STATE_VISIBLE: String = "visible"
const STATE_RESEARCHABLE: String = "researchable"
const STATE_LIT: String = "lit"

## 状态单向推进序列（数组索引即序数，替代旧的状态→魔法数映射表）
const STATE_SEQUENCE: Array[String] = [
	STATE_HIDDEN,
	STATE_RUMORED,
	STATE_VISIBLE,
	STATE_RESEARCHABLE,
	STATE_LIT,
]

const DEFAULT_TECHS_PATH: String = "res://src/data/techs.json"

var _nodes_data: Dictionary = {}
var _domain_enum: Array = []
var _domain_flags: Dictionary = {}
var _total_nodes: int = 0
var _pity_cap: int = 0
var _fog_gate_rumored: int = 0
var _fog_gate_visible: int = 0

# 状态字典：tech_id -> 状态字符串
var _fog_states: Dictionary = {}
var _pity_counter: int = 0
var _crossover_progress: int = 0


func _init(techs_path: String = DEFAULT_TECHS_PATH) -> void:
	_apply_config(DataLoader.load_json(techs_path))
	reset()


## 允许外部传入字典配置重置（对齐其他实体 setup 约定）
func setup(config: Dictionary) -> void:
	_apply_config(config)
	reset()


## 节点总数真源（事件引擎/UI 均经此取值，禁止各自硬编码）
func get_total_nodes() -> int:
	return _total_nodes


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
		if not _is_researchable_domain(str(node.get("domain", ""))):
			# 不可研域（他者道路）开局保持 rumored 传闻占位
			_fog_states[node_id] = STATE_RUMORED
		elif bool(node.get("opening_researchable", false)):
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
		if not _is_researchable_domain(str(node.get("domain", ""))):
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

	# 保底逻辑（Pity 计数器与 cap 硬保底）
	if any_revealed:
		_pity_counter = 0
	else:
		_pity_counter += 1
		# 硬保底：连续无翻雾达到 cap 周，必触发翻雾
		if _pity_counter >= _pity_cap:
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
	var researchable_domain: bool = _is_researchable_domain(str(node.get("domain", "")))
	if not researchable_domain and target_state == STATE_RESEARCHABLE:
		push_warning("TechFog.spill_reveal: 他者道路不允许提升为 researchable")
		return false

	var current_state: String = get_state(tech_id)
	if current_state == STATE_LIT:
		return false

	# 状态单向推进：hidden -> rumored -> visible -> researchable -> lit
	var current_val: int = maxi(STATE_SEQUENCE.find(current_state), 0)
	var target_val: int = maxi(STATE_SEQUENCE.find(target_state), 0)

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
	if not _is_researchable_domain(str(node.get("domain", ""))):
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


## 配置装载（techs.json 全量：域枚举/域标志/节点表/节点总数/pity/fog_gate）。
func _apply_config(config: Dictionary) -> void:
	if config.is_empty():
		push_error("TechFog: 配置为空（真源 %s）" % DEFAULT_TECHS_PATH)
		return

	_domain_enum = config.get("domain_enum", [])
	_domain_flags = config.get("domain_flags", {})
	_nodes_data = config.get("nodes", {}).duplicate(true)

	var total: Variant = DataLoader.require_key(config, "total_nodes", DEFAULT_TECHS_PATH)
	_total_nodes = int(total) if total != null else 0

	var pity: Dictionary = config.get("pity", {})
	var pity_cap: Variant = DataLoader.require_key(pity, "cap", DEFAULT_TECHS_PATH)
	_pity_cap = int(pity_cap) if pity_cap != null else 0

	var fog_gate: Dictionary = config.get("fog_gate", {})
	var rumored: Variant = DataLoader.require_key(fog_gate, "rumored", DEFAULT_TECHS_PATH)
	_fog_gate_rumored = int(rumored) if rumored != null else 0
	var visible: Variant = DataLoader.require_key(fog_gate, "visible", DEFAULT_TECHS_PATH)
	_fog_gate_visible = int(visible) if visible != null else 0


## 域是否可研（techs.json `domain_flags`；未列出的域默认可研）
func _is_researchable_domain(domain: String) -> bool:
	var flags: Dictionary = _domain_flags.get(domain, {})
	return bool(flags.get("researchable", true))


## 域是否计入主干（techs.json `domain_flags`；未列出的域默认计入）
func _counts_mainline(domain: String) -> bool:
	var flags: Dictionary = _domain_flags.get(domain, {})
	return bool(flags.get("counts_mainline", true))


func _evaluate_researchable_transitions() -> bool:
	var changed: bool = false
	var keep_checking: bool = true

	# 依赖可能形成多层拓扑链，循环直到无新节点晋级
	while keep_checking:
		keep_checking = false
		for node_id: String in _nodes_data:
			var node: Dictionary = _nodes_data[node_id]
			if not _is_researchable_domain(str(node.get("domain", ""))):
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


func _can_become_researchable(_node_id: String, node: Dictionary) -> bool:
	var parents: Array = node.get("parents", [])
	var unlock: Dictionary = node.get("unlock", {})

	# 交叉节点条件：由 techs.json 节点级 unlock 声明（predicate=crossover_count）
	if str(unlock.get("predicate", "")) == "crossover_count":
		var required: Variant = DataLoader.require_key(
			unlock.get("params", {}), "required_lit_count", DEFAULT_TECHS_PATH
		)
		if required == null:
			return false
		return _count_lit_mainline_nodes() >= int(required)

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
		# 主干节点：由 techs.json domain_flags.counts_mainline 决定（排除 elsewhere/crossover）
		if _counts_mainline(str(node.get("domain", ""))):
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
		if not _is_researchable_domain(str(node.get("domain", ""))):
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
		"total_nodes": _total_nodes,
		"fog_states": _fog_states.duplicate(),
		"domain_counts": get_domain_counts(),
		"crossover_progress": _crossover_progress,
		"pity": _pity_counter,
	}
	fog_changed.emit(payload)
