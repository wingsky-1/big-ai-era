class_name GameClock
extends RefCounted
## L2 时间与节拍（#127）：周/季/年节拍 + 1x/2x/4x + 暂停 + z2 锁定 + 失焦停。
## 硬约束（任务书/架构 H2/A1）：
## - RefCounted、零 Node/SceneTree 依赖（"无窗口服务器可跑"判据，headless 可单测）；
## - L2 只发周结级信号 week_settled（decisions-100 A1）；周内刻级表现由 L3
##   自定时器轮询数据面 week_progress——本单不建任何 L3；
## - 数值零硬编码：倍率/周数全部读 time.json 键（真源 time-spec D.2），
##   构造时注入整表（装配方 DataLoader 读表后传入；#128 schema 已保证键存在）；
## - 失焦停=装配方注入 focus_predicate 策略，本体只认 tick 源；恢复零补偿；
## - 节拍日历=time.json time_ritual_no_overlap 跨表共享日历（rivals 发版周
##   错峰读同表；#144 落 rivals 时间线前发版周集为空占位）。
## 数据面一律深拷贝返回；命令面副作用只改自身状态与周结信号。

signal week_settled(payload: Dictionary)

enum SpeedIndex {
	ONE_X,
	TWO_X,
	FOUR_X,
}

const KEY_WALL_CLOCK_1X: String = "time_wall_clock_1x"
const KEY_WALL_CLOCK_2X: String = "time_wall_clock_2x"
const KEY_WALL_CLOCK_4X: String = "time_wall_clock_4x"
const KEY_WEEKS_PER_QUARTER: String = "time_week_per_quarter"
const KEY_WEEKS_PER_YEAR: String = "time_week_per_year"
const KEY_QUARTERS_IN_GAME: String = "time_quarters_in_game"
const KEY_RITUAL_NO_OVERLAP: String = "time_ritual_no_overlap"
const SUB_QUARTER_AWARD_WEEKS: String = "quarter_award_weeks"
const SUB_ANNUAL_RANK_WEEKS: String = "annual_rank_weeks"
const SUB_RIVAL_RELEASE_WEEKS: String = "rival_release_weeks"
## 开局公历年锚（真源 GDD：2022 初→2024 末；time-spec D.2 无独立表键，语义锚常量）
const START_YEAR: int = 2022

## 装配方注入的失焦谓词（无参 Callable → bool；失焦应返回 false）。
## 失焦停=装配方策略（任务书硬约束 5）：装配方在 time_focus_loss_pause 阈值内
## 切换此谓词（OS 失焦监听属 L3/main，本类零 Node 依赖）；GameClock 只认
## tick 源 + 谓词门控，恢复后从断点继续（零补偿）。
var focus_predicate: Callable = func() -> bool: return true

var _config_ok: bool = false
var _seconds_per_week_1x: float = 1.0
var _speed_multipliers: Array[float] = []
var _weeks_per_quarter: int = 13
var _weeks_per_year: int = 52
var _quarters_in_game: int = 12
var _week: int = 1
var _speed_index: int = SpeedIndex.ONE_X
var _user_paused: bool = false
var _z2_blocked: bool = false
var _week_fraction: float = 0.0
var _quarter_award_weeks: Array[int] = []
var _annual_rank_weeks: Array[int] = []
var _rival_release_weeks: Array[int] = []
var _ritual_calendar: Array = []


func _init(time_table: Dictionary) -> void:
	if not _extract_config(time_table):
		return
	_build_ritual_calendar()


## ---------- 命令面（契约命令；全部无 Node 依赖） ----------


## 速度档循环 1x→2x→4x→1x（OP-TIM-01）；z2 阻塞期间拒绝并返回当前档。
func cycle_speed() -> int:
	if not can_change_speed():
		return _speed_index
	_speed_index = (_speed_index + 1) % _speed_multipliers.size()
	return _speed_index


