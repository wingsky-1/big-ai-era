class_name Rival
extends RefCounted
## L2 竞对个体（#144；architecture §2.1 rivals/rival.gd + rivals-spec A.1/D.2
## + E6）。职责：
## - **确定性时间线脚本消费**：动作表（论文/发版/涨价/挖人）周次升序表驱动，
##   周推进命中即触发（零博弈 AI——确定性验收红线，rivals-spec A.1）；
## - **分数曲线运行态轨迹**：发版周 score 追加 score_curve + actual_weeks
##   （architecture §9.1 rivals 存档同构：timeline_consumed/score_curve/
##   actual_weeks 入档，表更新不破坏档）；
## - **预警谓词**：黄灯（距动作 4 周）/红灯（2 周零误报）——rivals-spec
##   OP-RIV-01/B.2（红=周结谓词硬校验）；
## - **撞车判定输入**：同周玩家发版+竞对发版=撞车载荷（判定=严格大小走
##   SotaBoard，本类只出叙事标记，rivals-spec OP-RIV-03/rival_collision_rule）；
## - 动作后果（价格战/挖人决策卡）=P1 批（OP-RIV-04/05），本类只发动作载荷。
## 确定性纪律：时间线=静态表；发版 score 扰动=rng.rival（±≤2，rivals-spec
## D.2 rnd_rival_jitter）经注入 callable——扰动不改"严格大于/平局"判定。
## 硬约束：RefCounted 零 Node；每竞对一份实例（RivalPack 容器管理，本类
## 不假设"唯一竞对"）；数值零硬编码（频率/扰动全读表）。

signal rival_action_fired(payload: Dictionary)

## 动作类型稳定字符串（rivals-spec A.1 四类；禁散落字面量）
const ACTION_PAPER: String = "paper"
const ACTION_RELEASE: String = "release"
const ACTION_PRICEWAR: String = "pricewar"
const ACTION_POACH: String = "poach"

## 预警等级（黄灯=4 周/红灯=2 周；rivals-spec OP-RIV-01/B.2）
const WARN_YELLOW_WEEKS: int = 4
const WARN_RED_WEEKS: int = 2

## 撞车/普通动作标记（载荷字段）
const KIND_COLLISION: String = "collision"
const KIND_NORMAL: String = "normal"

## rivals.json 表键（键名真源=rivals-spec D.2；集中本类防散落）
const RIVALS_PATH: String = "res://src/data/rivals.json"
const KEY_ACTORS: String = "rival_actors"
const KEY_JITTER: String = "rival_jitter"
const KEY_PAPER_EFFECT: String = "rival_paper_effect"

## rng.rival 扰动注入（装配方接 RngStream.symmetric_domain("rival", jitter)；
## 未注入=零扰动（确定性测试路径），rivals-spec D.2 扰动 ≤±2 不改判定）
var rival_jitter_fn: Callable = func(_score: float) -> float: return _score

## 时间线动作周次窗口（红灯零误报=动作前 2 周谓词硬校验；周次=表脚本真源）
var _actor_key: String = ""
var _name_key: String = ""
var _timeline: Array[Dictionary] = []
var _cursor: int = 0  # 时间线消费指针（存档 timeline_consumed）
var _score_curve: Array[float] = []  # 发版轨迹分（运行态；存档同构）
var _actual_weeks: Array[int] = []  # 发版实际周（运行态；存档同构）
var _last_action_week: int = 0
var _last_action: String = ""
var _collision_week: int = 0  # 撞车周（叙事标记；0=无）
var _rivals_table: Dictionary = {}


func _init(actor_key: String = "") -> void:
	if actor_key.is_empty():
		return
	_actor_key = actor_key
	_rivals_table = DataLoader.load_json(RIVALS_PATH)
	var actors: Variant = _rivals_table.get(KEY_ACTORS)
	if actors is Dictionary:
		var actor: Variant = (actors as Dictionary).get(actor_key)
		if actor is Dictionary:
			_name_key = str((actor as Dictionary).get("name_key", ""))
			var tl: Variant = (actor as Dictionary).get("timeline", [])
			if tl is Array:
				for entry: Variant in tl as Array:
					if entry is Dictionary:
						_timeline.append((entry as Dictionary).duplicate(true))


## ---------- 周推进（周结 phase 7 竞对推进落点） ----------


