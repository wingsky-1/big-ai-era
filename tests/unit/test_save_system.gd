extends GutTest
## #126 验收点 3/4：SaveSystem IO 壳（autoload，真实 user:// IO，独立测试路径隔离）。
## 原子写：写失败保留磁盘原档（tmp→校验→rename，ADR-0005 双缓冲）；
## 周结自动存+手动存两档同格式可覆盖；schema 版本纪律经 SaveMigrator 在加载链生效。

const TEST_PATH: String = "user://test_save_system_126.json"


func before_each() -> void:
	_cleanup_test_files()


func after_each() -> void:
	_cleanup_test_files()


func _kind(payload: Dictionary) -> String:
	return str(payload.get(SnapshotCodec.KIND_KEY, SnapshotCodec.SAVE_KIND_AUTO))


func _is_world_state(payload: Dictionary) -> bool:
	# 档面只含信封 + §9.1 业务域（world 面==档面剥信封）
	if not payload.has("game") or not payload.has("resources"):
		return false
	if not payload.has(SnapshotCodec.VERSION_KEY):
		return false
	return true


func test_save_atomic_keep_old_on_fail() -> void:
	# 写失败保留磁盘原档：模拟 tmp 残留污染（非空目录项）→ 下次原子写被中止，
	# 磁盘主档仍是上一次成功内容。
	assert_true(SaveSystem.save_game({"week": 1}, TEST_PATH), "前置：第一次保存成功")
	# 模拟写失败：制造一个同名目录占用 tmp 路径（rename 到目录上必失败）
	var fake_dir_path := TEST_PATH + SaveSystem.SAVE_TMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fake_dir_path))
	assert_true(DirAccess.dir_exists_absolute(fake_dir_path), "前置：tmp 被目录占用")
	var ok := SaveSystem.save_game({"week": 2}, TEST_PATH)
	assert_false(ok, "tmp 路径被占用时保存必须失败")
	assert_push_error("无法写入临时档", "失败注入应有可读错误（写失败分支）")
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_eq(int(loaded.get("week")), 1, "写失败后磁盘原档（week=1）必须保留，不得半写覆盖")
	_cleanup_test_files()
	# 恢复后新保存成功且旧档被覆盖（两档同格式可覆盖的延续验证）
	assert_true(SaveSystem.save_game({"week": 3}, TEST_PATH), "清理后保存应成功")
	assert_eq(int(SaveSystem.load_game(TEST_PATH).get("week")), 3, "覆盖保存后读到新档")


func test_save_two_modes() -> void:
	# 周结自动存 + 手动存两档同格式（同一 SnapshotCodec 信封）可覆盖同一路径
	# （用默认档 user://savegame.json，即"关掉重开接着玩"的真实落盘点）
	var world: Dictionary = {
		"meta": {"saved_at_week": 1},
		"game": {"week": 1, "seed": 1},
		"resources": {"cash": 100},
		"flags": {"scored": false},
	}
	var auto_save := SnapshotCodec.encode(world, SnapshotCodec.SAVE_KIND_AUTO)
	assert_true(SaveSystem.save_game(auto_save, SaveSystem.SAVE_PATH), "周结自动存应成功")
	assert_eq(
		_kind(SaveSystem.load_game(SaveSystem.SAVE_PATH)), SnapshotCodec.SAVE_KIND_AUTO, "落盘档类=auto"
	)
	# 手动存覆盖同一路径（同格式可覆盖），档类=manual
	var manual_save := SnapshotCodec.encode(world, SnapshotCodec.SAVE_KIND_MANUAL)
	assert_true(SaveSystem.save_game(manual_save, SaveSystem.SAVE_PATH), "手动存应成功（覆盖自动档）")
	var loaded := SaveSystem.load_game(SaveSystem.SAVE_PATH)
	assert_eq(_kind(loaded), SnapshotCodec.SAVE_KIND_MANUAL, "手动档覆盖后档类=manual")
	assert_eq(int(loaded.get("game", {}).get("week")), 1, "覆盖后业务数据一致（同格式）")
	# 关掉重开语义：读档=同一 dict 信封完整（进度不丢，真人侧 [P] 以 IO 层保证）
	assert_true(_is_world_state(loaded), "读档返回完整档面（信封+业务域）")
	assert_true(SaveSystem.has_save(SaveSystem.SAVE_PATH), "默认档位置存在可续玩")


