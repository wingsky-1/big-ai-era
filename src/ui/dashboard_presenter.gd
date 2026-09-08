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
var _freedom_view: Dictionary = {}
var _finale_summary: Dictionary = {}


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


## 自由期三线视图（#82 RF-01/02；数据面在 L2，L3 只拼接排版）。
func get_freedom_view() -> Dictionary:
	return _freedom_view.duplicate(true)


## 终局收尾屏数据（#82 RF-03；由周结载荷 finale 段透传，非独立数据源）。
func get_finale_summary() -> Dictionary:
	return _finale_summary.duplicate(true)


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
	var staff_view: Dictionary = snap.get("staff_view", {})

	_resource_view = {
		"week": int(snap.get("week", 0)),
		"money": int(res.get("money", 0)),
		"compute_hours": float(comp.get("hours_remaining", 0.0)),
		"compute_tier": int(comp.get("tier", 1)),
		"influence": int(res.get("influence", 0)),
		"research_eff": int(snap.get("research_eff", 0)),
		"tech_bonus": float(snap.get("tech_bonus", 0.0)),
		"forecast": (snap.get("forecast", {}) as Dictionary).duplicate(true),
		"forecast_text": _format_forecast_row(snap.get("forecast", {})),
		"forecast_lines": _format_forecast_lines(snap.get("forecast", {})),
	}

	var task_board: Dictionary = snap.get("task_board", {})
	_workspace_view = {
		"tasks": snap.get("tasks", {}),
		"task_board": task_board.duplicate(true),
		# 工作区任务行（#104 P0 修复）：此前缺 active_task 键 → 接了任务仍显示
		# "当前无进行中任务"、进度条恒 0（实现了不可见）。数值/文案均来自 L2。
		"active_task": (task_board.get("active", {}) as Dictionary).duplicate(true),
		"staff": staff_view.get("rows", []),
		"training": snap.get("training", {}),
		"staff_total": int(staff_view.get("total", 0)),
		"staff_assigned": int(staff_view.get("assigned", 0)),
		"staff_idle": int(staff_view.get("idle", 0)),
		"naming": (snap.get("naming", {}) as Dictionary).duplicate(true),
	}

	_rival_view = _build_rival_view(
		snap.get("rival_view", {}), float(snap.get("sota", {}).get("best", 0.0))
	)

	_freedom_view = _build_freedom_view(snap.get("freedom", {}))

	_dock_view = {
		"has_unread_report": false,
		"active_z1": _stack.get_z1_panel() if _stack != null else PanelStack.PanelId.NONE,
	}


## 竞对条视图（消费 L2 rival_view；L3 只拼接排版，ADR-0016）。
func _build_rival_view(view: Dictionary, sota_best: float) -> Dictionary:
	var display: Dictionary = view.get("score_display", {})
	var label: String = str(display.get("label", ""))
	var separator: String = str(display.get("separator", ""))
	var score_line: String = label
	if bool(display.get("reveal_truth", false)):
		score_line = label + separator + str(display.get("score_text", ""))
	return {
		"sota_best": sota_best,
		"rival_best": float(view.get("rival_best", 0.0)),
		"rival_name": str(view.get("rival_name", "")),
		"player_model": str(view.get("player_model", "")),
		"player_score": float(view.get("player_score", 0.0)),
		"score_line": score_line,
		"reveal_truth": bool(display.get("reveal_truth", false)),
		"rival_progress": float(view.get("rival_progress", 0.0)),
		"warn_level": str(view.get("warn_level", "")),
		"warn_weeks_left": int(view.get("warn_weeks_left", 0)),
		# 竞对条字段对齐（#77 / X3）：差距/名次与时间线游标原样透传 L2 出数——
		# 修复"gap 未透传 → 竞对条只显玩家分数档位、看不到差距"的链路断裂。
		"gap": float(view.get("gap", 0.0)),
		"gap_text": str(view.get("gap_text", "")),
		"has_scored": bool(view.get("has_scored", false)),
		"rival_cursor": int(view.get("rival_cursor", 0)),
		"rival_total": int(view.get("rival_total", 0)),
	}


