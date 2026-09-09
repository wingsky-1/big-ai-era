class_name ModelCeremony
extends RefCounted
## L2 模型出分仪式编排（#143；models-spec OP-MDL-03 + onboarding OP-ONB-05 +
## architecture §4.3/§5.3 phase 2 落点）。职责：
## - **出分结算收口**：周结 phase 2 训练完成 → 出分（score/ndim/峰值）→
##   SOTA 判定（提交 SotaBoard 唯一权威）→ 入模型库；
## - **命名待办流**：submit_name（NameFilter 三层校验）/skip_naming（默认
##   名池确定性轮转）→ 定名入册；被拒 → 返回原因（弹层不关闭可重输）；
## - **首次出分=署名仪式**（首模型强制命名：无 skip 路径，见 submit/skip 分派）；
## - **峰值记录**：入册即峰值（P2 迭代前单模型一峰）；库 get_highest_peak 聚合；
## - 模型完成槽释放（架构 §5.3：出分仪式在周结内即时消费完成槽——训练
##   完成不回 EMPTY 则 4 槽死局；本类经注入 release_slot 回调释放）。
## 装配（注入防环）：library/sota_board/board 由装配方注入（GameWorld 批）；
## 纯 RefCounted 零 Node；数值零硬编码（出分=表驱动合成调用方提供）。
## 出分计算不在本类发明：score/ndim 由装配方（或 #143 后出分生产批）传入
## settle_finished 载荷——本类只做仪式状态流，防跨层。

signal ceremony_state_changed(payload: Dictionary)

## 仪式状态稳定字符串（L3 命名框数据面；禁散落字面量）
const STATE_IDLE: String = "idle"
const STATE_PENDING_NAMING: String = "pending_naming"

## 定名来源稳定键（skip 载荷标记；防歧义）
const SOURCE_NAMED: String = "named"
const SOURCE_POOL: String = "pool"

## 表路径与键名（默认名池文案键真源=texts-keys.md model_default_name_pool_*；
## 顺序遍历 _01.._NN，跳过缺失键——池=开放可续）
const TEXTS_PATH: String = "res://src/data/texts.json"
const POOL_KEY_PREFIX: String = "model_default_name_pool_"

## models.json 表路径与维序键（ndim 数组化入档真源；静态缓存防重复 IO）
const MODELS_PATH: String = "res://src/data/models.json"
const KEY_NDIM_SET: String = "model_ndim_set"

static var _dim_set: Array[String] = []  # 模型维序缓存（防周结多模型重复 IO）

## 完成槽释放回调注入（装配方接 TaskBoard.release_finished_slot；定名后调，
## 模型完成槽回 EMPTY——settlement 批不接时测试/装配方也可注入桩）
var release_slot: Callable = func(_slot: int) -> void: pass

var _library: Object = null  # ModelLibrary（注入防环）
var _sota_board: Object = null  # SotaBoard（注入防环）
var _pending: Array[Dictionary] = []  # 待定名队列（同周多模型串行）
var _state: String = STATE_IDLE
var _pool_index: int = 0  # 默认名池轮转游标（确定性：跳过=取下个名）
var _pool_names: Array[String] = []


func _init(
	library: Object = null,
	sota_board: Object = null,
) -> void:
	_library = library
	_sota_board = sota_board
	_refresh_pool_names()


## ---------- 出分仪式主入口（周结 phase 2 调用） ----------


## 训练完成结算：计算定名前的出分仪式态（score/ndim 由调用方传入=出分生产
## 批的合成结果；本方法只编排仪式状态机）。
## 参数：payload={project: ModelProject, score: float, ndim: Dictionary,
##   week: int, slot_index: int}——week=出分周（入册时间戳）；
##   slot_index=完成槽号（定名后释放该槽，防 4 槽死局）。
## ndim={dim_key: value}（5 维字典；0 缺维=防御按 0 补）。
## 流程：入待定名队列 → state=PENDING_NAMING → 返回状态载荷
## （首次出分 pending=强制命名；后续 pending=可跳过）。
func settle_finished(payload: Dictionary) -> Dictionary:
	var project: Object = payload.get("project")
	if project == null:
		push_error("ModelCeremony.settle_finished: 缺 project")
		return {"ok": false, "state": _state}
	if not (project as ModelProject).is_finished_pending():
		push_error("ModelCeremony.settle_finished: 项目非 FINISHED_PENDING")
		return {"ok": false, "state": _state}
	var item := {
		"project": project,
		"score": float(payload.get("score", 0.0)),
		"ndim": (payload.get("ndim", {}) as Dictionary).duplicate(true),
		"week": int(payload.get("week", 0)),
		"slot_index": int(payload.get("slot_index", -1)),
		"first": count_archived() == 0,  # 首模型=署名仪式（强制命名）
	}
	_pending.append(item)
	_state = STATE_PENDING_NAMING
	var view := _state_view()
	ceremony_state_changed.emit(view.duplicate())
	return {"ok": true, "state": _state, "pending": view}


## ---------- 命名命令（L3 命名框消费） ----------


## 玩家确认命名：NameFilter 三层校验 → 通过=定名入册+SOTA 判定+释放槽；
## 被拒=返回拒绝原因（弹层不关闭可重输；状态保持 PENDING_NAMING）。
## name=玩家输入原名（trim 后校验）。返回 {ok, reason, entry}：
## - ok=false：reason=NameFilter 拒绝层（whitelist/blocklist/homophone/
##   too_long/empty），消费方提示 name_filter_reason 并保持弹层；
## - ok=true：入册完成，entry=模型库条目（含 model_id/peak）。
func submit_name(name: String) -> Dictionary:
	if _pending.is_empty():
		return {"ok": false, "reason": "no_pending"}
	var check := NameFilter.check(name)
	if not check.ok:
		return {"ok": false, "reason": check.reason}
	return _finalize(str(check.clean), SOURCE_NAMED)


