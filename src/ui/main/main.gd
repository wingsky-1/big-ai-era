class_name MainScene
extends Control

## AppShell 界面壳（L3 表现容器，DR-009 / DR-015 / DR-020）：
## 整合 DashboardPresenter, GameLoopDriver, ResponsiveLayoutManager 与 PanelStack。
## UI 表现层零写路径：只单向监听 GameWorld 契约信号或调用 GameWorld 11 项契约命令。

const DECISION_CARD_SCENE: PackedScene = preload("res://src/ui/modals/decision_card_dialog.tscn")
const WEEKLY_REPORT_SCENE: PackedScene = preload("res://src/ui/modals/weekly_report_dialog.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://src/ui/modals/game_over_dialog.tscn")
const TECH_TREE_SCENE: PackedScene = preload("res://src/ui/modals/tech_tree_dialog.tscn")
const STAFF_ROSTER_SCENE: PackedScene = preload("res://src/ui/modals/staff_roster_dialog.tscn")
const INTRO_SCENE: PackedScene = preload("res://src/ui/modals/intro_dialog.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://src/ui/modals/pause_menu_dialog.tscn")
const NAMING_DIALOG_SCENE: PackedScene = preload("res://src/ui/modals/naming_dialog.tscn")
const FINALE_SCENE: PackedScene = preload("res://src/ui/modals/finale_dialog.tscn")
const TOKENS_COLORS: Resource = preload("res://src/ui/theme/tokens_colors.tres")

var _world: GameWorld
var _world_ref: WeakRef
var _presenter: DashboardPresenter
var _driver: GameLoopDriver
var _layout_mgr: ResponsiveLayoutManager
var _stack: PanelStack
var _active_modals: Dictionary = {}
var _mask_overlay: ColorRect
var _debug_beacon_enabled: bool = false
var _debug_shot_mode: bool = false
## 净流入预告副行（#78 / V1-18：动态挂载为 %ResourceSubrow 的兄弟行，竖屏保留不折叠）
var _forecast_row: HBoxContainer
var _forecast_label: Label
var _forecast_detail_label: Label
var _forecast_expanded: bool = false
## 自由期三线（#82 RF-01/02：动态挂载独立节点，不动竞对/预告既有行）
var _freedom_row: HBoxContainer
var _freedom_label: Label
var _freedom_panel: VBoxContainer
var _freedom_panel_title: Label
var _freedom_panel_body: Label

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
@onready var compute_upgrade_btn: Button = %ComputeUpgradeBtn

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
@onready var idle_staff_label: Label = %IdleStaffLabel
@onready var toast_label: Label = %ToastLabel

@onready var dock_tech_btn: Button = %DockTechBtn
@onready var dock_report_btn: Button = %DockReportBtn
@onready var dock_pause_btn: Button = %DockPauseBtn


func _ready() -> void:
	_init_runtime_systems()
	_connect_ui_events()
	_update_views()
	_on_viewport_resized()
	_setup_debug_shot_driver()
	_push_intro_if_needed()


## 开场引导（DR-029 D-3"不拦流淌"）：仅推入一次。
## ?shot= 合成模式跳过（截图须精确控制画面）；?selftest= 与正常游玩均推入
## （自测必须验证真实开局流程）。
func _push_intro_if_needed() -> void:
	if _debug_shot_mode:
		return
	_stack.push_panel(PanelStack.PanelId.INTRO)


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
	if _debug_beacon_enabled:
		_update_debug_beacon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# deferred 执行：等 stretch/缩放状态在本帧末稳定后再做基准切换与布局同步
		_on_viewport_resized.call_deferred()


