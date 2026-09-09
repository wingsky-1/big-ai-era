extends GutTest
## #127 GameClock（L2 RefCounted 时钟）测试。
## 验收点 1/2/3/4 的 GUT 用例名逐字落地：
##   test_speed_cycle_and_z2_lock / test_focus_loss_stops_clock /
##   test_ritual_calendar_no_overlap / test_only_week_settle_accounts
## 构造一律注入 time.json 真表（键名真源 time-spec D.2；#128/#126 键已建）。

const TIME_PATH: String = "res://src/data/time.json"

var _focused: bool = true
var _settle_count: int = 0
var _last_payload: Dictionary = {}


func before_each() -> void:
	_focused = true
	_settle_count = 0
	_last_payload = {}


## 读 time.json 真表构造时钟（装配方注入语义：装配方 DataLoader 读表后传入）。
func _make_clock() -> GameClock:
	var table := DataLoader.load_json(TIME_PATH)
	var clock := GameClock.new(table)
	assert_true(clock.is_config_ok(), "time.json 真表构造 GameClock 配置就绪")
	clock.focus_predicate = func() -> bool: return _focused
	return clock


## 1x 档整周墙钟秒（time_wall_clock_1x 读表，零硬编码）。
func _seconds_per_week_1x() -> float:
	var table := DataLoader.load_json(TIME_PATH)
	return float(table["time_wall_clock_1x"])


## 按当前速度档换算喂 tick：推进 weeks 周所需真实秒。
func _tick_weeks(clock: GameClock, weeks: float) -> void:
	var seconds := weeks * _seconds_per_week_1x() / clock.get_speed_multiplier()
	clock.tick(seconds)


func _on_week_settled(payload: Dictionary) -> void:
	_settle_count += 1
	_last_payload = payload


## 验收点 1：速度档循环 1x→2x→4x→1x；z2 阻塞置灰且暂停永不禁用。
func test_speed_cycle_and_z2_lock() -> void:
	var clock := _make_clock()
	assert_eq(clock.get_speed_index(), GameClock.SpeedIndex.ONE_X, "初始档=1x")
	assert_eq(clock.cycle_speed(), GameClock.SpeedIndex.TWO_X, "1x→2x 循环")
	assert_almost_eq(clock.get_speed_multiplier(), 2.0, 0.001, "2x 倍率读表 time_wall_clock_2x")
	assert_eq(clock.cycle_speed(), GameClock.SpeedIndex.FOUR_X, "2x→4x 循环")
	assert_almost_eq(clock.get_speed_multiplier(), 4.0, 0.001, "4x 倍率读表 time_wall_clock_4x")
	assert_eq(clock.cycle_speed(), GameClock.SpeedIndex.ONE_X, "4x→1x 循环闭合")
	# z2 阻塞：变速键置灰、循环/直设均被拒；暂停永不禁用
	clock.set_z2_blocked(true)
	assert_false(clock.can_change_speed(), "z2 阻塞期变速键置灰")
	var locked_index := clock.get_speed_index()
	assert_eq(clock.cycle_speed(), locked_index, "z2 阻塞期循环被拒（档位锁定）")
	assert_false(clock.set_speed_index(GameClock.SpeedIndex.FOUR_X), "z2 阻塞期直设档被拒")
	assert_eq(clock.get_speed_index(), locked_index, "z2 阻塞期档位保持不变")
	# 暂停永不禁用：z2 阻塞中调用暂停直接生效（暂停键不随变速一起置灰）
	clock.set_paused(true)
	var paused_view: Dictionary = clock.get_clock_view()
	assert_true(paused_view["user_paused"], "z2 阻塞期暂停生效（暂停永不禁用）")
	# z2 解除：用户暂停保持（独立语义），变速恢复可循环
	clock.set_z2_blocked(false)
	var resumed_view: Dictionary = clock.get_clock_view()
	assert_true(resumed_view["user_paused"], "z2 解除不清除用户暂停（用户暂停独立）")
	assert_true(clock.can_change_speed(), "z2 解除变速恢复")
	assert_eq(clock.cycle_speed(), GameClock.SpeedIndex.TWO_X, "解除后循环续走 1x→2x")


