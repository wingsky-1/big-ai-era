class_name SotaBoard
extends RefCounted

## SOTA 榜单系统（L2 RefCounted，DR-005 / DR-027）：
## - 裁决逻辑：严格大于刷新霸主（new_score > best_score）；平局归霸主（<= 拒绝）。
## - 预埋 sota.by_key 复合键容器支持（演进矩阵归零项）。

signal sota_record_broken(model_name: String, new_score: float, old_score: float)

const OPENING_PATH: String = "res://src/data/opening.json"

var _best_score: float = 0.0
var _best_model: String = ""
var _rival_best: float = 0.0
var _by_key: Dictionary = {}


## 注入开局数据（rival_baseline 真源=opening.json）；benchmarks 参数保留签名兼容，
## 出分参数改由 GameWorld 注入 TrainingProject，不再作基线兜底（消除双真源）。
func setup(opening_data: Dictionary, _benchmarks_data: Dictionary = {}) -> void:
	var rival_best_variant: Variant = DataLoader.require_key(
		opening_data, "rival_best", OPENING_PATH
	)
	var model_name_variant: Variant = DataLoader.require_key(
		opening_data, "rival_model_name", OPENING_PATH
	)
	if rival_best_variant != null:
		_rival_best = float(rival_best_variant)
	_best_score = _rival_best
	if model_name_variant != null:
		_best_model = str(model_name_variant)
	_by_key = {}


func get_best_score() -> float:
	return _best_score


func get_best_model() -> String:
	return _best_model


func get_rival_best() -> float:
	return _rival_best


func get_by_key() -> Dictionary:
	return _by_key.duplicate(true)


## 提交新出分，判定是否刷新 SOTA 纪录（严格大于，平局归霸主）
func submit_score(model: String, score: float, key: String = "overall") -> bool:
	# 记录到 by_key 容器
	if not _by_key.has(key) or score > float(_by_key[key].get("score", 0.0)):
		_by_key[key] = {"model": model, "score": score}

	# 主榜判定：严格大于
	if score > _best_score:
		var old: float = _best_score
		_best_score = score
		_best_model = model
		sota_record_broken.emit(model, score, old)
		return true

	return false


func to_snapshot() -> Dictionary:
	return {
		"best": _best_score,
		"best_model": _best_model,
		"rival_best": _rival_best,
		"by_key": _by_key.duplicate(true),
	}


func to_save() -> Dictionary:
	return {
		"best": _best_score,
		"rival_best": _rival_best,
		"by_key": _by_key.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	_best_score = float(data.get("best", 0.0))
	_rival_best = float(data.get("rival_best", 0.0))
	_by_key = data.get("by_key", {}).duplicate(true)