## 截图/试玩自动化驱动（仅 Web 且显式查询参数时激活，正常游玩零影响）：
## ?shot=<id>：合成指定弹层截图（home/tech/report/gameover）+ 就绪标志；
## ?selftest=1：仅启用面板栈信标供交互自测断言。两者均冻结时钟、丢弃挂起决策卡。
func _setup_debug_shot_driver() -> void:
	if OS.has_feature("web") == false:
		return
	var params: String = "new URLSearchParams(window.location.search)"
	var shot: String = str(JavaScriptBridge.eval("%s.get('shot') || ''" % params, true))
	var selftest: String = str(JavaScriptBridge.eval("%s.get('selftest') || ''" % params, true))
	if shot.is_empty() and selftest.is_empty():
		return
	_debug_shot_mode = not shot.is_empty()
	_world.set_paused(true)
	# 防御：若开局/推进已挂起决策卡，调试模式丢弃之，避免叠层污染证据
	if not _world.pending_decision.is_empty():
		_world.set_pending_decision({})
	# 注意：类内不可裸调 get_stack()——与 GDScript 内置全局函数（返回调试栈 Array）撞名
	var stack: PanelStack = _stack
	if stack == null:
		return
	match shot:
		"home":
			pass  # 主工作台即默认态
		"intro":
			stack.push_panel(PanelStack.PanelId.INTRO)
		"tech":
			stack.push_panel(PanelStack.PanelId.TECH_TREE)
		"report":
			stack.push_panel(PanelStack.PanelId.REPORT_ARCHIVE)
		"gameover":
			# 终局弹层为合成布局证据（world 并未真破产），保持暂停避免 tick 污染画面
			stack.push_panel(PanelStack.PanelId.GAME_OVER)
	# 面板栈信标：截图与自测脚本共用（_process 每帧同步）
	_debug_beacon_enabled = true
	_update_debug_beacon()
	# 精确就绪信号：仅截图模式使用（自测模式以信标出现为就绪判定）
	if not shot.is_empty():
		JavaScriptBridge.eval("window.__DSH_SHOT_READY__ = true;", true)


## 自测信标：把面板栈状态同步给 JS 侧（仅调试驱动激活时），供交互自测确定性断言
func _update_debug_beacon() -> void:
	if _stack == null:
		return
	var depth: int = (
		_stack.get_z2_stack().size()
		+ (1 if _stack.get_z1_panel() != PanelStack.PanelId.NONE else 0)
	)
	JavaScriptBridge.eval(
		(
			"window.__DSH_PANEL_STATE__ = { depth: %d, blocking: %s };"
			% [depth, "true" if _stack.has_blocking_panel() else "false"]
		),
		true
	)


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


## 视口变化统一入口：竖屏内容基准切换 + 折叠规则 + 已开弹层尺寸刷新。
## 幂等：基准未变化时写 content_scale_size 不触发额外 RESIZED。
func _on_viewport_resized() -> void:
	if _layout_mgr == null or not is_inside_tree():
		return
	var win := get_tree().root
	if win != null:
		var phys := Vector2i(win.size)
		var target: Vector2i = ResponsiveLayoutManager.resolve_content_scale(phys)
		if win.content_scale_size != target:
			win.content_scale_size = target
	_layout_mgr.update_viewport(get_viewport_rect().size)
	_sync_folded_elements()
	for modal: Control in _active_modals.values():
		if is_instance_valid(modal):
			ModalSizing.refresh(modal)


## 仅同步折叠态（资源栏副行），与 ResponsiveLayoutManager 竖屏规则一致
func _sync_folded_elements() -> void:
	if resource_subrow != null:
		resource_subrow.visible = not _layout_mgr.is_resource_subrow_folded()


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
	_setup_forecast_row()
	_setup_freedom_views()

	# 初始同步折叠状态（后续随视口变化由信号与 RESIZED 钩子驱动）
	_sync_folded_elements()


## 资源栏净流入预告副行（#78 / V1-18）：挂在资源栏主行之下、与 %ResourceSubrow 平级，
## 竖屏第一折只折叠 %ResourceSubrow（研发力/技术加成），预告副行保留不折叠。
## 数值与文案键全部来自 L2 数据面（dashboard_presenter.forecast_text/forecast_lines）。
func _setup_forecast_row() -> void:
	var host: Node = resource_subrow.get_parent()
	if host == null:
		return
	_forecast_row = HBoxContainer.new()
	_forecast_row.name = "ForecastRow"
	_forecast_row.add_theme_constant_override("separation", 12)  # num-ok: 布局间距（表现层）
	_forecast_label = Label.new()
	_forecast_label.name = "ForecastLabel"
	_forecast_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_forecast_label.add_theme_color_override("font_color", TOKENS_COLORS.get_meta("ink3"))
	_forecast_label.gui_input.connect(_on_forecast_row_clicked)
	_forecast_row.add_child(_forecast_label)
	_forecast_detail_label = Label.new()
	_forecast_detail_label.name = "ForecastDetailLabel"
	_forecast_detail_label.add_theme_color_override("font_color", TOKENS_COLORS.get_meta("ink3"))
	_forecast_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forecast_detail_label.visible = false
	_forecast_row.add_child(_forecast_detail_label)
	host.add_child(_forecast_row)
	host.move_child(_forecast_row, resource_subrow.get_index() + 1)


