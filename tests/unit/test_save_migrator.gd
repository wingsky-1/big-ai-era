extends GutTest

## SaveMigrator 单元测试（schema v1 机制壳，DR-008 / DR-021 B2）：
## v0→v1 升轨、当前版透传、未来版本拒绝、开放容器零迁移、壳字段集完整性。


func test_v0_dict_migrates_to_v1_shell() -> void:
	# 旧版无版本号档：升轨后携带 v1 机制壳全量字段。
	var raw := {"week": 12, "resources": {"money": 50000}}
	var migrated := SaveMigrator.migrate(raw)
	assert_eq(int(migrated.get("schema_version")), 1, "缺版本应视为 v0 并升到当前版")
	assert_eq(int(migrated.get("week")), 12, "已有 week 应原样保留")
	assert_eq(int(migrated.get("resources", {}).get("money")), 50000, "已有 money 应原样保留")
	assert_true(migrated.has("techs"), "缺 techs 壳应补齐")
	assert_true(migrated.has("sota"), "缺 sota 壳应补齐（by_key 预埋）")
	assert_true(migrated.get("sota", {}).has("by_key"), "sota.by_key 预埋容器应存在")
	assert_true(
		migrated.get("tasks", {}).get("active", {}).has("weeks_left"), "tasks.active.weeks_left 应落壳"
	)


func test_current_version_dict_fills_missing_shell_keys() -> void:
	var migrated := SaveMigrator.migrate({"schema_version": 1, "week": 7})
	assert_eq(int(migrated.get("week")), 7, "当前版已有数据原样保留")
	assert_eq(int(migrated.get("resources", {}).get("money")), 0, "缺 resources.money 应补壳默认")


func test_open_containers_keep_existing_keys() -> void:
	# 开放容器零迁移哲学：rng/flags 已有键一律不动，补缺不覆盖。
	var migrated := (
		SaveMigrator
		. migrate(
			{
				"schema_version": 1,
				"rng": {"rival_jitter": 42},
				"flags": {"name_cursor": 3},
			}
		)
	)
	assert_eq(int(migrated.get("rng", {}).get("rival_jitter")), 42, "rng 已有键不应被覆盖")
	assert_eq(int(migrated.get("flags", {}).get("name_cursor")), 3, "flags 已有键不应被覆盖")


func test_shell_contains_v1_field_set() -> void:
	# v1.1 §C 全量字段落壳核对（PR5R 冻结前结构真源）。
	var migrated := SaveMigrator.migrate({})
	for key in [
		"week",
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
		"flags",
	]:
		assert_true(migrated.has(key), "v1 壳应包含字段 %s" % key)
	var resources: Dictionary = migrated.get("resources", {})
	assert_true(
		resources.has("money") and resources.has("compute") and resources.has("influence"),
		"resources 三资源结构应落壳"
	)
	assert_true(
		(resources.get("compute", {}) as Dictionary).has("hours_remaining"),
		"compute{tier,hours_remaining} 结构应落壳（B2 精化）"
	)
	assert_true(
		(migrated.get("events", {}) as Dictionary).has("effects_pending"),
		"events.effects_pending 队列键应落壳"
	)
	assert_true(
		(migrated.get("staff", {}) as Dictionary).has("condition"), "staff.condition 占位应落壳（E#12 预埋）"
	)


func test_shell_defaults_are_deep_copies() -> void:
	# 壳默认值必须深拷贝：两次迁移结果互不串改（V1_SHELL 常量不可被污染）。
	var first := SaveMigrator.migrate({})
	var second := SaveMigrator.migrate({})
	(first.get("techs", {}).get("lit", []) as Array).append("polluted")
	assert_eq((second.get("techs", {}).get("lit", []) as Array).size(), 0, "两次迁移的容器默认值应相互独立")
	# V1_SHELL 常量本身不被污染
	assert_eq(
		(SaveMigrator.V1_SHELL.get("techs", {}).get("lit", []) as Array).size(),
		0,
		"V1_SHELL 常量不应被运行时污染"
	)


func test_future_version_rejected_with_empty_dict() -> void:
	var migrated := SaveMigrator.migrate({"schema_version": 99})
	assert_true(migrated.is_empty(), "更高 schema 版本应返回空字典（拒绝覆盖保护）")
	assert_push_error("高于当前支持版本", "拒绝迁移时应有明确错误提示")


func test_source_dict_not_mutated() -> void:
	var raw := {"week": 3}
	SaveMigrator.migrate(raw)
	assert_false(raw.has("schema_version"), "原始字典不应被打上版本号（深拷贝）")
	assert_false(raw.has("techs"), "原始字典不应被补壳")
