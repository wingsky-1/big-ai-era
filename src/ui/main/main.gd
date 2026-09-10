class_name MainScene
extends Control
## L3 主台（批7.3 #190 落地最小 UI 交互面）：main._ready 组合根注入 GameWorld
##（L2 门面，**经注入触达——本脚本零 L2 import/零 DataLoader**，ADR-0016/0027），
## 四主区 bind 数据面 + 目标卡带（z0 顶部）+ 六面板实体挂载（z1 三键/指派/
## 目标详情 + z2 命名弹层，PanelHost 双层遮罩）+ z2 门控接命名待决 +
## 员工卡点击指派链路（OP-STA-04 ≤2 击）。
## 原有职责保留：#145 布局切形态（LayoutPolicy 纯函数判定）+ Dock 三键 +
## PanelStack 栈语义 + Web 调试信标（?shot= 门控；状态/靶点/测试钩子）。
## 纪律：L3 禁读 L4/禁业务计算；全部数据经注入对象的数据面 view 下发。

## 世界脚本路径（动态 load 而非 import：L3 禁 import L2 红线——运行期解耦，
## 装配方/测试可经 inject_world 覆盖；ADR-0016 经注入触达数据面）
const WORLD_SCRIPT: String = "res://src/entities/game_world.gd"

## 触控下限（=ui.json ui_touch_min 48；装配镜像常量，测试断言两者一致）
const MIN_TOUCH: float = 48.0

## 刷新节流（0.5s 预算内；周内轮询兜底信号驱动）
const REFRESH_INTERVAL: float = 0.5

## 面板工厂映射（A8 落地面板实体=src/ui/panels/；未登记 id 不构造）
const PANEL_SCRIPTS: Dictionary = {
	PanelStack.PanelId.TASK_BOARD: "res://src/ui/panels/task_board_panel.gd",
	PanelStack.PanelId.TECH_TREE: "res://src/ui/panels/tech_tree_panel.gd",
	PanelStack.PanelId.PAUSE_MENU: "res://src/ui/panels/pause_menu_panel.gd",
	PanelStack.PanelId.STAFF_DETAIL: "res://src/ui/panels/assign_sheet_panel.gd",
	PanelStack.PanelId.TARGET_CARD: "res://src/ui/panels/target_card_panel.gd",
	PanelStack.PanelId.NAMING_DIALOG: "res://src/ui/panels/naming_dialog_panel.gd",
	PanelStack.PanelId.DECISION_CARD: "res://src/ui/panels/decision_card_panel.gd",
	PanelStack.PanelId.WEEKLY_REPORT: "res://src/ui/panels/weekly_report_panel.gd",
}

var _panel_stack: PanelStack = PanelStack.new()
## 世界引用=Object 动态调用（L3 禁 import L2；装配方注入 L2 门面）
var _world: Object = null
var _z2_blocked: bool = false
var _refresh_accum: float = 0.0
var _panels: Dictionary = {}  # PanelId → 面板实例缓存（mount 同源）
var _naming_logic: NamingDialogLogic = null
var _web_shot: String = ""
var _web_hooks_installed: bool = false
## z2 消费循环状态（批7.4：scheduler 只管待弹序，PanelStack 只管在屏互斥——
## 单向流 pop→呈现→源清 pop 下一个；presenting 防重入=同卡不弹两次）
var _presenting: PanelStack.PanelId = PanelStack.PanelId.MAIN_STAGE
var _report_dual: ReportDual = ReportDual.new()
var _last_handled_week: int = 0
var _auto_pop_requested: bool = false
## 数据面源（面板 bind；lambda 捕 self——inject_world 重绑后仍动态取新世界）
var _dash_source: Callable = func() -> Dictionary:
	return _world.get_dashboard_view() if _world != null else {}
var _pending_source: Callable = func() -> Dictionary:
	return _world.get_pending_view() if _world != null else {}