## 自由期三线视图（#82 RF-01/02；消费 L2 freedom_view，L3 只拼接排版，ADR-0016）。
func _build_freedom_view(view: Dictionary) -> Dictionary:
	var label_sep: String = str(view.get("label_separator", ": "))
	var line_sep: String = str(view.get("line_separator", " "))
	var lines_text: Array[String] = []
	var parts: Array[String] = []
	for line_variant: Variant in view.get("lines", []):
		var line: Dictionary = line_variant
		var label: String = str(line.get("label", ""))
		var value_text: String = str(line.get("value_text", ""))
		lines_text.append(label + label_sep + value_text)
		parts.append(label + " " + value_text)
	return {
		"visible": bool(view.get("visible", false)),
		"primary": bool(view.get("primary", false)),
		"stage": str(view.get("stage", "")),
		"section_label": str(view.get("section_label", "")),
		"row_text": line_sep.join(parts),
		"lines_text": lines_text,
		"banner_text": str(view.get("banner_text", "")),
		"king_weeks": int(view.get("king_weeks", 0)),
		"sota_times": int(view.get("sota_times", 0)),
		"tree_n": int(view.get("tree_n", 0)),
		"tree_total": int(view.get("tree_total", 0)),
		"influence": int(view.get("influence", 0)),
	}


## 三线刷新（资源/周结变化后；数据面仍由 L2 出数）。
func _refresh_freedom_view() -> void:
	if _world == null:
		return
	_freedom_view = _build_freedom_view(_world.get_freedom_view())


## 竞对条刷新（出分/竞对发版/命名后；数据面仍由 L2 出数）。
func _refresh_rival_view() -> void:
	if _world == null:
		return
	var latest: Variant = _rival_view.get("latest_sota")
	_rival_view = _build_rival_view(_world.get_rival_view(), _world.sota_best)
	if latest != null:
		_rival_view["latest_sota"] = latest


## 净流入预告副行文本（数值与文案键均由 L2 提供，L3 只格式化拼接）。
func _format_forecast_row(forecast: Dictionary) -> String:
	var display: Dictionary = forecast.get("display", {})
	if not bool(forecast.get("available", false)):
		return str(display.get("unavailable_text", ""))
	return (
		str(display.get("row_label", ""))
		+ str(display.get("net_separator", ""))
		+ str(display.get("approx_prefix", ""))
		+ Formatter.format_delta(int(forecast.get("net", 0)))
	)


