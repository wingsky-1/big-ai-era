class_name MainScene
extends Control
## L3 主台（批7.2 #189 从骨架落为可玩装配）：main._ready 组合根注入 GameWorld
##（L2 门面，**经注入触达——本脚本零 L2 import/零 DataLoader**，ADR-0016/0027），
## 四主区 bind 数据面，周结驱动喂墙钟，z2 门控挂命名待决。
## 原有职责保留：#145 布局切形态（LayoutPolicy 纯函数判定）+ Dock 三键 +
## PanelStack 栈语义（A8 逐批落地：Dock 三键接 z1 面板挂载）。
## 纪律：L3 禁读 L4/禁业务计算；全部数据经注入对象的数据面 view 下发。

## 世界脚本路径（动态 load 而非 import：L3 禁 import L2 红线——运行期解耦，
## 装配方/测试可经 inject_world 覆盖；ADR-0016 经注入触达数据面）
const WORLD_SCRIPT: String = "res://src/entities/game_world.gd"

## 触控下限（=ui.json ui_touch_min 48；装配镜像常量，测试断言两者一致）
const MIN_TOUCH: float = 48.0

## 刷新节流（0.5s 预算内；周内轮询兜底信号驱动）
const REFRESH_INTERVAL: float = 0.5

var _panel_stack: PanelStack = PanelStack.new()
## 世界引用=Object 动态调用（L3 禁 import L2；装配方注入 L2 门面）
var _world: Object = null
var _z2_blocked: bool = false
var _refresh_accum: float = 0.0

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
	_refresh_all()


## 世界注入覆盖（测试/装配方用：注入 mock 或预构造世界；_ready 后调用）
func inject_world(world: Object) -> void:
	_world = world
	_bind_dashboard()
	_refresh_all()


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


## z1 面板打开（A8：未落地面板=防御拒绝不崩；已落地=装配方挂载渲染）
func _open_panel(panel: PanelStack.PanelId) -> void:
	var result: Dictionary = _panel_stack.open(panel)
	if bool(result.get("ok", false)):
		_show_panel(panel)


## 面板渲染挂载（批7.2 最小：z1 面板实体=代码内建 Control，后续批逐落地）
func _show_panel(panel: PanelStack.PanelId) -> void:
	match panel:
		PanelStack.PanelId.TASK_BOARD, PanelStack.PanelId.TECH_TREE, PanelStack.PanelId.PAUSE_MENU:
			pass  # A8 逐批：栈语义+数据面已落，面板实体后批
		_:
			pass


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


## z2 门控：命名待决=世界停+变速置灰（ceremony pending 与 Settlement 同源）
func _sync_z2_gate() -> void:
	var blocked: bool = bool(_world.has_naming_pending())
	if blocked != _z2_blocked:
		_z2_blocked = blocked
		_world.set_z2_blocked(blocked)


## 数据面全量刷新（信号驱动之外的节流轮询兜底；0.5s 预算内）
func _refresh_all() -> void:
	_workspace_view.refresh_now()
	_staff_area_view.refresh_now()
	_resource_bar_view.refresh_now()
	_rival_light.refresh_now()


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


func get_workspace_view() -> WorkspaceView:
	return _workspace_view


func get_staff_area_view() -> StaffAreaView:
	return _staff_area_view


func get_resource_bar_view() -> ResourceBarView:
	return _resource_bar_view


func get_rival_light_entry() -> RivalLightEntry:
	return _rival_light


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
