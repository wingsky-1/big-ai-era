class_name PanelStack
extends RefCounted

## UI 面板栈管理器（L3 RefCounted，DR-015 / DR-020 / U48–U55）：
## - z0–z3 四层架构：
##   z0: 基础底板 / Dashboard 工作台（常驻）
##   z1: 常规功能面板（互斥，栈深 1，不暂停世界：名册/科技树/任务管理/周报重看/开场引导）
##   z2: 阻塞面板集合（"世界等玩家才停"：决策卡/命名框/Game Over/暂停菜单/自动周报）
##   z3: 顶层浮层 / Toast 层（同屏<=3，倒计时绑游戏时间，不阻塞，不入档）
## - 遮罩与点击规则：
##   z1 打开时点击遮罩一律关闭；
##   z2 暂停菜单点击遮罩恢复（关闭菜单）；
##   z2 其余阻塞面板（决策卡/命名/Game Over 等）点击遮罩不关闭（强迫玩家处理）
## - 动画锁与排队：pop 动画执行期间 push 操作进入排队队列；同帧按信号到达序串行
## - 面板与层级一律枚举（v0.1.3 起禁字符串面板 id）：封闭集合编译期可查，
##   状态不入存档/快照，无序列化兼容负担。

signal panel_pushed(panel: PanelId, layer: int)
signal panel_popped(panel: PanelId, layer: int)
signal mask_state_changed(visible: bool, dismissable: bool)
signal tick_feeding_gate_changed(allow_feeding: bool)

## 面板注册表（封闭枚举；新增面板必须在此登记）
enum PanelId {
	NONE = -1,  ## 哨兵：无面板 / pop 时表示"弹出栈顶"
	DASHBOARD,  ## z0 常驻工作台（概念席位，不入栈）
	ROSTER,  ## z1 员工名册
	TECH_TREE,  ## z1 科技树
	TASK_MGMT,  ## z1 任务管理（预留）
	REPORT_ARCHIVE,  ## z1 周报重看
	INTRO,  ## z1 开场引导（v0.1.3）
	DECISION_CARD,  ## z2 决策卡
	NAMING_DIALOG,  ## z2 命名仪式
	GAME_OVER,  ## z2 终局结算
	PAUSE_MENU,  ## z2 暂停菜单（遮罩可关）
	AUTO_REPORT,  ## z2 周结自动周报
}

## 面板所在操作层级（z0/z3 为概念层，不入栈操作）
enum Layer {
	NORMAL = 1,  ## z1 常规互斥层
	BLOCKING = 2,  ## z2 阻塞层
}

var _z1_panel: PanelId = PanelId.NONE
var _z2_stack: Array[PanelId] = []
var _push_queue: Array[Dictionary] = []
var _animating: bool = false
var _toasts: Array[Dictionary] = []


## 白名单 z2 阻塞面板判定（封闭集合 match，编译期可查；"世界等玩家"才停）
static func is_blocking(panel: PanelId) -> bool:
	match panel:
		PanelId.DECISION_CARD, PanelId.NAMING_DIALOG, PanelId.GAME_OVER:
			return true
		PanelId.PAUSE_MENU, PanelId.AUTO_REPORT:
			return true
		_:
			return false


func get_z1_panel() -> PanelId:
	return _z1_panel


func get_z2_stack() -> Array[PanelId]:
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


## 打开面板接口（layer 传 -1 时按面板注册表自动推导）
func push_panel(panel: PanelId, layer: int = -1, payload: Dictionary = {}) -> bool:
	if panel == PanelId.NONE:
		push_error("PanelStack: 拒绝推送 NONE 哨兵面板")
		return false

	# 自动推导层级
	if layer == -1:
		layer = _infer_layer(panel)

	# 若动画进行中，入队排队
	if _animating:
		_push_queue.append({"panel": panel, "layer": layer, "payload": payload})
		return true

	match layer:
		Layer.NORMAL:
			# 常规面板互斥，栈深为 1
			if _z1_panel != PanelId.NONE and _z1_panel != panel:
				panel_popped.emit(_z1_panel, Layer.NORMAL)
			_z1_panel = panel
			panel_pushed.emit(panel, Layer.NORMAL)
			_update_mask()
			return true

		Layer.BLOCKING:
			# z2 阻塞层
			_z2_stack.append(panel)
			panel_pushed.emit(panel, Layer.BLOCKING)
			_update_mask()
			tick_feeding_gate_changed.emit(is_tick_feeding_allowed())
			return true

		_:
			return false


## 关闭面板接口（panel 传 NONE 时优先从 z2 顶出，其次从 z1 顶出）
func pop_panel(panel: PanelId = PanelId.NONE) -> bool:
	if panel == PanelId.NONE:
		if not _z2_stack.is_empty():
			panel = _z2_stack.back()
		elif _z1_panel != PanelId.NONE:
			panel = _z1_panel

	if panel == PanelId.NONE:
		return false

	var popped: bool = false
	if not _z2_stack.is_empty() and _z2_stack.has(panel):
		_z2_stack.erase(panel)
		panel_popped.emit(panel, Layer.BLOCKING)
		popped = true
		tick_feeding_gate_changed.emit(is_tick_feeding_allowed())
	elif _z1_panel == panel:
		_z1_panel = PanelId.NONE
		panel_popped.emit(panel, Layer.NORMAL)
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
		var top_z2: PanelId = _z2_stack.back()
		if top_z2 == PanelId.PAUSE_MENU:
			pop_panel(top_z2)
		return

	# 2. 如果只有 z1 常规面板：点击遮罩一律关闭
	if _z1_panel != PanelId.NONE:
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
	push_panel(item.get("panel", PanelId.NONE), int(item.get("layer")), item.get("payload", {}))


func _infer_layer(panel: PanelId) -> int:
	return Layer.BLOCKING if is_blocking(panel) else Layer.NORMAL


func _update_mask() -> void:
	var visible_mask: bool = _z1_panel != PanelId.NONE or not _z2_stack.is_empty()
	var dismissable: bool = false
	if not _z2_stack.is_empty():
		dismissable = (_z2_stack.back() == PanelId.PAUSE_MENU)
	elif _z1_panel != PanelId.NONE:
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
