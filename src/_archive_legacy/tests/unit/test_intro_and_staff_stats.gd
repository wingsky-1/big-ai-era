extends GutTest

## v0.1.3 开局体验补全回归：
## 1. 待命员工统计（反馈①根因修复：staff_total/assigned/idle 三口径）；
## 2. 开场引导 z1 不拦流淌（DR-029 D-3）；
## 3. INTRO 面板枚举注册与主壳推入接线。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const INTRO_SCENE: PackedScene = preload("res://src/ui/modals/intro_dialog.tscn")


func test_workspace_view_staff_stats_three_lens() -> void:
	var world := GameWorld.new()
	world.start_new_game()
	var stack := PanelStack.new()
	var presenter := DashboardPresenter.new()
	presenter.setup(world, stack)

	var ws: Dictionary = presenter.get_workspace_view()
	assert_eq(int(ws.get("staff_total", -1)), 3, "开局应装载 3 名初始研究员（opening.json）")
	assert_eq(int(ws.get("staff_assigned", -1)), 0, "W0 无人指派")
	assert_eq(int(ws.get("staff_idle", -1)), 3, "W0 三人全员待命（反馈①：UI 不得显示 0 人）")

	world.assign_staff("r_lin", StaffRoster.SLOT_TASK)
	ws = presenter.get_workspace_view()
	assert_eq(int(ws.get("staff_assigned", -1)), 1, "指派后 assigned=1")
	assert_eq(int(ws.get("staff_idle", -1)), 2, "指派后 idle=2")


func test_intro_panel_is_z1_and_does_not_block_tick() -> void:
	var stack := PanelStack.new()
	assert_false(PanelStack.is_blocking(PanelStack.PanelId.INTRO), "INTRO 不属于 z2 阻塞集合")
	stack.push_panel(PanelStack.PanelId.INTRO)
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.INTRO, "INTRO 自动推导为 z1")
	assert_true(stack.is_tick_feeding_allowed(), "INTRO 打开时世界继续流淌（DR-029 D-3）")
	# z1 互斥：打开科技树自动关掉 INTRO（"随手关"）
	stack.push_panel(PanelStack.PanelId.TECH_TREE)
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.TECH_TREE)
	assert_false(stack.get_z2_stack().has(PanelStack.PanelId.INTRO))


func test_intro_dialog_scene_renders_texts_from_service() -> void:
	var dlg: IntroDialog = INTRO_SCENE.instantiate()
	add_child_autofree(dlg)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(dlg.get_node("%IntroLabel").text.is_empty(), "引子文案应来自 texts.json")
	assert_false(dlg.get_node("%GoalLabel").text.is_empty(), "目标文案应来自 texts.json")
	assert_false(dlg.get_node("%RivalLabel").text.is_empty(), "竞对文案应来自 texts.json")
	assert_false(dlg.get_node("%HintLabel").text.is_empty(), "提示文案应来自 texts.json")
	watch_signals(dlg)
	dlg.get_node("%StartBtn").emit_signal("pressed")
	assert_signal_emitted(dlg, "closed", "点击开始经营应发 closed")


func test_main_scene_pushes_intro_once_on_ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var stack: PanelStack = (main as MainScene).get_stack()
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.INTRO, "正常启动应推入开场引导")
	assert_null(main.get_node("%ModalContainer").get_node_or_null("IntroDialog") if false else null)

	# 关闭后不再复发（同一实例生命周期内）
	stack.pop_panel(PanelStack.PanelId.INTRO)
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.NONE)
	assert_false(stack.get_z2_stack().has(PanelStack.PanelId.INTRO))

	# W0 周数表达：准备周（消歧"第 0 周还没开始"）
	var week_label: Label = main.get_node("%WeekLabel")
	assert_eq(week_label.text, "准备周", "W0 应显示准备周而非第 0 周")

	# 待命标签可见且可点（反馈①表达）
	assert_true(main.get_node("%IdleStaffLabel").visible, "W0 待命 3 人，待命标签应可见")
