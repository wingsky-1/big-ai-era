extends GutTest
## #126 验收点 1：schema version 起步/迁移链逐级/未来版本拒绝（ADR-0003/ADR-0021）。
## v1.0.0 起步（architecture-100 §9.3）：schema_version=1；缺失按 v1；
## 低于 v1 的旧档弃迁拒绝（禁跳步）；高于当前版本=未来版本保护，拒绝加载（报错不崩）。


func test_save_migrator_chain() -> void:
	# 1) 起步：版本缺失按 v1 处理（ADR-0003 决策 1）
	var no_version := {"game": {"week": 1}, "resources": {"cash": 100}}
	var migrated := SaveMigrator.migrate(no_version)
	assert_eq(
		int(migrated.get(SaveMigrator.VERSION_KEY)),
		1,
		"缺失 schema_version 的存档按 v1 起步",
	)
	assert_eq(int(migrated.get("game", {}).get("week")), 1, "起步迁移不得改动业务数据")
	# 2) 当前版本透传（升轨终点；业务数据原样保留）
	var current := SaveMigrator.migrate({"schema_version": 1, "game": {"week": 7}})
	assert_eq(int(current.get("game", {}).get("week")), 7, "v1 当前档透传，业务数据原样")
	# 3) 禁跳步：低于 v1 的旧档拒绝迁移（v1 起步旧档弃迁，不提供跳步合并路径）
	var old := SaveMigrator.migrate({"schema_version": 0, "game": {"week": 5}})
	assert_true(old.is_empty(), "低于 v1 的旧档必须拒绝（v1 起步弃迁，禁跳步）")
	assert_push_error("低于当前支持版本", "拒绝旧档应有可读错误（弃迁提示）")
	# 4) 未来版本拒绝加载（报错不崩，返回空字典）
	var future := SaveMigrator.migrate({"schema_version": 99, "game": {"week": 5}})
	assert_true(future.is_empty(), "未来版本存档必须拒绝加载（防旧版本游戏覆盖新存档）")
	assert_push_error("高于当前支持版本", "未来版本应有可读错误（未来版本保护）")


func test_version_missing_defaults_to_current() -> void:
	# 起步契约的等价断言：缺版本档迁移后不产生任何错误（正常按 v1 放行）
	var migrated := SaveMigrator.migrate({"game": {"week": 2}})
	assert_eq(int(migrated.get(SaveMigrator.VERSION_KEY)), 1, "缺版本档按当前版本 v1 起步")
	assert_push_error_count(0, "缺版本按 v1 起步是正常路径，不应报错")


func test_future_version_rejected_keeps_raw_dict() -> void:
	# 未来版本保护：入参原字典不被 mutate（调用方可继续持有磁盘原档处置）
	var raw := {"schema_version": 2, "game": {"week": 3}}
	var result := SaveMigrator.migrate(raw)
	assert_true(result.is_empty(), "未来版本迁移结果必须为空（拒绝）")
	assert_eq(int(raw.get("schema_version")), 2, "拒绝不得改动入参原字典")
	assert_push_error("高于当前支持版本", "未来版本拒绝应有错误")


func test_current_version_passthrough_keeps_open_containers() -> void:
	# 开放容器零迁移哲学（ADR-0003 决策）：当前版本透传不得动任何业务键
	var migrated := (
		SaveMigrator
		. migrate(
			{
				"schema_version": 1,
				"flags": {"onb_step": "step_4", "scored": true},
				"rng": {"event": 12},
			}
		)
	)
	assert_eq(migrated.get("flags", {}).get("onb_step"), "step_4", "flags 开放容器键原样保留")
	assert_true(migrated.get("flags", {}).has("scored"), "flags 开放容器完整透传")
	assert_eq(int(migrated.get("rng", {}).get("event")), 12, "rng 键原样保留")
