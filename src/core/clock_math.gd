class_name ClockMath
extends RefCounted
## L0 时钟纯函数（#123 骨架占位；#127 原位填充周/季/年/节拍判定）。
## 纪律：零依赖、静态函数为主；数值一律由调用方从 time.json 传入（键名引用
## 在调用方/L2），本层只做"输入周数+周期常量 → 结构/谓词"的纯数学。

## 结构体约定（跨模块字典，同源派生防拼错）：
## - 周结构：{week, quarter, year_abs, year_label}，见 make_week_structure()
## - 日历行：{week, ritual, index, dual}，见 _calendar_row()；ritual 值为
##   CoreEnums.RitualType（编译期符号）；文案一律走 texts 键（L3），L0 不含文案


## 周 → 季度（1 起；周期常量由 time.json 键 time_week_per_quarter 传入）。
static func week_to_quarter(week: int, weeks_per_quarter: int) -> int:
	if weeks_per_quarter <= 0:
		return 1
	return int(floori((week - 1) / weeks_per_quarter)) + 1


## 周 → 年（1 起，绝对年序号；周期常量 time_week_per_year 传入）。
static func week_to_year_abs(week: int, weeks_per_year: int) -> int:
	if weeks_per_year <= 0:
		return 1
	return int(floori((week - 1) / weeks_per_year)) + 1


## 单局起始公历年（2022，真源 GDD 开局 2022）→ 公历年号。
static func year_label(week: int, weeks_per_year: int, start_year: int) -> int:
	return start_year + week_to_year_abs(week, weeks_per_year) - 1


## 季度末周（13 周季：13/26/39/…）；非季末周返回 0。
static func quarter_end_week(week: int, weeks_per_quarter: int) -> int:
	if weeks_per_quarter <= 0:
		return 0
	var rem: int = week % weeks_per_quarter
	if rem == 0:
		return week
	return 0


## 是否季度 SOTA 大赏周 = 季度末周 13n（裁决 #127：大赏 12 次/局=13n 全集
## 硬约束，52n 同为第 4 季度末大赏周，不因年度排名减少）。
static func is_quarter_award_week(week: int, weeks_per_quarter: int) -> bool:
	return quarter_end_week(week, weeks_per_quarter) != 0


## 是否年度实验室排名周 = 年末周 52n（time-spec：每 52 周一次、3 次/局）。
static func is_annual_rank_week(week: int, weeks_per_year: int) -> bool:
	if week <= 0 or weeks_per_year <= 0:
		return false
	return week % weeks_per_year == 0


## 是否竞对发版周（读共享节拍日历可排周集；表驱动 time_ritual_no_overlap）。
static func is_rival_release_week(week: int, release_weeks: Array) -> bool:
	return release_weeks.has(week)


## 一局内总周数（季度数 × 每季周数；time_quarters_in_game × time_week_per_quarter）。
static func total_weeks(quarters_in_game: int, weeks_per_quarter: int) -> int:
	return quarters_in_game * weeks_per_quarter


## 周结构（含 2022 起公历年）。start_year 默认 2022（真源：2022 初→2024 末）。
static func make_week_structure(
	week: int, weeks_per_quarter: int, weeks_per_year: int, start_year: int = 2022
) -> Dictionary:
	return {
		"week": week,
		"quarter": week_to_quarter(week, weeks_per_quarter),
		"year_abs": week_to_year_abs(week, weeks_per_year),
		"year_label": year_label(week, weeks_per_year, start_year),
	}


## 节拍日历行（单周单仪式）：{week, ritual, index, dual}。
## dual=true 表示该周同时是季度末与年末（52n ⊂ 13n，整除对齐必然）。
static func _calendar_row(week: int, ritual: int, index: int, dual: bool) -> Dictionary:
	return {"week": week, "ritual": ritual, "index": index, "dual": dual}


## 季度 SOTA 大赏行（13n 全集，12 行；52n 行 dual=true）。
static func quarter_award_rows(weeks_per_quarter: int, weeks_per_year: int, total: int) -> Array:
	var rows: Array = []
	if weeks_per_quarter <= 0 or weeks_per_year <= 0:
		return rows
	for week in range(weeks_per_quarter, total + 1, weeks_per_quarter):
		(
			rows
			. append(
				_calendar_row(
					week,
					CoreEnums.RitualType.QUARTER_AWARD,
					week / weeks_per_quarter,
					week % weeks_per_year == 0,
				)
			)
		)
	return rows


## 年度实验室排名行（52n 共 3 行；dual 恒 true——52n 必为季度末）。
static func annual_rank_rows(weeks_per_year: int, total: int) -> Array:
	var rows: Array = []
	if weeks_per_year <= 0:
		return rows
	for week in range(weeks_per_year, total + 1, weeks_per_year):
		rows.append(
			_calendar_row(week, CoreEnums.RitualType.ANNUAL_RANK, week / weeks_per_year, true)
		)
	return rows


## 合并仪式日历（13n 大赏 12 行 + 52n 排名 3 行，同周并列两行=双仪式位）。
## 呈现序列裁决：52n 周结算序列 phase 7e 内串行——季度大赏先行、年度排名殿后
## （同周两行按 ritual 升序：QUARTER_AWARD < ANNUAL_RANK，见 RitualType 声明序）。
static func build_ritual_calendar(weeks_per_quarter: int, weeks_per_year: int, total: int) -> Array:
	var calendar: Array = []
	calendar.append_array(quarter_award_rows(weeks_per_quarter, weeks_per_year, total))
	calendar.append_array(annual_rank_rows(weeks_per_year, total))
	calendar.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var week_a: int = int(a["week"])
			var week_b: int = int(b["week"])
			if week_a != week_b:
				return week_a < week_b
			return int(a["ritual"]) < int(b["ritual"])
	)
	return calendar


## 仪式日历周查询（无仪式返回空数组；52n 双仪式位返回 2 行：大赏在前排名在后）。
static func ritual_rows_at_week(calendar: Array, week: int) -> Array:
	var rows: Array = []
	for row: Dictionary in calendar:
		if int(row["week"]) == week:
			rows.append(row)
	return rows


## 仪式日历自检：周 ∈ [1,total]、行按 (周, ritual 序) 升序、同周行数 ≤2。
## 返回 {ok, errors}（与 DataSchema 结果同构）。
static func validate_ritual_calendar(calendar: Array, total: int) -> Dictionary:
	var errors: Array[String] = []
	var last_key := 0
	var week_count: Dictionary = {}
	for row: Dictionary in calendar:
		var week: int = int(row["week"])
		if week < 1 or week > total:
			errors.append("仪式周越界: %d" % week)
		week_count[week] = int(week_count.get(week, 0)) + 1
		var key: int = week * 10 + int(row["ritual"])
		if key < last_key:
			errors.append("仪式日历乱序: week=%d ritual=%d" % [week, int(row["ritual"])])
		last_key = key
	for week: Variant in week_count:
		if int(week_count[week]) > 2:
			errors.append("仪式同周超过 2 行: %s" % str(week))
	return {"ok": errors.is_empty(), "errors": errors}
