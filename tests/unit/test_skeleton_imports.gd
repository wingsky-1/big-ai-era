extends GutTest
## #123 验收点 2：新建 src/core|systems|entities|ui|data 空壳骨架可导入（无旧依赖）。
## 断言方式：逐文件 load() 成功 + RefCounted 骨架可实例化（headless）。

const SKELETON_FILES: Array[String] = [
	"res://src/core/enums.gd",
	"res://src/core/clock_math.gd",
	"res://src/systems/data/data_loader.gd",
	"res://src/systems/save/save_migrator.gd",
	"res://src/systems/save/save_system.gd",
	"res://src/systems/rng/rng_stream.gd",
	"res://src/systems/text/text_service.gd",
	"res://src/systems/ledger/ledger.gd",
	"res://src/entities/game_world.gd",
	"res://src/ui/main/main.gd",
]


func test_all_skeleton_files_importable() -> void:
	for path: String in SKELETON_FILES:
		var script: Variant = load(path)
		assert_not_null(script, "骨架脚本可 load（无旧依赖、可导入）: %s" % path)


func test_refcounted_stubs_instantiable() -> void:
	for path: String in SKELETON_FILES:
		if path.contains("save_system") or path.contains("ui/main"):
			continue  # Node 类走场景集成测试，不在纯单测实例化
		var script: GDScript = load(path)
		var instance: RefCounted = script.new()
		assert_not_null(instance, "RefCounted 骨架可 new(): %s" % path)


func test_new_skeleton_dirs_exist() -> void:
	# architecture-100 §2.1 目标目录树的关键子目录在重建期即就位（gitkeep 承载）
	for dir_path: String in [
		"res://src/data",
		"res://src/entities/projects",
		"res://src/entities/archives",
		"res://src/entities/rivals",
		"res://src/entities/events",
		"res://src/entities/onboarding",
		"res://src/ui/panels",
		"res://src/ui/modals",
		"res://src/ui/widgets",
		"res://src/ui/presenters",
	]:
		assert_true(
			DirAccess.dir_exists_absolute(dir_path),
			"骨架目录须就位: %s" % dir_path,
		)


func test_main_scene_placeholder_runs() -> void:
	# 空壳主台可实例化（占位 Label + 无旧资源依赖）
	var scene: PackedScene = load("res://src/ui/main/main.tscn")
	assert_not_null(scene, "主场景 .tscn 可加载")
	var node: Node = scene.instantiate()
	assert_not_null(node, "主场景可实例化")
	node.free()