## 直接设档（架构命令面 set_speed）；z2 阻塞或越界返回 false。
func set_speed_index(index: int) -> bool:
	if not can_change_speed():
		return false
	if index < 0 or index >= _speed_multipliers.size():
		return false
	_speed_index = index
	return true


## 玩家暂停（永不禁用：z2 阻塞/任意档位都可暂停，OP-TIM-01 异常/边界）。
func set_paused(paused: bool) -> void:
	_user_paused = paused


## z2 阻塞门控（决策卡/周报自动弹期间由装配方置 true；世界停+变速置灰）。
func set_z2_blocked(blocked: bool) -> void:
	_z2_blocked = blocked


## 墙钟 tick 源（装配方每帧喂真实秒；失焦=谓词 false 拒绝累积）。
## 满 1 周触发唯一周结推进（L2 只发周结级信号 week_settled）。
func tick(delta_seconds: float) -> void:
	if not _config_ok or delta_seconds <= 0.0 or not is_flowing():
		return
	_week_fraction += delta_seconds / _seconds_per_week_1x * _current_multiplier()
	_settle_pending_weeks()


## ---------- 数据面（只读、深拷贝，供 L3/测试轮询） ----------


func get_clock_view() -> Dictionary:
	return {
		"week": _week,
		"quarter": ClockMath.week_to_quarter(_week, _weeks_per_quarter),
		"year_abs": ClockMath.week_to_year_abs(_week, _weeks_per_year),
		"year": ClockMath.year_label(_week, _weeks_per_year, START_YEAR),
		"speed_index": _speed_index,
		"speed_multiplier": _current_multiplier(),
		"user_paused": _user_paused,
		"z2_blocked": _z2_blocked,
		"flowing": is_flowing(),
		"week_progress": get_week_progress(),
		"total_weeks": ClockMath.total_weeks(_quarters_in_game, _weeks_per_quarter),
	}


## 当前周内进度 [0,1)（A1：周内刻级表现=数据面，L3 自定时器轮询，不另发信号）。
func get_week_progress() -> float:
	return clampf(_week_fraction, 0.0, 1.0)


func is_config_ok() -> bool:
	return _config_ok


## 变速可用谓词（z2 阻塞期置灰；UI 读此谓词+time_speed_locked_reason）。
func can_change_speed() -> bool:
	return _config_ok and not _z2_blocked


## 世界是否流淌（用户暂停/z2 阻塞/失焦任一即停）。
func is_flowing() -> bool:
	return _config_ok and not _user_paused and not _z2_blocked and focus_predicate.call()


func get_speed_index() -> int:
	return _speed_index


func get_speed_multiplier() -> float:
	return _current_multiplier()


func get_week() -> int:
	return _week


func get_total_weeks() -> int:
	return ClockMath.total_weeks(_quarters_in_game, _weeks_per_quarter)


## 仪式日历全量（行={week, ritual, index, dual}；52n 双仪式位两行并列，
## 呈现序=quarter_award 先 annual_rank 后；深拷贝防越权）。
func get_ritual_calendar() -> Array:
	return _ritual_calendar.duplicate(true)


## 指定周仪式行（无=空；52n 双仪式位=2 行，大赏在前排名在后）。
func get_ritual_rows_for_week(week: int) -> Array:
	var rows: Array = []
	for row: Dictionary in _ritual_calendar:
		if int(row["week"]) == week:
			rows.append(row.duplicate())
	return rows


func get_quarter_award_weeks() -> Array[int]:
	return _quarter_award_weeks.duplicate()


func get_annual_rank_weeks() -> Array[int]:
	return _annual_rank_weeks.duplicate()


## 竞对发版可排周集（跨表共享日历接口；#144 rivals 时间线落位前为空占位）。
func get_rival_release_weeks() -> Array[int]:
	return _rival_release_weeks.duplicate()


## ---------- 私有 ----------


func _current_multiplier() -> float:
	return _speed_multipliers[_speed_index]