## 辅助：暂停停世界（周内操作不结算已在 test_only_week_settle_accounts）。
func test_user_pause_freezes_clock() -> void:
	var clock := _make_clock()
	clock.week_settled.connect(_on_week_settled)
	clock.set_paused(true)
	clock.tick(_seconds_per_week_1x() * 10.0)
	assert_eq(clock.get_week(), 1, "用户暂停中 tick 不推进（世界停）")
	assert_eq(_settle_count, 0, "暂停中不触发结算")
	assert_false(clock.is_flowing(), "暂停数据面 flowing=false")
	clock.set_paused(false)
	_tick_weeks(clock, 1.0)
	assert_eq(clock.get_week(), 2, "恢复后世界继续流淌")
	assert_eq(_settle_count, 1, "恢复后满周正常结算一次")


## 验收点 2：失焦 1s 内世界停、恢复零补偿（失焦=装配方注入谓词策略）。
func test_focus_loss_stops_clock() -> void:
	var clock := _make_clock()
	_focused = true
	_tick_weeks(clock, 1.0)
	assert_eq(clock.get_week(), 2, "聚焦时世界流淌（推进 1 周到 W2）")
	# 失焦（谓词翻 false；装配方在 time_focus_loss_pause 阈值内切换，GameClock
	# 门控即时生效——严格强于"失焦 1s 内世界停"红线）
	_focused = false
	clock.tick(_seconds_per_week_1x() * 100.0)
	assert_eq(clock.get_week(), 2, "失焦即停：即使外部继续喂 tick 世界也不推进")
	assert_false(clock.is_flowing(), "失焦数据面 flowing=false")
	# 恢复：只推进恢复后喂入的量，失焦期时间零补偿
	_focused = true
	_tick_weeks(clock, 1.0)
	assert_eq(clock.get_week(), 3, "恢复零补偿：仅推进 1 周到 W3（未补失焦期 100 周）")
	assert_eq(clock.get_speed_index(), GameClock.SpeedIndex.ONE_X, "失焦恢复速度档保持原样")


## 验收点 3：节拍表断言——季度大赏/年度排名/竞对发版互不重叠。
## 裁决口径（#127 主程序席）：time_ritual_no_overlap 语义=竞对发版周 ∉ 仪式周集
## （13n∪52n）；52n 周=季度大赏与年度排名双仪式位（13/52 整除对齐必然），
## 结算序列 phase 7e 内串行呈现=大赏先行、排名殿后（日历行序固化）。
func test_ritual_calendar_no_overlap() -> void:
	var clock := _make_clock()
	var award: Array[int] = clock.get_quarter_award_weeks()
	var annual: Array[int] = clock.get_annual_rank_weeks()
	var release: Array[int] = clock.get_rival_release_weeks()
	var table := DataLoader.load_json(TIME_PATH)
	var wpq: int = int(table["time_week_per_quarter"])
	var wpy: int = int(table["time_week_per_year"])
	var total: int = clock.get_total_weeks()
	assert_eq(award.size(), 12, "季度大赏 12 次/局（time-spec D.2 硬约束）")
	assert_eq(annual.size(), 3, "年度排名 3 次/局（单局 3 年）")
	# 表周集与 ClockMath 纯函数派生一致（防"表驱动日历"双真源漂移）
	var derived_award: Array = ClockMath.quarter_award_rows(wpq, wpy, total)
	assert_eq(award.size(), derived_award.size(), "表大赏行数与数学派生一致")
	for i: int in derived_award.size():
		assert_eq(award[i], int(derived_award[i]["week"]), "表大赏周 %d 与派生一致" % award[i])
	var derived_annual: Array = ClockMath.annual_rank_rows(wpy, total)
	assert_eq(annual.size(), derived_annual.size(), "表排名行数与数学派生一致")
	for i: int in derived_annual.size():
		assert_eq(annual[i], int(derived_annual[i]["week"]), "表排名周 %d 与派生一致" % annual[i])
	# 仪式日历合法（行有序、越界零、同周 ≤2）
	var calendar: Array = clock.get_ritual_calendar()
	assert_eq(calendar.size(), 15, "仪式日历=12 大赏行+3 排名行")
	var validation := ClockMath.validate_ritual_calendar(calendar, total)
	assert_true(validation.ok, "仪式日历自检全过: %s" % str(validation.errors))
	# 互斥核心：仪式周集与竞对发版周集零交集
	var ritual_weeks: Dictionary = {}
	for week: int in award:
		ritual_weeks[week] = true
	for week: int in annual:
		ritual_weeks[week] = true
	for week: int in release:
		assert_false(ritual_weeks.has(week), "表内竞对发版周 %d 不得与仪式周重叠" % week)
	# rivals 时间线表 #144 未建前=空占位；真源动作锚点 fixture 断言错峰已就绪
	# （README 勘误 3：8 动作实表周次——rivals 表落位后读 time.json 同表）
	var release_fixture: Array[int] = [6, 12, 24, 40, 54, 68, 75, 82]
	for week: int in release_fixture:
		assert_false(ritual_weeks.has(week), "fixture 竞对发版周 %d 与仪式周互斥" % week)
	# 52n 双仪式位：两行并列且呈现序=大赏先行、排名殿后（裁决 phase 7e）
	for week: int in annual:
		var rows: Array = clock.get_ritual_rows_for_week(week)
		assert_eq(rows.size(), 2, "52n=%d 双仪式位两行" % week)
		assert_eq(
			int(rows[0]["ritual"]), CoreEnums.RitualType.QUARTER_AWARD, "52n 周大赏先行（%d）" % week
		)
		assert_eq(int(rows[1]["ritual"]), CoreEnums.RitualType.ANNUAL_RANK, "52n 周排名殿后（%d）" % week)
		assert_true(rows[0]["dual"] and rows[1]["dual"], "52n 两行均 dual 标记")