@onready var _report_dot: Button = %ReportDot
@onready var _stage: Control = %MainStage
@onready var _workspace: Control = %WorkspaceZone
@onready var _workspace_view: WorkspaceView = %Workspace
@onready var _staff_area: Control = %StaffZone
@onready var _staff_area_view: StaffAreaView = %StaffArea
@onready var _resource_bar: Control = %ResourceBarZone
@onready var _resource_bar_view: ResourceBarView = %ResourceBarZone
@onready var _rival_light: RivalLightEntry = %RivalLight
@onready var _dock: Control = %DockZone
@onready var _dock_task: Button = %DockTask
@onready var _dock_tree: Button = %DockTree
@onready var _dock_pause: Button = %DockPause
@onready var _goal_band: GoalCardBand = %GoalBand
@onready var _panel_host: PanelHost = %PanelHost


func _ready() -> void:
	_apply_layout()
	for button: Button in [_dock_task, _dock_tree, _dock_pause]:
		button.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	get_viewport().size_changed.connect(_apply_layout)
	# 组合根注入：构造世界并开局（装配批 #188 门面；动态 load 防 L3→L2
	# import——测试/装配方可经 inject_world 覆盖）
	_world = (load(WORLD_SCRIPT) as GDScript).new()
	_world.start_new_game()
	_bind_dashboard()
	_bind_dock()
	_bind_entries()
	_bind_panels()
	_refresh_all()
	_setup_web_beacon()


## 世界注入覆盖（测试/装配方用：注入 mock 或预构造世界；_ready 后调用）
func inject_world(world: Object) -> void:
	_world = world
	_bind_dashboard()
	_bind_panels()
	_refresh_all()


## ---------- Web 调试信标（批7.3 #190）：?shot= 门控，非 Web 零副作用 ----------
## - 状态：window.__DSH_PANEL_STATE__（week/step/门控/资源/视口；0.5s 随刷新
##   节流 + 面板开收即时）——浏览器实测经 agent-browser eval 轮询；
## - 点击助手：window.__DSH_CLICK_AT__(px,py)（Godot Web 单 canvas 无 DOM
##   控件——a11y 快照不可用；助手按视口逻辑坐标→CSS 坐标合成指针序列，
##   经 Godot 真实输入管线驱动 GUI 按压，非直调命令）；
## - 测试钩子：window.__DSH_TEST__.{submit_name,skip_naming}（命名输入等价
##   键入——canvas 内 LineEdit 无 DOM 可聚焦；过滤/命令仍走 NameFilter+
##   WorldCommands 全链）。纪律：只读表现层数据+等价输入；零命令直调
##   （ADR-0016 决策③：不直调非契约方法）。
func _setup_web_beacon() -> void:
	if not OS.has_feature("web"):
		return
	_web_shot = _url_param("shot")
	if _web_shot.is_empty():
		return
	_world.tick(0.0)
	_refresh_all()
	JavaScriptBridge.eval("window.__DSH_SHOT_READY__ = true")
	JavaScriptBridge.eval(_click_helper_js())
	_refresh_web_beacon()
	_install_web_hooks()


func _refresh_web_beacon() -> void:
	if _web_shot.is_empty() or _world == null:
		return
	var dashboard: Dictionary = _world.get_dashboard_view()
	var clock: Dictionary = dashboard["clock"]
	var size := get_viewport().get_visible_rect().size
	var state := {
		"shot": _web_shot,
		"week": int(clock["week"]),
		"step": int(dashboard["goal_card"]["step_index"]),
		"goal_key": str(dashboard["goal_card"].get("goal_key", "")),
		"speed_index": int(clock["speed_index"]),
		"flowing": bool(clock["flowing"]),
		"user_paused": bool(clock["user_paused"]),
		"z2_blocked": bool(clock["z2_blocked"]),
		"naming_pending": bool(dashboard["naming_pending"]),
		"cash": int(dashboard["resources"]["cash"]),
		"influence": int(dashboard["resources"]["influence"]),
		"solvency_weeks": int(dashboard["resources"]["solvency_weeks"]),
		"card_hours_remaining": int(dashboard["resources"]["card_hours_remaining"]),
		"z1_open": _panel_host.is_z1_open(),
		"z2_open": _panel_host.is_z2_open(),
		"viewport": {"w": size.x, "h": size.y},
	}
	JavaScriptBridge.eval("window.__DSH_PANEL_STATE__ = %s" % JSON.stringify(state))


