class_name SnapshotCodec
extends RefCounted

## GameWorld ↔ 字典唯一映射点（v1.1 §A L2）：
## - ui_snapshot：get_ui_snapshot() 返回结构（B1），reload/读档/回菜单首渲染唯一来源；
##   不含 rng 计数器与 flags 全量（UI 无需、防误用）。
## - to_save：savegame schema v1 全量字典（§C），经 SaveSystem 唯一写入口落盘。
## 字段集与 SaveMigrator.V1_SHELL 对齐；业务字段冻结归 PR5R。


## UI 快照（只读视图；世界内部状态不外泄引用）。
## 呈现层数据面扩展（#78 / ADR-0016）：forecast/staff_view/domain_progress/rival_view/naming
## 均由 L2 出数（L3 只格式化），不经命令面（契约命令仍 12、信号仍 11）。
static func ui_snapshot(world: GameWorld) -> Dictionary:
	return {
		"week": world.week,
		"cum_income": world.cum_income,
		"resources":
		{
			"money": world.get_money(),
			"compute": world.get_compute(),
			"influence": world.get_influence(),
		},
		"research_eff": world.research_eff,
		"tech_bonus": world.tech_bonus,
		"techs":
		{
			"lit": world.tech_fog.get_lit_techs(),
			"fog": world.tech_fog.to_snapshot().get("fog_states", {}),
			"crossover_progress": world.tech_fog.get_crossover_progress(),
			"pity": world.tech_fog.get_pity(),
		},
		"tasks": world.task_queue.to_snapshot(),
		"staff": world.roster.to_snapshot(),
		"staff_view": world.get_staff_view(),
		"training": world.training.to_snapshot(),
		"rivals": world.rival_track.to_snapshot(),
		"rival_view": world.get_rival_view(),
		"domain_progress": world.get_domain_progress(),
		"forecast": world.get_income_forecast(),
		"freedom": world.get_freedom_view(),
		"naming": world.get_naming_view(),
		"pending_decision": world.pending_decision.duplicate(true),
		"user_paused": world.user_paused,
		"game_over": world.game_over_flag,
		"model_name": world.model_name,
		"sota": world.sota_board.to_snapshot(),
		"tutorial": {"step": world.tutorial_step, "done": world.tutorial_done},
	}


## 存档字典（schema v1 机制壳全量；SaveSystem 落盘前补 schema_version 一致性）。
static func to_save(world: GameWorld) -> Dictionary:
	var assigned: Dictionary = {}
	for staff_id: String in world.staff:
		assigned[staff_id] = str(world.staff[staff_id].get("assigned", ""))
	var model_names: Array = world._named_ids.keys()
	var flags: Dictionary = {
		"game_over": world.game_over_flag,
		"name_cursor": world._named_cursor,
		# 呈现层读档还原（#78）：出分标记与玩家最高分——否则读档后分级显示退化
		# 为起步档、命名仪式不再触发（flags 为开放容器，加键零迁移）。
		"scored": world._scored_once,
		"player_best_score": world._player_best_score,
		# 翻雾供给源（RK-04 / DR-031 §2.9）：累计获得影响力（只增不减），
		# flags 为开放容器，加键零迁移（旧档缺键由 restore 兜底为 0）。
		"cum_influence": world.economy.get_cum_influence(),
	}
	# 自由期三线计数器（#82 RF-01）：flags 开放容器合并，加键零迁移（红线 4）
	flags.merge(world.freedom.to_save())
	return {
		"schema_version": GameWorld.SCHEMA_VERSION,
		"week": world.week,
		"cum_income": world.cum_income,
		"resources":
		{
			"money": world.get_money(),
			"compute": world.get_compute(),
			"influence": world.get_influence(),
		},
		"rng": world.rng_stream.to_save(),
		"techs":
		{
			"lit": world.tech_fog.get_lit_techs(),
			"fog_visibility": world.tech_fog.to_save().get("fog_visibility", {}),
			"crossover_progress": world.tech_fog.get_crossover_progress(),
			"pity": world.tech_fog.get_pity(),
		},
		"tasks": world.task_queue.to_save(),
		"staff": world.roster.to_save(),
		"training": world.training.to_save(),
		"rivals": world.rival_track.to_save(),
		"events": world.event_engine.to_save(),
		"player_model_names": model_names,
		"stages": world.stages.to_save(),
		"sota": world.sota_board.to_save(),
		"tutorial": {"step": world.tutorial_step, "done": world.tutorial_done},
		"flags": flags,
	}


## 状态摘要（M6/nightly）：同 seed 双跑哈希比对入口——键序归一化的稳定序列化。
static func state_digest(world: GameWorld) -> String:
	return JSON.stringify(to_save(world)).md5_text()
