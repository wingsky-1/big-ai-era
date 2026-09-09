extends GutTest
## #145 验收点 3：竖屏不折叠工作区断言（GUT：`test_portrait_workspace_never_collapsed`）。
## 真源=ui-ux-spec A.1/B.5（竖屏：工作区在上永不折叠、员工区折为横滑行、
## 资源栏单行折叠副行；DR-009/015 硬纪律）+ 状态映射总表（工作区行"永不折叠"）。
## 断言：LayoutPolicy.fold_shape 在竖屏下=工作区 FOLD_NONE（硬纪律锚点）、
## 员工区 HSCROLL、资源栏 SUBROW；横屏全 FOLD_NONE；主场景装配按策略切形态
## （MainScene 布局态数据面与策略一致——场景 headless 实例化）。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")


func test_portrait_workspace_never_collapsed() -> void:
	# 竖屏：工作区永不折叠（DR-009/015 硬纪律）；员工区横滑行；资源栏副行
	var portrait := true
	assert_eq(
		LayoutPolicy.fold_shape(LayoutPolicy.ZONE_WORKSPACE, portrait),
		LayoutPolicy.FOLD_NONE,
		"竖屏工作区永不折叠（FOLD_NONE 硬纪律）",
	)
	assert_eq(
		LayoutPolicy.fold_shape(LayoutPolicy.ZONE_STAFF, portrait),
		LayoutPolicy.FOLD_HSCROLL,
		"竖屏员工区=横滑行单行",
	)
	assert_eq(
		LayoutPolicy.fold_shape(LayoutPolicy.ZONE_RESOURCE_BAR, portrait),
		LayoutPolicy.FOLD_SUBROW,
		"竖屏资源栏=单行折叠副行",
	)
	# 横屏：全无折叠（工作区左宽栏/员工区右窄栏形态=容器方向切，非折叠）
	var landscape := false
	for zone: String in [
		LayoutPolicy.ZONE_WORKSPACE,
		LayoutPolicy.ZONE_STAFF,
		LayoutPolicy.ZONE_RESOURCE_BAR,
		LayoutPolicy.ZONE_DOCK,
	]:
		assert_eq(
			LayoutPolicy.fold_shape(zone, landscape), LayoutPolicy.FOLD_NONE, "横屏 %s 无折叠" % zone
		)
	# 竖屏判定（宽<高=竖屏；触屏优先）
	assert_true(LayoutPolicy.is_portrait(375.0, 667.0), "375×667=竖屏")
	assert_false(LayoutPolicy.is_portrait(844.0, 390.0), "844×390=横屏")
	# Dock 竖屏也不折叠（底栏均分常显）
	assert_eq(
		LayoutPolicy.fold_shape(LayoutPolicy.ZONE_DOCK, true),
		LayoutPolicy.FOLD_NONE,
		"竖屏 Dock 不折叠（三键常显底栏）",
	)


func test_main_scene_layout_state_matches_policy() -> void:
	# 主场景装配一致性：MainScene 布局态数据面=LayoutPolicy 同源判定
	# （防装配漂移：形态切换只由策略驱动）
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := main as MainScene
	assert_not_null(scene, "主场景根脚本=MainScene")
	var state: Dictionary = scene.get_layout_state()
	# 视口 1280×720（project 默认）=横屏 → 无折叠
	assert_false(bool(state["portrait"]), "1280×720 判定横屏")
	assert_eq(str(state["workspace_fold"]), LayoutPolicy.FOLD_NONE, "横屏工作区无折叠")
	assert_eq(str(state["staff_fold"]), LayoutPolicy.FOLD_NONE, "横屏员工区无折叠")
	# PanelStack 实例已装配（数据面可取）
	assert_not_null(scene.get_panel_stack(), "PanelStack 装配在位")
	# Dock 三键节点在位且可点（≥48px 由 touch 测试断言）
	assert_not_null(main.get_node_or_null("%DockTask"), "%DockTask 在位")
	assert_not_null(main.get_node_or_null("%DockTree"), "%DockTree 在位")
	assert_not_null(main.get_node_or_null("%DockPause"), "%DockPause 在位")