## 点开资源栏副行 → 展开/收起收支结构行（工资 / 运维 / 任务 = 净）。
func _on_forecast_row_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_forecast_expanded = not _forecast_expanded
		_update_forecast_row()


func _update_forecast_row() -> void:
	if _forecast_label == null:
		return
	var res_view: Dictionary = _presenter.get_resource_view()
	_forecast_label.text = str(res_view.get("forecast_text", ""))
	var lines: Array = res_view.get("forecast_lines", [])
	if _forecast_detail_label != null:
		_forecast_detail_label.text = "\n".join(lines)
		_forecast_detail_label.visible = _forecast_expanded and not lines.is_empty()


## 自由期三线挂载（#82 RF-01/02）：
## - 弱展示位 = 资源栏副行（`%ResourceSubrow` 之下，与预告副行平级，W25 起常显）；
## - 主权重位 = 工作区面板（封顶后出现，优先级压过摆弄层，DR-029 C-6）。
## 数值/文案全部来自 L2（presenter.get_freedom_view），本处只做布局与可见性。
func _setup_freedom_views() -> void:
	var res_host: Node = resource_subrow.get_parent()
	if res_host != null:
		_freedom_row = HBoxContainer.new()
		_freedom_row.name = "FreedomRow"
		_freedom_row.add_theme_constant_override("separation", 12)  # num-ok: 布局间距（表现层）
		_freedom_label = Label.new()
		_freedom_label.name = "FreedomLabel"
		_freedom_label.add_theme_color_override("font_color", TOKENS_COLORS.get_meta("ink3"))
		_freedom_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_freedom_row.add_child(_freedom_label)
		res_host.add_child(_freedom_row)
		_freedom_row.visible = false
	var ws_host: Node = task_title_label.get_parent()
	if ws_host != null:
		_freedom_panel = VBoxContainer.new()
		_freedom_panel.name = "FreedomPanel"
		_freedom_panel.add_theme_constant_override("separation", 4)  # num-ok: 布局间距（表现层）
		_freedom_panel_title = Label.new()
		_freedom_panel_title.name = "FreedomPanelTitle"
		_freedom_panel.add_child(_freedom_panel_title)
		_freedom_panel_body = Label.new()
		_freedom_panel_body.name = "FreedomPanelBody"
		_freedom_panel_body.add_theme_color_override("font_color", TOKENS_COLORS.get_meta("ink3"))
		_freedom_panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_freedom_panel.add_child(_freedom_panel_body)
		ws_host.add_child(_freedom_panel)
		_freedom_panel.visible = false


## 三线两阶段可见性（RF-02）：W25 起资源栏副行弱展示；封顶后工作区主面板出现。
func _update_freedom_views() -> void:
	var freedom: Dictionary = _presenter.get_freedom_view()
	var visible_weak: bool = bool(freedom.get("visible", false))
	var primary: bool = bool(freedom.get("primary", false))
	if _freedom_row != null:
		_freedom_row.visible = visible_weak
		_freedom_label.text = str(freedom.get("row_text", ""))
	if _freedom_panel != null:
		_freedom_panel.visible = primary
		_freedom_panel_title.text = str(freedom.get("section_label", ""))
		_freedom_panel_body.text = "\n".join(freedom.get("lines_text", []))


func _setup_mask_overlay() -> void:
	_mask_overlay = ColorRect.new()
	_mask_overlay.color = Color(0.0, 0.0, 0.0, 0.6)  # num-ok: 遮罩透明度（表现层）
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


