extends GutTest
## 批7.3 #190 指派链路 UI 验收 GUT（补 #189 验收点 4 诚实债——该验收点在
## #189 交付评注中被"文本插值回归"顶位勾选，实体随 #190 本测试落账）：
## - test_assign_flow_ui：员工卡点击（1 击）→ 指派面板行点击（2 击）→
##   assign_staff 命令生效（槽上桌数=1）——OP-STA-04 ≤2 击契约全链；
## - test_naming_dialog_z2_flow：排训练→出分→命名待决→z2 命名弹层自开→
##   提交命名→弹层自收+引导步推进（W 出分命名主循环 UI 全链）。
## 真源：staff-spec OP-STA-04 + ui-ux A.3 OP-UX-05 + issue #189/#190。
## headless 输入模拟不可用——信号直发=契约级驱动（test_main_assembly 同法）。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const TICK_SECONDS: float = 20.0  # 一周（time_wall_clock_1x=20 表驱动）
const MAX_TICKS: int = 12  # mini 4 周完成+周结缓冲；少 tick 防 autosave 写盘放大


func _open_main() -> MainScene:
	var scene := MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene as MainScene


func test_assign_flow_ui() -> void:
	var main := await _open_main()
	var world: Object = main.get_world()
	var area: StaffAreaView = main.get_staff_area_view()
	assert_true(area.has_signal("staff_card_clicked"), "员工区点击中继信号在位")
	# 1 击：员工卡点击 → STAFF_DETAIL 指派面板自动开
	var staff_id := _first_free_staff_id(world)
	assert_false(staff_id.is_empty(), "名册存在员工")
	area.staff_card_clicked.emit(staff_id)
	await get_tree().process_frame
	var stack: PanelStack = main.get_panel_stack()
	assert_true(stack.is_open(PanelStack.PanelId.STAFF_DETAIL), "员工卡点击开指派面板")
	assert_true(main.get_panel_host().is_z1_open(), "z1 遮罩层展开")
	var assign := main.get_panel(PanelStack.PanelId.STAFF_DETAIL) as AssignSheetPanel
	assert_eq(assign.get_staff_id(), staff_id, "面板已锁定目标员工")
	# 面板列 W1 首任务槽（教学接单=IN_PROGRESS）
	var rows := assign.get_body().find_children("*", "Button", true, false)
	assert_true(rows.size() >= 1, "可上桌槽行 ≥1（实际 %d）" % rows.size())
	# 2 击：槽行点击 → assign_staff 命令（无其他调用方）
	(rows[0] as Button).pressed.emit()
	var tasks: Array = world.get_dashboard_view()["tasks"]
	assert_eq(int(tasks[0]["assigned_count"]), 1, "首槽上桌数=1（指派生效）")
	assert_true(
		str(tasks[0]["assigned_staff"][0]) == staff_id,
		"槽上桌成员=目标员工",
	)


func test_naming_dialog_z2_flow() -> void:
	var main := await _open_main()
	var world: Object = main.get_world()
	var commands: Object = world.get_commands()
	# 排训练（mini：4 周完成；命令经 UI 同款 WorldCommands 入口）
	assert_true(bool(commands.start_training("mini").get("ok", false)), "mini 训练入槽")
	# 墙钟推进至训练完成周结（z2 pending 出现即停流——有界循环防死等）
	var ticks := 0
	while not bool(world.has_naming_pending()) and ticks < MAX_TICKS:
		world.tick(TICK_SECONDS)
		ticks += 1
	assert_true(world.has_naming_pending(), "训练完成→命名待决（%d tick）" % ticks)
	# z2 门控：下一帧 main 侧弹层自开（命名框 z2 阻塞）
	await get_tree().process_frame
	var naming := main.get_panel(PanelStack.PanelId.NAMING_DIALOG) as NamingDialogPanel
	assert_true(main.get_panel_host().is_z2_open(), "z2 命名弹层自动展开")
	assert_true(main.get_panel_host().get_z2_panel() == naming, "弹层实例挂阻塞层")
	# 提交命名（NameFilter 全链；中文白名单内）
	naming.submit_text("灵犀一号")
	assert_false(bool(world.has_naming_pending()), "命名落账→pending 解除")
	# 弹层自收（下一帧 gate 翻转）
	await get_tree().process_frame
	assert_false(main.get_panel_host().is_z2_open(), "命名后 z2 弹层自动收起")
	# 引导机推进（出分命名步点亮）
	assert_true(
		int(world.get_machine().get_progress()["current_step"]) >= 4,
		"引导步推进至出分命名步之后",
	)


func _first_free_staff_id(world: Object) -> String:
	var staff: Dictionary = world.get_dashboard_view()["staff"]
	for member: Dictionary in staff.get("staff", []):
		var member_id := str(member.get("id", ""))
		if not member_id.is_empty() and _slot_of(world, member_id) == -1:
			return member_id
	return ""


func _slot_of(world: Object, staff_id: String) -> int:
	for task: Dictionary in world.get_dashboard_view()["tasks"]:
		for member_id: String in task.get("assigned_staff", []):
			if member_id == staff_id:
				return int(task.get("slot_index", -1))
	return -1
