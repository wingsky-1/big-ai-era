class_name RivalTrack
extends RefCounted

## 竞对深巷科技时间线系统（L2 RefCounted，DR-014 / DR-023 / DR-027④）：
## - 8 动作时间线（2 论文 + 4 发版 + 2 涨价）
## - ±15% 扰动（RNG 域 rival_jitter，仅周结消费）
## - 外溢翻态零 RNG（表序首个 hidden 节点或指定 target_tech）
## - 逼近预警：黄灯 ⌈0.15t⌉ 周（6/9/11/13），红灯 2 周零误报

signal rival_warned(level: String, action_id: String, weeks_left: int)
signal rival_launched(model: String, score: float)
signal rival_spill_triggered(tech_id: String, state: String)

const WARN_NONE: String = "none"
const WARN_YELLOW: String = "yellow"
const WARN_RED: String = "red"

var _config: Dictionary = {}
var _timeline: Array = []
var _action_actual_weeks: Dictionary = {}
var _cursor: int = 0
var _jitter_pct: float = 0.15


func setup(config: Dictionary, rng: RngStream) -> void:
	_config = config.duplicate(true)
	_timeline = _config.get("timeline", []).duplicate(true)
	_jitter_pct = float(_config.get("jitter_pct", 0.15))
	_cursor = 0
	_action_actual_weeks.clear()

	# 初始化每个动作的实际触发周（±15% 扰动由 RNG 域 rival_jitter 确定性计算）
	for action_variant: Variant in _timeline:
		if action_variant is Dictionary:
			var act: Dictionary = action_variant
			var base_week: int = int(act.get("week", 0))
			var act_id: String = str(act.get("id", ""))
			# 针对发版动作进行 ±15% 扰动计算
			if str(act.get("type", "")) == "launch":
				var rand_f: float = 0.5
				if rng != null:
					rand_f = rng.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
				# 映射到 [-jitter, +jitter]
				var offset_pct: float = (rand_f * 2.0 - 1.0) * _jitter_pct
				var actual_week: int = maxi(1, int(round(float(base_week) * (1.0 + offset_pct))))
				_action_actual_weeks[act_id] = actual_week
			else:
				_action_actual_weeks[act_id] = base_week


func get_cursor() -> int:
	return _cursor


func get_action_week(action_id: String) -> int:
	return int(_action_actual_weeks.get(action_id, 0))


## 周结推进判定（管线第 6 步）
func settle_week(current_week: int, fog: TechFog) -> Array[Dictionary]:
	var triggered_actions: Array[Dictionary] = []

	# 1. 检查逼近预警（对尚未发生的发版动作）
	_evaluate_warnings(current_week)

	# 2. 检查当前周触发的动作
	while _cursor < _timeline.size():
		var act: Dictionary = _timeline[_cursor]
		var act_id: String = str(act.get("id", ""))
		var actual_week: int = int(_action_actual_weeks.get(act_id, act.get("week", 0)))

		if current_week >= actual_week:
			_cursor += 1
			triggered_actions.append(act)
			_execute_action(act, fog)
		else:
			break

	return triggered_actions


func _evaluate_warnings(current_week: int) -> void:
	for idx: int in range(_cursor, _timeline.size()):
		var act: Dictionary = _timeline[idx]
		if str(act.get("type", "")) != "launch":
			continue

		var act_id: String = str(act.get("id", ""))
		var actual_week: int = int(_action_actual_weeks.get(act_id, act.get("week", 0)))
		var weeks_left: int = actual_week - current_week

		if weeks_left <= 0:
			continue

		# 红灯判定：2 周零误报（剩余 1~2 周）
		if weeks_left <= 2:
			rival_warned.emit(WARN_RED, act_id, weeks_left)
		else:
			# 黄灯判定：提前 ⌈0.15 * nominal_week⌉ 周（配置中带 warn_weeks，如 6/9/11/13）
			var warn_limit: int = int(
				act.get("warn_weeks", int(ceil(float(act.get("week", 0)) * 0.15)))
			)
			if weeks_left <= warn_limit:
				rival_warned.emit(WARN_YELLOW, act_id, weeks_left)


func _execute_action(act: Dictionary, fog: TechFog) -> void:
	var act_type: String = str(act.get("type", ""))
	match act_type:
		"paper":
			var target_tech: String = str(act.get("target_tech", ""))
			var target_state: String = str(act.get("target_state", TechFog.STATE_VISIBLE))
			if fog != null and target_tech != "":
				fog.spill_reveal(target_tech, target_state)
				rival_spill_triggered.emit(target_tech, target_state)
		"launch":
			var model: String = str(act.get("model", "深巷模型"))
			var score: float = float(act.get("score", 0.0))
			rival_launched.emit(model, score)
		"price_hike":
			pass


func to_snapshot() -> Dictionary:
	return {
		"cursor": _cursor,
	}


func to_save() -> Dictionary:
	return {
		"cursor": _cursor,
		"jitter_state": 0,
		"action_actual_weeks": _action_actual_weeks.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	_cursor = int(data.get("cursor", 0))
	if data.has("action_actual_weeks"):
		_action_actual_weeks = data.get("action_actual_weeks", {}).duplicate(true)
