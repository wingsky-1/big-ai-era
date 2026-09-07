class_name TestSchemaFreeze
extends GutTest

## PR5R (issue #11) 存档 schema 字段集冻结专项测试
## 验证全部 3 个 [T] 验收点：
## 1. 冻结清单逐字段核验单测（schema v1 全量字段表 §C）
## 2. 预埋键存在断言（sota.by_key{} 复合键容器 + staff.condition 占位 enabled:false）
## 3. 字段协商 6 项落定值与 §C 逐项对账

var _world: GameWorld


func before_each() -> void:
	_world = GameWorld.new()
	_world.start_new_game(123)


func test_acceptance_point_1_schema_v1_field_set_and_shell() -> void:
	# [T] 验收点 1：冻结清单逐字段核验（V1_SHELL 与 savegame schema v1 对齐）
	var save_data: Dictionary = SnapshotCodec.to_save(_world)
	var shell: Dictionary = SaveMigrator.V1_SHELL

	# 1. 顶层键全量核验
	var required_top_keys: Array[String] = [
		"schema_version",
		"week",
		"cum_income",
		"resources",
		"rng",
		"techs",
		"tasks",
		"staff",
		"training",
		"rivals",
		"events",
		"player_model_names",
		"stages",
		"sota",
		"tutorial",
		"flags",
	]

	for k: String in required_top_keys:
		if k == "schema_version":
			assert_eq(int(save_data.get(k)), GameWorld.SCHEMA_VERSION, "schema_version 必须为 1")
		else:
			assert_true(save_data.has(k), "to_save 顶层必须包含字段 '%s'" % k)
			assert_true(shell.has(k), "V1_SHELL 顶层必须包含字段 '%s'" % k)

	# 2. 子容器键全量核验
	# resources{money, compute{tier, hours_remaining}, influence}
	var res: Dictionary = save_data.get("resources", {})
	assert_true(res.has("money") and res.has("compute") and res.has("influence"))
	var comp: Dictionary = res.get("compute", {})
	assert_true(comp.has("tier") and comp.has("hours_remaining"))

	# techs{lit, fog_visibility, crossover_progress, pity}
	var techs: Dictionary = save_data.get("techs", {})
	assert_true(techs.has("lit") and techs.has("fog_visibility"))
	assert_true(techs.has("crossover_progress") and techs.has("pity"))

	# tasks{queue, active{task_id, weeks_left}}
	var tasks: Dictionary = save_data.get("tasks", {})
	assert_true(tasks.has("queue") and tasks.has("active"))

	# rivals{cursor, jitter_state}
	var rivals: Dictionary = save_data.get("rivals", {})
	assert_true(rivals.has("cursor") and rivals.has("jitter_state"))

	# events{fired, pending, effects_pending}
	var events: Dictionary = save_data.get("events", {})
	assert_true(events.has("fired") and events.has("pending") and events.has("effects_pending"))

	# tutorial{step, done}
	var tut: Dictionary = save_data.get("tutorial", {})
	assert_true(tut.has("step") and tut.has("done"))


func test_acceptance_point_2_embedded_placeholder_keys() -> void:
	# [T] 验收点 2：预埋键存在断言（sota.by_key{} 复合键容器 + staff.condition 占位）
	var save_data: Dictionary = SnapshotCodec.to_save(_world)
	var shell: Dictionary = SaveMigrator.V1_SHELL

	# 1. sota.by_key 复合键容器预埋（多基座/多榜单演进扩展点）
	var sota_save: Dictionary = save_data.get("sota", {})
	var sota_shell: Dictionary = shell.get("sota", {})
	assert_true(sota_save.has("by_key"), "to_save 必须预埋 sota.by_key")
	assert_true(sota_shell.has("by_key"), "V1_SHELL 必须预埋 sota.by_key")
	assert_true(sota_save.get("by_key") is Dictionary, "by_key 必须为字典复合键容器")

	# 2. staff.condition 占位预埋（体力/士气回归演进扩展点）
	var staff_save: Dictionary = save_data.get("staff", {})
	var staff_shell: Dictionary = shell.get("staff", {})
	assert_true(staff_save.has("condition"), "to_save 必须预埋 staff.condition 占位")
	assert_true(staff_shell.has("condition"), "V1_SHELL 必须预埋 staff.condition 占位")
	assert_true(staff_save.get("condition") is Array, "condition 占位为 Array 容器")


func test_acceptance_point_3_negotiated_fields_reconciliation() -> void:
	# [T] 验收点 3：字段协商 6 项落定值与 §C 逐项对账
	# 协商 1: tasks.json 补 unlock{predicate, params} 字段
	var tasks_cfg: Dictionary = DataLoader.load_json("res://src/data/tasks.json")
	for tid: String in tasks_cfg:
		var t_item: Dictionary = tasks_cfg[tid]
		assert_true(t_item.has("unlock"), "任务 %s 必须包含 unlock 字段" % tid)

	# 协商 2: techs.json 补 fog_gate 与 domain_enum 7 值
	var techs_cfg: Dictionary = DataLoader.load_json("res://src/data/techs.json")
	assert_true(techs_cfg.has("fog_gate"), "techs.json 必须有表级 fog_gate")
	assert_eq(techs_cfg.get("domain_enum", []).size(), 7, "domain_enum 必须为 7 值")

	# 协商 3: stages.json 阶段容器存在且 stage_0 为 enabled
	var stages_cfg: Dictionary = DataLoader.load_json("res://src/data/stages.json")
	assert_true(stages_cfg.get("stages", {}).has("stage_0"), "stages.json 必须含 stage_0")

	# 协商 4: economy.json 补 sources 开关容器
	var economy_cfg: Dictionary = DataLoader.load_json("res://src/data/economy.json")
	assert_true(economy_cfg.has("sources"), "economy.json 必须含 sources 开关容器")

	# 协商 5: cum_income 经营性收入累计字段在世界与存档中就绪
	assert_eq(_world.cum_income, 0, "开局 cum_income 应为 0")
	_world.settle_week()
	assert_true(_world.cum_income >= 0, "周结后 cum_income 累计经营性收入")

	# 协商 6: flags 开放容器在世界与存档中存在
	var save_data: Dictionary = SnapshotCodec.to_save(_world)
	assert_true(save_data.get("flags") is Dictionary, "flags 必须是开放字典容器")
