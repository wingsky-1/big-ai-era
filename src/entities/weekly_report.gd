class_name WeeklyReport
extends RefCounted
## L2 周报构建（#149；architecture §2.1 weekly_report.gd + ui-ux B.2 周报行
## /A.3 OP-UX-03 + time-spec D.2 平淡周阈值）。职责：
## - 行类型枚举 RowKind + 呈现顺序（账本对账→事件→竞对→仪式，OP-UX-03 收口）；
## - 行收集：add_row（事件/仪式天然显著）/add_delta_row（变化对经显著谓词）；
## - 显著变化谓词（单一源）：|Δ| ≥ time_bland_threshold% 或符号翻转，阈值读
##   time.json（time-spec D.2「与 ui-ux 周报收敛谓词同源」；ui.json
##   ui_report_significant=同值镜像，测试断言两表一致）；
## - 数据面 get_report_view()：{week, significant, rows[按 kind 序]}——自动弹
##   （显著周 z2）/灰点（平淡周 z0）/归档（z1 同构）三挂载共用同一 view；
## - 自动弹门控 should_auto_pop(speed_index)：仅 1x 弹（ui-ux A.2「4x 下不弹，
##   灰点累积，退出 4x 补看」；2x 同为加速档不弹——弹窗只在 1x 出现）。
## 硬约束：RefCounted 零 Node（headless 可单测）；读 time.json（L2 合法）；
## 数值零硬编码（阈值表驱动，代码零数值）。

## 行类型（呈现顺序语义；数值=排序秩，账本最早仪式最晚）
enum RowKind {
	LEDGER,  # 账本对账（收入/支出/结算行）
	EVENT,  # 事件（通知/决策/解锁/toast 类收口）
	RIVAL,  # 竞对（时间线/动作/预警/撞车）
	RITUAL,  # 仪式（出分/命名/晋升/大赏）
}

const TIME_PATH: String = "res://src/data/time.json"
const KEY_BLAND_THRESHOLD: String = "time_bland_threshold"
## 行类型→呈现秩（账本对账→事件→竞对→仪式；同秩保序=稳定排序）
const ROW_KIND_RANK: Dictionary = {
	RowKind.LEDGER: 0,
	RowKind.EVENT: 1,
	RowKind.RIVAL: 2,
	RowKind.RITUAL: 3,
}

var _week: int = 0
var _rows: Array[Dictionary] = []
var _significant: bool = false
var _bland_threshold: int = 5


func _init() -> void:
	var table := DataLoader.load_json(TIME_PATH)
	_bland_threshold = int(table.get(KEY_BLAND_THRESHOLD, 5))


## 显著变化谓词（time-spec D.2「变化 ≥5% 或符号翻转」；threshold_pct 表驱动传参）。
## 语义：
## - prev==cur=不显著；从无到有/到无（任一侧 0）=显著（100% 变化，含符号翻转）；
## - 正↔负符号翻转=显著（无论幅值）；同号=幅值百分比 ≥ 阈值。
static func is_significant_change(prev: float, cur: float, threshold_pct: int) -> bool:
	if prev == cur:
		return false
	if prev == 0.0 or cur == 0.0:
		return true
	if (prev < 0.0) != (cur < 0.0):
		return true
	var base := maxf(absf(prev), 0.0001)
	return absf(cur - prev) / base * 100.0 >= float(threshold_pct)


## 周起始（装配方周结启动时调用：清行+记周号；z2 阻塞跳过周不调用）。
func begin_week(week: int) -> void:
	_week = week
	_rows = []
	_significant = false


## 普通行（事件/仪式等天然显著；行本身即"发生了什么"）。
func add_row(kind: RowKind, text: String, significant: bool = true) -> void:
	_append_row(kind, text, significant)


## 变化对行（数值行：prev/cur 相邻周同口径值，显著=谓词单源计算）。
func add_delta_row(kind: RowKind, text: String, prev: float, cur: float) -> void:
	var flag := is_significant_change(prev, cur, _bland_threshold)
	_append_row(kind, text, flag)


func _append_row(kind: RowKind, text: String, significant: bool) -> void:
	(
		_rows
		. append(
			{
				"kind": kind,
				"kind_rank": int(ROW_KIND_RANK.get(kind, 99)),
				"text": text,
				"significant": significant,
			}
		)
	)
	if significant:
		_significant = true


## 本周显著判定（任一显著行 ⇒ 显著周 ⇒ 自动弹候选）
func is_significant() -> bool:
	return _significant


func get_bland_threshold() -> int:
	return _bland_threshold


func get_row_count() -> int:
	return _rows.size()


## 周报 view（三挂载共用：自动弹/灰点/归档同构渲染的数据源）。
## 呈现序=RowKind 秩（账本→事件→竞对→仪式；同秩保序）。
func get_report_view() -> Dictionary:
	var ordered := _rows.duplicate(true)
	ordered.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["kind_rank"]) < int(b["kind_rank"])
	)
	return {
		"week": _week,
		"significant": _significant,
		"row_count": ordered.size(),
		"rows": ordered,
	}


## 自动弹门控：仅 1x 弹（ui-ux A.2「4x 下不弹（灰点累积，退出 4x 补看）」）。
## 2x 同为加速档=不弹（弹窗只出现在玩家主动降速/1x 观察档）。
func should_auto_pop(speed_index: int) -> bool:
	return _significant and speed_index == GameClock.SpeedIndex.ONE_X
