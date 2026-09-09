class_name SaveMigrator
extends RefCounted

## 存档升轨迁移链：把任意历史版本的存档字典逐级升到 CURRENT_VERSION。
## 纯字典操作、纯静态函数，可无头单测；文件 IO 一律在 [class SaveSystem]。
##
## 约定（DR-008 / DR-021 B2）：
## - schema v1 为机制壳重置基线：字段集=架构稿 v1.1 §C 全量表（壳默认值），
##   业务字段集冻结在 PR5R（issue #11）执行，本表先落壳不冻结。
## - 缺 schema_version 的存档视为 v0（前 schema 时代旧档），走 0→1 迁移。
## - 每个迁移步骤只做「上一版 -> 当前版」的最小变更，禁止跳步合并。
## - 开放容器（rng/flags）新键=加键零迁移：补缺不覆盖，已有键原样保留。
## - 遇到比当前更新 schema 的存档（来自更新的游戏版本）返回空字典，
##   由调用方拒绝写入，防止用旧版本逻辑覆盖新版本存档造成坏档。

const CURRENT_VERSION: int = 1

## schema v1 机制壳全量字段（v1.1 §C + PR5R 冻结包硬 deadline）：
## 包含 tutorial{step,done}、cum_income（经营性口径）、staff.condition 预埋、
## sota.by_key 预埋、flags 开放容器。
const V1_SHELL: Dictionary = {
	"week": 0,
	"cum_income": 0,
	"resources":
	{
		"money": 0,
		"compute": {"tier": 0, "hours_remaining": 0.0},
		"influence": 0,
	},
	"rng": {},
	"techs": {"lit": [], "fog_visibility": {}, "crossover_progress": 0, "pity": 0},
	"tasks": {"queue": [], "active": {"task_id": "", "weeks_left": 0}},
	"staff": {"assigned": {}, "condition": []},
	"training": {"base": "", "weeks_left": 0},
	"rivals": {"cursor": 0, "jitter_state": 0},
	"events": {"fired": [], "cooldowns": {}, "pending": [], "effects_pending": []},
	"player_model_names": [],
	"stages": {"current": 0},
	"sota": {"best": 0.0, "rival_best": 0.0, "by_key": {}},
	"tutorial": {"step": 0, "done": false},
	"flags": {},
}


## 将原始存档字典迁移到 CURRENT_VERSION；无法迁移时返回空字典。
static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var version: int = int(data.get("schema_version", 0))
	if version > CURRENT_VERSION:
		push_error(
			"SaveMigrator: 存档 schema_version(%d) 高于当前支持版本(%d)，拒绝迁移以防坏档" % [version, CURRENT_VERSION]
		)
		return {}
	while version < CURRENT_VERSION:
		match version:
			0:
				# v0（无版本号旧档）-> v1：补齐机制壳字段，已有数据保留。
				version = 1
			_:
				# 未知的中间版本：中止迁移，防止死循环。
				push_error("SaveMigrator: 未知的中间 schema 版本: %d" % version)
				return {}
	data["schema_version"] = CURRENT_VERSION
	_fill_shell(data, V1_SHELL)
	return data


## 按 shell 深度补缺：只填缺失键，已有键一律不动（开放容器零迁移哲学）。
static func _fill_shell(target: Dictionary, shell: Dictionary) -> void:
	for key: String in shell:
		var default_value: Variant = shell[key]
		if not target.has(key):
			if default_value is Dictionary or default_value is Array:
				target[key] = default_value.duplicate(true)
			else:
				target[key] = default_value
		elif default_value is Dictionary and target[key] is Dictionary:
			_fill_shell(target[key], default_value)