func _on_panel_pushed(panel_id: PanelStack.PanelId, _layer: int) -> void:
	var world := _resolve_world()
	if world == null:
		return

	match panel_id:
		PanelStack.PanelId.DECISION_CARD:
			var event_data: Dictionary = world.pending_decision
			var modal: DecisionCardDialog = DECISION_CARD_SCENE.instantiate()
			modal.setup(event_data)
			modal.option_selected.connect(
				func(idx: int) -> void:
					world.choose_decision(str(event_data.get("id", "")), idx)
					_stack.pop_panel(PanelStack.PanelId.DECISION_CARD)
			)
			_active_modals[panel_id] = modal
			_mount_modal(modal)

		PanelStack.PanelId.AUTO_REPORT, PanelStack.PanelId.REPORT_ARCHIVE:
			# 周报唯一数据源 = GameWorld 最近一次周结报告（RE-02 UI 侧修复：
			# 此前传 get_resource_view() 无 rows 键 → 恒显兜底文案，收支行不可见）
			var report_data: Dictionary = world.get_last_report()
			var modal: WeeklyReportDialog = WEEKLY_REPORT_SCENE.instantiate()
			modal.setup(report_data)
			modal.confirmed.connect(func() -> void: _stack.pop_panel(panel_id))
			_active_modals[panel_id] = modal
			_mount_modal(modal)

		PanelStack.PanelId.INTRO:
			var intro: IntroDialog = INTRO_SCENE.instantiate()
			intro.closed.connect(func() -> void: _stack.pop_panel(PanelStack.PanelId.INTRO))
			_active_modals[panel_id] = intro
			_mount_modal(intro)

		PanelStack.PanelId.GAME_OVER:
			var summary: Dictionary = _presenter.get_game_over_summary()
			var modal: GameOverDialog = GAME_OVER_SCENE.instantiate()
			modal.setup(summary)
			modal.restart_requested.connect(
				func() -> void:
					world.start_new_game()
					_stack.pop_panel(PanelStack.PanelId.GAME_OVER)
					_update_views()
			)
			_active_modals[panel_id] = modal
			_mount_modal(modal)

		PanelStack.PanelId.TECH_TREE:
			var modal: TechTreeDialog = TECH_TREE_SCENE.instantiate()
			modal.setup(world)
			modal.closed.connect(func() -> void: _stack.pop_panel(panel_id))
			modal.research_requested.connect(
				func(tid: String) -> void:
					world.start_research(tid)
					_update_views()
			)
			_active_modals[panel_id] = modal
			_mount_modal(modal)

		PanelStack.PanelId.ROSTER:
			var modal: StaffRosterDialog = STAFF_ROSTER_SCENE.instantiate()
			modal.setup(world)
			modal.closed.connect(func() -> void: _stack.pop_panel(panel_id))
			_active_modals[panel_id] = modal
			_mount_modal(modal)

		PanelStack.PanelId.PAUSE_MENU:
			var modal: PauseMenuDialog = PAUSE_MENU_SCENE.instantiate()
			modal.closed.connect(func() -> void: _stack.pop_panel(panel_id))
			modal.restart_requested.connect(
				func() -> void:
					world.start_new_game()
					_stack.pop_panel(PanelStack.PanelId.PAUSE_MENU)
					_update_views()
			)
			modal.settings_requested.connect(_on_pause_settings_requested)
			_active_modals[panel_id] = modal
			_mount_modal(modal)

		PanelStack.PanelId.NAMING_DIALOG:
			# 命名仪式 UI 落点（X7）：此前 submit_model_name 无任何入口。
			# 提交/跳过统一走契约命令，成功（model_name 非空）才关框。
			var naming: NamingDialog = NAMING_DIALOG_SCENE.instantiate()
			naming.setup(world.model_name)
			naming.submitted.connect(
				func(raw_name: String) -> void:
					world.submit_model_name(raw_name)
					if not world.model_name.is_empty():
						_stack.pop_panel(PanelStack.PanelId.NAMING_DIALOG)
						_update_views()
			)
			naming.skipped.connect(
				func() -> void:
					world.submit_model_name("")
					if not world.model_name.is_empty():
						_stack.pop_panel(PanelStack.PanelId.NAMING_DIALOG)
						_update_views()
			)
			_active_modals[panel_id] = naming
			_mount_modal(naming)

		PanelStack.PanelId.FINALE:
			# 终局收尾屏（#82 RF-03 / Q-R3）：走满单局周数当周自动弹，可继续自由期；
			# 与破产 Game Over 卡两套并存（本分支不触碰 GAME_OVER 分支语义）。
			var finale: FinaleDialog = FINALE_SCENE.instantiate()
			finale.setup(_presenter.get_finale_summary())
			finale.continue_requested.connect(
				func() -> void: _stack.pop_panel(PanelStack.PanelId.FINALE)
			)
			_active_modals[panel_id] = finale
			_mount_modal(finale)


