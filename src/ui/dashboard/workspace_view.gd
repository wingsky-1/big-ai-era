class_name WorkspaceView
extends VBoxContainer
## L3 工作区（#146；ui-ux-spec A.1 工作区永不折叠 + B.2 任务槽行）。
## 装配 4 张任务槽卡；数据面注入=槽 view 源（Callable：() -> Array[Dictionary]，
## 装配方传 TaskBoard.get_task_view）+变更信号（Object 发射者+信号名——L3 禁
## import L2，以 Object 鸭子类型连接，不引类）。
## 刷新语义（B.2「0.5s 刷新」+ task_board 头注"L3 消费信号重查 get_task_view"）：
## 信号驱动随查随新（同帧，远小于 0.5s 预算 token ui_slot_refresh_dur 镜像）；
## 完成（IN_PROGRESS→FINISHED_PENDING）=顶入动画；入槽（EMPTY→IN_PROGRESS）
## =弹入动画（0.5s，ui_slot_finish_anim_dur 镜像）——状态迁移由本类比较前后
## 帧识别（信号载荷最小化，不依赖载荷字段）。
## 硬约束：零业务计算（ADR-0016）；只读数据面；竖屏永不折叠（折叠形态由
## MainScene 按 LayoutPolicy 切，本类不做判定）。

## 槽卡数（=TaskBoard.TASK_SLOT_COUNT 4 的 L3 镜像；GUT 断言锁同源）
const SLOT_CARD_COUNT: int = 4
## 刷新预算镜像（ui.json ui_slot_refresh_dur；信号同帧刷新 ≪ 预算）
const REFRESH_DUR: float = 0.5

var _cards: Array[TaskSlotCard] = []
var _task_view_source: Callable = Callable()
var _changed_emitter: Object = null
var _changed_signal: String = ""
var _prev_states: Array[int] = []


func _init() -> void:
	add_theme_constant_override("separation", 8)
	for _i: int in SLOT_CARD_COUNT:
		var card := TaskSlotCard.new()
		_cards.append(card)
		add_child(card)
		_prev_states.append(CoreEnums.ProjectState.EMPTY)


## 绑定数据面（装配方/测试调用；重复绑定=先断开旧信号防泄漏）。
## task_view_source=返回 Array[槽 view] 的 Callable（TaskBoard.get_task_view）；
## changed_emitter/signal=变更广播（TaskBoard 实例 + "task_board_changed"）。
func bind(task_view_source: Callable, changed_emitter: Object, changed_signal: String) -> void:
	if _changed_emitter != null and not _changed_signal.is_empty():
		if _changed_emitter.is_connected(_changed_signal, _on_changed):
			_changed_emitter.disconnect(_changed_signal, _on_changed)
	_task_view_source = task_view_source
	_changed_emitter = changed_emitter
	_changed_signal = changed_signal
	if changed_emitter != null and not changed_signal.is_empty():
		if changed_emitter.has_signal(changed_signal):
			changed_emitter.connect(changed_signal, _on_changed)
	refresh_now()


## 立即按当前 view 源刷新全部槽卡（同帧；0.5s 预算内）。
func refresh_now() -> void:
	if not _task_view_source.is_valid():
		return
	var views: Array = _task_view_source.call()
	for i: int in mini(views.size(), SLOT_CARD_COUNT):
		var view: Dictionary = views[i]
		var prev: int = _prev_states[i]
		var new_state: int = int(view.get("state", CoreEnums.ProjectState.EMPTY))
		_cards[i].refresh(view)
		if (
			prev == CoreEnums.ProjectState.IN_PROGRESS
			and (new_state == CoreEnums.ProjectState.FINISHED_PENDING)
		):
			_cards[i].play_finish_anim()
		elif (
			prev == CoreEnums.ProjectState.EMPTY
			and (new_state == CoreEnums.ProjectState.IN_PROGRESS)
		):
			_cards[i].play_pop_anim()
		_prev_states[i] = new_state


func _on_changed(_change: Variant) -> void:
	refresh_now()


## ---------- 数据面（测试/装配方读） ----------


func get_slot_card(slot_index: int) -> TaskSlotCard:
	if slot_index < 0 or slot_index >= _cards.size():
		return null
	return _cards[slot_index]


func get_refresh_budget() -> float:
	return REFRESH_DUR