## 跳过命名（"交给命运"）：默认名池确定性轮转取名下个名。**首模型无跳过
## 路径**（署名仪式强制——返回 no_pending 同形拒绝，L3 据此隐藏跳过键）。
func skip_naming() -> Dictionary:
	if _pending.is_empty():
		return {"ok": false, "reason": "no_pending"}
	var item: Dictionary = _pending[0]
	if bool(item.get("first", false)):
		return {"ok": false, "reason": "first_mandatory"}
	var name := _next_pool_name()
	if name.is_empty():
		push_error("ModelCeremony.skip_naming: 默认名池为空")
		return {"ok": false, "reason": "no_pool_name"}
	return _finalize(name, SOURCE_POOL)


## 当前待定名队列是否空（L3 命名框可见性谓词：pending 非空=显示）
func has_pending() -> bool:
	return not _pending.is_empty()


## 当前待定名视图（命名框数据面：项目名/基座/出分/首模型标）
func peek_pending() -> Dictionary:
	if _pending.is_empty():
		return {}
	return _pending[0].duplicate(true)


## ---------- 数据面（只读） ----------


func get_state() -> String:
	return _state


## 默认名池轮转游标（读档重建后注入续轮；确定性语义）
func get_pool_index() -> int:
	return _pool_index


func restore_pool_index(index: int) -> void:
	_pool_index = maxi(0, index)


## ---------- 私有 ----------


## 定名入册收口（命名/skip 共用）：入 ModelLibrary → SOTA 判定 → 释放槽 →
## 弹队首 → 队列空=回 IDLE。返回 {ok, entry, broke_record, record_score}。
func _finalize(name: String, source: String) -> Dictionary:
	var item: Dictionary = _pending[0]
	var project: Object = item["project"]
	var entry := {}
	if _library != null:
		entry = (
			_library
			. add_model(
				name,
				(project as ModelProject).get_base_id(),
				_dict_to_dim_array(item["ndim"]),
				float(item["score"]),
				int(item["week"]),
			)
		)
	var broke := false
	var record_score := 0.0
	if _sota_board != null and not entry.is_empty():
		var submit: Dictionary = _sota_board.submit_player_score(
			float(item["score"]), int(item["week"])
		)
		broke = bool(submit.get("broke_record", false))
		record_score = float(submit.get("record_score", 0.0))
	# 释放完成槽（注入回调：装配方接 TaskBoard.release_finished_slot）
	var slot := int(item["slot_index"])
	if slot >= 0:
		release_slot.call(slot)
	_pending.pop_front()
	if _pending.is_empty():
		_state = STATE_IDLE
	var payload := {
		"ok": true,
		"entry": entry.duplicate(true) if not entry.is_empty() else {},
		"source": source,
		"broke_record": broke,
		"record_score": record_score,
		"name": name,
	}
	ceremony_state_changed.emit(payload.duplicate())
	return payload


## ndim 字典 → 模型维序数组（真源=model_ndim_set；缺维=按 0 补，
## 数组化字段入档=architecture §9.1 ndim=[…]；维序静态缓存防重复 IO）
func _dict_to_dim_array(ndim: Dictionary) -> Array:
	if _dim_set.is_empty():
		var table := DataLoader.load_json(MODELS_PATH)
		var set_v: Variant = table.get(KEY_NDIM_SET, [])
		if set_v is Array:
			for dim: Variant in set_v as Array:
				_dim_set.append(str(dim))
	var out: Array = []
	if _dim_set.is_empty():
		for dim: Variant in ndim.keys():
			out.append(float(ndim[dim]))
		return out
	for dim: String in _dim_set:
		out.append(float(ndim.get(dim, 0.0)))
	return out


## 默认名池下一名（确定性轮转：游标递增取模；池名=texts.json 池键遍历）
func _next_pool_name() -> String:
	_refresh_pool_names()
	if _pool_names.is_empty():
		return ""
	var name := _pool_names[_pool_index % _pool_names.size()]
	_pool_index = (_pool_index + 1) % _pool_names.size()
	return name


## 装载默认名池（texts.json model_default_name_pool_01..；遍历到断号停）
func _refresh_pool_names() -> void:
	if not _pool_names.is_empty():
		return
	var table := DataLoader.load_json(TEXTS_PATH)
	var i := 1
	while true:
		var key := POOL_KEY_PREFIX + "%02d" % i
		if not table.has(key):
			break
		_pool_names.append(str(table[key]))
		i += 1


func count_archived() -> int:
	if _library == null:
		return 0
	return _library.count()


## 当前仪式状态视图（L3/测试）
func _state_view() -> Dictionary:
	if _pending.is_empty():
		return {"state": _state, "pending": false}
	var item: Dictionary = _pending[0]
	var project: Object = item.get("project", null)
	return {
		"state": _state,
		"pending": true,
		"first": bool(item.get("first", false)),
		"score": float(item.get("score", 0.0)),
		"ndim": (item.get("ndim", {}) as Dictionary).duplicate(true),
		"base_id": (project as ModelProject).get_base_id() if project != null else "",
		"slot_index": int(item.get("slot_index", -1)),
	}