func _on_panel_popped(panel_id: PanelStack.PanelId, _layer: int) -> void:
	# 暂停菜单出栈（继续 / Esc / 遮罩三条路径统一走 pop）= 恢复流淌：
	# 归零 user_paused；GameClock 双源 OR 保证决策卡在场时仍停（唯一源不变式不破）。
	if panel_id == PanelStack.PanelId.PAUSE_MENU:
		var world := _resolve_world()
		if world != null:
			world.set_paused(false)
			_update_speed_buttons()
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


## 弹层统一挂载：容器加入 + 自适应 min size 收敛
func _mount_modal(modal: Control) -> void:
	modal_container.add_child(modal)
	ModalSizing.apply(modal)


func _connect_ui_events() -> void:
	speed_pause_btn.pressed.connect(_on_speed_pause_pressed)
	speed_1x_btn.pressed.connect(func() -> void: _set_speed(1.0))
	speed_2x_btn.pressed.connect(func() -> void: _set_speed(2.0))  # num-ok: 速度按钮 2x 档位（View）
	speed_4x_btn.pressed.connect(func() -> void: _set_speed(4.0))  # num-ok: 速度按钮 4x 档位（View）

	dock_tech_btn.pressed.connect(_on_dock_tech_pressed)
	dock_report_btn.pressed.connect(_on_dock_report_pressed)
	dock_pause_btn.pressed.connect(_on_dock_pause_pressed)
	compute_upgrade_btn.pressed.connect(_on_compute_upgrade_pressed)
	staff_count_label.gui_input.connect(_on_staff_label_clicked)
	idle_staff_label.gui_input.connect(_on_staff_label_clicked)

	_world.resources_changed.connect(
		func(_money: int, _comp: float, _inf: int) -> void: _update_views()
	)
	_world.progress_ticked.connect(func(_prog: Dictionary) -> void: _update_views())
	_world.task_state_changed.connect(func(_tid: String, _st: String) -> void: _update_views())
	_world.week_settled.connect(func(_report: Dictionary) -> void: _update_views())
	_world.toast_queued.connect(_on_toast_queued)


## 买卡入口（RC-02：资源栏按钮，不新增面板/不注册 PanelStack）
func _on_compute_upgrade_pressed() -> void:
	var view: Dictionary = _world.get_compute_upgrade_view()
	if not bool(view.get("available", false)):
		return
	_world.upgrade_compute(int(view.get("next_tier", 0)))
	_update_views()


func _on_speed_pause_pressed() -> void:
	if _world.user_paused:
		_world.set_paused(false)
	else:
		_world.set_paused(true)
	_update_speed_buttons()


## ResponsiveLayoutManager 竖屏折叠规则信号联动（DR-009）
func _on_layout_folded(_folded: bool, _elements: Array[String]) -> void:
	_sync_folded_elements()


func _set_speed(spd: float) -> void:
	if _world.user_paused:
		_world.set_paused(false)
	if is_equal_approx(spd, 1.0):
		_driver.speed_index = 0
	elif is_equal_approx(spd, 2.0):  # num-ok: 速度档比较（View）
		_driver.speed_index = 1
	elif is_equal_approx(spd, 4.0):  # num-ok: 速度档比较（View）
		_driver.speed_index = 2  # num-ok: 速度档索引（纯逻辑索引）
	_update_speed_buttons()


func _update_speed_buttons() -> void:
	var paused: bool = _world.user_paused
	var spd: float = _driver.get_speed_multiplier()
	speed_pause_btn.button_pressed = paused
	speed_1x_btn.button_pressed = (not paused and is_equal_approx(spd, 1.0))
	speed_2x_btn.button_pressed = (not paused and is_equal_approx(spd, 2.0))  # num-ok: 速度档比较（View）
	speed_4x_btn.button_pressed = (not paused and is_equal_approx(spd, 4.0))  # num-ok: 速度档比较（View）


func _on_dock_tech_pressed() -> void:
	_stack.push_panel(PanelStack.PanelId.TECH_TREE)


func _on_staff_label_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_stack.push_panel(PanelStack.PanelId.ROSTER)


func _on_dock_report_pressed() -> void:
	_presenter.open_report_archive()


