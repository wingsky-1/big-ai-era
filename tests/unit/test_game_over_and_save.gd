class_name TestGameOverAndSave
extends GutTest

## PR8 (issue #16) 存档三保险与 Game Over 短路专项测试
## 验证全部 4 个 [T] 验收点：
## 1. 三路径触发断言（周界自动/退出切后台/手动，各一）
## 2. 破产短路单测：短路后不执行出分/SOTA/竞对/迷雾/事件/阶段/周报
## 3. 终局档保存+刷新恢复断言（game_over 态可还原）
## 4. summary 字典字段断言（周数/最高分/竞对分/累计收入/原因）

var _world: GameWorld


func before_each() -> void:
	_world = GameWorld.new()
	_world.start_new_game(42)


func test_acceptance_point_1_three_save_paths() -> void:
	# [T] 验收点 1：三路径触发断言（经 SaveSystem 唯一写入口）
	# 路径 1: 手动触发存档
	var ok_manual: bool = _world.request_save("manual")
	assert_true(ok_manual, "手动存档成功")
	var save_manual := SaveSystem.load_game()
	assert_eq(save_manual.get("save_reason"), "manual", "记录 manual 触发源")

	# 路径 2: 退出/切后台触发存档
	var ok_suspend: bool = _world.request_save("suspend")
	assert_true(ok_suspend, "切后台存档成功")
	var save_suspend := SaveSystem.load_game()
	assert_eq(save_suspend.get("save_reason"), "suspend", "记录 suspend 触发源")

	# 路径 3: 周界自动存档（步序 11）
	_world.settle_week()
	var save_auto := SaveSystem.load_game()
	assert_eq(int(save_auto.get("week")), 1, "周结推进为第 1 周")
	assert_eq(save_auto.get("save_reason"), "weekly_auto", "记录 weekly_auto 触发源")


func test_acceptance_point_2_bankruptcy_short_circuit() -> void:
	# [T] 验收点 2：破产短路单测：短路后不执行后续出分/SOTA/竞对/迷雾/事件/阶段/周报
	watch_signals(_world)

	# 安排一个正在训练的项目
	_world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	_world.start_training("base_pushi_1b")
	assert_true(_world.training.is_training(), "训练项目正在运行")

	# 将资金置为破产线以下（<= -200,000，扣除课题可能收益后依然破产）
	_world.economy.init_resources(-300000, 0, 1, 40.0)

	# 执行周结
	_world.settle_week()

	# 验证短路发生
	assert_true(_world.game_over_flag, "game_over_flag 应被置为 true")
	assert_signal_emitted(_world, "game_over", "必须发射 game_over 信号")

	# 验证短路后的阻断：不应发射 week_settled
	assert_signal_not_emitted(_world, "week_settled", "破产短路不得发射 week_settled")

	# 检查终局档保存
	var saved := SaveSystem.load_game()
	assert_eq(saved.get("save_reason"), "game_over", "终局档被成功保存落盘")
	assert_true(saved.get("flags", {}).get("game_over"), "存档中记录 game_over 标记")


func test_acceptance_point_3_game_over_restore() -> void:
	# [T] 验收点 3：终局档保存+刷新恢复断言（game_over 态可还原）
	_world.economy.init_resources(-250000, 0, 1, 40.0)
	_world.settle_week()
	assert_true(_world.game_over_flag)

	var loaded := SaveSystem.load_game()
	var fresh := GameWorld.new()
	autofree(fresh)
	fresh.restore(loaded)

	assert_true(fresh.game_over_flag, "读档后 game_over 态必须完全还原")
	var snap := fresh.get_ui_snapshot()
	assert_true(bool(snap.get("game_over")), "快照中 game_over 必须为 true")


func test_acceptance_point_4_summary_dictionary_fields() -> void:
	# [T] 验收点 4：summary 字典字段断言
	watch_signals(_world)
	_world.economy.init_resources(-300000, 0, 1, 40.0)
	_world.settle_week()

	var summary: Dictionary = _world.get_game_over_summary()
	assert_true(summary.has("week"), "summary 必须含周数")
	assert_true(summary.has("best_score"), "summary 必须含最高分")
	assert_true(summary.has("rival_best"), "summary 必须含竞对基线")
	assert_true(summary.has("cum_income"), "summary 必须含累计经营收入")
	assert_eq(summary.get("reason"), "bankruptcy", "原因必须为 bankruptcy")
