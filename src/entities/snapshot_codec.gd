class_name SnapshotCodec
extends RefCounted

## GameWorld ↔ 字典唯一映射点（v1.1 §A L2）：
## - ui_snapshot：get_ui_snapshot() 返回结构（B1），reload/读档/回菜单首渲染唯一来源；
##   不含 rng 计数器与 flags 全量（UI 无需、防误用）。
## - to_save：savegame schema v1 全量字典（§C），经 SaveSystem 唯一写入口落盘。
## 字段集与 SaveMigrator.V1_SHELL 对齐；业务字段冻结归 PR5R。


## UI 快照（只读视图；世界内部状态不外泄引用）。
static func ui_snapshot(world: GameWorld) -> Dictionary:
	var staff_list: Array = []
	for staff_id: String in world.staff:
		var row: Dictionary = world.staff[staff_id]
		(
			staff_list
			. append(
				{
					"staff_id": staff_id,
					"name": row.get("name", ""),
					"assigned": row.get("assigned", ""),
				}
			)
		)
	return {
		"week": world.week,
		"resources":
		{
			"money": world.get_money(),
			"compute": world.get_compute(),
			"influence": world.get_influence(),
		},
		"research_eff": world.research_eff,
		"tech_bonus": world.tech_bonus,
		"techs": {"lit": [], "fog": {}, "crossover_progress": 0, "pity": 0},
		"tasks": world.task_queue.to_snapshot(),
		"staff": world.roster.to_snapshot(),
		"training": {"base_id": "", "weeks_left": 0},
		"rivals": {"cursor": 0},
		"pending_decision": world.pending_decision.duplicate(true),
		"user_paused": world.user_paused,
		"game_over": world.game_over_flag,
		"model_name": world.model_name,
		"sota": {"best": world.sota_best, "rival_best": world.rival_best, "by_key": {}},
	}


## 存档字典（schema v1 机制壳全量；SaveSystem 落盘前补 schema_version 一致性）。
static func to_save(world: GameWorld) -> Dictionary:
	var assigned: Dictionary = {}
	for staff_id: String in world.staff:
		assigned[staff_id] = str(world.staff[staff_id].get("assigned", ""))
	var model_names: Array = world._named_ids.keys()
	return {
		"schema_version": GameWorld.SCHEMA_VERSION,
		"week": world.week,
		"resources":
		{
			"money": world.get_money(),
			"compute": world.get_compute(),
			"influence": world.get_influence(),
		},
		"rng": {},
		"techs": {"lit": [], "fog_visibility": {}, "crossover_progress": 0, "pity": 0},
		"tasks": world.task_queue.to_save(),
		"staff": world.roster.to_save(),
		"training": {"base": "", "weeks_left": 0},
		"rivals": {"cursor": 0, "jitter_state": 0},
		"events": {"fired": [], "pending": [], "effects_pending": []},
		"player_model_names": model_names,
		"stages": {"current": 0},
		"sota": {"best": world.sota_best, "rival_best": world.rival_best, "by_key": {}},
		"flags": {"game_over": world.game_over_flag, "name_cursor": world._named_cursor},
	}


## 状态摘要（M6/nightly）：同 seed 双跑哈希比对入口——键序归一化的稳定序列化。
static func state_digest(world: GameWorld) -> String:
	return JSON.stringify(to_save(world)).md5_text()
