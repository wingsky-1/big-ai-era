extends GutTest

## SaveMigrator 单元测试：v1 -> v2 升轨、未来版本拒绝、未知版本防死循环。


func test_missing_version_treated_as_v1_and_migrated() -> void:
	var raw := {"hp": 80.0}
	var migrated := SaveMigrator.migrate(raw)
	assert_eq(migrated.get("schema_version"), 2, "缺版本应视为 v1 并升到当前版")
	assert_almost_eq(float(migrated.get("health", 0.0)), 80.0, 0.0001, "hp 应重命名为 health")
	assert_false(migrated.has("hp"), "旧字段 hp 应被移除")


func test_v1_dict_upgraded_with_default_health() -> void:
	var migrated := SaveMigrator.migrate({"schema_version": 1})
	assert_almost_eq(float(migrated.get("health", 0.0)), 100.0, 0.0001, "缺 hp 字段应补默认值 100")


func test_current_version_dict_passes_through() -> void:
	var raw := {"schema_version": 2, "health": 55.0}
	var migrated := SaveMigrator.migrate(raw)
	assert_eq(migrated.get("health"), 55.0, "当前版本数据应原样保留")


func test_future_version_rejected_with_empty_dict() -> void:
	var migrated := SaveMigrator.migrate({"schema_version": 99})
	assert_true(migrated.is_empty(), "更高 schema 版本应返回空字典（拒绝覆盖保护）")
	assert_push_error("高于当前支持版本", "拒绝迁移时应有明确错误提示")


func test_source_dict_not_mutated() -> void:
	var raw := {"hp": 42.0}
	SaveMigrator.migrate(raw)
	assert_true(raw.has("hp"), "原始字典不应被修改（深拷贝）")
	assert_false(raw.has("schema_version"), "原始字典不应被打上版本号")
