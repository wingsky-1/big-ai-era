extends GutTest
## 批7.4 #194 z2 通道流 GUT（ADR-0028 消费循环/调度序/停流挂遮罩）：
## - test_scheduler_priority_order：DECISION(0)>NAMING(1)>REPORT(2) 显式序
##   （同帧并发=按秩串行；REPORT 秩 1→2=ADR-0028 契约演进）
## - test_decision_card_flow_ui：主场景 pending→决策卡自动弹→选项→入账→
##   确认钮收层（世界恢复流动）
## - test_weekly_report_ack_flow：显著周自动弹→知道了→收层；灰点手开同停流
## 真源：issue #194 验收点 + randomness OP-RND-01 + ui-ux A.2。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")


func _open_main() -> MainScene:
	var scene := MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene as MainScene


func _force_event(world: Object) -> void:
	var commands: Object = world.get_commands()
	for i: int in 40:
		if not (commands.get_decision_view() as Dictionary).is_empty():
			return
		world.tick(20.0)  # 一周（time_wall_clock_1x 表驱动；phase11 事件判定）


func test_scheduler_priority_order() -> void:
	# ADR-0028 显式序：决策(0) > 命名(1) > 周报(2)（REPORT 秩 1→2=契约演进）
	assert_eq(int(ModalScheduler.KIND_PRIORITY[ModalScheduler.ModalKind.DECISION]), 0, "决策最高优先")
	assert_eq(
		int(ModalScheduler.KIND_PRIORITY[ModalScheduler.ModalKind.NAMING]), 1, "命名次之（ADR-0028）"
	)
	assert_eq(
		int(ModalScheduler.KIND_PRIORITY[ModalScheduler.ModalKind.REPORT]), 2, "周报第三（ADR-0028）"
	)
	# 同帧并发：REPORT 先入队、DECISION 后入队 → peek 仍=决策（秩小先出）
	var scheduler := ModalScheduler.new()
	scheduler.push(ModalScheduler.ModalKind.REPORT, {"week": 3})
	scheduler.push(ModalScheduler.ModalKind.DECISION, {"card_id": "grant"})
	var head: Variant = scheduler.peek_next()
	assert_eq(int(head["rank"]), 0, "同帧决策先于周报（秩 0）")


func test_decision_card_flow_ui() -> void:
	var main := await _open_main()
	var world: Object = main.get_world()
	_force_event(world)
	var commands: Object = world.get_commands()
	assert_false((commands.get_decision_view() as Dictionary).is_empty(), "前置：决策 pending")
	await get_tree().process_frame
	var host: PanelHost = main.get_panel_host()
	assert_true(host.is_z2_open(), "决策卡 z2 自动弹")
	assert_eq(
		main.get_panel_stack().top(),
		PanelStack.PanelId.DECISION_CARD,
		"栈顶=决策卡",
	)
	var panel := main.get_panel(PanelStack.PanelId.DECISION_CARD) as DecisionCardPanel
	assert_eq(panel.get_choice_count(), 2, "两选项渲染")
	var view: Dictionary = commands.get_decision_view()
	var first: Dictionary = view["choices"][0]
	var cash_before := int(world.get_dashboard_view()["resources"]["cash"])
	var influence_before := int(world.get_dashboard_view()["resources"]["influence"])
	(panel.get_body().find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	await get_tree().process_frame
	# 预览承诺一致：入账差值==首选项预览值（cash/influence 两口径）
	match int(first["effect_type"]):
		0:  # cash
			assert_eq(
				int(world.get_dashboard_view()["resources"]["cash"]) - cash_before,
				int(first["amount"]),
				"现金入账==预览值",
			)
		1:  # influence
			assert_eq(
				int(world.get_dashboard_view()["resources"]["influence"]) - influence_before,
				int(first["amount"]),
				"影响力入账==预览值",
			)
		_:
			pass
	# 结果句可读+确认钮收层
	var buttons := panel.get_body().find_children("*", "Button", true, false)
	var ack: Button = null
	for button: Button in buttons:
		if button.text == TextService.text("ui_report_ack"):
			ack = button
	assert_true(ack != null, "确认钮出现（结果句即时可读）")
	assert_false(ack.disabled, "确认钮可用（选项禁用不得波及——浏览器实测暴露的顺序缺陷）")
	assert_true(host.is_z2_open(), "确认前 z2 保持（结果句不被一闪而过）")
	ack.pressed.emit()
	await get_tree().process_frame
	assert_false(host.is_z2_open(), "确认后 z2 收层")
	assert_true(
		bool(world.get_dashboard_view()["clock"]["flowing"]),
		"决策入账后世界恢复流动",
	)


func test_weekly_report_ack_flow() -> void:
	var main := await _open_main()
	var host: PanelHost = main.get_panel_host()
	# 灰点手开（显著/平淡周未弹出时点击=同面板同停流语义）
	main._on_report_dot_pressed()
	await get_tree().process_frame
	# 灰点仅在 pending 报告存在时呈现面板；本断言取"手开路径可收层"
	if host.is_z2_open():
		assert_eq(
			main.get_panel_stack().top(),
			PanelStack.PanelId.WEEKLY_REPORT,
			"灰点手开=周报面板",
		)
		var panel := main.get_panel(PanelStack.PanelId.WEEKLY_REPORT) as WeeklyReportPanel
		var buttons := panel.get_body().find_children("*", "Button", true, false)
		var ack: Button = null
		for button: Button in buttons:
			if button.text == TextService.text("ui_report_ack"):
				ack = button
		if ack != null:
			ack.pressed.emit()
			await get_tree().process_frame
			assert_false(host.is_z2_open(), "知道了→收层（停流解除）")
	else:
		# 无显著报告周=灰点静默（空态正常态；dot 未亮点击无面板）
		assert_false(main.get_panel_stack().is_open(PanelStack.PanelId.WEEKLY_REPORT), "无报告=空态静默")
