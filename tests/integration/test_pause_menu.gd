extends GutTest

## issue #67 暂停菜单面板挂载集成测试（PR-δ）：
## test_pause_menu_panel_renders —— 点 Dock「暂停」→ 面板真实渲染「继续 / 重开 / 设置」三入口，
## 且 GameClock.paused 置位；根因回归：PANEL_PAUSE_MENU 入栈但 main.gd 无挂载分支。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")


func test_pause_menu_panel_renders() -> void:
	# [T] 验收点 1：面板真实渲染 + 暂停真值置位
	var main: MainScene = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var stack: PanelStack = main.get_stack()
	var world: GameWorld = main.get_world()
	# 开局引导（z1 INTRO）先关掉，让渲染证据只针对暂停菜单
	stack.pop_panel(PanelStack.PanelId.INTRO)
	await get_tree().process_frame
	assert_false(world.get_clock().paused, "前置态：开局未暂停")

	# 用户操作：点 Dock「暂停」
	var dock_pause_btn: Button = main.get_node("%DockPauseBtn")
	dock_pause_btn.emit_signal("pressed")
	await get_tree().process_frame

	# 1) 栈状态 + GameClock.paused 唯一源置位
	var z2: Array[PanelStack.PanelId] = stack.get_z2_stack()
	assert_eq(z2.size(), 1, "点暂停 → z2 栈内恰好一个面板")
	assert_eq(z2.back(), PanelStack.PanelId.PAUSE_MENU, "点暂停 → PAUSE_MENU 入栈")
	assert_true(world.get_clock().paused, "GameClock.paused 必须置位（用户暂停）")

	# 2) 面板真实挂载（#67 根因：缺挂载分支 → 只有遮罩没有面板）
	var dialog: PauseMenuDialog = _find_pause_dialog(main)
	assert_not_null(dialog, "ModalContainer 中必须挂载 PauseMenuDialog 实例（#67 缺失的挂载分支）")
	if dialog == null:
		return
	assert_true(dialog.visible, "暂停菜单面板必须真实可见")

	var title_label: Label = dialog.get_node("%TitleLabel")
	assert_eq(title_label.text, "已暂停", "标题常显'已暂停'（世界停了）")

	# 3) 三入口渲染（继续 / 重开 / 设置）
	var continue_btn: Button = dialog.get_node("%ContinueBtn")
	var restart_btn: Button = dialog.get_node("%RestartBtn")
	var settings_btn: Button = dialog.get_node("%SettingsBtn")
	assert_eq(continue_btn.text, "继续", "第一入口=继续")
	assert_eq(restart_btn.text, "重开", "第二入口=重开")
	assert_eq(settings_btn.text, "设置", "第三入口=设置")
	for btn: Button in [continue_btn, restart_btn, settings_btn]:
		assert_true(btn.visible, "入口必须可见: %s" % btn.name)
		assert_true(btn.custom_minimum_size.y >= 48.0, "触屏目标 ≥48px: %s" % btn.name)

	# 4) z2 遮罩在场（可关语义由 panel_stack 既有用例锁定）
	var mask: ColorRect = _find_mask(main)
	assert_not_null(mask, "z2 弹层应挂遮罩")
	if mask != null:
		assert_true(mask.visible, "暂停菜单在场时遮罩可见")

	# 5) 可观察终态：点「继续」→ 面板出栈释放 + 世界恢复流淌
	continue_btn.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(stack.get_z2_stack().is_empty(), "点继续 → PAUSE_MENU 出栈")
	assert_false(world.get_clock().paused, "点继续 → 恢复流淌（user_paused 归零）")
	assert_null(_find_pause_dialog(main), "面板实例随出栈释放")


func test_pause_menu_esc_and_mask_dismiss_resume_world() -> void:
	# 映射表 §2 PAUSE_MENU 行契约："Esc 可关、遮罩可关"——两条关闭路径都必须恢复流淌
	var main: MainScene = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var stack: PanelStack = main.get_stack()
	var world: GameWorld = main.get_world()
	stack.pop_panel(PanelStack.PanelId.INTRO)
	await get_tree().process_frame
	var dock_pause_btn: Button = main.get_node("%DockPauseBtn")

	# 1) Esc 关：ui_cancel 直达弹层 _unhandled_input（headless 禁 Input 单例，故直调虚方法）
	dock_pause_btn.emit_signal("pressed")
	await get_tree().process_frame
	var dialog: PauseMenuDialog = _find_pause_dialog(main)
	assert_not_null(dialog, "Esc 路径前置：暂停菜单已挂载")
	if dialog == null:
		return
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	dialog._unhandled_input(cancel)
	await get_tree().process_frame
	assert_true(stack.get_z2_stack().is_empty(), "Esc → 暂停菜单出栈")
	assert_false(world.get_clock().paused, "Esc → 恢复流淌")

	# 2) 遮罩关：点击遮罩同样恢复（DR-020 暂停菜单可关语义）
	dock_pause_btn.emit_signal("pressed")
	await get_tree().process_frame
	assert_eq(stack.get_z2_stack().size(), 1, "再次点暂停键 → 面板重新入栈")
	var mask: ColorRect = _find_mask(main)
	assert_not_null(mask, "z2 弹层应挂遮罩")
	if mask == null:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	mask.gui_input.emit(click)
	await get_tree().process_frame
	assert_true(stack.get_z2_stack().is_empty(), "点遮罩 → 暂停菜单出栈")
	assert_false(world.get_clock().paused, "点遮罩 → 恢复流淌")

	# 3) 幂等：同帧重复点 Dock 暂停键只入栈一次（防 z2 同 id 双挂载泄漏）
	dock_pause_btn.emit_signal("pressed")
	dock_pause_btn.emit_signal("pressed")
	await get_tree().process_frame
	assert_eq(stack.get_z2_stack().size(), 1, "重复点暂停键只入栈一次")


func _find_pause_dialog(main: MainScene) -> PauseMenuDialog:
	var container: Control = main.get_node("%ModalContainer")
	for child in container.get_children():
		if child is PauseMenuDialog:
			return child as PauseMenuDialog
	return null


func _find_mask(main: MainScene) -> ColorRect:
	var container: Control = main.get_node("%ModalContainer")
	for child in container.get_children():
		if child is ColorRect:
			return child as ColorRect
	return null