## 验收点 4：周结=唯一结算点——周内任何操作不触发结算，满周恰触发一次。
func test_only_week_settle_accounts() -> void:
	var clock := _make_clock()
	clock.week_settled.connect(_on_week_settled)
	# 周内操作全集：半周 tick + 变速循环 + 暂停切换 + z2 阻塞切换 → 零结算
	_tick_weeks(clock, 0.5)
	clock.cycle_speed()
	clock.set_paused(true)
	clock.set_paused(false)
	clock.set_z2_blocked(true)
	clock.set_z2_blocked(false)
	assert_eq(_settle_count, 0, "周内任何操作不触发结算（周结=唯一结算点）")
	assert_eq(clock.get_week(), 1, "半周后周数不变")
	assert_true(clock.can_change_speed(), "变速操作在周内可用但不结算")
	# 补足半周=满 1 周 → 恰一次结算
	_tick_weeks(clock, 0.5)
	assert_eq(_settle_count, 1, "满 1 周恰触发一次结算")
	assert_eq(clock.get_week(), 2, "结算后周数 +1（W2）")
	assert_eq(int(_last_payload["week"]), 2, "week_settled 载荷 week=结算后周")
	assert_eq(int(_last_payload["quarter"]), 1, "W2 属第 1 季度")
	assert_eq(int(_last_payload["year"]), 2022, "W2 公历 2022")
	# 连续多周：每周恰一次
	_tick_weeks(clock, 3.0)
	assert_eq(_settle_count, 4, "连续推进 3 周=3 次结算（累计 4 次）")
	assert_eq(clock.get_week(), 5, "连续推进后 W5")
	# 结算信号=唯一事件出口：周内推进不产生其它 L2 信号（A1 只发周结级）
	assert_eq(clock.get_clock_view()["week_progress"], 0.0, "整周结算后进度归零")


func test_clock_view_reports_state() -> void:
	var clock := _make_clock()
	clock.set_speed_index(GameClock.SpeedIndex.FOUR_X)
	clock.set_z2_blocked(true)
	var view: Dictionary = clock.get_clock_view()
	assert_eq(int(view["week"]), 1, "视图 week=当前周")
	assert_eq(int(view["quarter"]), 1, "视图 quarter=1")
	assert_eq(int(view["year"]), 2022, "视图公历年=2022")
	assert_eq(int(view["speed_index"]), GameClock.SpeedIndex.FOUR_X, "视图档位=4x")
	assert_almost_eq(float(view["speed_multiplier"]), 4.0, 0.001, "视图倍率=4")
	assert_true(view["z2_blocked"], "视图 z2 阻塞态")
	assert_false(view["flowing"], "视图流淌态=false（z2）")
	assert_eq(int(view["total_weeks"]), 156, "单局 156 周")


func test_speed_index_set_and_bounds() -> void:
	var clock := _make_clock()
	assert_true(clock.set_speed_index(GameClock.SpeedIndex.TWO_X), "直设 2x 成功")
	assert_false(clock.set_speed_index(3), "越界档位拒绝")
	assert_false(clock.set_speed_index(-1), "负档位拒绝")
	assert_eq(clock.get_speed_index(), GameClock.SpeedIndex.TWO_X, "拒绝后档位不变")
