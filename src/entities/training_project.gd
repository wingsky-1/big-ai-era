class_name TrainingProject
extends RefCounted

## 训练项目管理（L2 RefCounted，DR-001 / DR-005）：
## - 管理单训练位的启动、推进与出分。
## - research_eff == 0 时拒绝启动训练！

signal training_started(base_id: String, weeks: int)
signal training_completed(result: Dictionary)

var _bases_cfg: Dictionary = {}
var _active_training: Dictionary = {}


func setup(bases_config: Dictionary) -> void:
	_bases_cfg = bases_config.duplicate(true)
	_active_training = {}


func is_training() -> bool:
	return not _active_training.is_empty()


func get_active_training() -> Dictionary:
	return _active_training.duplicate(true)


## 预检是否满足训练启动条件
func can_start_training(base_id: String, context: Dictionary) -> Dictionary:
	if not _bases_cfg.has(base_id):
		return {"ok": false, "reason": "invalid_base"}
	if is_training():
		return {"ok": false, "reason": "already_training"}
	if int(context.get("research_eff", 0)) <= 0:
		return {"ok": false, "reason": "zero_research_eff"}
	var base_data: Dictionary = _bases_cfg[base_id]
	if int(context.get("compute_tier", 1)) < int(base_data.get("min_tier", 1)):
		return {"ok": false, "reason": "insufficient_compute_tier"}
	if int(context.get("money", 0)) < int(base_data.get("cost", 0)):
		return {"ok": false, "reason": "insufficient_money"}
	return {"ok": true, "reason": ""}


## 启动训练检查与执行
func start_training(base_id: String, context: Dictionary) -> Dictionary:
	var check := can_start_training(base_id, context)
	if not check.get("ok", false):
		return check

	var base_data: Dictionary = _bases_cfg[base_id]
	var cost: int = int(base_data.get("cost", 0))
	var economy: Economy = context.get("economy")
	if economy != null and not economy.apply_delta("money", -cost, "training_cost"):
		return {"ok": false, "reason": "deduct_failed"}

	var train_weeks: int = int(base_data.get("train_weeks", 10))
	_active_training = {
		"base_id": base_id,
		"weeks_left": train_weeks,
		"total_weeks": train_weeks,
		"quality": float(base_data.get("quality", 0.55)),
	}

	training_started.emit(base_id, train_weeks)
	return {"ok": true, "base_id": base_id, "weeks": train_weeks}


## 周结推进与出分（管线第 4 步）
func settle_week(research_eff: int, tech_bonus: float, compute_tier: int) -> Dictionary:
	if not is_training():
		return {"completed": false}

	_active_training["weeks_left"] = int(_active_training["weeks_left"]) - 1
	if int(_active_training["weeks_left"]) <= 0:
		var base_id: String = str(_active_training["base_id"])
		var quality: float = float(_active_training["quality"])
		var ability: float = ScoreMath.calculate_ability(
			research_eff, tech_bonus, compute_tier, quality
		)
		var score: float = ScoreMath.calculate_score(ability)
		var result: Dictionary = {
			"completed": true,
			"base_id": base_id,
			"ability": ability,
			"score": score,
		}
		_active_training.clear()
		training_completed.emit(result)
		return result

	return {
		"completed": false,
		"base_id": str(_active_training["base_id"]),
		"weeks_left": int(_active_training["weeks_left"]),
	}


func to_snapshot() -> Dictionary:
	if not is_training():
		return {"base_id": "", "weeks_left": 0}
	return {
		"base_id": str(_active_training.get("base_id", "")),
		"weeks_left": int(_active_training.get("weeks_left", 0)),
	}


func to_save() -> Dictionary:
	if not is_training():
		return {"base": "", "weeks_left": 0}
	return {
		"base": str(_active_training.get("base_id", "")),
		"weeks_left": int(_active_training.get("weeks_left", 0)),
	}


func restore(data: Dictionary) -> void:
	var base_id: String = str(data.get("base", data.get("base_id", "")))
	var weeks_left: int = int(data.get("weeks_left", 0))
	if base_id != "" and weeks_left > 0 and _bases_cfg.has(base_id):
		_active_training = {
			"base_id": base_id,
			"weeks_left": weeks_left,
			"total_weeks": int(_bases_cfg[base_id].get("train_weeks", weeks_left)),
			"quality": float(_bases_cfg[base_id].get("quality", 0.55)),
		}
	else:
		_active_training.clear()
