class_name Stages
extends RefCounted

## 阶段系统（L2 RefCounted，DR-006 阶段软门，DR-021 B4）：
## - 晋升判定仅周结点执行（管线第 10 步）。
## - 单步跃迁原则：每次晋升最多提升 1 级。
## - 阶段经济修正挂钩 stage_depr。

signal stage_advanced(old_stage: int, new_stage: int, economy_mod: Dictionary)

var _current_stage: int = 0
var _stages: Dictionary = {}


func setup(config: Dictionary) -> void:
	_stages = config.get("stages", {}).duplicate(true)
	_current_stage = 0


func get_current_stage() -> int:
	return _current_stage


func get_current_stage_data() -> Dictionary:
	var key: String = "stage_%d" % _current_stage
	return _stages.get(key, {})


## 周结点重评阶段软门晋升
func reevaluate(context: Dictionary) -> Dictionary:
	var next_stage_num: int = _current_stage + 1
	var next_key: String = "stage_%d" % next_stage_num

	# 检查下一阶段是否存在且已启用
	if not _stages.has(next_key):
		return {"advanced": false, "old_stage": _current_stage, "new_stage": _current_stage}

	var next_data: Dictionary = _stages[next_key]
	if not bool(next_data.get("enabled", false)):
		return {"advanced": false, "old_stage": _current_stage, "new_stage": _current_stage}

	# 判定 gate 全部谓词（隐式 AND）
	var gate: Array = next_data.get("gate", [])
	for spec: Variant in gate:
		if spec is Dictionary and not PredicateRegistry.evaluate(spec, context):
			return {"advanced": false, "old_stage": _current_stage, "new_stage": _current_stage}

	# 满足条件，单步跃迁
	var old: int = _current_stage
	_current_stage = next_stage_num
	var economy_mod: Dictionary = next_data.get("economy_mod", {})
	stage_advanced.emit(old, _current_stage, economy_mod)
	return {
		"advanced": true,
		"old_stage": old,
		"new_stage": _current_stage,
		"economy_mod": economy_mod.duplicate(true),
		"name": str(next_data.get("name", "")),
	}


func to_snapshot() -> Dictionary:
	return {
		"current": _current_stage,
		"name": str(get_current_stage_data().get("name", "")),
	}


func to_save() -> Dictionary:
	return {
		"current": _current_stage,
	}


func restore(data: Dictionary) -> void:
	_current_stage = int(data.get("current", 0))
