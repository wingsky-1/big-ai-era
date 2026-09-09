extends GutTest
## #145 验收点 1：PanelStack 注册表——全 z1 面板注册且层级合法 z0<z1<z2<z3
## （GUT：`test_panelstack_registry_complete`）。
## 真源=ui-ux-spec A.2（PanelStack 层级表与注册纪律）+ A8（PanelId 逐批
## 登记：enum 契约先注册，面板实体随批落地）+ architecture §6。
## 断言：PanelId 全量注册（含 z2 弹层/z3 通知）；z_of 分层合法且 ∈[0,3]；
## 全 z1 面板精确集合=ui-ux A.2 z1 行；层级序=注册纪律（栈操作按层）。


func test_panelstack_registry_complete() -> void:
	# 全量注册：z1+z2+z3+MAIN_STAGE 均在 PANEL_Z
	var all_ids: Array[PanelStack.PanelId] = [
		PanelStack.PanelId.MAIN_STAGE,
		PanelStack.PanelId.TASK_BOARD,
		PanelStack.PanelId.TECH_TREE,
		PanelStack.PanelId.STAFF_DETAIL,
		PanelStack.PanelId.PAPER_ARCHIVE,
		PanelStack.PanelId.MODEL_LIBRARY,
		PanelStack.PanelId.CHIP_YARD,
		PanelStack.PanelId.RELIEF_MARKET,
		PanelStack.PanelId.RIVAL_CURVE,
		PanelStack.PanelId.REPORT_ARCHIVE,
		PanelStack.PanelId.PAUSE_MENU,
		PanelStack.PanelId.TARGET_CARD,
		PanelStack.PanelId.DECISION_CARD,
		PanelStack.PanelId.WEEKLY_REPORT,
		PanelStack.PanelId.NAMING_DIALOG,
		PanelStack.PanelId.UNLOCK_POPUP,
		PanelStack.PanelId.TOAST,
	]
	for panel: PanelStack.PanelId in all_ids:
		assert_true(PanelStack.is_registered(panel), "PanelId 注册: %s" % panel)
		var z := PanelStack.z_of(panel)
		assert_true(z >= 0 and z <= 3, "层级 ∈[0,3]: %s→z%d" % [panel, z])
	# 层级合法：MAIN_STAGE=z0、全 z1=1、弹层=2、toast=3
	assert_eq(PanelStack.z_of(PanelStack.PanelId.MAIN_STAGE), 0, "MAIN_STAGE=z0")
	assert_eq(PanelStack.z_of(PanelStack.PanelId.DECISION_CARD), 2, "决策卡=z2")
	assert_eq(PanelStack.z_of(PanelStack.PanelId.TOAST), 3, "toast=z3")
	# 全 z1 精确集合=ui-ux A.2 z1 行（11 面板；P2 项 RECRUIT/COLLECTION/
	# GUIDE_MANUAL 不注册——A8 逐批登记）
	var z1 := PanelStack.all_z1_panels()
	assert_eq(z1.size(), 11, "z1 面板 11 个（ui-ux A.2 P0 落地行）")
	for panel: PanelStack.PanelId in z1:
		assert_eq(PanelStack.z_of(panel), 1, "all_z1_panels 全 z1: %s" % panel)
	# 层级合法性=z0<z1<z2<z3（全序无越级；分步断言防链式比较不支持）
	var z_stage := PanelStack.z_of(PanelStack.PanelId.MAIN_STAGE)
	var z_z1 := PanelStack.z_of(PanelStack.PanelId.TASK_BOARD)
	var z_z2 := PanelStack.z_of(PanelStack.PanelId.DECISION_CARD)
	var z_z3 := PanelStack.z_of(PanelStack.PanelId.TOAST)
	assert_true(z_stage < z_z1 and z_z1 < z_z2 and z_z2 < z_z3, "层级全序 z0<z1<z2<z3")


func test_panelstack_stack_semantics() -> void:
	# 栈操作语义（open/close/back/同层互斥/z2 阻塞）——注册表机制可操作
	var stack := PanelStack.new()
	# z1 开合
	assert_true(stack.open(PanelStack.PanelId.TASK_BOARD).ok, "z1 可开")
	assert_true(stack.is_open(PanelStack.PanelId.TASK_BOARD), "开后在栈")
	assert_eq(stack.top(), PanelStack.PanelId.TASK_BOARD, "顶层=TASK_BOARD")
	# 同层互斥：开 TECH_TREE 关 TASK_BOARD（同层新开旧关）
	stack.open(PanelStack.PanelId.TECH_TREE)
	assert_false(stack.is_open(PanelStack.PanelId.TASK_BOARD), "同层互斥（旧 z1 关）")
	assert_true(stack.is_open(PanelStack.PanelId.TECH_TREE), "新 z1 开")
	# z2 阻塞：决策卡开 → 新 z1 被拒（世界等待）
	stack.open(PanelStack.PanelId.DECISION_CARD)
	assert_true(stack.has_blocking_top(), "z2 顶层=阻塞")
	var blocked := stack.open(PanelStack.PanelId.PAUSE_MENU)
	assert_false(blocked.ok, "z2 阻塞期 z1 不可开")
	assert_eq(blocked.reason, "blocked_by_z2", "拒绝原因=blocked_by_z2")
	# back 关顶层（决策卡）；MAIN_STAGE/TOAST 不入栈（常显/通知层）
	stack.back()
	assert_false(stack.is_open(PanelStack.PanelId.DECISION_CARD), "back 关顶层")
	assert_false(stack.open(PanelStack.PanelId.MAIN_STAGE).ok, "MAIN_STAGE 不入栈（常显层）")
	assert_false(stack.open(PanelStack.PanelId.TOAST).ok, "TOAST 不入栈（通知层）")
	# close 未开面板=false
	assert_false(stack.close(PanelStack.PanelId.WEEKLY_REPORT), "close 未开=防御 false")
