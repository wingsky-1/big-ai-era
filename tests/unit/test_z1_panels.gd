extends GutTest
## 批7.3 #190 z1/z2 面板实体 GUT（三键面板内容/目标卡详情/宿主遮罩语义/
## 工厂登记——对应 issue #190 [T]1 最小 UI 交互面 + A8 落地登记）：
## - test_panel_scripts_registered：6 面板登记与脚本路径（A8 增量登记面）
## - test_dock_panels_render_content：三键各开面板=挂载+z1 遮罩+内容行
## - test_pause_menu_speed_save：变速轮转/暂停命令经面板按钮生效
## - test_target_card_panel_detail：目标卡详情（detail_key+周提示插值）
## - test_panel_host_z1_backdrop：z1 遮罩点外关闭（close_z1+栈回退）
## 真源：ui-ux A.2 z1/z2 语义 + issue #190/#189 验收点 + ADR-0016。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const HOST_SCRIPT: GDScript = preload("res://src/ui/panels/panel_host.gd")


func _open_main() -> MainScene:
	var scene := MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene as MainScene


func test_panel_scripts_registered() -> void:
	# A8 登记：#190 落地 6 面板（Dock 三键+STAFF_DETAIL/TARGET_CARD/NAMING_DIALOG）
	assert_true(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.TASK_BOARD, false)),
		"TASK_BOARD 已登记落地",
	)
	assert_true(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.TECH_TREE, false)),
		"TECH_TREE 已登记落地",
	)
	assert_true(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.PAUSE_MENU, false)),
		"PAUSE_MENU 已登记落地",
	)
	assert_true(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.STAFF_DETAIL, false)),
		"STAFF_DETAIL 已登记落地",
	)
	assert_true(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.TARGET_CARD, false)),
		"TARGET_CARD 已登记落地",
	)
	assert_true(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.NAMING_DIALOG, false)),
		"NAMING_DIALOG 已登记落地",
	)
	# 未落地面板不入表（PAPER_ARCHIVE 等仍为后批）
	assert_false(
		bool(PanelStack.PANEL_IMPLEMENTED.get(PanelStack.PanelId.PAPER_ARCHIVE, false)),
		"PAPER_ARCHIVE 未落地不登记",
	)


func test_dock_panels_render_content() -> void:
	var main := await _open_main()
	var host: PanelHost = main.get_panel_host()
	# Dock 三键逐一开面板：z1 遮罩展开+实例挂载（同层互斥换面板）
	for panel_id: PanelStack.PanelId in [
		PanelStack.PanelId.TASK_BOARD,
		PanelStack.PanelId.TECH_TREE,
		PanelStack.PanelId.PAUSE_MENU,
	]:
		main.get_panel(panel_id).refresh()
		host.show_z1(main.get_panel(panel_id))
		await get_tree().process_frame
		assert_true(host.is_z1_open(), "%s z1 展开" % PanelStack.PanelId.keys()[panel_id])
		assert_true(host.get_z1_panel() != null, "%s 实例挂载" % PanelStack.PanelId.keys()[panel_id])
	# 任务板内容：W1 教学接单后=在跑槽摘要行非空
	var task_panel := main.get_panel(PanelStack.PanelId.TASK_BOARD) as TaskBoardPanel
	task_panel.refresh()
	assert_false(
		task_panel.get_body().find_children("*", "Label", true, false).is_empty(), "任务板含标签内容"
	)


func test_pause_menu_speed_save() -> void:
	var main := await _open_main()
	var panel := main.get_panel(PanelStack.PanelId.PAUSE_MENU) as PauseMenuPanel
	panel.refresh()
	# 初始 1x（speed_index=0）
	var clock: Dictionary = main.get_world().get_dashboard_view()["clock"]
	assert_eq(int(clock["speed_index"]), 0, "开局 1x")
	# 变速钮（面板内首个按钮）→ 2x
	var buttons := panel.get_body().find_children("*", "Button", true, false)
	assert_true(buttons.size() >= 3, "暂停面板三按钮（变速/暂停/存档）")
	(buttons[0] as Button).pressed.emit()
	clock = main.get_world().get_dashboard_view()["clock"]
	assert_eq(int(clock["speed_index"]), 1, "变速钮→2x")
	# 暂停钮 → user_paused 翻转
	(buttons[1] as Button).pressed.emit()
	clock = main.get_world().get_dashboard_view()["clock"]
	assert_true(bool(clock["user_paused"]), "暂停钮→已暂停")
	(buttons[1] as Button).pressed.emit()
	clock = main.get_world().get_dashboard_view()["clock"]
	assert_false(bool(clock["user_paused"]), "再按→继续")


func test_target_card_panel_detail() -> void:
	var main := await _open_main()
	var panel := main.get_panel(PanelStack.PanelId.TARGET_CARD) as TargetCardPanel
	panel.refresh()
	# W1 当前步=点树（1）：详情句+周提示插值（onb_week_hint <X> 替换）
	var labels := panel.get_body().find_children("*", "Label", true, false)
	assert_true(labels.size() >= 2, "详情+周提示两行")
	var detail := (labels[0] as Label).text
	assert_false(detail.is_empty(), "详情句非空")
	var hint := (labels[1] as Label).text
	assert_false(hint.contains("<X>"), "周提示插值已替换: %s" % hint)


func test_panel_host_z1_backdrop() -> void:
	var host: PanelHost = HOST_SCRIPT.new()
	add_child_autofree(host)
	var panel := ZPanel.new()
	panel.name = "ProbePanel"
	add_child_autofree(panel)
	host.show_z1(panel)
	assert_true(host.is_z1_open(), "z1 展开")
	assert_true(host.get_z1_panel() == panel, "z1 挂载探针面板")
	host.close_z1()
	assert_false(host.is_z1_open(), "close_z1 收层")
	assert_true(host.get_z1_panel() == null, "层空无挂载")
	# z2 点外不关：遮罩点击无信号路径（分层语义，装配方 main 消费）
	host.show_z2(panel)
	assert_true(host.is_z2_open(), "z2 展开")
	assert_true(host.get_z2_panel() == panel, "z2 挂载探针面板")
	host.close_z2()
	assert_false(host.is_z2_open(), "z2 收起（仅显式路径）")
