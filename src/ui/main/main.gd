class_name MainScene
extends Control

## AppShell 界面壳（L3 表现容器，DR-009 / DR-015 / DR-020）：
## 整合 DashboardPresenter, GameLoopDriver, ResponsiveLayoutManager 与 PanelStack。
## UI 表现层零写路径：只单向监听 GameWorld 契约信号或调用 GameWorld 11 项契约命令。

const DECISION_CARD_SCENE: PackedScene = preload("res://src/ui/modals/decision_card_dialog.tscn")
const WEEKLY_REPORT_SCENE: PackedScene = preload("res://src/ui/modals/weekly_report_dialog.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://src/ui/modals/game_over_dialog.tscn")

var _world: GameWorld
var _world_ref: WeakRef
var _presenter: DashboardPresenter
var _driver: GameLoopDriver
var _layout_mgr: ResponsiveLayoutManager
var _stack: PanelStack
var _active_modals: Dictionary = {}
var _mask_overlay: ColorRect

@onready var resource_bar: PanelContainer = %ResourceBar
@onready var resource_subrow: HBoxContainer = %ResourceSubrow
@onready var week_bar: PanelContainer = %WeekBar
@onready var rival_track: PanelContainer = %RivalTrack
@onready var workspace: PanelContainer = %Workspace
@onready var dock: PanelContainer = %Dock
@onready var modal_container: Control = %ModalContainer

@onready var money_label: Label = %MoneyLabel
@onready var compute_label: Label = %ComputeLabel
@onready var influence_label: Label = %InfluenceLabel
@onready var research_eff_label: Label = %ResearchEffLabel
@onready var tech_bonus_label: Label = %TechBonusLabel
@onready var week_label: Label = %WeekLabel

@onready var speed_pause_btn: Button = %SpeedPauseBtn
@onready var speed_1x_btn: Button = %Speed1xBtn
@onready var speed_2x_btn: Button = %Speed2xBtn
@onready var speed_4x_btn: Button = %Speed4xBtn

@onready var rival_name_label: Label = %RivalNameLabel
@onready var rival_progress_bar: ProgressBar = %RivalProgressBar
@onready var rival_gap_label: Label = %RivalGapLabel

@onready var task_title_label: Label = %TaskTitleLabel
@onready var task_progress_bar: ProgressBar = %TaskProgressBar
@onready var staff_count_label: Label = %StaffCountLabel
@onready var toast_label: Label = %ToastLabel

@onready var dock_tech_btn: Button = %DockTechBtn
@onready var dock_report_btn: Button = %DockReportBtn
@onready var dock_pause_btn: Button = %DockPauseBtn


func _ready() -> void:
	_init_runtime_systems()
	_connect_ui_events()
	_update_views()


func _exit_tree() -> void:
	if _driver != null:
		_driver.free()
		_driver = null
	if _mask_overlay != null and is_instance_valid(_mask_overlay):
		_mask_overlay.free()
		_mask_overlay = null
	for modal in _active_modals.values():
		if is_instance_valid(modal):
			modal.free()
	_active_modals.clear()