## 命名等价键入钩子（批7.3 #190）：纯 JS 命令队列 + GDScript 0.5s 节流轮询
## 消费（规避 create_callback 无强引用被 JS GC 回收——首版钩子静默丢失教训；
## 命令仍走 NamingDialogPanel→Logic→NameFilter→WorldCommands 全链，非直调）。
func _install_web_hooks() -> void:
	if _web_hooks_installed:
		return
	_web_hooks_installed = true
	JavaScriptBridge.eval(
		"window.__DSH_TEST__ = {queue: [], push: function(cmd){this.queue.push(cmd);}}"
	)


## 轮询消费 JS 队列（submit:NAME / skip；节流在 _refresh_all 0.5s 内）
func _drain_web_hooks() -> void:
	if not _web_hooks_installed:
		return
	var raw := str(JavaScriptBridge.eval("JSON.stringify(window.__DSH_TEST__.queue)"))
	JavaScriptBridge.eval("window.__DSH_TEST__.queue.length = 0")
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Array:
		for command: Variant in parsed as Array:
			_dispatch_web_command(str(command))


func _dispatch_web_command(command: String) -> void:
	var naming := _ensure_panel(PanelStack.PanelId.NAMING_DIALOG) as NamingDialogPanel
	if naming == null:
		return
	if command.begins_with("submit:"):
		naming.submit_text(command.trim_prefix("submit:"))
	elif command == "skip":
		naming.skip_external()


func _click_helper_js() -> String:
	return """
window.__DSH_CLICK_AT__ = function(px, py) {
  const c = document.querySelector('canvas');
  if (!c) return false;
  const vp = window.__DSH_PANEL_STATE__ && window.__DSH_PANEL_STATE__.viewport;
  if (!vp) return false;
  const r = c.getBoundingClientRect();
  const cx = r.left + (px / vp.w) * r.width;
  const cy = r.top + (py / vp.h) * r.height;
  const opts = {bubbles: true, cancelable: true, composed: true, view: window,
    clientX: cx, clientY: cy, button: 0, buttons: 1, pointerId: 7,
    pointerType: 'mouse', isPrimary: true};
  c.dispatchEvent(new PointerEvent('pointermove', opts));
  c.dispatchEvent(new PointerEvent('pointerdown', opts));
  c.dispatchEvent(new PointerEvent('pointerup', Object.assign({}, opts, {buttons: 0})));
  return true;
};
true;
"""


