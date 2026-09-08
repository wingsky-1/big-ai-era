extends GutTest

## #104 PR-B 训练板 UI 集成（入口可达 + 挂载幂等 + 启动闭环）：
## 1. test_training_entry_button_exists        —— 工作区存在「训练」轻键；Dock 仍为三键（GDD §13）
## 2. test_training_panel_mounts_once_and_returns —— push TRAINING 只挂一个实例，关闭后回收
## 3. test_start_round_trip_starts_training_and_refreshes —— 面板启动 → 契约命令 → 工作区训练行可见（P0-5）
## 4. test_training_command_reachable_from_ui  —— 门禁：`start_training` 必须有 UI 调用方
## 5. test_training_panel_buttons_have_labels  —— 按钮文案必须来自 L2（防空白按钮）

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const UI_MAIN_PATH: String = "res://src/ui/main/main.gd"
const BASES_PATH: String = "res://src/data/model_bases.json"
const FIRST_BASE: String = "base_pushi_1b"


func test_training_entry_button_exists() -> void:
	var main: MainScene = await _boot()
	assert_not_null(main.get_node_or_null("%TrainingBtn"), "工作区应有「训练」轻键（#104 PR-B）")
	assert_not_null(main.get_node_or_null("%TrainingProgressBar"), "工作区应有训练进度条")
	assert_null(main.get_node_or_null("%DockTrainingBtn"), "Dock 必须保持三键（GDD §13 冻结裁决）")


func test_training_panel_mounts_once_and_returns() -> void:
	var main: MainScene = await _boot()
	var stack: PanelStack = main.get_stack()
	stack.push_panel(PanelStack.PanelId.TRAINING)
	await get_tree().process_frame
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.TRAINING, "训练板应挂在 z1")
	assert_eq(_training_modals(main).size(), 1, "应只挂载一个训练板实例")
	stack.push_panel(PanelStack.PanelId.TRAINING)
	await get_tree().process_frame
	assert_eq(_training_modals(main).size(), 1, "同 id 重复 push 不得产生孤儿实例")
	stack.pop_panel(PanelStack.PanelId.TRAINING)
	await get_tree().process_frame
	assert_eq(_training_modals(main).size(), 0, "关闭后应回收实例")


func test_start_round_trip_starts_training_and_refreshes() -> void:
	var main: MainScene = await _boot()
	var world: GameWorld = main.get_world()
	# 前置：研发力 > 0（否则所有基座都会被 zero_research_eff 拒绝）
	var staff_ids: Array = world.staff.keys()
	world.assign_staff(str(staff_ids[0]), StaffRoster.SLOT_TRAINING)
	main.get_stack().push_panel(PanelStack.PanelId.TRAINING)
	await get_tree().process_frame
	var modal: TrainingDialog = _training_modals(main)[0]
	var cost: int = int(DataLoader.load_json(BASES_PATH)[FIRST_BASE]["cost"])
	var money_before: int = world.get_money()
	modal.start_requested.emit(FIRST_BASE)
	await get_tree().process_frame
	assert_true(world.training.is_training(), "启动应经契约命令生效（进入训练态）")
	assert_eq(money_before - world.get_money(), cost, "启动应扣一次成本")
	# 工作区（presenter 视图）必须已刷新（P0-5：启动后可见）
	var ws: Dictionary = main.get_presenter().get_workspace_view()
	assert_false((ws.get("active_training", {}) as Dictionary).is_empty(), "启动后工作区应有进行中训练")
	assert_eq(
		str((ws["active_training"] as Dictionary).get("base_id", "")), FIRST_BASE, "工作区训练与训练态同源"
	)


func test_training_command_reachable_from_ui() -> void:
	# 门禁（#104）：契约命令必须有玩家可达调用方 + 面板必须入栈。
	var source: String = FileAccess.get_file_as_string(UI_MAIN_PATH)
	assert_false(source.is_empty(), "AppShell 源码应可读取")
	assert_true(
		source.contains("world.start_training(") or source.contains("_world.start_training("),
		"start_training 必须由 AppShell 经契约命令调用（#104 P0）"
	)
	assert_true(source.contains("PanelStack.PanelId.TRAINING"), "训练板必须挂在面板栈（z1 TRAINING）")
	assert_true(source.contains("training_btn.pressed.connect"), "训练轻键必须接线到入口")


func test_training_panel_buttons_have_labels() -> void:
	# 回归门禁：数据面漏返回文案键 → 按钮空白（任务板已实测踩到，训练板同源风险）。
	var main: MainScene = await _boot()
	main.get_stack().push_panel(PanelStack.PanelId.TRAINING)
	await get_tree().process_frame
	var modal: TrainingDialog = _training_modals(main)[0]
	var view: Dictionary = main.get_world().get_training_view()
	assert_false(str(view.get("start_label", "")).is_empty(), "L2 训练板必须出启动按钮文案")
	var close_btn: Button = modal.get_node("%TrainingCloseBtn")
	var start_count: int = 0
	for node: Node in modal.find_children("*", "Button", true, false):
		var btn: Button = node as Button
		assert_false(btn.text.is_empty(), "训练板按钮不得空白（文案必须来自 L2）")
		if btn != close_btn:
			start_count += 1
			assert_eq(btn.text, str(view.get("start_label", "")), "启动按钮文案应与数据面一致")
	assert_gt(start_count, 0, "训练板应至少渲染一个启动按钮")


## 启动主场景（headless 下需显式推两帧让 _ready/布局跑完）。
func _boot() -> MainScene:
	var main: MainScene = MAIN_SCENE.instantiate() as MainScene
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


## 当前挂载的训练板实例（经模态容器查找，不碰私有字段）。
func _training_modals(main: MainScene) -> Array[TrainingDialog]:
	var found: Array[TrainingDialog] = []
	var container: Node = main.get_node_or_null("%ModalContainer")
	if container == null:
		return found
	for child: Node in container.get_children():
		if child is TrainingDialog:
			found.append(child as TrainingDialog)
	return found
