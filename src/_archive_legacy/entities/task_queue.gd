class_name TaskQueue
extends RefCounted

## 任务队列管理（L2 纯逻辑，无 Node 依赖）
##
## 管理任务入队、排队与执行推进：
## - FIFO 待办队列（存储 task_id）
## - 入队校验：enabled、cost、unlock predicate（DR-021 M4 / DR-023）
## - **去重**：同一 task_id 在「进行中或已排队」时拒绝重复入队（issue #104 P0：
##   此前无去重 + `GameWorld.enqueue_task` 每次点击先扣 cost → 连点 N 次 = N 倍收入）
## - **资金门只对成本 > 0 的任务生效**（issue #101：资金转负后零成本任务仍可接，防死亡螺旋）
## - 自动激活与顶入队首（Auto-fill，DR-009 / ST5）
## - 周结推进与刻级推进

## 入队拒绝原因（封闭集合；L2 出数、L3 只透传文案，ADR-0016 R3）。
const REASON_NONE: String = ""
const REASON_DISABLED: String = "disabled_or_not_found"
const REASON_INSUFFICIENT_FUNDS: String = "insufficient_funds"
const REASON_PREDICATE_NOT_MET: String = "predicate_not_met"
const REASON_NEVER_UNLOCKED: String = "never_unlocked"
const REASON_ALREADY_ACTIVE: String = "already_active_or_queued"

var _config: Dictionary = {}
var _active_task: Dictionary = {}
var _queue: Array[String] = []


