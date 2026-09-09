extends GutTest
## #127 时钟纯函数测试（L0 clock_math）：周→季→年转换、节拍谓词、仪式日历行。
## 真源：time-spec D.2（季 13/年 52/单局 12 季 156 周）；裁决 #127（52n 双仪式位、
## 大赏 12 次/局=13n 全集、呈现序=大赏先排名后）；数值经参数传入，零硬编码。

const WEEKS_PER_QUARTER: int = 13
const WEEKS_PER_YEAR: int = 52
const TOTAL_WEEKS: int = 156


func test_week_to_quarter_boundaries() -> void:
	assert_eq(ClockMath.week_to_quarter(1, WEEKS_PER_QUARTER), 1, "W1 属第 1 季度")
	assert_eq(ClockMath.week_to_quarter(13, WEEKS_PER_QUARTER), 1, "W13 仍属第 1 季度（季末）")
	assert_eq(ClockMath.week_to_quarter(14, WEEKS_PER_QUARTER), 2, "W14 进入第 2 季度")
	assert_eq(ClockMath.week_to_quarter(52, WEEKS_PER_QUARTER), 4, "W52 属第 4 季度（年末）")
	assert_eq(ClockMath.week_to_quarter(53, WEEKS_PER_QUARTER), 5, "W53 属第 5 季度（第 2 年 Q1）")
	assert_eq(ClockMath.week_to_quarter(156, WEEKS_PER_QUARTER), 12, "W156 属第 12 季度（单局末）")


func test_week_to_year_and_label() -> void:
	assert_eq(ClockMath.week_to_year_abs(1, WEEKS_PER_YEAR), 1, "W1 属第 1 年")
	assert_eq(ClockMath.week_to_year_abs(52, WEEKS_PER_YEAR), 1, "W52 属第 1 年（年末）")
	assert_eq(ClockMath.week_to_year_abs(53, WEEKS_PER_YEAR), 2, "W53 属第 2 年")
	assert_eq(ClockMath.week_to_year_abs(156, WEEKS_PER_YEAR), 3, "W156 属第 3 年")
	assert_eq(ClockMath.year_label(1, WEEKS_PER_YEAR, 2022), 2022, "开局 2022")
	assert_eq(ClockMath.year_label(52, WEEKS_PER_YEAR, 2022), 2022, "W52=2022 年末")
	assert_eq(ClockMath.year_label(53, WEEKS_PER_YEAR, 2022), 2023, "W53=2023")
	assert_eq(ClockMath.year_label(105, WEEKS_PER_YEAR, 2022), 2024, "W105=2024")
	assert_eq(ClockMath.year_label(156, WEEKS_PER_YEAR, 2022), 2024, "W156=2024 年末")


func test_quarter_award_week_predicate() -> void:
	assert_true(ClockMath.is_quarter_award_week(13, WEEKS_PER_QUARTER), "W13=大赏周")
	assert_true(ClockMath.is_quarter_award_week(26, WEEKS_PER_QUARTER), "W26=大赏周")
	assert_true(ClockMath.is_quarter_award_week(52, WEEKS_PER_QUARTER), "W52=第 4 季度末大赏周（裁决 12 次恒）")
	assert_true(ClockMath.is_quarter_award_week(156, WEEKS_PER_QUARTER), "W156=第 12 季度末大赏周")
	assert_false(ClockMath.is_quarter_award_week(14, WEEKS_PER_QUARTER), "W14 非大赏周")
	assert_false(ClockMath.is_quarter_award_week(1, WEEKS_PER_QUARTER), "W1 非大赏周")


func test_annual_rank_week_predicate() -> void:
	assert_true(ClockMath.is_annual_rank_week(52, WEEKS_PER_YEAR), "W52=年度排名周")
	assert_true(ClockMath.is_annual_rank_week(104, WEEKS_PER_YEAR), "W104=年度排名周")
	assert_true(ClockMath.is_annual_rank_week(156, WEEKS_PER_YEAR), "W156=年度排名周")
	assert_false(ClockMath.is_annual_rank_week(51, WEEKS_PER_YEAR), "W51 非年度排名周")
	assert_false(ClockMath.is_annual_rank_week(53, WEEKS_PER_YEAR), "W53 非年度排名周")


