extends GutTest

## #104 任务板 UI 集成（入口可达 + 挂载幂等 + 接单闭环）：
## 1. test_task_entry_button_exists            —— 工作区存在「接单」轻键；Dock 仍为三键（GDD §13）
## 2. test_task_panel_mounts_once_and_returns  —— push TASK_MGMT 只挂一个实例，关闭后回收
## 3. test_accept_round_trip_enqueues_and_refreshes —— 面板接单 → 契约命令 → 工作区刷新（P0-4）
## 4. test_task_command_reachable_from_ui      —— 门禁：`enqueue_task` 必须有 UI 调用方（防 #104 复现）

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const UI_MAIN_PATH: String = "res://src/ui/main/main.gd"


func test_task_entry_button_exists() -> void:
	var main: MainScene = await _boot()
	assert_not_null(main.get_node_or_null("%TaskAcceptBtn"), "工作区应有「接单」轻键（#104 P0）")
	assert_null(main.get_node_or_null("%DockTaskBtn"), "Dock 必须保持三键（GDD §13 冻结裁决）")


func test_task_panel_mounts_once_and_returns() -> void:
	var main: MainScene = await _boot()
	var stack: PanelStack = main.get_stack()
	stack.push_panel(PanelStack.PanelId.TASK_MGMT)
	await get_tree().process_frame
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.TASK_MGMT, "任务板应挂在 z1")
	assert_eq(_task_modals(main).size(), 1, "应只挂载一个任务板实例")
	stack.push_panel(PanelStack.PanelId.TASK_MGMT)
	await get_tree().process_frame
	assert_eq(_task_modals(main).size(), 1, "同 id 重复 push 不得产生孤儿实例")
	stack.pop_panel(PanelStack.PanelId.TASK_MGMT)
	await get_tree().process_frame
	assert_eq(_task_modals(main).size(), 0, "关闭后应回收实例")


func test_accept_round_trip_enqueues_and_refreshes() -> void:
	var main: MainScene = await _boot()
	var world: GameWorld = main.get_world()
	var stack: PanelStack = main.get_stack()
	stack.push_panel(PanelStack.PanelId.TASK_MGMT)
	await get_tree().process_frame
	var modal: TaskManageDialog = _task_modals(main)[0]
	var money_before: int = world.get_money()
	# 模拟玩家点「接单」：面板只发信号，AppShell 调契约命令
	modal.accept_requested.emit("task_reproduce_paper_0")
	await get_tree().process_frame
	var active: Dictionary = world.task_queue.get_active_task()
	assert_eq(str(active.get("task_id", "")), "task_reproduce_paper_0", "接单应经契约命令生效（进行中任务）")
	assert_eq(world.get_money(), money_before, "零成本任务不应扣款")
	# 工作区（presenter 视图）必须已刷新（P0-4：接单后可见）
	var ws: Dictionary = main.get_presenter().get_workspace_view()
	assert_false((ws.get("active_task", {}) as Dictionary).is_empty(), "接单后工作区应有进行中任务")
	assert_eq(
		str((ws["active_task"] as Dictionary).get("task_id", "")),
		"task_reproduce_paper_0",
		"工作区任务与队列同源"
	)


func test_task_command_reachable_from_ui() -> void:
	# 门禁（#104）：契约命令必须有玩家可达调用方 + 面板必须入栈；防止"信号/命令零调用方"再次发生。
	var source: String = FileAccess.get_file_as_string(UI_MAIN_PATH)
	assert_false(source.is_empty(), "AppShell 源码应可读取")
	assert_true(
		source.contains("world.enqueue_task(") or source.contains("_world.enqueue_task("),
		"enqueue_task 必须由 AppShell 经契约命令调用（#104 P0）"
	)
	assert_true(source.contains("PanelStack.PanelId.TASK_MGMT"), "任务板必须挂在面板栈（z1 TASK_MGMT）")
	assert_true(source.contains("task_accept_btn.pressed.connect"), "接单轻键必须接线到入口")


func test_panel_buttons_have_labels() -> void:
	# 回归门禁：数据面漏返回文案键 → 按钮空白（本轮实测踩到：accept_label 未进 view）。
	var main: MainScene = await _boot()
	main.get_stack().push_panel(PanelStack.PanelId.TASK_MGMT)
	await get_tree().process_frame
	var modal: TaskManageDialog = _task_modals(main)[0]
	var view: Dictionary = main.get_world().get_task_board_view()
	assert_false(str(view.get("accept_label", "")).is_empty(), "L2 任务板必须出接单按钮文案")
	var close_btn: Button = modal.get_node("%TaskBoardCloseBtn")
	var accept_count: int = 0
	for node: Node in modal.find_children("*", "Button", true, false):
		var btn: Button = node as Button
		assert_false(btn.text.is_empty(), "任务板按钮不得空白（文案必须来自 L2）")
		if btn != close_btn:
			accept_count += 1
			assert_eq(btn.text, str(view.get("accept_label", "")), "接单按钮文案应与数据面一致")
	assert_gt(accept_count, 0, "任务板应至少渲染一个接单按钮")


## 启动主场景（headless 下需显式推两帧让 _ready/布局跑完）。
func _boot() -> MainScene:
	var main: MainScene = MAIN_SCENE.instantiate() as MainScene
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


## 当前挂载的任务板实例（经模态容器查找，不碰私有字段）。
func _task_modals(main: MainScene) -> Array[TaskManageDialog]:
	var found: Array[TaskManageDialog] = []
	var container: Node = main.get_node_or_null("%ModalContainer")
	if container == null:
		return found
	for child: Node in container.get_children():
		if child is TaskManageDialog:
			found.append(child as TaskManageDialog)
	return found
