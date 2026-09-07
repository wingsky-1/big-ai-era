class_name PanelStack
extends RefCounted

## UI 面板栈管理器（L3 RefCounted，DR-015 / DR-020 / U48–U55）：
## - z0–z3 四层架构：
##   z0: 基础底板 / Dashboard 工作台（常驻）
##   z1: 常规功能面板（互斥，栈深 1，不暂停世界：名册/科技树/任务管理/周报重看）
##   z2: 阻塞面板集合（"世界等玩家才停"：决策卡/命名框/Game Over/暂停菜单/自动周报）
##   z3: 顶层浮层 / Toast 层（同屏<=3，倒计时绑游戏时间，不阻塞，不入档）
## - 遮罩与点击规则：
##   z1 打开时点击遮罩一律关闭；
##   z2 暂停菜单点击遮罩恢复（关闭菜单）；
##   z2 其余阻塞面板（决策卡/命名/Game Over 等）点击遮罩不关闭（强迫玩家处理）
## - 动画锁与排队：pop 动画执行期间 push 操作进入排队队列；同帧按信号到达序串行

signal panel_pushed(panel_id: String, layer: int)
signal panel_popped(panel_id: String, layer: int)
signal mask_state_changed(visible: bool, dismissable: bool)
signal tick_feeding_gate_changed(allow_feeding: bool)

const LAYER_BASE: int = 0
const LAYER_NORMAL: int = 1
const LAYER_BLOCKING: int = 2
const LAYER_TOAST: int = 3

## 官方登记的 9 大核心面板注册表（与 11 契约命令完全对账）
const PANEL_DASHBOARD: String = "panel_dashboard"  # z0
const PANEL_ROSTER: String = "panel_roster"  # z1
const PANEL_TECH_TREE: String = "panel_tech_tree"  # z1
const PANEL_TASK_MGMT: String = "panel_task_mgmt"  # z1
const PANEL_REPORT_ARCHIVE: String = "panel_report_archive"  # z1 (周报重看)
const PANEL_DECISION_CARD: String = "panel_decision_card"  # z2
const PANEL_NAMING_DIALOG: String = "panel_naming_dialog"  # z2
const PANEL_GAME_OVER: String = "panel_game_over"  # z2
const PANEL_PAUSE_MENU: String = "panel_pause_menu"  # z2
const PANEL_AUTO_REPORT: String = "panel_auto_report"  # z2 (自动周报)

## 白名单 z2 阻塞面板集合（"世界等玩家"才停）
const BLOCKING_PANELS: Dictionary = {
	PANEL_DECISION_CARD: true,
	PANEL_NAMING_DIALOG: true,
	PANEL_GAME_OVER: true,
	PANEL_PAUSE_MENU: true,
	PANEL_AUTO_REPORT: true,
}

var _z1_panel: String = ""
var _z2_stack: Array[String] = []
var _push_queue: Array[Dictionary] = []
var _animating: bool = false
var _toasts: Array[Dictionary] = []


func get_z1_panel() -> String:
	return _z1_panel


func get_z2_stack() -> Array[String]:
	return _z2_stack.duplicate()


func get_toasts() -> Array[Dictionary]:
	return _toasts.duplicate(true)


func is_animating() -> bool:
	return _animating


## 判定当前是否有 z2 阻塞面板打开
func has_blocking_panel() -> bool:
	return not _z2_stack.is_empty()


## 视图停喂门控：若存在 z2 阻塞面板则停喂 tick
func is_tick_feeding_allowed() -> bool:
	return not has_blocking_panel()


