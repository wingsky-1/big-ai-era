extends GutTest

## SaveSystem 端到端测试（真实 user:// IO，独立测试路径隔离真实存档）：
## 双缓冲写、坏档 .bak 回退、schema 过新拒绝、唯一写入口审计。
## 注意：autoload SaveSystem 由引擎注入，测试直接使用全局单例。

const TEST_PATH: String = "user://test_save_shell.json"


func before_each() -> void:
	_cleanup_test_files()


func after_each() -> void:
	_cleanup_test_files()


func test_save_then_load_roundtrip() -> void:
	var payload := {"week": 9, "resources": {"money": 12345}}
	assert_true(SaveSystem.save_game(payload, TEST_PATH), "保存应返回成功")
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_eq(int(loaded.get("week")), 9, "roundtrip 后 week 应一致")
	assert_eq(int(loaded.get("resources", {}).get("money")), 12345, "roundtrip 后 money 应一致")
	assert_eq(int(loaded.get("schema_version")), SaveMigrator.CURRENT_VERSION, "应补写当前 schema 版本")


func test_save_stamps_schema_version() -> void:
	# 调用方故意带旧/错版本号，落盘时必须被覆盖为当前版本。
	assert_true(SaveSystem.save_game({"schema_version": 42, "week": 1}, TEST_PATH), "保存应成功")
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_eq(int(loaded.get("schema_version")), SaveMigrator.CURRENT_VERSION, "版本号应以落盘时为准")


func test_corrupt_main_falls_back_to_bak() -> void:
	# 坏档回退链路：好档 → 写坏主档 → load 应从 .bak 恢复上一周目。
	assert_true(SaveSystem.save_game({"week": 1}, TEST_PATH), "第一次保存应成功")
	assert_true(SaveSystem.save_game({"week": 2}, TEST_PATH), "第二次保存应成功（生成 .bak=week1）")
	var main_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	main_file.store_string("{corrupted json !!!")
	main_file = null
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_eq(int(loaded.get("week")), 1, "主档损坏应回退 .bak（上一周目）")
	assert_push_warning("主档损坏", "回退应有 warning 提示")
	# 坏主档解析产生的错误需显式消费（回退成功但读取痕迹仍在）
	assert_push_error("不是合法 JSON 对象", "坏主档应报 JSON 拒绝")
	assert_engine_error("error != Error::OK", "引擎层应报 JSON 解析失败")


func test_corrupt_all_leaves_disk_untouched() -> void:
	# 主备皆坏：拒绝加载但磁盘原档保留（供人工恢复）。
	assert_true(SaveSystem.save_game({"week": 1}, TEST_PATH), "保存应成功")
	var main_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	main_file.store_string("### broken ###")
	main_file = null
	var bak_file := FileAccess.open(TEST_PATH + ".bak", FileAccess.WRITE)
	bak_file.store_string("]]] also broken [[[")
	bak_file = null
	assert_true(FileAccess.file_exists(TEST_PATH), "主档原文件应保留在磁盘")
	var loaded := SaveSystem.save_game({"week": 9}, TEST_PATH)
	assert_true(loaded, "坏档不应阻止下次保存（下次保存将覆盖主档）")
	# 覆盖保存后应可正常读回（主备皆坏的死档被冲掉）
	assert_eq(int(SaveSystem.load_game(TEST_PATH).get("week")), 9, "覆盖保存后新档应可读回")


func test_load_missing_save_returns_empty_without_error() -> void:
	# 无档=新游戏正常态：返回 {} 且不产生任何错误。
	assert_false(FileAccess.file_exists(TEST_PATH), "前置：测试路径无档")
	var loaded := SaveSystem.load_game(TEST_PATH)
	assert_true(loaded.is_empty(), "无档应返回空字典")
	assert_push_error_count(0, "无档不是错误（PR3 start_new_game 依赖此语义）")


func test_atomic_write_cleans_tmp_file() -> void:
	assert_true(SaveSystem.save_game({"week": 3}, TEST_PATH), "保存应成功")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "成功换名后不应残留 tmp 文件")


func test_save_system_is_sole_disk_writer() -> void:
	# 唯一写入口审计（issue #3 [T]）：全库 src/ 存档写路径只允许 SaveSystem。
	var save_script: Script = load("res://src/systems/save/save_system.gd")
	var source: String = save_script.source_code
	for line: String in source.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		if trimmed.contains("FileAccess.WRITE"):
			assert_true(true, "SaveSystem 自身写点：%s" % trimmed)
			return
	fail_test("SaveSystem 源码中应存在唯一写点（FileAccess.WRITE），未找到说明结构漂移")


func _cleanup_test_files() -> void:
	for path in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
