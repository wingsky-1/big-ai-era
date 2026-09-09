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

const RIVALS_PATH: String = "res://src/data/rivals.json"

var _config: Dictionary = {}
var _timeline: Array = []
var _action_actual_weeks: Dictionary = {}
var _cursor: int = 0
var _jitter_pct: float = 0.0
var _jitter_span: float = 0.0
var _warn_red_weeks: int = 0
var _warn_yellow_factor: float = 0.0


## consume_rng=false：读档恢复路径专用——不重抽 jitter，避免 RNG 序列漂移（D3）。
func setup(config: Dictionary, rng: RngStream, consume_rng: bool = true) -> void:
	_config = config.duplicate(true)
	_timeline = _config.get("timeline", []).duplicate(true)
	var jitter_variant: Variant = DataLoader.require_key(_config, "jitter_pct", RIVALS_PATH)
	var span_variant: Variant = DataLoader.require_key(_config, "jitter_span", RIVALS_PATH)
	var red_variant: Variant = DataLoader.require_key(_config, "warn_red_weeks", RIVALS_PATH)
	var yellow_variant: Variant = DataLoader.require_key(_config, "warn_yellow_factor", RIVALS_PATH)
	if (
		jitter_variant == null
		or span_variant == null
		or red_variant == null
		or yellow_variant == null
	):
		return
	_jitter_pct = float(jitter_variant)
	_jitter_span = float(span_variant)
	_warn_red_weeks = int(red_variant)
	_warn_yellow_factor = float(yellow_variant)
	_cursor = 0
	_action_actual_weeks.clear()

	# 初始化每个动作的实际触发周（±jitter 扰动由 RNG 域 rival_jitter 确定性计算）
	for action_variant: Variant in _timeline:
		if action_variant is Dictionary:
			var act: Dictionary = action_variant
			var base_week: int = int(act.get("week", 0))
			var act_id: String = str(act.get("id", ""))
			# 针对发版动作进行 ±jitter 扰动计算
			if str(act.get("type", "")) == "launch":
				# 无 RNG 源时不做扰动（offset=0），保持与注入源一致的中性行为
				var offset_pct: float = 0.0
				if consume_rng and rng != null:
					var rand_f: float = rng.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
					# 映射到 [-jitter, +jitter]
					offset_pct = (rand_f * _jitter_span - 1.0) * _jitter_pct
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

		# 红灯判定：warn_red_weeks 周零误报（数据键，DR-027④）
		if weeks_left <= _warn_red_weeks:
			rival_warned.emit(WARN_RED, act_id, weeks_left)
		else:
			# 黄灯判定：提前 ⌈warn_yellow_factor × nominal_week⌉ 周（配置中带 warn_weeks）
			var warn_limit: int = int(
				act.get("warn_weeks", int(ceil(float(act.get("week", 0)) * _warn_yellow_factor)))
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
