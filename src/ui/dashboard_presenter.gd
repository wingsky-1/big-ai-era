class_name DashboardPresenter
extends RefCounted

## Dashboard 呈现控制器（L3 RefCounted，无写实体路径，DR-015 / DR-020）：
## - 四主区表现状态聚合：
##   1. 资源栏（资金/卡时/影响力/周数）
##   2. 工作区（任务进度/训练进度/员工分配）
##   3. 竞对条（深巷逼近进度/差距行/预警灯）
##   4. Dock 导航区（名册/科技/任务/周报）
## - 消费 GameWorld 11 契约信号，转换为 UI 呈现结构字典
## - 协调 PanelStack 处理周报双挂载（自动弹 z2 停喂 / 重看 z1 不暂停）、命名框与 Game Over 卡

var _world: GameWorld
var _stack: PanelStack

var _resource_view: Dictionary = {}
var _workspace_view: Dictionary = {}
var _rival_view: Dictionary = {}
var _dock_view: Dictionary = {}
var _game_over_summary: Dictionary = {}


func setup(world: GameWorld, stack: PanelStack) -> void:
	_world = world
	_stack = stack
	_connect_world_signals()
	_update_all_views()


func get_resource_view() -> Dictionary:
	return _resource_view.duplicate(true)


func get_workspace_view() -> Dictionary:
	return _workspace_view.duplicate(true)


func get_rival_view() -> Dictionary:
	return _rival_view.duplicate(true)


func get_dock_view() -> Dictionary:
	return _dock_view.duplicate(true)


func get_game_over_summary() -> Dictionary:
	return _game_over_summary.duplicate(true)


func _connect_world_signals() -> void:
	if _world == null:
		return

	_world.resources_changed.connect(_on_resources_changed)
	_world.progress_ticked.connect(_on_progress_ticked)
	_world.task_state_changed.connect(_on_task_state_changed)
	_world.week_settled.connect(_on_week_settled)
	_world.game_over.connect(_on_game_over)
	_world.sota_updated.connect(_on_sota_updated)
	_world.model_named.connect(_on_model_named)
	_world.toast_queued.connect(_on_toast_queued)


func _update_all_views() -> void:
	if _world == null:
		return

	var snap: Dictionary = _world.get_ui_snapshot()
	var res: Dictionary = snap.get("resources", {})
	var comp: Dictionary = res.get("compute", {})

	_resource_view = {
		"week": int(snap.get("week", 0)),
		"money": int(res.get("money", 0)),
		"compute_hours": float(comp.get("hours_remaining", 0.0)),
		"compute_tier": int(comp.get("tier", 1)),
		"influence": int(res.get("influence", 0)),
		"research_eff": int(snap.get("research_eff", 0)),
		"tech_bonus": float(snap.get("tech_bonus", 0.0)),
	}

	_workspace_view = {
		"tasks": snap.get("tasks", {}),
		"staff": snap.get("staff", []),
		"training": snap.get("training", {}),
	}

	_rival_view = {
		"sota_best": float(snap.get("sota", {}).get("best", 0.0)),
		"rival_best": float(snap.get("sota", {}).get("rival_best", 0.0)),
		"cursor": int(snap.get("rivals", {}).get("cursor", 0)),
	}

	_dock_view = {
		"has_unread_report": false,
		"active_z1": _stack.get_z1_panel() if _stack != null else "",
	}


func _on_resources_changed(money: int, compute_hours: float, influence: int) -> void:
	_resource_view["money"] = money
	_resource_view["compute_hours"] = compute_hours
	_resource_view["influence"] = influence


func _on_progress_ticked(progress: Dictionary) -> void:
	_workspace_view["current_progress"] = progress.duplicate(true)


func _on_task_state_changed(task_id: String, state: String) -> void:
	_workspace_view["last_task_change"] = {"task_id": task_id, "state": state}


func _on_week_settled(report: Dictionary) -> void:
	_resource_view["week"] = int(report.get("week", _resource_view.get("week", 0)))
	_dock_view["has_unread_report"] = true

	# 周报双挂载之 1：周结自动弹 z2（阻塞停喂 tick）
	if _stack != null:
		_stack.push_panel(PanelStack.PANEL_AUTO_REPORT, PanelStack.LAYER_BLOCKING, report)


func _on_game_over(summary: Dictionary) -> void:
	_game_over_summary = summary.duplicate(true)
	if _stack != null:
		_stack.push_panel(PanelStack.PANEL_GAME_OVER, PanelStack.LAYER_BLOCKING, summary)


func _on_sota_updated(headline: Dictionary) -> void:
	_rival_view["latest_sota"] = headline.duplicate(true)
	_rival_view["sota_best"] = float(headline.get("score", _rival_view.get("sota_best", 0.0)))


func _on_model_named(final_name: String) -> void:
	_workspace_view["named_model"] = final_name


func _on_toast_queued(toast_data: Dictionary) -> void:
	if _stack != null:
		var text: String = str(toast_data.get("text_key", "toast"))
		_stack.push_toast(text)


## 周报双挂载之 2：玩家主动重看周报（z1 层，不暂停，不停喂）
func open_report_archive() -> void:
	if _stack != null:
		_stack.push_panel(PanelStack.PANEL_REPORT_ARCHIVE, PanelStack.LAYER_NORMAL)
		_dock_view["has_unread_report"] = false


## 打开命名仪式弹窗（z2 阻塞层）
func open_naming_dialog() -> void:
	if _stack != null:
		_stack.push_panel(PanelStack.PANEL_NAMING_DIALOG, PanelStack.LAYER_BLOCKING)
