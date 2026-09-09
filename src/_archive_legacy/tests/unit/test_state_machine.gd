extends GutTest

## StateMachine 单元测试：使用文件尾的 Stub 状态验证生命周期与信号。


func _build_machine(initial: StringName) -> StateMachine:
	var machine := StateMachine.new()
	machine.add_state(&"idle", IdleState.new())
	machine.add_state(&"run", RunState.new())
	machine.start(initial)
	return machine


func test_start_enters_initial_state() -> void:
	var machine := _build_machine(&"idle")
	assert_eq(machine.get_current_id(), &"idle", "启动后应处于初始状态")
	assert_true((machine.get_current() as IdleState).entered, "初始状态应收到 enter 调用")


func test_transition_switches_state_and_emits_signal() -> void:
	var machine := _build_machine(&"idle")
	watch_signals(machine)
	var ok := machine.transition_to(&"run")
	assert_true(ok, "合法切换应返回 true")
	assert_eq(machine.get_current_id(), &"run", "切换后应为 run 状态")
	assert_true((machine.get_state(&"idle") as IdleState).exited, "旧状态应收到 exit")
	assert_signal_emitted(machine, "state_changed", "切换成功后应发出 state_changed")
	# 手动校验参数（同 test_stat_attribute 的信号参数断言策略）
	var params: Array = get_signal_parameters(machine, "state_changed")
	assert_eq(params.size(), 2, "state_changed 应携带新旧两个状态名")
	assert_eq(params[0], &"idle", "第一个参数应为旧状态名")
	assert_eq(params[1], &"run", "第二个参数应为新状态名")


func test_transition_to_unknown_state_returns_false() -> void:
	var machine := _build_machine(&"idle")
	assert_false(machine.transition_to(&"fly"), "未注册状态应拒绝切换")


func test_transition_to_same_state_returns_false() -> void:
	var machine := _build_machine(&"idle")
	assert_false(machine.transition_to(&"idle"), "自转换应被拒绝")


func test_transition_before_start_returns_false() -> void:
	var machine := StateMachine.new()
	machine.add_state(&"idle", IdleState.new())
	assert_false(machine.transition_to(&"idle"), "未 start 前切换应被拒绝（防空引用崩溃）")
	assert_eq(machine.get_current_id(), &"", "未启动时当前状态名应为空")
	assert_push_error("尚未 start", "未启动切换应有明确错误提示")


func test_update_delegates_to_current_state() -> void:
	var machine := _build_machine(&"idle")
	machine.update(0.25)
	machine.update(0.25)
	var idle := machine.get_current() as IdleState
	assert_eq(idle.update_calls, 2, "update 应按次数委派给当前状态")


func test_state_weakref_to_machine_is_valid() -> void:
	var machine := _build_machine(&"idle")
	var state := machine.get_state(&"run") as RunState
	var machine_ref := state.get_machine()
	assert_not_null(machine_ref, "状态的弱引用应已注入")
	assert_not_null(machine_ref.get_ref(), "状态机存活期间弱引用应可解析")


class IdleState:
	extends State
	var entered: bool = false
	var exited: bool = false
	var update_calls: int = 0

	func enter() -> void:
		entered = true

	func exit() -> void:
		exited = true

	func update(_delta: float) -> void:
		update_calls += 1


class RunState:
	extends State

	func enter() -> void:
		pass

	func exit() -> void:
		pass