## 收支结构展开行（工资 / 运维 / 任务 = 净；零值行不渲染）。
func _format_forecast_lines(forecast: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if not bool(forecast.get("available", false)):
		return lines
	var display: Dictionary = forecast.get("display", {})
	var labels: Dictionary = display.get("line_labels", {})
	var separator: String = str(display.get("line_separator", ""))
	var approx: String = str(display.get("approx_prefix", ""))
	var parts: Array[String] = []
	for line_variant: Variant in forecast.get("lines", []):
		var line: Dictionary = line_variant
		var amount: int = int(line.get("amount", 0))
		if amount == 0:
			continue
		var line_id: String = str(line.get("id", ""))
		parts.append(
			str(labels.get(line_id, line_id)) + " " + approx + Formatter.format_delta(amount)
		)
	var total: String = (
		str(display.get("net_label", ""))
		+ " "
		+ approx
		+ Formatter.format_delta(int(forecast.get("net", 0)))
	)
	lines.append(
		(
			"".join(parts)
			if parts.is_empty()
			else separator.join(parts) + str(display.get("net_separator", "")) + total
		)
	)
	return lines


## 员工三口径刷新（数据面在 L2，L3 只透传；ADR-0016）。
func _refresh_staff_view() -> void:
	var view: Dictionary = _world.get_staff_view()
	_workspace_view["staff"] = view.get("rows", [])
	_workspace_view["staff_total"] = int(view.get("total", 0))
	_workspace_view["staff_assigned"] = int(view.get("assigned", 0))
	_workspace_view["staff_idle"] = int(view.get("idle", 0))


## 净流入预告刷新（资源/周结变化时重算，刷新断言=周结后重算）。
func _refresh_forecast_view() -> void:
	var forecast: Dictionary = _world.get_income_forecast()
	_resource_view["forecast"] = forecast.duplicate(true)
	_resource_view["forecast_text"] = _format_forecast_row(forecast)
	_resource_view["forecast_lines"] = _format_forecast_lines(forecast)


func _on_resources_changed(money: int, compute_hours: float, influence: int) -> void:
	_resource_view["money"] = money
	_resource_view["compute_hours"] = compute_hours
	_resource_view["influence"] = influence
	_refresh_staff_view()
	_refresh_forecast_view()
	# 资金变化会影响"能否接单"（cost>0 资金门），故同步刷新任务板可接性。
	_refresh_task_board_view()


func _on_progress_ticked(progress: Dictionary) -> void:
	_workspace_view["current_progress"] = progress.duplicate(true)


func _on_task_state_changed(task_id: String, state: String) -> void:
	_workspace_view["last_task_change"] = {"task_id": task_id, "state": state}
	# 任务板随接单/完成刷新（#104 P0：否则工作区与任务板停在 setup 时刻的旧值）。
	_refresh_task_board_view()


## 任务板视图刷新（只更新两键，不整表重算；供任务/资金/周结信号调用）。
func _refresh_task_board_view() -> void:
	if _world == null:
		return
	var task_board: Dictionary = _world.get_task_board_view()
	_workspace_view["task_board"] = task_board.duplicate(true)
	_workspace_view["active_task"] = ((task_board.get("active", {}) as Dictionary).duplicate(true))


func _on_week_settled(report: Dictionary) -> void:
	_resource_view["week"] = int(report.get("week", _resource_view.get("week", 0)))
	_dock_view["has_unread_report"] = true
	# 周结后任务进度/队列推进（#104：工作区任务行随周结刷新）
	_refresh_task_board_view()
	# 刷新断言：周结后重算净流入预告（ADR-0015 账期翻页进入新账期）
	_refresh_forecast_view()
	# 竞对条随周结刷新（#77 / X3 根因修复）：出分、竞对发版、时间线游标都在周结变化，
	# 此前只在 sota_updated（破纪录）时刷新 → 未破纪录时竞对条停在上一次状态（恒 0%）。
	_refresh_rival_view()

	# 周报双挂载之 1：周结自动弹 z2（阻塞停喂 tick）
	if _stack != null:
		_stack.push_panel(PanelStack.PanelId.AUTO_REPORT, PanelStack.Layer.BLOCKING, report)

	# 自由期三线刷新（#82 RF-01/02）
	_refresh_freedom_view()

	# 终局收尾屏挂载（#82 RF-03 / Q-R3）：走满单局周数当周自动弹，与破产卡两套并存
	var finale: Dictionary = report.get("finale", {})
	if not finale.is_empty():
		_finale_summary = finale.duplicate(true)
		if _stack != null and not _stack.get_z2_stack().has(PanelStack.PanelId.FINALE):
			_stack.push_panel(PanelStack.PanelId.FINALE, PanelStack.Layer.BLOCKING)

	# 命名仪式（X7）：出分且未命名 → 推 NAMING_DIALOG
	_refresh_naming_view()


## 命名仪式挂载（L2 出 pending 判定，L3 只负责挂载；幂等不叠层）。
func _refresh_naming_view() -> void:
	if _world == null:
		return
	var naming: Dictionary = _world.get_naming_view()
	_workspace_view["naming"] = naming.duplicate(true)
	if not bool(naming.get("pending", false)) or _stack == null:
		return
	if _stack.get_z2_stack().has(PanelStack.PanelId.NAMING_DIALOG):
		return
	_stack.push_panel(PanelStack.PanelId.NAMING_DIALOG, PanelStack.Layer.BLOCKING)


func _on_game_over(summary: Dictionary) -> void:
	_game_over_summary = summary.duplicate(true)
	if _stack != null:
		_stack.push_panel(PanelStack.PanelId.GAME_OVER, PanelStack.Layer.BLOCKING, summary)


func _on_sota_updated(headline: Dictionary) -> void:
	_rival_view["latest_sota"] = headline.duplicate(true)
	_refresh_rival_view()


func _on_model_named(final_name: String) -> void:
	_workspace_view["named_model"] = final_name
	# 榜单显示新名（玩家模型名 + 竞对条刷新）
	_refresh_rival_view()
	_workspace_view["naming"] = _world.get_naming_view() if _world != null else {}


func _on_toast_queued(toast_data: Dictionary) -> void:
	if _stack != null:
		var text: String = str(toast_data.get("text_key", "toast"))
		_stack.push_toast(text)


## 周报双挂载之 2：玩家主动重看周报（z1 层，不暂停，不停喂）
func open_report_archive() -> void:
	if _stack != null:
		_stack.push_panel(PanelStack.PanelId.REPORT_ARCHIVE, PanelStack.Layer.NORMAL)
		_dock_view["has_unread_report"] = false


## 打开命名仪式弹窗（z2 阻塞层）
func open_naming_dialog() -> void:
	if _stack != null:
		_stack.push_panel(PanelStack.PanelId.NAMING_DIALOG, PanelStack.Layer.BLOCKING)