func _extract_config(table: Dictionary) -> bool:
	var required: Array[String] = [
		KEY_WALL_CLOCK_1X,
		KEY_WALL_CLOCK_2X,
		KEY_WALL_CLOCK_4X,
		KEY_WEEKS_PER_QUARTER,
		KEY_WEEKS_PER_YEAR,
		KEY_QUARTERS_IN_GAME,
		KEY_RITUAL_NO_OVERLAP,
	]
	for key: String in required:
		if not table.has(key):
			push_error("GameClock: time.json 缺必需键 '%s'" % key)
			return false
	_seconds_per_week_1x = float(table[KEY_WALL_CLOCK_1X])
	# 1x=恒等基值（time-spec C.3：1x 是基准档而非倍率），2x/4x 倍率读表
	_speed_multipliers = [1.0, float(table[KEY_WALL_CLOCK_2X]), float(table[KEY_WALL_CLOCK_4X])]
	_weeks_per_quarter = int(table[KEY_WEEKS_PER_QUARTER])
	_weeks_per_year = int(table[KEY_WEEKS_PER_YEAR])
	_quarters_in_game = int(table[KEY_QUARTERS_IN_GAME])
	var ritual: Dictionary = table[KEY_RITUAL_NO_OVERLAP]
	var q_weeks: Variant = ritual.get(SUB_QUARTER_AWARD_WEEKS)
	var a_weeks: Variant = ritual.get(SUB_ANNUAL_RANK_WEEKS)
	var r_weeks: Variant = ritual.get(SUB_RIVAL_RELEASE_WEEKS)
	if q_weeks is not Array or a_weeks is not Array or r_weeks is not Array:
		push_error("GameClock: time_ritual_no_overlap 子键必须为周次数组")
		return false
	_quarter_award_weeks = _to_int_array(q_weeks)
	_annual_rank_weeks = _to_int_array(a_weeks)
	_rival_release_weeks = _to_int_array(r_weeks)
	_config_ok = true
	return true


## 表驱动日历构建：行从 time.json 周集转出（防 ClockMath 派生与表漂移由
## 测试断言校验，见 test_ritual_calendar_no_overlap）；同周序=ritual 升序
## （QUARTER_AWARD 先于 ANNUAL_RANK，即 52n 周"大赏先行、排名殿后"裁决）。
func _build_ritual_calendar() -> void:
	var rows: Array = []
	var award_index := 1
	for week: int in _quarter_award_weeks:
		var dual: bool = _annual_rank_weeks.has(week)
		rows.append(_make_ritual_row(week, CoreEnums.RitualType.QUARTER_AWARD, award_index, dual))
		award_index += 1
	var rank_index := 1
	for week: int in _annual_rank_weeks:
		rows.append(_make_ritual_row(week, CoreEnums.RitualType.ANNUAL_RANK, rank_index, true))
		rank_index += 1
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var week_a: int = int(a["week"])
			var week_b: int = int(b["week"])
			if week_a != week_b:
				return week_a < week_b
			return int(a["ritual"]) < int(b["ritual"])
	)
	_ritual_calendar = rows


func _make_ritual_row(week: int, ritual: int, index: int, dual: bool) -> Dictionary:
	return {"week": week, "ritual": ritual, "index": index, "dual": dual}


## 周界推进=唯一结算触发点（周结后周数 +1 并广播；载荷={week,quarter,year}，
## 对齐 architecture §5.2 week_settled 示意载荷；report_id 属周报批 5 扩展）。
func _settle_pending_weeks() -> void:
	while _week_fraction >= 1.0 and _config_ok:
		# phase 0 门控（architecture §5.3）：z2 阻塞/失焦期间不跨周，边界保持
		if _z2_blocked or not focus_predicate.call():
			return
		_week_fraction -= 1.0
		_advance_week()


func _advance_week() -> void:
	_week += 1
	var payload := {
		"week": _week,
		"quarter": ClockMath.week_to_quarter(_week, _weeks_per_quarter),
		"year": ClockMath.year_label(_week, _weeks_per_year, START_YEAR),
	}
	week_settled.emit(payload)


func _to_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		result.append(int(value))
	return result