func _on_dock_pause_pressed() -> void:
	# 幂等：z2 允许同 id 叠加，重复点击会二次挂载并泄漏前一个实例（#67 顺带封堵）
	if _stack.get_z2_stack().has(PanelStack.PanelId.PAUSE_MENU):
		return
	_world.set_paused(true)
	_stack.push_panel(PanelStack.PanelId.PAUSE_MENU)


## 设置入口即时反馈（z3 级）：设置面板尚未落地，先给可辨反馈，
## 避免"可见了无反馈"（ui-feedback-checklist §1 即时态）；设置面板立单后改接面板。
func _on_pause_settings_requested() -> void:
	_show_toast("设置面板开发中")


## 世界侧 toast（载荷 = `{text_key, …}`；ADR-0016：L3 只取文案键并格式化，不拼装业务）。
## 修复签名不匹配（#80 连带暴露）：信号是 `toast_queued(payload: Dictionary)`，旧实现
## 按 `(msg, color_tag)` 接收 → 任何世界侧 toast 都会抛 "Method expected 2 argument(s)"。
func _on_toast_queued(payload: Dictionary) -> void:
	var key: String = str(payload.get("text_key", ""))
	if key.is_empty() or not TextService.table().has(key):
		return
	_show_toast(TextService.text(key))


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.visible = true


func _update_views() -> void:
	var res_view: Dictionary = _presenter.get_resource_view()
	money_label.text = "资金: " + Formatter.format_money(int(res_view.get("money", 0)))
	compute_label.text = "算力: %d卡时" % int(res_view.get("compute_hours", 0))
	influence_label.text = "声誉: %d" % int(res_view.get("influence", 0))

	research_eff_label.text = "研发力: +%d" % int(res_view.get("research_eff", 0))
	var tech_bonus_pct: float = float(res_view.get("tech_bonus", 0.0)) * 100.0  # num-ok: 百分比换算
	tech_bonus_label.text = "技术加成: +%.0f%%" % tech_bonus_pct

	var week_num: int = int(res_view.get("week", 1))
	week_label.text = "准备周" if week_num == 0 else "第 %d 周" % week_num

	# 买卡入口三态（N9）：可买/置灰 + 顶档提示（文案走 TextService）
	var upgrade_view: Dictionary = _world.get_compute_upgrade_view()
	if str(upgrade_view.get("reason", "")) == "max_tier":
		compute_upgrade_btn.text = TextService.text("compute_upgrade_maxed")
	else:
		compute_upgrade_btn.text = TextService.format(
			"compute_upgrade_button",
			{"price": Formatter.format_money(int(upgrade_view.get("price", 0)))}
		)
	compute_upgrade_btn.disabled = not bool(upgrade_view.get("available", false))

	var ws_view: Dictionary = _presenter.get_workspace_view()
	var active_task: Dictionary = ws_view.get("active_task", {})
	if active_task.is_empty():
		task_title_label.text = "当前无进行中任务"
		task_progress_bar.value = 0.0
	else:
		task_title_label.text = str(active_task.get("title", "未命名任务"))
		task_progress_bar.value = float(active_task.get("progress", 0.0)) * 100.0  # num-ok: 百分比换算

	# 员工双口径：在岗=已指派任务/训练槽，待命=已入职未指派（W0 三人全员待命）
	var staff_total: int = int(ws_view.get("staff_total", 0))
	var staff_assigned: int = int(ws_view.get("staff_assigned", 0))
	var staff_idle: int = int(ws_view.get("staff_idle", 0))
	staff_count_label.text = "在岗研究员: %d/%d人" % [staff_assigned, staff_total]
	idle_staff_label.text = "待命: %d人" % staff_idle
	idle_staff_label.visible = staff_idle > 0

	var rival_view: Dictionary = _presenter.get_rival_view()
	rival_name_label.text = str(rival_view.get("rival_name", ""))
	# 竞对条差距（#77/X3 字段对齐）：名次+差距文本由 L2 出数、L3 只透传；
	# 未出分时为占位符（不再用玩家分数档位冒充"差距"）。
	rival_gap_label.text = str(rival_view.get("gap_text", ""))
	rival_progress_bar.value = float(rival_view.get("rival_progress", 0.0)) * 100.0  # num-ok: 百分比换算

	_update_forecast_row()
	_update_freedom_views()
	_update_speed_buttons()