## URL 查询参数读取（仅 Web；非 Web 返回空）
func _url_param(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var script := "new URLSearchParams(window.location.search).get('%s') || ''" % key
	return str(JavaScriptBridge.eval(script))


## ---------- 装配（组合根；四主区 bind 数据面） ----------


func _bind_dashboard() -> void:
	# 工作区：槽 view 源 + TaskBoard 变更信号（既有 bind 形状不变）
	_workspace_view.bind(
		func() -> Array: return _world.get_dashboard_view()["tasks"],
		_world.get_task_board(),
		"task_board_changed",
	)
	# 员工区：名册+槽双源（staff_area bind 五参形状）
	_staff_area_view.bind(
		func() -> Dictionary: return _world.get_dashboard_view()["staff"],
		func() -> Array: return _world.get_dashboard_view()["tasks"],
		_world.get_task_board(),
		_world.get_roster(),
	)
	# 资源栏：resource view 源（presenter 兼容键集，L2 计算）
	_resource_bar_view.bind(
		func() -> Dictionary: return _world.get_dashboard_view()["resources"],
		_world.get_task_board(),
		"task_board_changed",
	)
	# 竞对灯：玩家 SOTA 纪录分数源（float；-1=未出分）
	_rival_light.bind(
		func() -> float: return _world.get_sota_record_score(),
		_world.get_sota_board(),
		"",
	)


func _bind_dock() -> void:
	_dock_task.pressed.connect(func() -> void: _open_panel(PanelStack.PanelId.TASK_BOARD))
	_dock_tree.pressed.connect(func() -> void: _open_panel(PanelStack.PanelId.TECH_TREE))
	_dock_pause.pressed.connect(func() -> void: _open_panel(PanelStack.PanelId.PAUSE_MENU))


## 入口信号接线（_ready 一次；节点常驻不受 inject_world 影响）
func _bind_entries() -> void:
	_staff_area_view.staff_card_clicked.connect(_on_staff_card_clicked)
	_goal_band.band_clicked.connect(func() -> void: _open_panel(PanelStack.PanelId.TARGET_CARD))
	_panel_host.z1_backdrop_pressed.connect(_on_z1_backdrop_pressed)
	# 周报灰点（z1 指示器→点击开 z2 周报面板=同一停流语义，ADR-0028）
	_report_dot.visible = false
	_report_dot.pressed.connect(_on_report_dot_pressed)


## 灰点手开周报（与自动弹同一面板/同一确认路径；非自动弹语境不占 presenting——
## 直接呈现并置位，玩家"知道了"经 _finish_z2 复位）
func _on_report_dot_pressed() -> void:
	if _presenting != PanelStack.PanelId.MAIN_STAGE or _panel_stack.has_blocking_top():
		return
	_presenting = PanelStack.PanelId.WEEKLY_REPORT
	_show_panel(PanelStack.PanelId.WEEKLY_REPORT)


## 面板数据面 bind（构造时+inject_world 重绑；Callable 捕 self——重绑幂等）
func _bind_panels() -> void:
	for panel_id: PanelStack.PanelId in _panels.keys():
		_bind_panel(panel_id, _panels[panel_id] as ZPanel)


func _bind_panel(panel_id: PanelStack.PanelId, panel: ZPanel) -> void:
	var commands: Object = _world.get_commands() if _world != null else null
	match panel_id:
		PanelStack.PanelId.TASK_BOARD:
			(panel as TaskBoardPanel).bind(_dash_source, commands)
		PanelStack.PanelId.TECH_TREE:
			(panel as TechTreePanel).bind(_dash_source, commands)
		PanelStack.PanelId.PAUSE_MENU:
			(
				(panel as PauseMenuPanel)
				. bind(
					_dash_source,
					Callable(commands, "cycle_speed"),
					Callable(commands, "set_paused"),
					Callable(_world, "manual_save"),
				)
			)
		PanelStack.PanelId.STAFF_DETAIL:
			(panel as AssignSheetPanel).bind(_dash_source, commands)
		PanelStack.PanelId.TARGET_CARD:
			(panel as TargetCardPanel).bind(_dash_source)
		PanelStack.PanelId.NAMING_DIALOG:
			_naming_logic = NamingDialogLogic.new()
			(
				_naming_logic
				. bind(
					Callable(commands, "submit_name"),
					Callable(commands, "skip_naming"),
					_pending_source,
				)
			)
			(panel as NamingDialogPanel).bind(_naming_logic, _pending_source)
		PanelStack.PanelId.DECISION_CARD:
			(panel as DecisionCardPanel).bind(
				Callable(commands, "submit_decision"), Callable(commands, "get_decision_view")
			)
		PanelStack.PanelId.WEEKLY_REPORT:
			(panel as WeeklyReportPanel).bind(_world.get_report_view)
		_:
			pass


## 面板实例获取（懒构造+信号连接一次；未登记 id=防御返回 null）
func _ensure_panel(panel_id: PanelStack.PanelId) -> ZPanel:
	var panel: ZPanel = _panels.get(panel_id)
	if panel != null:
		return panel
	if not PANEL_SCRIPTS.has(panel_id):
		return null
	panel = (load(str(PANEL_SCRIPTS[panel_id])) as GDScript).new() as ZPanel
	panel.close_requested.connect(_on_panel_close_requested.bind(panel_id))
	_panels[panel_id] = panel
	_bind_panel(panel_id, panel)
	return panel


func _on_panel_close_requested(panel_id: PanelStack.PanelId) -> void:
	if _is_z2_panel(panel_id):
		_finish_z2(panel_id)
		return
	_panel_stack.close(panel_id)
	_panel_host.close_z1()
	_refresh_web_beacon()


## z1 点外关闭（轻遮罩；栈顶 z1 回退后收层）
func _on_z1_backdrop_pressed() -> void:
	var top: PanelStack.PanelId = _panel_stack.top()
	if PanelStack.z_of(top) == 1:
		_panel_stack.close(top)
	_panel_host.close_z1()
	_refresh_web_beacon()


func _open_panel(panel_id: PanelStack.PanelId) -> void:
	var result: Dictionary = _panel_stack.open(panel_id)
	if not bool(result.get("ok", false)):
		return
	_show_panel(panel_id)


## 面板呈现挂载（z2 命名弹层走阻塞层；z1 走轻遮罩层并 mount 句柄）
func _show_panel(panel_id: PanelStack.PanelId) -> void:
	var panel := _ensure_panel(panel_id)
	if panel == null:
		return
	panel.refresh()
	if _is_z2_panel(panel_id):
		# z2 入栈（同层互斥=栈语义；z2 在位=has_blocking_top→停流判定生效）
		_panel_stack.open(panel_id)
		panel.set_close_visible(false)
		_panel_host.show_z2(panel)
	else:
		_panel_host.show_z1(panel)
		_panel_stack.mount(panel_id, panel)
	_refresh_web_beacon()


## z2 面板判定（决策卡/命名/周报=阻塞层；其余=z1 轻遮罩——ADR-0028 单向流）
func _is_z2_panel(panel_id: PanelStack.PanelId) -> bool:
	return (
		panel_id == PanelStack.PanelId.NAMING_DIALOG
		or panel_id == PanelStack.PanelId.DECISION_CARD
		or panel_id == PanelStack.PanelId.WEEKLY_REPORT
	)


func _on_staff_card_clicked(staff_id: String) -> void:
	var assign := _ensure_panel(PanelStack.PanelId.STAFF_DETAIL) as AssignSheetPanel
	if assign == null:
		return
	assign.open_for(staff_id, _staff_name_of(staff_id))
	_open_panel(PanelStack.PanelId.STAFF_DETAIL)


func _staff_name_of(staff_id: String) -> String:
	if _world == null:
		return staff_id
	for staff: Dictionary in _world.get_dashboard_view()["staff"]["staff"]:
		if str(staff.get("id", "")) == staff_id:
			return str(staff.get("name", staff_id))
	return staff_id


## ---------- 游戏循环（唯一墙钟喂入口） ----------


func _process(delta: float) -> void:
	if _world == null:
		return
	_world.tick(delta)
	_sync_z2_gate()
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		_refresh_all()


## z2 门控：命名待决=世界停+变速置灰；命名弹层随 pending 翻转开收
##（ceremony pending 与 Settlement 同源；z2 遮罩点击不关=强迫处理）
func _sync_z2_gate() -> void:
	if _world == null:
		return
	var sources := _active_z2_sources()
	# 呈现中面板源已清=玩家已处理：命名流自动收（提交即清 pending）；决策卡/
	# 周报由确认钮 close_requested 走 _on_panel_close_requested 收层
	if _presenting != PanelStack.PanelId.MAIN_STAGE:
		if _presenting == PanelStack.PanelId.NAMING_DIALOG and not sources.has(_presenting):
			_finish_z2(_presenting)
	# 无呈现且无 z2 在屏→呈现最高优先源（ModalScheduler 秩序：决策>周报>命名
	# —— append 序即优先级序；同帧并发=同帧按序串行呈现）
	if _presenting == PanelStack.PanelId.MAIN_STAGE and not sources.is_empty():
		_presenting = sources[0]
		_show_panel(_presenting)
	# 停流=f(任意 z2 在屏 或 任一 pending 源活跃)——与触发源解耦（ADR-0028）：
	# 自动弹周报与灰点手开周报同一停流语义
	var blocked := _panel_stack.has_blocking_top() or not sources.is_empty()
	if blocked != _z2_blocked:
		_z2_blocked = blocked
		_world.set_z2_blocked(blocked)


## 活跃 z2 源（ModalScheduler 秩序：DECISION(0)>NAMING(1)>REPORT(2)；
## append 序=优先级序）。报告源=显著周未消费（自动弹/灰点打开后消费）。
func _active_z2_sources() -> Array[PanelStack.PanelId]:
	var sources: Array[PanelStack.PanelId] = []
	if _world == null:
		return sources
	var commands: Object = _world.get_commands()
	if not (commands.get_decision_view() as Dictionary).is_empty():
		sources.append(PanelStack.PanelId.DECISION_CARD)
	if bool(_world.has_naming_pending()):
		sources.append(PanelStack.PanelId.NAMING_DIALOG)
	if _auto_pop_requested:
		sources.append(PanelStack.PanelId.WEEKLY_REPORT)
	return sources


## z2 面板完成收层（确认钮/pending 清驱动；栈回退+遮罩收起+呈现位复位）
func _finish_z2(panel_id: PanelStack.PanelId) -> void:
	_panel_stack.close(panel_id)
	_panel_host.close_z2()
	if panel_id == PanelStack.PanelId.WEEKLY_REPORT:
		_auto_pop_requested = false  # 报告已消费（自动弹与灰点手开共用）
		_report_dot.visible = false
	_presenting = PanelStack.PanelId.MAIN_STAGE
	_refresh_web_beacon()


## 数据面全量刷新（信号驱动之外的节流轮询兜底；0.5s 预算内）
func _refresh_all() -> void:
	if _world == null:
		return
	_workspace_view.refresh_now()
	_staff_area_view.refresh_now()
	_resource_bar_view.refresh_now()
	_rival_light.refresh_now()
	var dashboard: Dictionary = _world.get_dashboard_view()
	_goal_band.refresh(dashboard["goal_card"])
	_sync_report_channel(dashboard)
	var z1: Control = _panel_host.get_z1_panel()
	if _panel_host.is_z1_open() and z1 is ZPanel:
		(z1 as ZPanel).refresh()
	_drain_web_hooks()
	_refresh_web_beacon()


## 周报双通道同步（批7.4：周号翻动→ReportDual.ingest 挂载决策——显著+1x=自动
## 弹请求；其余=灰点亮（dot）。ReportDual 为 #149 已交付挂载决策纯函数组件）
func _sync_report_channel(dashboard: Dictionary) -> void:
	var clock: Dictionary = dashboard.get("clock", {})
	var week := int(clock.get("week", 0))
	if week == _last_handled_week:
		return
	_last_handled_week = week
	var report_view: Dictionary = _world.get_report_view()
	if report_view.is_empty():
		return
	var decision: Dictionary = _report_dual.ingest(report_view, int(clock.get("speed_index", 0)))
	_auto_pop_requested = bool(decision.get("pop", false))
	_report_dot.visible = bool(decision.get("dot", false))


## ---------- 数据面（测试/装配方读） ----------


func get_layout_state() -> Dictionary:
	var viewport := get_viewport()
	var size: Vector2 = viewport.size if viewport != null else Vector2(1280, 720)
	var portrait := LayoutPolicy.is_portrait(size.x, size.y)
	return {
		"portrait": portrait,
		"workspace_fold": LayoutPolicy.fold_shape(LayoutPolicy.ZONE_WORKSPACE, portrait),
		"staff_fold": LayoutPolicy.fold_shape(LayoutPolicy.ZONE_STAFF, portrait),
		"resource_fold": LayoutPolicy.fold_shape(LayoutPolicy.ZONE_RESOURCE_BAR, portrait),
		"dock_fold": LayoutPolicy.fold_shape(LayoutPolicy.ZONE_DOCK, portrait),
	}


func get_panel_stack() -> PanelStack:
	return _panel_stack


func get_panel_host() -> PanelHost:
	return _panel_host


func get_workspace_view() -> WorkspaceView:
	return _workspace_view


func get_staff_area_view() -> StaffAreaView:
	return _staff_area_view


func get_resource_bar_view() -> ResourceBarView:
	return _resource_bar_view


func get_rival_light_entry() -> RivalLightEntry:
	return _rival_light


func get_goal_band() -> GoalCardBand:
	return _goal_band


## 面板实例（测试/信标钩子读；懒构造契约同 _ensure_panel）
func get_panel(panel_id: PanelStack.PanelId) -> ZPanel:
	return _ensure_panel(panel_id)


## 世界引用（测试/装配方读；生产只经 get_dashboard_view 动态取）
func get_world() -> Object:
	return _world


## ---------- 私有（布局切形态；原 #145 语义保留） ----------


func _apply_layout() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var portrait := LayoutPolicy.is_portrait(viewport.size.x, viewport.size.y)
	var staff_fold := LayoutPolicy.fold_shape(LayoutPolicy.ZONE_STAFF, portrait)
	_staff_area_view.apply_shape(staff_fold)
	_resource_bar_view.apply_shape(
		LayoutPolicy.fold_shape(LayoutPolicy.ZONE_RESOURCE_BAR, portrait)
	)
	if staff_fold == LayoutPolicy.FOLD_HSCROLL:
		_staff_area.custom_minimum_size = Vector2(0, 96.0)
		_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_staff_area.custom_minimum_size = Vector2(280.0, 0.0)
	_staff_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
