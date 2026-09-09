class_name MainScene
extends Control
## L3 主台骨架（#145；ui-ux-spec A.1 四主区 + architecture §2.1 main/）。
## 装配职责：
## - 四主区容器（工作区/员工区/资源栏/Dock）按视口形态切布局：竖屏=工作区
##   上（永不折叠）+员工区横滑行+资源栏副行；横屏=工作区左宽栏+员工区右
##   窄栏（LayoutPolicy 纯函数判定，零业务计算）；
## - Dock 三键（任务板/科技树/暂停）=PanelStack.PanelId 冻结集（本骨架期
##   只登记键+最小可点按钮；面板实体逐批装配，A8）；
## - PanelStack 实例（z0-z3 栈语义；后续面板批 open/close 消费）。
## 触控纪律（ui-ux B.5）：全部可点元素 custom_minimum_size ≥48px（灰点
## ≥24）——Dock 三键按 ui.json ui_touch_min 声明（表断言锁定 48；本脚本
## 常量=表值镜像，防 L3 读表违规——双通道由 GUT 断言锁一致）。
## L3 禁读 L4/禁业务计算（ADR-0016/0027）；本脚本零 DataLoader。

## 触控下限（=ui.json ui_touch_min 48；装配镜像常量，测试断言两者一致）
const MIN_TOUCH: float = 48.0

var _panel_stack: PanelStack = PanelStack.new()

@onready var _stage: Control = %MainStage
@onready var _workspace: Control = %WorkspaceZone
@onready var _staff_area: Control = %StaffZone
@onready var _resource_bar: Control = %ResourceBarZone
@onready var _dock: Control = %DockZone
@onready var _dock_task: Button = %DockTask
@onready var _dock_tree: Button = %DockTree
@onready var _dock_pause: Button = %DockPause


func _ready() -> void:
	_apply_layout()
	for button: Button in [_dock_task, _dock_tree, _dock_pause]:
		button.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	get_viewport().size_changed.connect(_apply_layout)


## 竖屏/横屏布局切形态（LayoutPolicy 纯函数判定；工作区永不折叠=策略保证，
## 装配不做业务判定）
func _apply_layout() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var portrait := LayoutPolicy.is_portrait(viewport.size.x, viewport.size.y)
	var staff_fold := LayoutPolicy.fold_shape(LayoutPolicy.ZONE_STAFF, portrait)
	if staff_fold == LayoutPolicy.FOLD_HSCROLL:
		# 竖屏：员工区折为横滑行单行（卡高 ≥48 由员工卡批声明）
		_staff_area.custom_minimum_size = Vector2(0, 96.0)
		_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		# 横屏：员工区右窄栏
		_staff_area.custom_minimum_size = Vector2(280.0, 0.0)
	_staff_area.size_flags_vertical = Control.SIZE_EXPAND_FILL


## 数据面（测试/装配方读：当前形态与折叠态）
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
