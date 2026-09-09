class_name TechTree
extends RefCounted
## L2 科技树迷雾状态机（#137）：五态单向转换 + 翻雾三通路 + 同域 pity。
## 设计约束（任务书/tech-tree-spec A.1/architecture-100 §2.2 要点 6/ADR-0009）：
## - RefCounted、零 Node/SceneTree 依赖（headless 可单测）；禁 import L3/L4；
## - 迷雾五态=enum（禁字符串散落，H6 stringly-typed 防线）；五态链
##   hidden→rumored→visible→researchable→lit 单向前进、恰一档推进、无跳态/回退——
##   非法推进（未知节点/lit 终态）拒绝 + push_error；lit 为终态；
## - 翻雾三通路：①周推进揭示=经 RngStream 消费 rng.insight（pity_pull_domain 载体，
##   触发率 tree_fog_reveal_rate 表驱动，pity 参数读 rng.json rnd_insight_pity_max，
##   #125 定稿键）；②竞对论文外溢=确定性注入表（weekly_spill_nodes 可注入 Callable
##   ∩ 节点表 spill_eligible 声明；#144 周报真接线点，本单留接口+测试注入验证）；
##   ③交叉进度=他域 lit → 联动推进相邻交叉节点（tree_cross_nodes 表驱动
##   cross_from 声明，每次联动恰推进一节点=tree_reveal_cross 语义）；
## - 数据面 get_fog_view()：hidden="???" 行（name_key=tree_fog_hidden）/rumored=
##   传闻句（tree_fog_rumored），域组带计数（total/lit/known）+ pity 剩余周条——
##   [P] "迷雾里有一个方向想点亮"的数据面契约（L3 迷雾面板留真人）；
## - 信号 fog_changed：{domain, node_id, state}（architecture-100 §5.2 信号表）。

signal fog_changed(payload: Dictionary)

## 迷雾五态（节点状态机，tech-tree-spec A.1；值经 _state_key 映射为视图字符串）
enum FogState {
	HIDDEN,
	RUMORED,
	VISIBLE,
	RESEARCHABLE,
	LIT,
}

const TREE_TABLE_PATH: String = "res://src/data/tech_tree.json"
const DOMAIN_ORDER_KEY: String = "_order"

## tech-tree-spec D.2 键名（真源精确拼写；#137 落位键前缀分区：
## tree_fog_*/tree_insight_* 归本单，tree_research_* 归 #138 同文件增量）
const KEY_NODE_TOTAL: String = "tree_node_total"
const KEY_DOMAIN_NODES: String = "tree_domain_nodes"
const KEY_PITY_MAX: String = "tree_insight_pity_max"
const KEY_REVEAL_CROSS: String = "tree_reveal_cross"
const KEY_FOG_REVEAL_RATE: String = "tree_fog_reveal_rate"
const KEY_DOMAINS: String = "tree_domains"
const KEY_NODES: String = "tree_nodes"
const KEY_CROSS_NODES: String = "tree_cross_nodes"
const KEY_RUMOR_NODES: String = "tree_rumor_nodes"
const KEY_RNG_PITY_MAX: String = "rnd_insight_pity_max"
const KEY_INSIGHT_DOMAIN: String = "insight"

## 翻雾通路标识（揭示结果载荷 path 用；代码闭集，频率带登记未来可挂）
const PATH_WEEKLY: String = "weekly"
const PATH_SPILL: String = "spill"
const PATH_CROSS: String = "cross"
const PATHS_VALID: Array[String] = [PATH_WEEKLY, PATH_SPILL, PATH_CROSS]

## 节点迷雾分组（tech-tree-spec A.1：10 域节点/3 交叉/1 传闻占位）
const FOG_GROUP_DOMAIN: String = "domain"
const FOG_GROUP_CROSS: String = "cross"
const FOG_GROUP_RUMOR: String = "rumor"

## hidden="???" 掩码行文案键（tech-tree-spec C.1 tree_fog_hidden）；rumored 行=
## 域传闻句（tree_fog_rumored）。文案渲染归 L3 TextService，本类只透传 name_key。
const NAME_KEY_FOG_HIDDEN: String = "tree_fog_hidden"
const NAME_KEY_FOG_RUMORED: String = "tree_fog_rumored"

