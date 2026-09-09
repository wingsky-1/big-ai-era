extends GutTest
## 批7.2 #189 验收点 GUT（L3 接线：四区 bind 数据可见 / Dock 面板栈 / 目标卡带 /
## 文本插值断链回归）：
## - test_main_assembly_bound：headless 实例化主场景，四区 bind 后数据可见
##   （槽卡/员工卡/资源栏/竞对灯有内容）
## - test_dock_panels_open：Dock 三键 open z1 面板（PanelStack 栈语义）
## - test_goal_card_band_refresh：目标卡带渲染 GoalCard view（6 点+周数）
## - test_text_interpolation_regression：texts.json 27 键占位对齐 <X>/<Y> 契约
##   形态后 TextService 断链为空（既有 test_text_service 同源兜底）
## 真源：ui-ux-spec A.1/B.2 + issue #189 验收点 + ADR-0016（L3 禁读表）。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")


func test_main_assembly_bound() -> void:
	var scene := MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var main := scene as MainScene
	# 四区视图在位且 bind 后无崩溃（World 已注入：main._ready 动态构造）
	assert_true(main.get_world() != null, "World 组合根已注入")
	assert_true(main.get_workspace_view() != null, "工作区视图在位")
	assert_true(main.get_staff_area_view() != null, "员工区视图在位")
	assert_true(main.get_resource_bar_view() != null, "资源栏视图在位")
	assert_true(main.get_rival_light_entry() != null, "竞对灯在位")
	# 世界数据面可读（开局后：接单步已点亮（start_new_game 即 advance W1），
	# 当前步=点树（1））
	var world: Object = main.get_world()
	var dashboard: Dictionary = world.get_dashboard_view()
	var goal: Dictionary = dashboard["goal_card"]
	assert_eq(int(goal["step_index"]), 1, "开局接单步点亮→当前步=点树")
	assert_true(int(dashboard["resources"]["cash"]) > 0, "资源栏现金>0（eco_startup_cash 表驱动）")


func test_dock_panels_open() -> void:
	var scene := MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	var main := scene as MainScene
	var stack: PanelStack = main.get_panel_stack()
	# Dock 三键=冻结集合（ui-ux A.2 纪律；增键=变更控制）
	assert_eq(
		PanelStack.DOCK_KEYS,
		[
			PanelStack.PanelId.TASK_BOARD,
			PanelStack.PanelId.TECH_TREE,
			PanelStack.PanelId.PAUSE_MENU
		],
		"Dock 三键冻结集",
	)
	# open 栈语义（A8：面板实体未落地=防御拒绝不崩；栈操作正常）
	var result: Dictionary = stack.open(PanelStack.PanelId.TASK_BOARD)
	assert_true(bool(result.get("ok", false)), "TASK_BOARD open 入栈")
	assert_true(stack.is_open(PanelStack.PanelId.TASK_BOARD), "面板在栈")
	assert_eq(stack.top(), PanelStack.PanelId.TASK_BOARD, "顶层=TASK_BOARD")
	# 同层互斥：开 TECH_TREE 顶掉 TASK_BOARD
	stack.open(PanelStack.PanelId.TECH_TREE)
	assert_false(stack.is_open(PanelStack.PanelId.TASK_BOARD), "同层互斥（旧 z1 关）")
	assert_true(stack.is_open(PanelStack.PanelId.TECH_TREE), "新 z1 在栈")
	# back 返回
	assert_true(stack.back(), "back 关顶层")
	assert_false(stack.is_open(PanelStack.PanelId.TECH_TREE), "back 后面板已关")


func test_goal_card_band_refresh() -> void:
	var band := preload("res://src/ui/widgets/goal_card_band.gd").new()
	add_child_autofree(band)
	await get_tree().process_frame
	# 正常态：6 点进度+目标句+周数（GoalCard view 同构）
	(
		band
		. refresh(
			{
				"all_done": false,
				"total_steps": 6,
				"completed_count": 2,
				"goal_key": "onb_goal_3",
				"weeks_hint": 3,
			}
		)
	)
	assert_eq(band.get_goal_key(), "onb_goal_3", "目标键透传")
	# 空态：全完成=隐藏内容（B.2 空态）
	band.refresh(
		{"all_done": true, "total_steps": 6, "completed_count": 6, "goal_key": "", "weeks_hint": 0}
	)
	assert_eq(band.get_goal_key(), "", "空态无目标键")


func test_text_interpolation_regression() -> void:
	# 27 键裸占位对齐 <X>/<Y> 契约形态（texts-keys.md 契约）后断链为空：
	# TextService 已注册 X/Y；分数/年份格式（XX.X/202X）不受误伤
	var broken := TextService.missing_interp_variables()
	assert_true(broken.is_empty(), "含插值键断链为空: %s" % str(broken))
	# 契约形态抽查：onb_week_hint 走 format 可插值（批7.2 首消费）
	var hint := TextService.format("onb_week_hint", {"X": "3"})
	assert_eq(hint, "约再跑 3 周", "onb_week_hint 插值正确")
	# 误伤排除抽查：分数模板保持原样（XX.X 非插值占位）
	var score_template: String = TextService.text("model_score_title")
	assert_true(score_template.contains("XX.X"), "分数格式模板未误伤: %s" % score_template)