func test_atomic_write_cleanup_tmp_and_bak_rotation() -> void:
	# 原子写成功后：tmp 清场 + 上一代转 .bak（双缓冲轮换）
	assert_true(SaveSystem.save_game({"week": 1}, TEST_PATH), "第一次保存成功")
	assert_false(FileAccess.file_exists(TEST_PATH + SaveSystem.SAVE_TMP_SUFFIX), "成功后不残留 tmp")
	assert_true(SaveSystem.save_game({"week": 2}, TEST_PATH), "第二次保存成功")
	assert_true(FileAccess.file_exists(TEST_PATH + SaveSystem.SAVE_BAK_SUFFIX), "第二次写后 .bak=上一代")
	var bak := SaveSystem.load_game(TEST_PATH + SaveSystem.SAVE_BAK_SUFFIX)
	assert_eq(int(bak.get("week")), 1, ".bak 保留上一周目内容")


func test_load_roundtrip_and_schema_stamp() -> void:
	# 保存盖当前版本章；读档经迁移链按 v1 透传
	var payload := {"week": 9, "resources": {"cash": 12345}}
	assert_true(SaveSystem.save_game(payload, TEST_PATH), "保存应成功")
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_eq(
		int(loaded.get(SaveMigrator.VERSION_KEY)), SaveMigrator.CURRENT_VERSION, "落盘补写当前 schema 版本"
	)
	assert_eq(int(loaded.get("week")), 9, "读档数据一致")
	assert_true(SaveSystem.has_save(TEST_PATH), "has_save 判定存在")


func test_load_missing_returns_empty_without_error() -> void:
	# 无档=新游戏正常态：返回 {} 且不产生任何错误
	assert_false(SaveSystem.has_save(TEST_PATH), "前置：测试路径无档")
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_true(loaded.is_empty(), "无档应返回空字典")
	assert_push_error_count(0, "无档不是错误（新游戏正常态）")


func test_load_future_schema_rejected_keeps_disk() -> void:
	# 未来版本保护在 IO 链生效：档在磁盘上、拒绝加载但文件保留（报错不崩）
	var raw := {"schema_version": 99, "week": 9}
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file = null
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_true(loaded.is_empty(), "未来版本档拒绝加载")
	assert_push_error("高于当前支持版本", "未来版本拒绝应有可读错误（迁移链层）")
	assert_push_error("迁移被拒", "未来版本拒绝应有可读错误（IO 壳层）")
	assert_true(FileAccess.file_exists(TEST_PATH), "拒绝加载后磁盘原档保留")
	var raw_text := FileAccess.get_file_as_string(TEST_PATH)
	assert_true(str(raw_text).contains("schema_version"), "磁盘原档内容未被破坏")


func _cleanup_test_files() -> void:
	for path in [TEST_PATH, SaveSystem.SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var tmp_path: String = TEST_PATH + SaveSystem.SAVE_TMP_SUFFIX
	var global_tmp := ProjectSettings.globalize_path(tmp_path)
	if DirAccess.dir_exists_absolute(global_tmp):
		DirAccess.remove_absolute(global_tmp)
	elif FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(global_tmp)
	for path in [TEST_PATH, SaveSystem.SAVE_PATH]:
		var bak_global := ProjectSettings.globalize_path(path + SaveSystem.SAVE_BAK_SUFFIX)
		if FileAccess.file_exists(path + SaveSystem.SAVE_BAK_SUFFIX):
			DirAccess.remove_absolute(bak_global)
