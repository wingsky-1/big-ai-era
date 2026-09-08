extends GutTest

## issue #67 暂停菜单栈语义专项测试（PR-δ）：
## test_pause_menu_overlay_rules —— DR-020 遮罩规则：暂停菜单恢复时其余 z2 弹层不关、z1 一律关；
## test_pause_menu_stack_serialization —— 暂停菜单与决策卡同帧到达按信号到达序串行，不叠层。


func test_pause_menu_overlay_rules() -> void:
	# [T] 验收点 2：遮罩规则合规（DR-020）
	var stack := PanelStack.new()
	var mask_states: Array[Array] = []
	stack.mask_state_changed.connect(
		func(visible: bool, dismissable: bool) -> void: mask_states.append([visible, dismissable])
	)

	# 1) 决策卡阻塞期叠加暂停菜单（DR-020 边界态：user_paused 与 blocked_by_card 双源独立）
	stack.push_panel(PanelStack.PanelId.DECISION_CARD)
	stack.push_panel(PanelStack.PanelId.PAUSE_MENU)
	assert_eq(stack.get_z2_stack().size(), 2, "暂停菜单可叠加在决策卡之上（双源暂停互不干扰）")
	var top_state: Array = mask_states.back()
	assert_true(bool(top_state[0]), "暂停菜单置顶时遮罩可见")
	assert_true(bool(top_state[1]), "暂停菜单置顶时遮罩可关（dismissable）")

	# 2) 点击遮罩 = 暂停菜单恢复：其余 z2 弹层不关，遮罩仍在但不再可关
	stack.on_mask_clicked()
	var remaining: Array[PanelStack.PanelId] = stack.get_z2_stack()
	assert_eq(remaining.size(), 1, "遮罩点击只恢复暂停菜单，其余 z2 弹层不关")
	assert_eq(remaining.back(), PanelStack.PanelId.DECISION_CARD, "决策卡仍在场")
	assert_true(stack.has_blocking_panel(), "决策卡在场 → 世界继续停喂 tick")
	var after_state: Array = mask_states.back()
	assert_true(bool(after_state[0]), "决策卡置顶时遮罩仍可见")
	assert_false(bool(after_state[1]), "决策卡置顶时遮罩不可关（强迫处理）")

	# 3) z1 一律关
	stack.pop_panel(PanelStack.PanelId.DECISION_CARD)
	stack.push_panel(PanelStack.PanelId.ROSTER)
	stack.on_mask_clicked()
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.NONE, "z1 常规面板点击遮罩一律关闭")
	var empty_state: Array = mask_states.back()
	assert_false(bool(empty_state[0]), "栈空后遮罩隐藏")

	# 4) 暂停菜单单独在场：遮罩点击恢复并隐藏遮罩
	stack.push_panel(PanelStack.PanelId.PAUSE_MENU)
	stack.on_mask_clicked()
	assert_true(stack.get_z2_stack().is_empty(), "暂停菜单单独在场时点击遮罩恢复关闭")
	assert_true(stack.is_tick_feeding_allowed(), "恢复后世界重新流淌（停喂门控复位）")
	var resumed_state: Array = mask_states.back()
	assert_false(bool(resumed_state[0]), "恢复后遮罩隐藏")


func test_pause_menu_stack_serialization() -> void:
	# [T] 验收点 3：栈序串行（同帧到达按信号到达序，不叠层）
	var stack := PanelStack.new()
	var pushed_order: Array[PanelStack.PanelId] = []
	stack.panel_pushed.connect(
		func(panel: PanelStack.PanelId, _layer: int) -> void: pushed_order.append(panel)
	)

	# 同一帧到达：暂停菜单先、决策卡后（动画锁=同帧多推）
	stack.lock_animation()
	stack.push_panel(PanelStack.PanelId.PAUSE_MENU)
	stack.push_panel(PanelStack.PanelId.DECISION_CARD)
	assert_true(stack.get_z2_stack().is_empty(), "动画锁期间同帧两弹层排队，不叠层")
	assert_eq(pushed_order.size(), 0, "动画锁期间零挂载")

	# 第一周期：只放行先到达的暂停菜单
	stack.unlock_animation()
	assert_eq(pushed_order.size(), 1, "解锁后每周期只放行一个弹层（串行不叠层）")
	assert_eq(pushed_order[0], PanelStack.PanelId.PAUSE_MENU, "先到达的暂停菜单先入场")
	var first_cycle: Array[PanelStack.PanelId] = stack.get_z2_stack()
	assert_eq(first_cycle.size(), 1, "首个周期栈内仅一个 z2 弹层")

	# 第二周期：后到达的决策卡入场（仍按到达序）
	stack.unlock_animation()
	assert_eq(pushed_order.size(), 2, "第二周期才放行后到达者")
	assert_eq(pushed_order[1], PanelStack.PanelId.DECISION_CARD, "后到达的决策卡后入场")
	var second_cycle: Array[PanelStack.PanelId] = stack.get_z2_stack()
	assert_eq(second_cycle.size(), 2, "两弹层分两周期串行入场")
	assert_eq(second_cycle.back(), PanelStack.PanelId.DECISION_CARD, "后入场者置顶")
	assert_true(stack.has_blocking_panel(), "两 z2 弹层在场时停喂门控保持关闭")
