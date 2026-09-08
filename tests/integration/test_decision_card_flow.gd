extends GutTest

## #104 PR-C 决策卡可达性（P0-3）：事件层出卡 → `decision_pending` 广播 → z2 面板挂载 → 玩家选择。
## 修复前：`GameWorld.decision_pending` 零 emit 点，`settle_week` 无 policy 时自动选 0 号选项并清卡
## → 玩家永远看不到决策卡（`#REV-03` 的 [P] 不可执行、事件注入任务路径永不可达）。

## 固定 seed 下第 3 周必出决策卡（`evt_compute_maintenance`，本轮实测；RNG 确定性）。
const SEED_WITH_EARLY_CARD: int = 104
const MAX_WEEKS: int = 10


func test_decision_card_surfaces_and_blocks() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED_WITH_EARLY_CARD)
	var stack := PanelStack.new()
	var presenter := DashboardPresenter.new()
	presenter.setup(world, stack)
	var seen: Array[Dictionary] = []
	world.decision_pending.connect(func(card: Dictionary) -> void: seen.append(card))
	for _week: int in range(MAX_WEEKS):
		world.settle_week()
		if not seen.is_empty():
			break
	assert_false(seen.is_empty(), "%d 周内应至少出一张决策卡（seed=%d）" % [MAX_WEEKS, SEED_WITH_EARLY_CARD])
	var card: Dictionary = seen[0]
	assert_false(card.is_empty(), "决策卡载荷不得为空")
	assert_false(str(card.get("id", "")).is_empty(), "决策卡应带事件 id")
	assert_eq(
		str(world.pending_decision.get("id", "")), str(card.get("id", "")), "pending_decision 与载荷同源"
	)
	assert_true(stack.get_z2_stack().has(PanelStack.PanelId.DECISION_CARD), "决策卡应挂到 z2（玩家可见）")
	assert_false(stack.is_tick_feeding_allowed(), "z2 决策卡必须停喂 tick（带卡不结周，DR-022①）")
	# 玩家选择 → 卡消费 + 面板出栈（main.gd 的真实流程：choose_decision → pop）
	var option_count: int = (card.get("options", []) as Array).size()
	assert_gt(option_count, 0, "决策卡应有可选项")
	world.choose_decision(str(card.get("id", "")), 0)
	stack.pop_panel(PanelStack.PanelId.DECISION_CARD)
	assert_true(world.pending_decision.is_empty(), "选择后 pending_decision 应清空")
	assert_false(stack.get_z2_stack().has(PanelStack.PanelId.DECISION_CARD), "选择后决策卡应出栈")
	# 直接调 settle_week 时每周都会推入 AUTO_REPORT（真实游玩由停喂保证不叠），
	# 故清空剩余 z2 后再断言世界恢复流淌。
	while not stack.get_z2_stack().is_empty():
		stack.pop_panel(stack.get_z2_stack().back())
	assert_true(stack.is_tick_feeding_allowed(), "z2 全部出栈后恢复 tick 喂入")


func test_decision_card_not_duplicated() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED_WITH_EARLY_CARD)
	var stack := PanelStack.new()
	var presenter := DashboardPresenter.new()
	presenter.setup(world, stack)
	for _week: int in range(MAX_WEEKS):
		world.settle_week()
		if not world.pending_decision.is_empty():
			break
	assert_true(stack.get_z2_stack().has(PanelStack.PanelId.DECISION_CARD), "决策卡应挂载（幂等前提）")
	var depth_before: int = stack.get_z2_stack().size()
	# 同卡重复广播不得叠层
	presenter.call("_on_decision_pending", world.pending_decision.duplicate(true))
	assert_eq(stack.get_z2_stack().size(), depth_before, "同 id 重复广播不得叠加面板")


func test_headless_simulation_with_policy_does_not_block() -> void:
	# 反向保护：注入 policy 的 headless 模拟必须能跑完（决策卡同帧应答，不卡死）。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED_WITH_EARLY_CARD)
	var policy := AutoDecisionPolicy.new()
	world.simulate_weeks(30, policy)
	assert_gte(world.week, 25, "注入 policy 后模拟应持续推进（实测 W%d）" % world.week)
	assert_true(world.pending_decision.is_empty(), "policy 应答后不应残留 pending 卡")