func _process(delta: float) -> void:
	if _driver != null and _world != null:
		_driver.feed_frame(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _layout_mgr != null:
			_layout_mgr.update_viewport(get_viewport_rect().size)


func get_world() -> GameWorld:
	return _world


func get_driver() -> GameLoopDriver:
	return _driver


func get_stack() -> PanelStack:
	return _stack


func get_presenter() -> DashboardPresenter:
	return _presenter


func get_layout_manager() -> ResponsiveLayoutManager:
	return _layout_mgr


## 保持向后兼容（供迁移过渡使用）
func get_text_count() -> int:
	return TextService.table().size()


func _init_runtime_systems() -> void:
	_world = GameWorld.new()
	_world.start_new_game()
	_world_ref = weakref(_world)

	_stack = PanelStack.new()
	_stack.panel_pushed.connect(_on_panel_pushed)
	_stack.panel_popped.connect(_on_panel_popped)
	_stack.mask_state_changed.connect(_on_mask_state_changed)
	_stack.tick_feeding_gate_changed.connect(_on_tick_feeding_gate_changed)

	_presenter = DashboardPresenter.new()
	_presenter.setup(_world, _stack)

	_driver = GameLoopDriver.new()
	_driver.setup(_world)

	_layout_mgr = ResponsiveLayoutManager.new()
	_layout_mgr.setup(get_viewport_rect().size)
	_layout_mgr.layout_folded.connect(_on_layout_folded)

	_setup_mask_overlay()

	# 初始同步折叠状态
	resource_subrow.visible = not _layout_mgr.is_resource_subrow_folded()


func _setup_mask_overlay() -> void:
	_mask_overlay = ColorRect.new()
	_mask_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_mask_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_mask_overlay.visible = false
	_mask_overlay.gui_input.connect(_on_mask_gui_input)
	modal_container.add_child(_mask_overlay)


func _on_mask_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_stack.on_mask_clicked()


func _on_mask_state_changed(mask_visible: bool, _dismissable: bool) -> void:
	if _mask_overlay != null:
		_mask_overlay.visible = mask_visible


func _on_tick_feeding_gate_changed(allow_feeding: bool) -> void:
	if _driver != null:
		_driver.set_feeding_enabled(allow_feeding)


func _on_panel_pushed(panel_id: String, _layer: int) -> void:
	var world := _resolve_world()
	if world == null:
		return

	match panel_id:
		PanelStack.PANEL_DECISION_CARD:
			var event_data: Dictionary = world.pending_decision
			var modal: DecisionCardDialog = DECISION_CARD_SCENE.instantiate()
			modal.setup(event_data)
			modal.option_selected.connect(
				func(idx: int) -> void:
					world.choose_decision(str(event_data.get("id", "")), idx)
					_stack.pop_panel(PanelStack.PANEL_DECISION_CARD)
			)
			_active_modals[panel_id] = modal
			modal_container.add_child(modal)

		PanelStack.PANEL_AUTO_REPORT, PanelStack.PANEL_REPORT_ARCHIVE:
			var report_data: Dictionary = _presenter.get_resource_view()
			var modal: WeeklyReportDialog = WEEKLY_REPORT_SCENE.instantiate()
			modal.setup(report_data)
			modal.confirmed.connect(func() -> void: _stack.pop_panel(panel_id))
			_active_modals[panel_id] = modal
			modal_container.add_child(modal)

		PanelStack.PANEL_GAME_OVER:
			var summary: Dictionary = _presenter.get_game_over_summary()
			var modal: GameOverDialog = GAME_OVER_SCENE.instantiate()
			modal.setup(summary)
			modal.restart_requested.connect(
				func() -> void:
					world.start_new_game()
					_stack.pop_panel(PanelStack.PANEL_GAME_OVER)
					_update_views()
			)
			_active_modals[panel_id] = modal
			modal_container.add_child(modal)


func _on_panel_popped(panel_id: String, _layer: int) -> void:
	if _active_modals.has(panel_id):
		var modal: Node = _active_modals[panel_id]
		_active_modals.erase(panel_id)
		if is_instance_valid(modal):
			modal.queue_free()


func _resolve_world() -> GameWorld:
	if _world_ref != null:
		var w: Variant = _world_ref.get_ref()
		if w != null and w is GameWorld:
			return w as GameWorld
	return _world


func _connect_ui_events() -> void:
	speed_pause_btn.pressed.connect(_on_speed_pause_pressed)
	speed_1x_btn.pressed.connect(func() -> void: _set_speed(1.0))
	speed_2x_btn.pressed.connect(func() -> void: _set_speed(2.0))
	speed_4x_btn.pressed.connect(func() -> void: _set_speed(4.0))

	dock_tech_btn.pressed.connect(_on_dock_tech_pressed)
	dock_report_btn.pressed.connect(_on_dock_report_pressed)
	dock_pause_btn.pressed.connect(_on_dock_pause_pressed)

	_world.resources_changed.connect(
		func(_money: int, _comp: float, _inf: int) -> void: _update_views()
	)
	_world.progress_ticked.connect(func(_prog: Dictionary) -> void: _update_views())
	_world.task_state_changed.connect(func(_tid: String, _st: String) -> void: _update_views())
	_world.week_settled.connect(func(_report: Dictionary) -> void: _update_views())
	_world.toast_queued.connect(_on_toast_queued)


func _on_layout_folded(_folded: bool, _elements: Array[String]) -> void:
	resource_subrow.visible = not _layout_mgr.is_resource_subrow_folded()


func _on_speed_pause_pressed() -> void:
	if _world.user_paused:
		_world.set_paused(false)
	else:
		_world.set_paused(true)
	_update_speed_buttons()


func _set_speed(spd: float) -> void:
	if _world.user_paused:
		_world.set_paused(false)
	if is_equal_approx(spd, 1.0):
		_driver.speed_index = 0
	elif is_equal_approx(spd, 2.0):
		_driver.speed_index = 1
	elif is_equal_approx(spd, 4.0):
		_driver.speed_index = 2
	_update_speed_buttons()


func _update_speed_buttons() -> void:
	var paused: bool = _world.user_paused
	var spd: float = _driver.get_speed_multiplier()
	speed_pause_btn.button_pressed = paused
	speed_1x_btn.button_pressed = (not paused and is_equal_approx(spd, 1.0))
	speed_2x_btn.button_pressed = (not paused and is_equal_approx(spd, 2.0))
	speed_4x_btn.button_pressed = (not paused and is_equal_approx(spd, 4.0))


func _on_dock_tech_pressed() -> void:
	_stack.push_panel(PanelStack.PANEL_TECH_TREE)


func _on_dock_report_pressed() -> void:
	_presenter.open_report_archive()


func _on_dock_pause_pressed() -> void:
	_world.set_paused(true)
	_stack.push_panel(PanelStack.PANEL_PAUSE_MENU)


func _on_toast_queued(msg: String, _color_tag: String) -> void:
	toast_label.text = msg
	toast_label.visible = true


func _update_views() -> void:
	var res_view: Dictionary = _presenter.get_resource_view()
	money_label.text = "资金: " + Formatter.format_money(int(res_view.get("money", 0)))
	compute_label.text = "算力: %d卡时" % int(res_view.get("compute_hours", 0))
	influence_label.text = "声誉: %d" % int(res_view.get("influence", 0))

	research_eff_label.text = "研发力: +%d" % int(res_view.get("research_eff", 0))
	tech_bonus_label.text = "技术加成: +%.0f%%" % (float(res_view.get("tech_bonus", 0.0)) * 100.0)

	var week_num: int = int(res_view.get("week", 1))
	week_label.text = "第 %d 周" % week_num

	var ws_view: Dictionary = _presenter.get_workspace_view()
	var active_task: Dictionary = ws_view.get("active_task", {})
	if active_task.is_empty():
		task_title_label.text = "当前无进行中任务"
		task_progress_bar.value = 0.0
	else:
		task_title_label.text = str(active_task.get("title", "未命名任务"))
		task_progress_bar.value = float(active_task.get("progress", 0.0)) * 100.0

	var staff_arr: Array = ws_view.get("staff_assigned", [])
	staff_count_label.text = "在岗研究员: %d人" % staff_arr.size()

	var rival_view: Dictionary = _presenter.get_rival_view()
	rival_name_label.text = str(rival_view.get("rival_name", "深巷科技"))
	rival_gap_label.text = str(rival_view.get("gap_text", "追赶中"))
	rival_progress_bar.value = float(rival_view.get("rival_progress", 0.0)) * 100.0

	_update_speed_buttons()
