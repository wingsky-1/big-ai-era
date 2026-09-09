class_name ReportDual
extends RefCounted
## L3 周报双挂载逻辑（#149；ui-ux A.3 OP-UX-03 + B.2 ui_report_dual 行）。
## 挂载决策：显著周+1x=自动弹（z2 WEEKLY_REPORT）；平淡周或加速抑制=灰点
## （z0 资源栏副行灰点位，点一次本周消失）；归档重看=同数据源同构渲染
## （z1 REPORT_ARCHIVE 消费本类归档的 view 字典）。
## 纯逻辑 RefCounted（headless 可单测）：显著判定在 L2 WeeklyReport（谓词单源），
## 本类只做"挂载决策+灰点状态+归档",零业务计算（ADR-0016）。

var _archive: Array[Dictionary] = []
var _last_report: Dictionary = {}
var _dot_active: bool = false
var _dot_dismissed: bool = false


## 收下本周期报 view（装配方在 week_settled 后调用；自动弹/灰点/归档同源）。
## 返回挂载决策 {pop, dot}：
## - pop=显著周且 1x（z2 自动弹候选）
## - dot=不弹（平淡周，或加速档抑制——灰点累积语义：抑制周也留点，退出加速补看）
func ingest(report_view: Dictionary, speed_index: int) -> Dictionary:
	_archive.append(report_view.duplicate(true))
	_last_report = report_view
	var decision := decide(report_view, speed_index)
	_dot_active = bool(decision.get("dot", false))
	_dot_dismissed = false  # 新周灰点未点（点一次本周消失）
	return decision


## 挂载决策纯函数（significant+1x=弹；其余=灰点）。
static func decide(report_view: Dictionary, speed_index: int) -> Dictionary:
	var pop: bool = (
		bool(report_view.get("significant", false)) and speed_index == GameClock.SpeedIndex.ONE_X
	)
	return {"pop": pop, "dot": not pop}


## 灰点点一次消失（ui-ux A.3：灰点点一次本周消失；新周 ingest 重置）。
func dismiss_dot() -> void:
	_dot_dismissed = true
	_dot_active = false


func is_dot_active() -> bool:
	return _dot_active and not _dot_dismissed


## 最新周报 view（自动弹渲染源）。
func get_last_report() -> Dictionary:
	return _last_report


## 归档（重看=同构渲染：与自动弹同一 view 字典）。
func get_archive() -> Array[Dictionary]:
	return _archive.duplicate(true)


func get_archive_count() -> int:
	return _archive.size()
