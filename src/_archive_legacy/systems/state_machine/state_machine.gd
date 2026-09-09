class_name StateMachine
extends RefCounted

## 字典驱动的有限状态机：纯逻辑（RefCounted），不依赖场景树。
##
## 与 State 构成单向引用：状态机强持有状态表，状态弱引用状态机，
## 无 RefCounted 循环引用，无内存泄漏。

## 状态切换成功后发出，携带（旧状态名， 新状态名）。
signal state_changed(from_state: StringName, to_state: StringName)

var _states: Dictionary[StringName, State] = {}
var _current_id: StringName = &""
var _current: State = null


## 注册状态；重复注册同一 id 视为编程错误，直接报错阻断。
func add_state(id: StringName, state: State) -> void:
	assert(not id.is_empty(), "状态 id 不能为空字符串")
	assert(state != null, "状态对象不能为 null")
	if _states.has(id):
		push_error("StateMachine: 状态 id 重复注册: %s" % id)
		return
	state.set_machine(self)
	_states[id] = state


## 以指定初始状态启动机器。必须在 add_state 之后调用。
func start(initial_id: StringName) -> void:
	assert(_states.has(initial_id), "初始状态未注册: %s" % initial_id)
	_current_id = initial_id
	_current = _states[initial_id]
	_current.enter()


## 切换到目标状态。机器未启动、目标未注册或与当前相同则拒绝并返回 false。
func transition_to(target_id: StringName) -> bool:
	if _current == null:
		push_error("StateMachine: 尚未 start()，拒绝切换（先调用 start 初始化）")
		return false
	if not _states.has(target_id):
		push_warning("StateMachine: 目标状态未注册: %s" % target_id)
		return false
	if target_id == _current_id:
		return false
	var previous_id := _current_id
	_current.exit()
	_current = _states[target_id]
	_current_id = target_id
	_current.enter()
	state_changed.emit(previous_id, target_id)
	return true


## 当前状态 id；未启动时返回空 StringName。
func get_current_id() -> StringName:
	return _current_id


## 当前状态对象；未启动时返回 null。
func get_current() -> State:
	return _current


## 按状态名查询状态对象；未注册返回 null。
func get_state(id: StringName) -> State:
	return _states.get(id)


## 推进当前状态（由宿主在 _physics_process / _process 中调用）。
func update(delta: float) -> void:
	if _current != null:
		_current.update(delta)