func test_total_weeks_and_structure() -> void:
	assert_eq(ClockMath.total_weeks(12, WEEKS_PER_QUARTER), TOTAL_WEEKS, "单局 12 季 ×13 周=156")
	var s: Dictionary = ClockMath.make_week_structure(53, WEEKS_PER_QUARTER, WEEKS_PER_YEAR)
	assert_eq(int(s["week"]), 53, "周结构 week 字段")
	assert_eq(int(s["quarter"]), 5, "W53 季=5")
	assert_eq(int(s["year_abs"]), 2, "W53 年序=2")
	assert_eq(int(s["year_label"]), 2023, "W53 公历=2023")


func test_quarter_award_rows_full_set() -> void:
	var rows: Array = ClockMath.quarter_award_rows(WEEKS_PER_QUARTER, WEEKS_PER_YEAR, TOTAL_WEEKS)
	assert_eq(rows.size(), 12, "季度大赏 12 行/局（time-spec D.2 硬约束）")
	var expected: Array[int] = []
	for week in range(WEEKS_PER_QUARTER, TOTAL_WEEKS + 1, WEEKS_PER_QUARTER):
		expected.append(week)
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		assert_eq(int(row["week"]), expected[i], "大赏周 13n 全集序 %d" % expected[i])
		assert_eq(int(row["ritual"]), CoreEnums.RitualType.QUARTER_AWARD, "大赏行类型正确")
		assert_eq(int(row["index"]), i + 1, "大赏行索引 1 起")


func test_annual_rank_rows_dual() -> void:
	var rows: Array = ClockMath.annual_rank_rows(WEEKS_PER_YEAR, TOTAL_WEEKS)
	assert_eq(rows.size(), 3, "年度排名 3 行/局（3 年）")
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		assert_eq(int(row["week"]), (i + 1) * WEEKS_PER_YEAR, "排名周=52n")
		assert_eq(int(row["ritual"]), CoreEnums.RitualType.ANNUAL_RANK, "排名行类型正确")
		assert_true(row["dual"], "52n 双仪式位 dual=true（52n⊂13n 整除对齐）")


func test_build_ritual_calendar_order_and_dual() -> void:
	var calendar: Array = ClockMath.build_ritual_calendar(
		WEEKS_PER_QUARTER, WEEKS_PER_YEAR, TOTAL_WEEKS
	)
	assert_eq(calendar.size(), 15, "仪式日历=12 大赏 + 3 排名")
	var validation := ClockMath.validate_ritual_calendar(calendar, TOTAL_WEEKS)
	assert_true(validation.ok, "仪式日历自检全过: %s" % str(validation.errors))
	# 52n 双仪式位：两行并列，序=大赏先排名后（裁决 phase 7e 串行呈现序）
	for week_index: int in [0, 1, 2]:
		var week: int = (week_index + 1) * WEEKS_PER_YEAR
		var rows: Array = ClockMath.ritual_rows_at_week(calendar, week)
		assert_eq(rows.size(), 2, "52n=%d 双仪式位两行" % week)
		assert_eq(
			int(rows[0]["ritual"]),
			CoreEnums.RitualType.QUARTER_AWARD,
			"52n 周序列先行=季度大赏（%d）" % week,
		)
		assert_eq(
			int(rows[1]["ritual"]),
			CoreEnums.RitualType.ANNUAL_RANK,
			"52n 周序列殿后=年度排名（%d）" % week,
		)
		assert_true(rows[0]["dual"] and rows[1]["dual"], "52n 两行均 dual")


func test_ritual_calendar_no_illegal_overlap() -> void:
	# 无重叠语义=time_ritual_no_overlap：竞对发版周 ∉ 仪式周集（13n∪52n）。
	# 仪式周集内部 13n∩52n={52,104,156}=裁决允许的双仪式位（同周串行非冲突）。
	var award_set: Dictionary = {}
	for week in range(WEEKS_PER_QUARTER, TOTAL_WEEKS + 1, WEEKS_PER_QUARTER):
		award_set[week] = true
	for week: int in [WEEKS_PER_YEAR, WEEKS_PER_YEAR * 2, WEEKS_PER_YEAR * 3]:
		assert_true(award_set.has(week), "52n 属 13n（52 是 13 的倍数）: %d" % week)
	# 真源动作锚点周次（README 勘误 3：8 动作实表周次）为竞对时间线 fixture，
	# 与仪式周集零交集（rivals 时间线表 #144 建后错峰断言读 time.json 同表）
	var release_fixture: Array[int] = [6, 12, 24, 40, 54, 68, 75, 82]
	for week: int in release_fixture:
		assert_false(award_set.has(week), "竞对动作周 %d 不得与仪式周重叠" % week)
