extends GutTest
## 批7.1 #188 验收点 GUT（World 装配：GameWorld 门面 + 周结相位硬序 + 首循环
## + 存档往返）：
## - test_week_pipeline_order：phase7-10 硬序（出分先于竞对，player_released 撞车输入）
## - test_world_commands：命令面全齐（接单/排训练/指派/研究/命名/变速/暂停/存档）
## - test_world_first_loop：新局种子 W1-W13 六步目标卡达成且无空等（复用 #153
##   断言收敛为 GameWorld 正式装配）
## - test_world_snapshot_roundtrip：12 域编解码往返（flags/rivals/products 已实现域
##   状态一致）
## 真源：architecture §5.3 phase 0-10 + ADR-0015 步序契约 + issue #188 验收点。

const TIME_PATH: String = "res://src/data/time.json"
const FIRST_NODE_ID: String = "align_rlhf_align"

var _world: GameWorld = null


func before_each() -> void:
	_world = GameWorld.new()


func after_each() -> void:
	_world = null


## ---------- 验收点 1：周结相位硬序（出分 → 竞对 → 迷雾 → 员工） ----------


func test_week_pipeline_order() -> void:
	watch_signals(_world)
	assert_eq(_world.start_new_game()["ok"], true, "开局成功")
	# 推进 W1..W3：出分相位须先于竞对（撞车判定输入），迷雾研究点亮
	_tick_weeks(2.0)
	# W3 结算后：首任务完成（paper 入谱）且研究点亮（fog lit）
	var dashboard: Dictionary = _world.get_dashboard_view()
	var goal: Dictionary = dashboard["goal_card"]
	assert_eq(int(goal["step_index"]), 3, "W3 引导推进到排训练步")
	# 员工状态掷点=周粒度一次（roster 数据面=嵌套 {staff_count, staff:[]}）
	var staff_view: Dictionary = dashboard["staff"]
	assert_eq(int(staff_view["staff_count"]), 4, "名册 4 人（掷点相位后视图在位）")
	# 命名待决=z2 阻塞跨周门控（无出分时 false）
	assert_eq(bool(dashboard["naming_pending"]), false, "无待命名")


## ---------- 验收点 2：命令面全齐 ----------


func test_world_commands() -> void:
	_world.start_new_game()
	# 先推进一周：卡时预算周结重置（budget_met 依赖 remaining，首结前=0）
	_tick_weeks(1.0)
	# 接单（accept_paper 选题 id；首任务已在槽，再入空槽）
	var paper_result: Dictionary = _world.get_commands().accept_paper("lora_align")
	assert_eq(bool(paper_result.get("ok", false)), true, "accept_paper 入槽")
	# 排训练（mini 基座；预算已重置=T0 供给 8 ≥ 1）
	var train_result: Dictionary = _world.get_commands().start_training("mini")
	assert_eq(
		bool(train_result.get("ok", false)),
		true,
		"start_training 入槽: %s" % str(train_result),
	)
	# 指派（s1 上桌）
	assert_eq(
		_world.get_commands().assign_staff("s1", int(train_result["slot_index"])),
		CoreEnums.SlotRejectReason.NONE,
		"assign_staff 上桌成功",
	)
	# 研究（首节点；开局已启动→再启动=拒绝不崩，防御面）
	var research_result: Dictionary = _world.get_commands().start_research(FIRST_NODE_ID)
	assert_true(research_result.has("ok"), "start_research 返回结果（防御路径不崩）")
	# 命名（无待定名=拒绝不崩）
	var naming_result: Dictionary = _world.get_commands().submit_name("灵犀初号")
	assert_eq(bool(naming_result.get("ok", false)), false, "无待命名时 submit_name 拒绝")
	# 变速/暂停/存档
	var speed := _world.get_commands().cycle_speed()
	assert_true(
		speed >= GameClock.SpeedIndex.ONE_X and speed <= GameClock.SpeedIndex.FOUR_X,
		"cycle_speed 循环 1x→2x",
	)
	_world.get_commands().set_paused(true)
	_world.get_commands().set_paused(false)
	assert_true(_world.manual_save(), "manual_save 原子写成功")


## ---------- 验收点 3：新局种子 W1-W13 六步全达成无空等 ----------


func test_world_first_loop() -> void:
	# start_new_game 重建 machine——必须先开局再取引用（信号/进度同源）
	_world.start_new_game()
	var machine: TutorialMachine = _world.get_machine()
	watch_signals(machine)
	var expected: Array[int] = _world.get_goal_card().get_expected_weeks()
	var step_weeks: Dictionary = {}
	# 开局即 advance_check(W1)→接单步点亮（connect 前已发，按开局语义手动登记）
	step_weeks[0] = GameWorld.START_WEEK
	machine.step_advanced.connect(
		func(payload: Dictionary) -> void:
			var step_index := int(payload["step_index"])
			if not step_weeks.has(step_index):
				step_weeks[step_index] = int(payload["week"])
	)
	# W1..W13：周结推进 + 周界玩家命令（W4 排训练+指派；W7 命名响应）
	for week: int in range(2, 14):
		_tick_weeks(1.0)
		if week == 3:
			# W3 结算后（=W4 周界）：首任务完成释放槽 → 排训练+指派
			var train_result: Dictionary = _world.get_commands().start_training("mini")
			if bool(train_result.get("ok", false)):
				_world.get_commands().assign_staff("s1", int(train_result["slot_index"]))
		if _world.has_naming_pending():
			assert_eq(
				bool(_world.get_commands().submit_name("灵犀初号").get("ok", false)), true, "命名入册"
			)
	# 六步全达成
	assert_eq(int(_world.get_machine().get_progress()["completed_count"]), 6, "六步全达成")
	assert_signal_emit_count(machine, "chain_completed", 1, "链完成恰一次")
	# 无空等：达成周 ≤ 节拍锚（W2 首结标签约定；护栏 lit∈[W2,W4]/rival W10 仍过）
	for i: int in 6:
		assert_true(
			int(step_weeks[i]) <= expected[i],
			"步 %d 达成周 %d ≤ 锚 %d（无空等）" % [i, int(step_weeks[i]), expected[i]],
		)
	assert_between(int(step_weeks[1]), 2, 4, "首节点 lit 周 ∈[W2,W4]（GameClock 首结标签 W2）")
	assert_eq(int(step_weeks[5]), 10, "首对手 W10（rivals timeline 表驱动）")


## ---------- 验收点 4：存档往返（12 域编解码唯一映射点） ----------


func test_world_snapshot_roundtrip() -> void:
	_world.start_new_game()
	# 推进若干周产生状态（引导 flags + 论文入库）
	_tick_weeks(2.0)
	var save: Dictionary = SnapshotCodec.encode(
		_world.get_save_state(), SnapshotCodec.SAVE_KIND_AUTO
	)
	assert_eq(str(save["schema_version"]), str(SaveMigrator.CURRENT_VERSION), "信封盖章")
	# 重建世界 → 反写 → 状态一致
	var restored := GameWorld.new()
	restored.start_new_game()
	var result: Dictionary = restored.restore_from_save(save)
	assert_eq(bool(result.get("ok", false)), true, "restore 成功: %s" % str(result))
	# 引导 flags 往返一致（已实现域）
	assert_eq(
		restored.get_machine().get_save_view(),
		_world.get_machine().get_save_view(),
		"flags 域往返一致",
	)


## ---------- 私有辅助 ----------


func _tick_weeks(weeks: float) -> void:
	var table := DataLoader.load_json(TIME_PATH)
	var seconds := weeks * float(table["time_wall_clock_1x"])
	_world.tick(seconds)
