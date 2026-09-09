class_name StaffAreaView
extends Control
## L3 员工区（#147；staff-spec A.1 员工区 + ui-ux B.2 ui_staff_card 行 +
## B.5 竖屏折叠）。竖屏=横滑行单行卡（卡高 ≥48px）；横屏=网格 2–3 列
## （LayoutPolicy 折叠形态驱动，apply_shape 由 MainScene._apply_layout 下发——
## 本类只切容器不判形态，布局决策单点在策略层）。
## 数据面注入=名册 view 源 + 任务槽 view 源（Callable）+ 双变更信号
## （task_board_changed / staff_state_rolled，Object 鸭子连接，L3 禁 import L2）；
## 刷新=信号同步随查随新（B.2「指派 0.5s 刷新」；刷新预算 token ui_slot_refresh_dur
## 镜像，与工作区同一键——0.5s 预算非延迟承诺）。
## 卡片数随名册增减（E1 扩编 4→8→12：复用既有卡/补新卡，零装配改）。
## 硬约束：零业务计算（ADR-0016）；只读数据面；折叠形态判定不做在本类。

## ---------- ui.json 镜像常量（GUT test_staff_area_responsive 断言=表值） ----------

const REFRESH_DUR: float = 0.5  # ui_slot_refresh_dur（B.2 指派 0.5s 刷新预算）
const GRID_COLUMNS: int = 3  # ui_staff_grid_columns（B.5 横屏网格 2-3 列）

var _hscroll: ScrollContainer
var _hbox: HBoxContainer  # 横滑行单行容器（竖屏）
var _grid: GridContainer  # 网格容器（横屏）
var _cards: Array[StaffCard] = []
var _roster_source: Callable = Callable()
var _task_source: Callable = Callable()
var _task_emitter: Object = null
var _roster_emitter: Object = null
var _shape: String = LayoutPolicy.FOLD_HSCROLL


func _init() -> void:
	# 横滑行=Godot4 ScrollContainer 水平滚动模式（HScrollContainer 4.x 已移除）
	_hscroll = ScrollContainer.new()
	_hscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_hscroll)
	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 8)
	_hscroll.add_child(_hbox)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.visible = false
	add_child(_grid)


## 绑定数据面（装配方/测试调用；重复绑定=先断开旧信号防泄漏）。
## roster_source=() -> {staff: [view]}（Roster.get_roster_view）；task_source=
## () -> Array[槽 view]（TaskBoard.get_task_view）；task_emitter/roster_emitter=
## TaskBoard/Roster 实例（信号名固定 task_board_changed/staff_state_rolled）。
func bind(
	roster_source: Callable,
	task_source: Callable,
	task_emitter: Object,
	roster_emitter: Object,
) -> void:
	_unbind()
	_roster_source = roster_source
	_task_source = task_source
	_task_emitter = task_emitter
	_roster_emitter = roster_emitter
	if task_emitter != null and task_emitter.has_signal("task_board_changed"):
		task_emitter.connect("task_board_changed", _on_changed)
	if roster_emitter != null and roster_emitter.has_signal("staff_state_rolled"):
		roster_emitter.connect("staff_state_rolled", _on_changed)
	refresh_now()


## 立即按当前数据源刷新全部员工卡（同帧；0.5s 预算内）。
func refresh_now() -> void:
	if not _roster_source.is_valid():
		return
	var roster_view: Dictionary = _roster_source.call()
	var staff_views: Array = roster_view.get("staff", [])
	var task_views: Array = []
	if _task_source.is_valid():
		task_views = _task_source.call()
	# 卡片数随名册增减（E1 扩编：复用既有卡/补新卡/收尾移除）
	while _cards.size() < staff_views.size():
		var card := StaffCard.new()
		_cards.append(card)
		_reparent(card)
	while _cards.size() > staff_views.size():
		var removed: StaffCard = _cards.pop_back()
		if removed.get_parent() != null:
			removed.get_parent().remove_child(removed)
	for i: int in staff_views.size():
		var fields := DashboardPresenter.staff_card_view(staff_views[i], task_views)
		_cards[i].refresh(fields)


func _on_changed(_payload: Variant) -> void:
	refresh_now()


## 折叠形态下发（MainScene 按 LayoutPolicy 判定后调用；本类只切容器）。
func apply_shape(fold: String) -> void:
	_shape = fold
	_hscroll.visible = fold == LayoutPolicy.FOLD_HSCROLL
	_grid.visible = not _hscroll.visible
	for card: StaffCard in _cards:
		_reparent(card)


## ---------- 数据面（测试/装配方读） ----------


func get_staff_card(slot_index: int) -> StaffCard:
	if slot_index < 0 or slot_index >= _cards.size():
		return null
	return _cards[slot_index]


func get_staff_card_by_id(staff_id: String) -> StaffCard:
	for card: StaffCard in _cards:
		if card.get_staff_id() == staff_id:
			return card
	return null


func get_card_count() -> int:
	return _cards.size()


func get_layout_shape() -> String:
	return _shape


func get_grid_columns() -> int:
	return _grid.columns


func get_refresh_budget() -> float:
	return REFRESH_DUR


## ---------- 私有 ----------


func _unbind() -> void:
	if _task_emitter != null and _task_emitter.is_connected("task_board_changed", _on_changed):
		_task_emitter.disconnect("task_board_changed", _on_changed)
	if _roster_emitter != null and _roster_emitter.is_connected("staff_state_rolled", _on_changed):
		_roster_emitter.disconnect("staff_state_rolled", _on_changed)
	_task_emitter = null
	_roster_emitter = null


func _reparent(card: StaffCard) -> void:
	var target: Node = _hbox if _shape == LayoutPolicy.FOLD_HSCROLL else _grid
	if card.get_parent() == target:
		return
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	target.add_child(card)
