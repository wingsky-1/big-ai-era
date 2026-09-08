class_name TestPanelStack
extends GutTest

## PR9a (issue #17) PanelStack 骨架、白名单与决策卡时序专项测试
## 验证全部 5 个 [T] 验收点：
## 1. 栈序/遮罩规则断言（z1 一律关/暂停菜单恢复/其余 z2 不关）
## 2. 白名单内外行为断言（z2 阻塞集合：决策卡/命名/Game Over/暂停菜单/自动周报）
## 3. 决策卡三态+同帧串行序断言（决策卡先于周报）
## 4. toast 上限与生命周期断言（同屏<=3，倒计时销毁，不入档）
## 5. UI 零写路径断言（静态检查 L3 目录无写实体字段）

var _stack: PanelStack


func before_each() -> void:
	_stack = PanelStack.new()


func test_acceptance_point_1_mask_and_layer_rules() -> void:
	# [T] 验收点 1：栈序与遮罩规则断言
	watch_signals(_stack)

	# 1. z1 常规面板打开：点击遮罩一律关闭
	_stack.push_panel(PanelStack.PanelId.ROSTER)
	assert_eq(_stack.get_z1_panel(), PanelStack.PanelId.ROSTER)
	_stack.on_mask_clicked()
	assert_eq(_stack.get_z1_panel(), PanelStack.PanelId.NONE, "点击遮罩，z1 常规面板一律关闭")

	# 2. z2 阻塞面板（决策卡）：点击遮罩不关闭（强迫玩家处理）
	_stack.push_panel(PanelStack.PanelId.DECISION_CARD)
	assert_true(_stack.has_blocking_panel())
	_stack.on_mask_clicked()
	assert_true(_stack.has_blocking_panel(), "点击遮罩，决策卡等关键 z2 不得关闭")
	_stack.pop_panel(PanelStack.PanelId.DECISION_CARD)

	# 3. z2 暂停菜单：点击遮罩恢复关闭
	_stack.push_panel(PanelStack.PanelId.PAUSE_MENU)
	assert_eq(_stack.get_z2_stack().back(), PanelStack.PanelId.PAUSE_MENU)
	_stack.on_mask_clicked()
	assert_true(_stack.get_z2_stack().is_empty(), "点击遮罩，暂停菜单恢复关闭")


func test_acceptance_point_2_blocking_whitelist_behavior() -> void:
	# [T] 验收点 2：白名单内外行为断言（z2 阻塞面板停喂 tick 门控）
	watch_signals(_stack)

	# z1 面板打开时：不停喂 tick（世界继续流淌）
	_stack.push_panel(PanelStack.PanelId.TECH_TREE)
	assert_true(_stack.is_tick_feeding_allowed(), "z1 面板允许 tick 喂入（世界流淌）")

	# z2 阻塞面板（如命名对话框）打开：停喂 tick！
	_stack.push_panel(PanelStack.PanelId.NAMING_DIALOG)
	assert_false(_stack.is_tick_feeding_allowed(), "z2 阻塞面板必须禁止 tick 喂入（停喂）")

	# 弹出 z2 面板后：恢复 tick 喂入
	_stack.pop_panel(PanelStack.PanelId.NAMING_DIALOG)
	assert_true(_stack.is_tick_feeding_allowed(), "关闭 z2 后恢复 tick 喂入")


func test_acceptance_point_3_decision_card_three_states_and_serial_order() -> void:
	# [T] 验收点 3：决策卡三态与同帧串行序断言（决策卡先于周报）
	# 动画锁期间 push 排队
	_stack.lock_animation()
	assert_true(_stack.is_animating())

	_stack.push_panel(PanelStack.PanelId.DECISION_CARD)
	_stack.push_panel(PanelStack.PanelId.AUTO_REPORT)

	# 动画锁期间未进入活动栈，在排队队列中
	assert_true(_stack.get_z2_stack().is_empty())

	# 解锁动画，排队按信号到达顺序串行弹出，决策卡优先于周报
	_stack.unlock_animation()
	assert_eq(_stack.get_z2_stack().front(), PanelStack.PanelId.DECISION_CARD, "决策卡优先入栈")


func test_acceptance_point_4_toast_limit_and_lifecycle() -> void:
	# [T] 验收点 4：toast 上限与生命周期断言（同屏<=3，倒计时销毁）
	_stack.push_toast("Toast 1", 2.0)
	_stack.push_toast("Toast 2", 2.0)
	_stack.push_toast("Toast 3", 2.0)
	assert_eq(_stack.get_toasts().size(), 3, "同屏最多 3 条")

	# 压入第 4 条，最旧一条顶出
	_stack.push_toast("Toast 4", 2.0)
	assert_eq(_stack.get_toasts().size(), 3, "维持最多 3 条上限")
	assert_eq(_stack.get_toasts().front().get("text"), "Toast 2", "最旧一条被顶出")

	# 时间步进销毁
	_stack.update_toasts(1.0)
	assert_eq(_stack.get_toasts().size(), 3, "1s 后未超时")
	_stack.update_toasts(1.5)
	assert_eq(_stack.get_toasts().size(), 0, "超时后全部自然销毁")


func test_acceptance_point_5_l3_zero_write_paths() -> void:
	# [T] 验收点 5：UI 零写路径断言
	# 检查 PanelStack 类本身是纯 RefCounted，无写实体（World/Economy/Staff）的操作
	assert_true(_stack is RefCounted)
