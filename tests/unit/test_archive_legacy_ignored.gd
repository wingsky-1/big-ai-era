extends GutTest
## #123 验收点 1：旧 src/ 全部脚本/数据表移入 _archive_legacy 且门禁忽略该目录。
## 断言机制：.gdignore 存在（Godot 资源系统跳过）+ verify.sh 静态检查目录清单
## 显式排除 _archive_legacy（ADR-0017 目录级豁免）。

const VERIFY_SCRIPT_PATH: String = "res://scripts/verify.sh"


func test_archive_gdignore_present() -> void:
	assert_true(
		FileAccess.file_exists("res://src/_archive_legacy/.gdignore"),
		"src/_archive_legacy/ 必须带 .gdignore（Godot 资源系统目录级豁免，ADR-0017）",
	)
	assert_true(
		FileAccess.file_exists("res://src/_archive_legacy/core/clock_math.gd"),
		"旧 core 实现须保留在归档目录（git mv 保底料，不删除）",
	)
	assert_true(
		FileAccess.file_exists("res://src/_archive_legacy/data/texts.json"),
		"旧数据表须保留在归档目录（内容底料，不并入新树）",
	)


func test_legacy_not_in_src_top_level() -> void:
	var top_dirs: Array[String] = []
	var dir := DirAccess.open("res://src")
	assert_not_null(dir, "无法打开 res://src")
	if dir == null:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if dir.current_is_dir() and not item.begins_with("."):
			top_dirs.append(item)
		item = dir.get_next()
	dir.list_dir_end()
	for legacy: String in ["core", "data", "entities", "systems", "ui"]:
		assert_false(
			(
				legacy in top_dirs
				and DirAccess.dir_exists_absolute("res://src/%s/clock_math.gd" % legacy)
			),
			"旧实现不得留在 src/ 顶层（已 git mv 入 _archive_legacy）",
		)
	assert_true(
		top_dirs.has("_archive_legacy"),
		"src/ 顶层须含归档目录 _archive_legacy",
	)


func test_verify_script_excludes_archive() -> void:
	assert_true(
		FileAccess.file_exists(VERIFY_SCRIPT_PATH),
		"verify.sh 应存在（read 目标）",
	)
	var file := FileAccess.open(VERIFY_SCRIPT_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	assert_true(
		content.contains("_archive_legacy"),
		"verify.sh 必须显式排除 _archive_legacy（lint/format 目录清单跳过归档）",
	)
	assert_true(
		content.contains("*_archive_legacy/") or content.contains("_archive_legacy/)"),
		"verify.sh 目录清单须以 glob 模式跳过归档子目录（gdformat/gdlint 不支持排除语法）",
	)
