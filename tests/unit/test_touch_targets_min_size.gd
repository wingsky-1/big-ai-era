extends GutTest
## #145 验收点 4：触控目标——可点元素 ≥48px（灰点 ≥24px）
## （GUT：`test_touch_targets_min_size`）。
## 真源=ui-ux-spec B.5/触屏纪律（可点 ≥48px，灰点例外 ≥24px 触区）+
## D.2 ui_touch_min=48 硬约束 + ui.json 表。断言双通道：
## - 表通道：ui.json ui_touch_min ≥48 / ui_touch_min_dot ≥24（schema 已断，
##   此处断 LayoutPolicy 判定函数用表值结果）；
## - 节点通道：MainScene Dock 三键实际 custom_minimum_size ≥48（headless
##   实例化后读节点）——装配镜像常量与表一致。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const UI_PATH: String = "res://src/data/ui.json"


func test_touch_targets_min_size() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var touch_min := float(table["ui_touch_min"])
	var touch_min_dot := float(table["ui_touch_min_dot"])
	assert_true(touch_min >= 48.0, "ui_touch_min ≥48（表真源）")
	assert_true(touch_min_dot >= 24.0, "ui_touch_min_dot ≥24（表真源）")
	# LayoutPolicy 判定：可点 ≥48 过、47 拒；灰点 24 过、23 拒
	assert_true(
		LayoutPolicy.meets_touch_target(48.0, 48.0, false, touch_min, touch_min_dot),
		"48×48 可点=过",
	)
	assert_false(
		LayoutPolicy.meets_touch_target(47.0, 48.0, false, touch_min, touch_min_dot),
		"47 宽可点=拒（<48）",
	)
	assert_true(
		LayoutPolicy.meets_touch_target(24.0, 24.0, true, touch_min, touch_min_dot),
		"24×24 灰点=过（例外）",
	)
	assert_false(
		LayoutPolicy.meets_touch_target(23.0, 24.0, true, touch_min, touch_min_dot),
		"23 宽灰点=拒（<24）",
	)
	# 装配镜像一致：MainScene.MIN_TOUCH == 表 ui_touch_min（防镜像漂移）
	assert_eq(MainScene.MIN_TOUCH, touch_min, "装配镜像常量=表值（防双源漂移）")


func test_main_scene_dock_buttons_touch_size() -> void:
	# 节点通道：Dock 三键实例化后 custom_minimum_size ≥48（_ready 装配）
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	for path: String in ["%DockTask", "%DockTree", "%DockPause"]:
		var button: Button = main.get_node_or_null(path)
		assert_not_null(button, "%s 节点在位" % path)
		if button == null:
			continue
		assert_true(
			button.custom_minimum_size.x >= 48.0 and button.custom_minimum_size.y >= 48.0,
			"%s 触控尺寸 ≥48×48（实际 %s）" % [path, str(button.custom_minimum_size)],
		)