## 注入配置字典（源自 tasks.json）
func setup(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_active_task = {}
	_queue.clear()


## 入队校验（DR-021 M4 / DR-023 + #101 资金门 + #104 去重）
func can_enqueue(task_id: String, context: Dictionary) -> Dictionary:
	if not _config.has(task_id):
		return {"ok": false, "reason": REASON_DISABLED}

	var task_cfg: Dictionary = _config.get(task_id, {})
	if not bool(task_cfg.get("enabled", false)):
		return {"ok": false, "reason": REASON_DISABLED}

	# 去重（#104 P0）：进行中或已排队即拒绝，防"连点刷单"。
	if str(_active_task.get("task_id", "")) == task_id or _queue.has(task_id):
		return {"ok": false, "reason": REASON_ALREADY_ACTIVE}

	var cost: int = int(task_cfg.get("cost", 0))
	var current_money: int = int(context.get("money", 0))
	# 资金门只对 cost > 0 生效（#101）：零成本任务不因资金转负被拒（防死亡螺旋）。
	if cost > 0 and current_money < cost:
		return {"ok": false, "reason": REASON_INSUFFICIENT_FUNDS}

	return _check_unlock(task_cfg.get("unlock", {}), context)


## 入队：校验通过后入队，若当前无任务则直接激活
func enqueue(task_id: String, context: Dictionary) -> bool:
	var check: Dictionary = can_enqueue(task_id, context)
	if not bool(check.get("ok", false)):
		return false

	if _is_active_task_empty():
		_activate_task(task_id)
	else:
		_queue.append(task_id)
	return true


## 刻级累积推进
func advance_tick(ticks: int = 1) -> void:
	if _is_active_task_empty() or ticks <= 0:
		return
	var accumulated: int = int(_active_task.get("ticks_accumulated", 0))
	_active_task["ticks_accumulated"] = accumulated + ticks


## 周结推进
func settle_week() -> Dictionary:
	if _is_active_task_empty():
		return {"completed": false, "task_id": ""}

	var weeks_left: int = int(_active_task.get("weeks_left", 0)) - 1
	_active_task["weeks_left"] = weeks_left

	if weeks_left <= 0:
		return _finish_active_task()

	return {
		"completed": false,
		"task_id": str(_active_task.get("task_id", "")),
		"weeks_left": weeks_left,
	}


## 查询当前正在进行的任务
func get_active_task() -> Dictionary:
	return _active_task.duplicate(true)


## 查询排队中的任务队列
func get_queue() -> Array[String]:
	return _queue.duplicate()


## UI 渲染与运行态快照
func to_snapshot() -> Dictionary:
	return {
		"queue": _queue.duplicate(),
		"active": _active_task.duplicate(true),
	}


## 存档数据持久化
func to_save() -> Dictionary:
	return {
		"queue": _queue.duplicate(),
		"active": _active_task.duplicate(true),
	}


## 从快照/存档数据恢复状态
func restore(data: Dictionary) -> void:
	_queue.clear()
	var raw_queue: Array = data.get("queue", [])
	for item: Variant in raw_queue:
		_queue.append(str(item))

	var raw_active: Variant = data.get("active", {})
	if raw_active is Dictionary and not (raw_active as Dictionary).is_empty():
		_active_task = (raw_active as Dictionary).duplicate(true)
	else:
		_active_task = {}


func _check_unlock(unlock: Dictionary, context: Dictionary) -> Dictionary:
	var predicate: String = str(unlock.get("predicate", "none"))
	var params: Dictionary = unlock.get("params", {})
	var current_money: int = int(context.get("money", 0))
	var ok: bool = false
	var reason: String = REASON_PREDICATE_NOT_MET

	match predicate:
		"none":
			ok = true
			reason = REASON_NONE
		"min_money":
			var required_amount: int = int(params.get("amount", 0))
			if current_money >= required_amount:
				ok = true
				reason = REASON_NONE
		"tech_lit":
			var required_tech: String = str(params.get("tech_id", ""))
			var lit_techs: Array = context.get("lit_techs", [])
			if lit_techs.has(required_tech):
				ok = true
				reason = REASON_NONE
		"never":
			reason = REASON_NEVER_UNLOCKED

	return {"ok": ok, "reason": reason}


## 任务板行（#104：L2 只出数，不出文案；文案由 GameWorld 依 ui_display 拼装）。
## 返回**全部 enabled 任务**（含当前不可接者与原因），按数据表键序稳定。
func get_task_rows(context: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for task_id: String in _config:
		var cfg: Dictionary = _config[task_id]
		if not bool(cfg.get("enabled", false)):
			continue
		var check: Dictionary = can_enqueue(task_id, context)
		(
			rows
			. append(
				{
					"task_id": task_id,
					"name": str(cfg.get("name", task_id)),
					"duration_weeks": int(cfg.get("duration_weeks", 0)),
					"income": int(cfg.get("income", 0)),
					"rp_output": int(cfg.get("rp_output", 0)),
					"cost": int(cfg.get("cost", 0)),
					"ok": bool(check.get("ok", false)),
					"reason": str(check.get("reason", "")),
					"active": str(_active_task.get("task_id", "")) == task_id,
					"queued": _queue.has(task_id),
				}
			)
		)
	return rows


## 任务显示名（数据表 name 真源；缺键退化为 id，数据契约由 test_tasks_data 门禁保证）。
func get_task_name(task_id: String) -> String:
	var cfg: Dictionary = _config.get(task_id, {})
	return str(cfg.get("name", task_id))


## 进行中任务进度（0…1，周粒度；L2 出数，L3 只显示）。
func get_active_progress() -> float:
	if _is_active_task_empty():
		return 0.0
	var duration: int = int(_active_task.get("duration_weeks", 0))
	if duration <= 0:
		return 0.0
	var weeks_left: int = int(_active_task.get("weeks_left", 0))
	return clampf(float(duration - weeks_left) / float(duration), 0.0, 1.0)


func _is_active_task_empty() -> bool:
	return _active_task.is_empty() or str(_active_task.get("task_id", "")) == ""


func _activate_task(task_id: String) -> void:
	var task_cfg: Dictionary = _config.get(task_id, {})
	var duration: int = int(task_cfg.get("duration_weeks", 1))
	_active_task = {
		"task_id": task_id,
		"weeks_left": duration,
		"duration_weeks": duration,
		"ticks_accumulated": 0,
	}


func _finish_active_task() -> Dictionary:
	var finished_id: String = str(_active_task.get("task_id", ""))
	var task_cfg: Dictionary = _config.get(finished_id, {})
	var rp: int = int(task_cfg.get("rp_output", 0))
	var income: int = int(task_cfg.get("income", 0))
	var task_type: String = str(task_cfg.get("type", ""))

	var report: Dictionary = {
		"completed": true,
		"task_id": finished_id,
		"rp_output": rp,
		"income": income,
		"type": task_type,
	}

	_active_task = {}
	if not _queue.is_empty():
		var next_id: String = _queue.pop_front()
		_activate_task(next_id)

	return report
