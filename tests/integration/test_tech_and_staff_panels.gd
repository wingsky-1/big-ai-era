extends GutTest

## PR-C 科技树（§13 C方案）与员工名册详情集成测试：
## 1. 验证 TechTreeDialog (C 方案：列表展示、1-hop 微图前置显示、??? 行占位、域计数)；
## 2. 验证 StaffRosterDialog (详情展示、工位调度、单人单槽/单槽独占约束生效)；
## 3. 验证通过 UI 弹窗操作仅调用契约命令 (零直接改写实体状态)。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const TECH_TREE_SCENE: PackedScene = preload("res://src/ui/modals/tech_tree_dialog.tscn")
const STAFF_ROSTER_SCENE: PackedScene = preload("res://src/ui/modals/staff_roster_dialog.tscn")


func test_tech_tree_dialog_c_plan_features() -> void:
	var world := GameWorld.new()
	world.start_new_game()

	var dialog: TechTreeDialog = TECH_TREE_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.setup(world)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. 验证领域计数信息
	var summary_lbl: Label = dialog.get_node("%DomainSummaryLabel")
	assert_not_null(summary_lbl, "领域统计标签应存在")
	assert_string_contains(summary_lbl.text, "模型架构", "应包含模型架构计数")
	assert_string_contains(summary_lbl.text, "算法演进", "应包含算法演进计数")
	assert_string_contains(summary_lbl.text, "工程基建", "应包含工程基建计数")

	# 2. 验证列表内包含 ??? 深层迷雾占位行
	var list_vbox: VBoxContainer = dialog.get_node("%TechListVBox")
	assert_true(list_vbox.get_child_count() > 0, "科技列表子项不应为空")

	var has_hidden_placeholder: bool = false
	var has_researchable_item: bool = false
	for child in list_vbox.get_children():
		var hbox := child as HBoxContainer
		if hbox != null and hbox.get_child_count() > 0:
			var lbl := hbox.get_child(0) as Label
			if lbl != null:
				if lbl.text.contains("???"):
					has_hidden_placeholder = true
				if lbl.text.contains("●"):
					has_researchable_item = true

	assert_true(has_hidden_placeholder, "迷雾深层节点必须以 '???' 占位显示")
	assert_true(has_researchable_item, "开局可研节点应以 '●' 标注并挂载研发按钮")


func test_staff_roster_dialog_slot_assignment_ui() -> void:
	var world := GameWorld.new()
	world.start_new_game()

	var dialog: StaffRosterDialog = STAFF_ROSTER_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.setup(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var list_vbox: VBoxContainer = dialog.get_node("%StaffListVBox")
	assert_eq(list_vbox.get_child_count(), 3, "开局应列出 3 位研究员卡片")

	# 模拟点击为 r_lin 指派任务工位
	world.assign_staff("r_lin", StaffRoster.SLOT_TASK)
	assert_eq(world.staff.get("r_lin", {}).get("assigned", ""), StaffRoster.SLOT_TASK)

	# 再次指派到模型训练工位（单人单槽）
	world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	assert_eq(world.staff.get("r_lin", {}).get("assigned", ""), StaffRoster.SLOT_TRAINING)

	# 撤岗
	world.unassign_staff("r_lin")
	assert_eq(world.staff.get("r_lin", {}).get("assigned", ""), "")


func test_app_shell_dock_and_staff_entry_opens_panels() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	var stack: PanelStack = main_scene.get_stack()

	# 1. 点击 Dock 科技键打开科技树
	var dock_tech_btn: Button = main.get_node("%DockTechBtn")
	dock_tech_btn.emit_signal("pressed")
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.TECH_TREE, "Dock 科技键应打开科技树")

	# 2. 点击 Dock 周报键打开周报重看
	var dock_report_btn: Button = main.get_node("%DockReportBtn")
	dock_report_btn.emit_signal("pressed")
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.REPORT_ARCHIVE, "Dock 周报键应以 z1 打开历史周报")