## 推进到指定周：命中时间线动作=生成动作载荷（发版分经扰动注入）。
## player_released=玩家本周是否发版（出分模型≥1 且上榜——撞车判定输入，
## 由编排方传入：玩家侧出分周 == 本竞对发版周=撞车，OP-RIV-03）。
## 返回：本周触发动作载荷数组（0..1 个；同周不重复=表结构护栏断言）。
## 载荷={actor_key, action, week, score(仅 release), domain(仅 paper),
##   kind(collision/normal), collision(是否撞车)}。
func advance_week(week: int, player_released: bool = false) -> Array[Dictionary]:
	var fired: Array[Dictionary] = []
	while _cursor < _timeline.size():
		var entry: Dictionary = _timeline[_cursor]
		var entry_week := int(entry["week"])
		if entry_week > week:
			break
		# 时间线消费（含补推进：跳周也消费，周次升序表=确定性）
		_cursor += 1
		var action := str(entry["action"])
		var payload := {
			"actor_key": _actor_key,
			"action": action,
			"week": entry_week,
			"kind": KIND_NORMAL,
		}
		match action:
			ACTION_RELEASE:
				var base_score := float(entry.get("score", 0.0))
				var score: float = rival_jitter_fn.call(base_score)
				payload["score"] = score
				_score_curve.append(score)
				_actual_weeks.append(entry_week)
				if player_released:
					payload["kind"] = KIND_COLLISION
					_collision_week = entry_week
			ACTION_PAPER:
				payload["domain"] = str(entry.get("domain", ""))
			_:
				pass
		_last_action_week = entry_week
		_last_action = action
		fired.append(payload)
		rival_action_fired.emit(payload.duplicate())
	return fired


## ---------- 预警谓词（黄/红灯；周报行消费） ----------


## 当前预警等级：距最近未发生动作 ≤红周=红灯；≤黄周=黄灯；否则无。
## 返回 {level, weeks_left, action, week}：level=0 无/1 黄/2 红（rivals-spec
## B.2：黄=4 周/红=2 周零误报——红=谓词硬校验）。
func warn_state(week: int) -> Dictionary:
	var next := next_action_week(week)
	if next <= 0:
		return {"level": 0, "weeks_left": -1, "action": "", "week": 0}
	var left := next - week
	if left <= WARN_RED_WEEKS:
		return {"level": 2, "weeks_left": left, "action": _action_at_week(next), "week": next}
	if left <= WARN_YELLOW_WEEKS:
		return {"level": 1, "weeks_left": left, "action": _action_at_week(next), "week": next}
	return {"level": 0, "weeks_left": left, "action": _action_at_week(next), "week": next}


## 下一未消费动作周（>当前周；无=0）。周报黄/红行与"威胁时间查得到"同源。
func next_action_week(after_week: int) -> int:
	for i: int in range(_cursor, _timeline.size()):
		var week := int(_timeline[i]["week"])
		if week > after_week:
			return week
	return 0


## ---------- 数据面（只读深拷贝；ADR-0016） ----------


func get_rival_view() -> Dictionary:
	var next_week := next_action_week(_last_action_week)
	return {
		"actor_key": _actor_key,
		"name_key": _name_key,
		"timeline_consumed": _cursor,
		"score_curve": _score_curve.duplicate(),
		"actual_weeks": _actual_weeks.duplicate(),
		"next_action_week": next_week,
		"next_action": _action_at_week(next_week) if next_week > 0 else "",
		"last_action": _last_action,
		"last_action_week": _last_action_week,
		"collision_week": _collision_week,
		"latest_score": _score_curve.back() if not _score_curve.is_empty() else 0.0,
	}


func get_actor_key() -> String:
	return _actor_key


func get_name_key() -> String:
	return _name_key


## 存档视图（architecture §9.1 rivals 行同构；读档重建纯值注入零环）
func get_save_view() -> Dictionary:
	return {
		"actor_key": _actor_key,
		"timeline_consumed": _cursor,
		"score_curve": _score_curve.duplicate(),
		"actual_weeks": _actual_weeks.duplicate(),
		"collision_week": _collision_week,
	}


func restore_from_save(snapshot: Dictionary) -> void:
	_cursor = int(snapshot.get("timeline_consumed", 0))
	_score_curve.clear()
	for v: Variant in snapshot.get("score_curve", []):
		_score_curve.append(float(v))
	_actual_weeks.clear()
	for v: Variant in snapshot.get("actual_weeks", []):
		_actual_weeks.append(int(v))
	_collision_week = int(snapshot.get("collision_week", 0))
	# 重放至已消费指针（last_action 视图一致性）
	_replay_consumed()


## ---------- 私有 ----------


func _action_at_week(week: int) -> String:
	for entry: Dictionary in _timeline:
		if int(entry["week"]) == week:
			return str(entry["action"])
	return ""


## 读档重建后：按消费指针重放 last_action 状态（无副作用：不重发载荷）
func _replay_consumed() -> void:
	_last_action = ""
	_last_action_week = 0
	for i: int in _cursor:
		var entry: Dictionary = _timeline[i]
		_last_action = str(entry["action"])
		_last_action_week = int(entry["week"])