## 打开面板接口
func push_panel(panel_id: String, layer: int = -1, payload: Dictionary = {}) -> bool:
	# 自动推导层级
	if layer == -1:
		layer = _infer_layer(panel_id)

	# 若动画进行中，入队排队
	if _animating:
		_push_queue.append({"panel_id": panel_id, "layer": layer, "payload": payload})
		return true

	match layer:
		LAYER_NORMAL:
			# 常规面板互斥，栈深为 1
			if _z1_panel != "" and _z1_panel != panel_id:
				panel_popped.emit(_z1_panel, LAYER_NORMAL)
			_z1_panel = panel_id
			panel_pushed.emit(panel_id, LAYER_NORMAL)
			_update_mask()
			return true

		LAYER_BLOCKING:
			# z2 阻塞层
			_z2_stack.append(panel_id)
			panel_pushed.emit(panel_id, LAYER_BLOCKING)
			_update_mask()
			tick_feeding_gate_changed.emit(is_tick_feeding_allowed())
			return true

		_:
			return false


## 关闭面板接口
func pop_panel(panel_id: String = "") -> bool:
	# 若指定面板为空，优先从 z2 顶出，其次从 z1 顶出
	if panel_id == "":
		if not _z2_stack.is_empty():
			panel_id = _z2_stack.back()
		elif _z1_panel != "":
			panel_id = _z1_panel

	if panel_id == "":
		return false

	var popped: bool = false
	if not _z2_stack.is_empty() and _z2_stack.has(panel_id):
		_z2_stack.erase(panel_id)
		panel_popped.emit(panel_id, LAYER_BLOCKING)
		popped = true
		tick_feeding_gate_changed.emit(is_tick_feeding_allowed())
	elif _z1_panel == panel_id:
		_z1_panel = ""
		panel_popped.emit(panel_id, LAYER_NORMAL)
		popped = true

	if popped:
		_update_mask()
		_process_queue()

	return popped


## 遮罩点击事件处理
func on_mask_clicked() -> void:
	# 遮罩规则（DR-020）：
	# 1. 如果有 z2 阻塞面板：
	#    - 暂停菜单：点击遮罩关闭（恢复游戏）
	#    - 决策卡/命名/Game Over/自动周报：点击遮罩不关闭（强迫玩家交互选择）
	if not _z2_stack.is_empty():
		var top_z2: String = _z2_stack.back()
		if top_z2 == PANEL_PAUSE_MENU:
			pop_panel(top_z2)
		return

	# 2. 如果只有 z1 常规面板：点击遮罩一律关闭
	if _z1_panel != "":
		pop_panel(_z1_panel)


## 锁定动画锁（动画播放完毕后调用 unlock_animation）
func lock_animation() -> void:
	_animating = true


func unlock_animation() -> void:
	_animating = false
	_process_queue()


func _process_queue() -> void:
	if _animating or _push_queue.is_empty():
		return
	var item: Dictionary = _push_queue.pop_front()
	push_panel(str(item.get("panel_id")), int(item.get("layer")), item.get("payload", {}))


func _infer_layer(panel_id: String) -> int:
	if BLOCKING_PANELS.has(panel_id):
		return LAYER_BLOCKING
	return LAYER_NORMAL


func _update_mask() -> void:
	var visible_mask: bool = _z1_panel != "" or not _z2_stack.is_empty()
	var dismissable: bool = false
	if not _z2_stack.is_empty():
		dismissable = (_z2_stack.back() == PANEL_PAUSE_MENU)
	elif _z1_panel != "":
		dismissable = true
	mask_state_changed.emit(visible_mask, dismissable)


## ============ Toast 顶层管理器（z3）============


## 发送 Toast：同屏最多 3 条，超出则顶出最旧一条，不入档
func push_toast(text: String, duration_seconds: float = 3.0) -> void:
	if _toasts.size() >= 3:
		_toasts.pop_front()

	(
		_toasts
		. append(
			{
				"text": text,
				"time_left": duration_seconds,
				"duration": duration_seconds,
			}
		)
	)


## 步进推进 Toast 剩余时间（绑定的游戏时间）
func update_toasts(delta: float) -> void:
	var idx: int = _toasts.size() - 1
	while idx >= 0:
		var t: Dictionary = _toasts[idx]
		t["time_left"] = float(t.get("time_left", 0.0)) - delta
		if float(t["time_left"]) <= 0.0:
			_toasts.remove_at(idx)
		idx -= 1