## 返回载荷键与错误码（中文消息随 reason 返回；转换类错误另 push_error）
const ERR_REVEAL: String = "reveal_failed"
const ERR_RESEARCH: String = "research_start_failed"
const REASON_NO_TARGET: String = "域内无待翻雾节点（???/传闻行不存在）"
const REASON_NO_RNG: String = "周推进须注入 RngStream（rng.insight 载体）"
const REASON_NO_HIT: String = "本周未触发周推进揭示"
const REASON_NOT_VISIBLE: String = "仅 visible 节点可开始研究"
const REASON_UNKNOWN_NODE: String = "未知节点"
const REASON_UNKNOWN_DOMAIN: String = "未知域"
const REASON_ALREADY_LIT: String = "lit 为终态不可再推进"
const REASON_NO_SPILL: String = "竞对论文外溢：无表内命中节点"
const REASON_NO_CROSS: String = "域内无相邻交叉节点可联动揭示"

## 可注入的竞对外溢源（#144 真接线点：周报外溢名单源注入；默认真=无外溢）。
## 注入返回 Array[String]（node_id 名单），本单只做揭示逻辑，测试注入验证。
var weekly_spill_nodes: Callable = func() -> Array: return []

var _node_rows: Dictionary = {}
var _domain_order: Array[String] = []
var _fog: Dictionary = {}
var _pity_streak_by_domain: Dictionary = {}
var _rng: RngStream = null
var _tree_pity_max: int = 0
var _rng_pity_max: int = 0
var _fog_reveal_rate: float = 0.0
## tree_reveal_cross：每次联动最多推进的交叉节点数（D.2 表值；占位 1=每次恰 1）
var _cross_reveal_max: int = 0
## tree_domain_nodes：每域节点数（D.2 表值，视图/断言与表同源）
var _domain_node_count: int = 0


func _init(tree_table: Dictionary = {}, rng_stream: RngStream = null) -> void:
	var table: Dictionary = tree_table
	if table.is_empty():
		table = DataLoader.load_json(TREE_TABLE_PATH)
		if table.is_empty():
			push_error("TechTree: tech_tree.json 加载失败（真源 %s）" % TREE_TABLE_PATH)
			return
	_tree_pity_max = int(table.get(KEY_PITY_MAX, 0))
	_fog_reveal_rate = float(table.get(KEY_FOG_REVEAL_RATE, 0.0))
	_cross_reveal_max = int(table.get(KEY_REVEAL_CROSS, 1))
	_domain_node_count = int(table.get(KEY_DOMAIN_NODES, 0))
	_assemble_table(table)
	_rng = rng_stream
	if _rng != null:
		if not _rng.get_registered_domains().has(KEY_INSIGHT_DOMAIN):
			push_error("TechTree: rng.insight 域未登记（#125 rng.json 域登记表）")
		_rng_pity_max = _rng.get_int_param(KEY_RNG_PITY_MAX)
		for domain_id: String in _domain_order:
			_pity_streak_by_domain[domain_id] = 0
	else:
		## 无 rng 注入：pity 视图用 tech_tree.json 上限兜底（周推进命令拒绝）
		_rng_pity_max = _tree_pity_max


func _assemble_table(table: Dictionary) -> void:
	## 表驱动装配：10 域节点（每域 2）+ 3 交叉 + 1 传闻占位；名称/成本/效果 #138
	var domains_block: Dictionary = table.get(KEY_DOMAINS, {})
	for item: Variant in domains_block.get(DOMAIN_ORDER_KEY, []):
		if item is String:
			_domain_order.append(item)
	for domain_id: String in _domain_order:
		var raw: Variant = table.get(KEY_NODES, {}).get(domain_id, [])
		if raw is Array:
			for row_variant: Variant in raw:
				_register_row(row_variant, domain_id, FOG_GROUP_DOMAIN)
	var cross_raw: Variant = table.get(KEY_CROSS_NODES, [])
	if cross_raw is Array:
		for row_variant: Variant in cross_raw:
			_register_row(row_variant, FOG_GROUP_CROSS, FOG_GROUP_CROSS)
	var rumor_raw: Variant = table.get(KEY_RUMOR_NODES, [])
	if rumor_raw is Array:
		for row_variant: Variant in rumor_raw:
			_register_row(row_variant, FOG_GROUP_RUMOR, FOG_GROUP_RUMOR)


