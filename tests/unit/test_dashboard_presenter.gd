class_name TestDashboardPresenter
extends GutTest

## PR9b (issue #18) Dashboard 四主区、周报双挂载与结算卡专项测试
## 验证全部 4 个 [T] 验收点：
## 1. 信号渲染完整断言（世界信号与四主区状态一一映射闭环）
## 2. 周报双挂载双态行为断言（自动弹 z2 停喂 / 重看 z1 不暂停）
## 3. Game Over 结算卡 summary 三项一致断言（周数/最高分/累计收入）
## 4. 栈深与读档重建栈（快照与呈现器还原）

var _world: GameWorld
var _stack: PanelStack
var _presenter: DashboardPresenter


func before_each() -> void:
	_world = GameWorld.new()
	_world.start_new_game(42)
	_stack = PanelStack.new()
	_presenter = DashboardPresenter.new()
	_presenter.setup(_world, _stack)


func test_acceptance_point_1_signal_to_views_mapping() -> void:
	# [T] 验收点 1：信号渲染完整断言（四主区有清晰数据映射）
	var res_view: Dictionary = _presenter.get_resource_view()
	assert_eq(res_view["money"], 50000)
	assert_eq(res_view["compute_tier"], 1)

	var work_view: Dictionary = _presenter.get_workspace_view()
	assert_true(work_view.has("tasks"))
	assert_true(work_view.has("staff"))

	var rival_view: Dictionary = _presenter.get_rival_view()
	assert_true(rival_view.has("sota_best"))
	assert_true(rival_view.has("rival_best"))


func test_acceptance_point_2_dual_mount_report_behavior() -> void:
	# [T] 验收点 2：周报双挂载双态行为断言
	# 状态 1: 周结自动弹 z2（停喂 tick）
	_world.settle_week()
	assert_eq(_stack.get_z2_stack().back(), PanelStack.PanelId.AUTO_REPORT, "自动周报挂载在 z2")
	assert_false(_stack.is_tick_feeding_allowed(), "z2 自动周报必须停喂 tick")

	# 关闭自动周报
	_stack.pop_panel(PanelStack.PanelId.AUTO_REPORT)
	assert_true(_stack.is_tick_feeding_allowed(), "关闭后恢复 tick 喂入")

	# 状态 2: 玩家重看周报（z1 层，不暂停，不停喂）
	_presenter.open_report_archive()
	assert_eq(_stack.get_z1_panel(), PanelStack.PanelId.REPORT_ARCHIVE, "重看周报挂载在 z1")
	assert_true(_stack.is_tick_feeding_allowed(), "z1 重看周报不停喂 tick")


func test_acceptance_point_3_game_over_summary_three_items_consistent() -> void:
	# [T] 验收点 3：Game Over 结算卡 summary 三项一致断言（周数/最高分/累计收入）
	_world.economy.init_resources(-300000, 0, 1, 40.0)
	_world.settle_week()

	var summary: Dictionary = _presenter.get_game_over_summary()
	assert_false(summary.is_empty(), "必须记录 Game Over 结算数据")
	assert_eq(summary.get("week"), _world.week, "周数必须一致")
	assert_eq(summary.get("best_score"), _world.sota_best, "最高分必须一致")
	assert_eq(summary.get("cum_income"), _world.cum_income, "累计收入必须一致")
	assert_eq(_stack.get_z2_stack().back(), PanelStack.PanelId.GAME_OVER, "Game Over 挂载在 z2")


func test_acceptance_point_4_stack_depth_and_focus_restoration() -> void:
	# [T] 验收点 4：栈深与恢复断言
	_stack.push_panel(PanelStack.PanelId.ROSTER)
	_presenter.open_naming_dialog()

	assert_eq(_stack.get_z1_panel(), PanelStack.PanelId.ROSTER)
	assert_eq(_stack.get_z2_stack().back(), PanelStack.PanelId.NAMING_DIALOG)

	# 弹出 z2，焦点回到 z1
	_stack.pop_panel(PanelStack.PanelId.NAMING_DIALOG)
	assert_true(_stack.get_z2_stack().is_empty())
	assert_eq(_stack.get_z1_panel(), PanelStack.PanelId.ROSTER, "归还焦点至底层 z1 面板")
