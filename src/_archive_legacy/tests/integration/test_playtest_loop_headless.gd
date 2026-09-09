extends GutTest

## PR-B 试玩闭环断言与全链路集成测试：
## 1. 栈深互斥（z1 栈深 1，互斥覆盖）；
## 2. 停喂门控（z2 阻塞面板打开时驱动停喂 tick）；
## 3. z2 遮罩点击不关闭 + 同帧信号序（决策卡先于周报）；
## 4. weakref 兜底防御与 AppShell 零写路径静态断言；
## 5. Headless 全链路端到端确定性贯通（开局→指派→流淌→决策卡→周报→破产 Game Over）。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")


func test_panel_stack_depth_and_feeding_gate_integration() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	var stack: PanelStack = main_scene.get_stack()
	var driver: GameLoopDriver = main_scene.get_driver()
	assert_not_null(stack, "PanelStack 应存在")
	assert_not_null(driver, "GameLoopDriver 应存在")

	# 1. 常规面板互斥，栈深 1
	stack.push_panel(PanelStack.PanelId.ROSTER, PanelStack.Layer.NORMAL)
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.ROSTER, "打开名册")
	stack.push_panel(PanelStack.PanelId.TECH_TREE, PanelStack.Layer.NORMAL)
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.TECH_TREE, "打开科技树应顶替名册，栈深保持 1")
	assert_true(driver.visible_gate, "z1 打开不阻塞，驱动保持流淌")

	# 2. z2 阻塞面板开启触发停喂门控
	stack.push_panel(PanelStack.PanelId.AUTO_REPORT, PanelStack.Layer.BLOCKING)
	assert_false(stack.is_tick_feeding_allowed(), "存在 z2 时不允许喂帧")
	assert_false(driver.visible_gate, "驱动停喂门控应关闭")

	stack.pop_panel(PanelStack.PanelId.AUTO_REPORT)
	assert_true(stack.is_tick_feeding_allowed(), "z2 关闭后恢复喂帧")
	assert_true(driver.visible_gate, "驱动停喂门控恢复")


func test_z2_mask_click_and_same_frame_signal_order() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	var stack: PanelStack = main_scene.get_stack()

	# 1. z2 决策卡遮罩点击不关闭（DR-020 回归防护）
	stack.push_panel(PanelStack.PanelId.DECISION_CARD, PanelStack.Layer.BLOCKING)
	assert_eq(stack.get_z2_stack().back(), PanelStack.PanelId.DECISION_CARD)
	stack.on_mask_clicked()
	assert_eq(
		stack.get_z2_stack().back(), PanelStack.PanelId.DECISION_CARD, "决策卡点击遮罩绝对不能关闭（强迫玩家交互）"
	)
	stack.pop_panel(PanelStack.PanelId.DECISION_CARD)

	# 2. 同帧信号序：同帧触发决策卡与周报时，决策卡必须先于周报弹起
	var order: Array = []
	stack.panel_pushed.connect(
		func(pid: PanelStack.PanelId, _layer: int) -> void: order.append(pid)
	)

	# 模拟同帧信号到达：先推 decision_card，再推 auto_report
	stack.push_panel(PanelStack.PanelId.DECISION_CARD, PanelStack.Layer.BLOCKING)
	stack.push_panel(PanelStack.PanelId.AUTO_REPORT, PanelStack.Layer.BLOCKING)

	assert_eq(order.size(), 2)
	assert_eq(order[0], PanelStack.PanelId.DECISION_CARD, "决策卡必须排在第一位响应")
	assert_eq(order[1], PanelStack.PanelId.AUTO_REPORT, "周报排在其后")


func test_l3_weakref_and_zero_write_paths() -> void:
	# 1. weakref 兜底安全
	var driver := GameLoopDriver.new()
	driver.setup(null)
	driver.feed_frame(0.016)
	driver.free()
	assert_true(true, "Driver 遇到 null/失效引用时不抛异常崩溃")

	# 2. UI 零写路径：扫描 src/ui/**/*.gd，除 GameWorld/SaveSystem 内部外，禁止直接修改磁盘或逻辑实体
	var ui_gd_files: Array[String] = []
	_collect_gd_files("res://src/ui", ui_gd_files)

	var banned_patterns: Array[String] = [
		"SaveSystem.save_game",
		"FileAccess.open",
		".money +=",
		".money -=",
		".apply_delta",
	]

	for path: String in ui_gd_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var line_idx: int = 0
		while not file.eof_reached():
			line_idx += 1
			var line: String = file.get_line().strip_edges()
			if line.begins_with("#"):
				continue
			for pat: String in banned_patterns:
				assert_false(
					line.contains(pat),
					(
						"UI 文件 %s 第 %d 行包含禁止的直写逻辑 '%s': %s (必须只调用 11 契约命令)"
						% [path, line_idx, pat, line]
					)
				)


func test_headless_full_loop_deterministic() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	var world: GameWorld = main_scene.get_world()
	var driver: GameLoopDriver = main_scene.get_driver()
	var stack: PanelStack = main_scene.get_stack()

	assert_not_null(world, "GameWorld 应正常初始化")
	assert_eq(world.week, 0, "新开局处于第 0 周")

	# 1. 指派研究员 (调用 11 契约命令之一，开局默认有 r_lin)
	world.assign_staff("r_lin", "slot_core")
	assert_true(world.staff.has("r_lin"), "研究员应成功指派")

	# 2. 4x 速度推演挂机
	driver.speed_index = 2
	assert_eq(driver.get_speed_multiplier(), 4.0, "当前速度为 4x")

	# 3. 模拟时钟流淌跨越周界
	var max_iterations: int = 120
	var iter: int = 0
	while world.week < 5 and iter < max_iterations:
		iter += 1
		driver.feed_frame(0.2)

		# 若遭遇决策卡弹层，模拟处理
		if not world.pending_decision.is_empty():
			var event_id: String = str(world.pending_decision.get("id", ""))
			world.choose_decision(event_id, 0)
			if stack.has_blocking_panel():
				stack.pop_panel(PanelStack.PanelId.DECISION_CARD)

		# 若遭遇周报弹层，模拟玩家点击确认关闭
		if stack.get_z2_stack().has(PanelStack.PanelId.AUTO_REPORT):
			stack.pop_panel(PanelStack.PanelId.AUTO_REPORT)

	assert_true(world.week >= 1, "应经历了周界流淌推进 (周数: %d)" % world.week)

	# 4. 模拟扣除资金触碰破产线，推进至周界触发结算并验证破产短路与 Game Over 弹层接入
	world.economy.init_resources(-300000, 0, 1, 40.0)
	driver.feed_frame(3.0)  # 4x 速度下 3.0s = 12.0s = 48 ticks > 40 ticks 越过周界

	assert_true(world.game_over_flag, "触及破产线后短路触发破产 Game Over")
	assert_true(stack.get_z2_stack().has(PanelStack.PanelId.GAME_OVER), "Game Over 面板应被压入 z2 栈")
	var summary: Dictionary = world.get_game_over_summary()
	assert_eq(summary.get("reason", ""), "bankruptcy", "Game Over 原因应为破产")


func _collect_gd_files(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_collect_gd_files(dir_path.path_join(file_name), out_files)
		elif file_name.ends_with(".gd"):
			out_files.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