## 节点注册：域行 domain=五域 id；交叉/传闻行 domain=组 id（不参与任何域计数）；
## 交叉节点 cross_from 只收表驱动声明中 ∈ 五域的去重相邻域。
func _register_row(row_variant: Variant, fallback_domain: String, group_id: String) -> void:
	if row_variant is not Dictionary:
		return
	var row: Dictionary = row_variant
	var node_id := str(row.get("id", ""))
	if node_id.is_empty() or _node_rows.has(node_id):
		return
	var domain_id: String = str(row.get("domain", ""))
	if group_id == FOG_GROUP_DOMAIN:
		if domain_id.is_empty() or not _domain_order.has(domain_id):
			domain_id = fallback_domain
	else:
		domain_id = group_id
	var cross_from: Array = []
	if group_id == FOG_GROUP_CROSS:
		var declared: Variant = row.get("cross_from", [])
		if declared is Array:
			for item: Variant in declared:
				if item is String and _domain_order.has(item) and not cross_from.has(item):
					cross_from.append(item)
	_node_rows[node_id] = {
		"id": node_id,
		"domain": domain_id,
		"fog_type": group_id,
		"name_key": str(row.get("name_key", NAME_KEY_FOG_HIDDEN)),
		"cross_from": cross_from,
		"spill_eligible": bool(row.get("spill_eligible", false)),
		"state": FogState.HIDDEN,
	}
	_fog[node_id] = FogState.HIDDEN


## ---------- 命令面（契约命令） ----------


## ①周推进揭示（周结由 Settlement 逐域调用）：先判本域是否有待揭节点（无可揭
## 则空转失败，不消费 rng/pity——保底只对"有 ???/传闻行可翻"的域有意义）；
## 再经 rng.insight pity_pull_domain 判定本周是否触发（连 N 周不揭示第 N 周必
## 触发=域内保底）；触发则把域内最浅待揭节点推进恰一档并重置域 pity。
func weekly_reveal(domain_id: String) -> Dictionary:
	if not _is_domain(domain_id):
		return _fail(ERR_REVEAL, REASON_UNKNOWN_DOMAIN)
	if not _has_reveal_target(domain_id):
		return _fail(ERR_REVEAL, REASON_NO_TARGET)
	if _rng == null or _rng_pity_max <= 0:
		return _fail(ERR_REVEAL, REASON_NO_RNG)
	var streak: int = _pity_streak(domain_id)
	var pull: Dictionary = _rng.pity_pull_domain(
		KEY_INSIGHT_DOMAIN, _fog_reveal_rate, _rng_pity_max, streak
	)
	if not bool(pull.get("hit", false)):
		_pity_streak_by_domain[domain_id] = streak + 1
		return _fail(ERR_REVEAL, REASON_NO_HIT)
	var target: String = _first_reveal_target(domain_id)
	if target.is_empty() or not advance_fog(target):
		return _fail(ERR_REVEAL, REASON_NO_TARGET)
	_pity_streak_by_domain[domain_id] = 0
	return _ok(target, PATH_WEEKLY)


## ②竞对论文外溢：确定性注入名单 ∩ 节点表 spill_eligible 声明 ∩ 待揭，
## 命中的最浅节点推进恰一档；无命中=空转失败（#144 真接线前常态）。
func spill_reveal() -> Dictionary:
	var candidates: Array = _spill_candidates()
	if candidates.is_empty():
		return _fail(ERR_REVEAL, REASON_NO_SPILL)
	for node_id: String in candidates:
		if not advance_fog(node_id):
			continue
		# 外溢翻雾同样算"同域揭示"：重置被翻节点所属域的 pity（randomness-spec A.2 边界）
		var node_domain: String = str(_node_rows[node_id]["domain"])
		if _is_domain(node_domain):
			_pity_streak_by_domain[node_domain] = 0
		return _ok(node_id, PATH_SPILL)
	return _fail(ERR_REVEAL, REASON_NO_SPILL)


## ③交叉进度：本域已有 lit 节点（他域 lit 联动语义=域内实证出现）→ 把
## cross_from 声明含本域的相邻交叉节点推进恰一档（table-driven 相邻域声明）。
## 由编排方在节点 lit 后调用（本单只出命令与纯函数判定；#138 研究完成联动接线）。
func cross_reveal(domain_id: String) -> Dictionary:
	if not _is_domain(domain_id):
		return _fail(ERR_REVEAL, REASON_UNKNOWN_DOMAIN)
	if _lit_count(domain_id) <= 0:
		return _fail(ERR_REVEAL, "无已 lit 节点（他域 lit 才联动揭示）")
	## tree_reveal_cross 表驱动联动上限（D.2 行：相邻域 lit +N 揭示；表值 1=恰一节点）
	var budget: int = maxi(0, _cross_reveal_max)
	var advanced: Array[String] = []
	for node_id: Variant in _node_rows.keys():
		if budget <= 0:
			break
		var node_key := str(node_id)
		if (
			_is_cross_adjacent(node_key, domain_id)
			and _has_reveal_target_for(node_key)
			and advance_fog(node_key)
		):
			advanced.append(node_key)
			budget -= 1
	if advanced.is_empty():
		return _fail(ERR_REVEAL, REASON_NO_CROSS)
	return _ok(advanced[0], PATH_CROSS)


