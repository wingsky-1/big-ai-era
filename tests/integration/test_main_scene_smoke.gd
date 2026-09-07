extends GutTest

## 启动自检场景冒烟测试：
## 验证 main.tscn 可实例化、场景树完整、数据管线在真实引擎下可用。
## Headless 注意事项：Control 布局需推两帧；输入模拟在 headless 下不可用。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")


func test_main_scene_instantiates_and_reports_items() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	# Headless 下布局与 _ready 需要显式推帧
	await get_tree().process_frame
	await get_tree().process_frame

	var status_label: Label = main.get_node("%StatusLabel")
	assert_not_null(status_label, "%StatusLabel 唯一名应可寻址")
	var main_scene := main as MainScene
	assert_not_null(main_scene, "根脚本应为 MainScene")
	assert_eq(main_scene.get_item_count(), 2, "数据管线应加载到 2 个条目")
	assert_string_contains(status_label.text, "SCAFFOLD OK", "状态文案应标记自检通过")