## 五态状态机公开原语：节点恰推进一档（hidden→rumored→visible→researchable→
## lit 单向前进）。非法推进（未知节点/lit 终态）返回 false + push_error。
## 研究业务命令（成本/前置/周结完成与效果）归 #138，本方法只保证 fog 迁移合法。
func advance_fog(node_id: String) -> bool:
	if not _node_rows.has(node_id):
		push_error("TechTree: %s（%s）" % [REASON_UNKNOWN_NODE, node_id])
		return false
	var from_state: FogState = _fog[node_id]
	if from_state == FogState.LIT:
		push_error("TechTree: %s（%s）" % [REASON_ALREADY_LIT, node_id])
		return false
	var to_state: FogState = from_state + 1
	_fog[node_id] = to_state
	_node_rows[node_id]["state"] = to_state
	fog_changed.emit(_fog_payload(node_id))
	return true


## researchable 态判定（#138 研究命令占位）：仅 visible（可见可研）可开始研究；
## rumored→researchable 直接拒绝=无跳态（rumored 需先翻雾到 visible）。
func is_researchable_ready(node_id: String) -> bool:
	if not _node_rows.has(node_id):
		return false
	return _fog[node_id] == FogState.VISIBLE


## 研究开始（#138 只出接口与态判定，不落成本/进度）：visible → researchable。
func start_research(node_id: String) -> Dictionary:
	if not _node_rows.has(node_id):
		return _fail(ERR_RESEARCH, REASON_UNKNOWN_NODE)
	if _fog[node_id] != FogState.VISIBLE:
		return _fail(ERR_RESEARCH, REASON_NOT_VISIBLE)
	if advance_fog(node_id):
		return _ok(node_id, "research")
	return _fail(ERR_RESEARCH, REASON_NOT_VISIBLE)


## ---------- 数据面（只读契约，深拷贝） ----------


## 迷雾视图：全量组（五域 + cross/rumor 分组）；域组行=??? 掩码行 + 计数 + pity。
func get_fog_view() -> Dictionary:
	var view: Dictionary = {
		"tree_node_total": _node_rows.size(),
		"tree_domain_nodes": _domain_nodes_per_domain(),
		"pity_max": _pity_max_display(),
		"groups": {},
	}
	for domain_id: String in _domain_order:
		view["groups"][domain_id] = _group_view(domain_id)
	view["groups"][FOG_GROUP_CROSS] = _group_view(FOG_GROUP_CROSS)
	view["groups"][FOG_GROUP_RUMOR] = _group_view(FOG_GROUP_RUMOR)
	return view


## 域迷雾视图（迷雾面板按域刷新用；行/计数/pity 与 get_fog_view 同口径）。
func get_domain_view(domain_id: String) -> Dictionary:
	if not _is_domain(domain_id):
		return {}
	return _group_view(domain_id)


func get_node_fog_state(node_id: String) -> int:
	if not _node_rows.has(node_id):
		return -1
	return int(_fog[node_id])


func is_node_hidden(node_id: String) -> bool:
	if not _node_rows.has(node_id):
		return false
	return _fog[node_id] == FogState.HIDDEN


func is_node_lit(node_id: String) -> bool:
	if not _node_rows.has(node_id):
		return false
	return _fog[node_id] == FogState.LIT


## 本域 pity 剩余周（数据面条：值=距保底必揭示的剩余周数，0=本周即保底）。
func get_domain_pity_left(domain_id: String) -> int:
	if not _is_domain(domain_id):
		return -1
	return maxi(0, _rng_pity_max - _pity_streak(domain_id))


## ---------- 内部（组视图/计数/pity） ----------


func _group_view(group_id: String) -> Dictionary:
	var rows: Array = []
	var lit_count: int = 0
	var hidden_count: int = 0
	for node_id: String in _node_rows.keys():
		if (
			_node_rows[node_id]["fog_type"] != group_id
			and _node_rows[node_id]["domain"] != group_id
		):
			continue
		if _fog[node_id] == FogState.LIT:
			lit_count += 1
		elif _fog[node_id] == FogState.HIDDEN:
			hidden_count += 1
		rows.append(_row_view(node_id))
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a["node_id"]) < str(b["node_id"])
	)
	var total: int = rows.size()
	return {
		"group_id": group_id,
		"rows": rows,
		"total": total,
		"lit_count": lit_count,
		"known_count": total - hidden_count,
		"hidden_count": hidden_count,
		"pity_left": get_domain_pity_left(group_id) if _is_domain(group_id) else 0,
	}


func _row_view(node_id: String) -> Dictionary:
	var row: Dictionary = _node_rows[node_id]
	var state: FogState = _fog[node_id]
	var name_key: String = str(row["name_key"])
	if state == FogState.HIDDEN:
		name_key = NAME_KEY_FOG_HIDDEN
	elif state == FogState.RUMORED:
		name_key = NAME_KEY_FOG_RUMORED
	return {
		"node_id": node_id,
		"domain": str(row["domain"]),
		"fog_type": str(row["fog_type"]),
		"state": _state_key(state),
		"name_key": name_key,
		"hidden": state == FogState.HIDDEN,
	}


func _state_key(state: FogState) -> String:
	match state:
		FogState.HIDDEN:
			return "hidden"
		FogState.RUMORED:
			return "rumored"
		FogState.VISIBLE:
			return "visible"
		FogState.RESEARCHABLE:
			return "researchable"
		FogState.LIT:
			return "lit"
	return "unknown"


func _fog_payload(node_id: String) -> Dictionary:
	var row: Dictionary = _node_rows[node_id]
	return {
		"domain": str(row["domain"]),
		"node_id": node_id,
		"state": _state_key(_fog[node_id]),
	}


## 域节点数（每域 2；schema 测试守全表同构）。tech-tree-spec D.2 tree_domain_nodes。
func _domain_nodes_per_domain() -> int:
	var count: int = 0
	for node_id: String in _node_rows.keys():
		if _node_rows[node_id]["fog_type"] == FOG_GROUP_DOMAIN:
			count += 1
	if count <= 0 or _domain_order.is_empty():
		return 0
	return int(roundf(float(count) / float(_domain_order.size())))


func _count_domain_nodes(domain_id: String) -> int:
	var count: int = 0
	for node_id: String in _node_rows.keys():
		if (
			_node_rows[node_id]["fog_type"] == FOG_GROUP_DOMAIN
			and _node_rows[node_id]["domain"] == domain_id
		):
			count += 1
	return count


func _lit_count(domain_id: String) -> int:
	var count: int = 0
	for node_id: String in _node_rows.keys():
		if _node_rows[node_id]["domain"] == domain_id and _fog[node_id] == FogState.LIT:
			count += 1
	return count


func _is_domain(domain_id: String) -> bool:
	return _domain_order.has(domain_id)


func _is_cross_adjacent(node_id: String, domain_id: String) -> bool:
	if not _node_rows.has(node_id):
		return false
	var row: Dictionary = _node_rows[node_id]
	if row["fog_type"] != FOG_GROUP_CROSS:
		return false
	var adjacent: Array = row["cross_from"]
	return adjacent.has(domain_id)


## 待揭目标=HIDDEN 或 RUMORED（翻雾只揭示未点亮节点，visible 起归研究面）。
func _has_reveal_target_for(node_id: String) -> bool:
	if not _node_rows.has(node_id):
		return false
	var state: FogState = _fog[node_id]
	return state == FogState.HIDDEN or state == FogState.RUMORED


func _first_reveal_target(group_or_domain_id: String) -> String:
	for node_id: String in _node_rows.keys():
		var row: Dictionary = _node_rows[node_id]
		var belongs: bool = (
			row["fog_type"] == group_or_domain_id or row["domain"] == group_or_domain_id
		)
		if belongs and _has_reveal_target_for(node_id):
			return node_id
	return ""


func _has_reveal_target(group_or_domain_id: String) -> bool:
	return not _first_reveal_target(group_or_domain_id).is_empty()


## 外溢候选：注入名单 ∩ spill_eligible 声明 ∩ 待揭（推进恰一档）。
func _spill_candidates() -> Array:
	var candidates: Array = []
	var injected: Variant = weekly_spill_nodes.call()
	if injected is Array:
		for item: Variant in injected:
			var node_id := str(item)
			if (
				_node_rows.has(node_id)
				and bool(_node_rows[node_id]["spill_eligible"])
				and _has_reveal_target_for(node_id)
			):
				candidates.append(node_id)
	return candidates


func _pity_streak(domain_id: String) -> int:
	return int(_pity_streak_by_domain.get(domain_id, 0))


func _pity_max_display() -> int:
	if _rng != null:
		return maxi(1, _rng_pity_max)
	return maxi(1, _tree_pity_max)


func _ok(node_id: String, path: String) -> Dictionary:
	return {
		"ok": true,
		"node_id": node_id,
		"path": path,
		"state": _state_key(_fog[node_id]),
	}


func _fail(code: String, reason: String) -> Dictionary:
	return {"ok": false, "code": code, "reason": reason}
