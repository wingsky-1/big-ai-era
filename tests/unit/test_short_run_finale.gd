extends GutTest

## #82（v0.1.5）短单局收尾专项测试（DR-031 / 纪要 §十二 + 需求 §0.3/§11 RF-01…RF-04）。
## 覆盖 issue #82 的 4 个 [T] 验收点（5 个 GUT 用例，用例名与 issue 逐字一致）：
## 1. test_freedom_three_lines_counters          —— 三线计数器（保霸周 +1 / 树 n / 影响力存量）+ flags 开放容器零迁移
## 2. test_three_line_visible_from_week25        —— W25 起资源栏副行弱展示（不弹横幅，两时点分离）
## 3. test_three_line_takes_over_after_saturation —— 首达饱和阈值当周升主权重 + 弹横幅一次 + 周报携带三线行 + 封顶后 ≥3 次变化
## 4. test_final_summary_has_six_fields          —— 终局屏 summary 六项 + 关键决策回溯 3 条 + 一句话评价 + 零状态边界
## 5. test_single_run_duration_guard             —— 160 周 × 10s ≈1600s；变速不改变决策数；终局只触发一次
##
## 路径披露（两条路径互补，均经公开契约，不伪造内部字段）：
## - 纯逻辑路径：`FreedomTracker` 单点（阶段判定/计数器/横幅一次性），可穷举边界；
## - 真表集成路径：真 `GameWorld`，经 `start_new_game` / `SnapshotCodec.to_save`+`restore` /
##   `settle_week` / 只读数据面驱动（`restore` 是公开契约，flags 为开放容器）。
## 数值一律读 `src/data/`（`ui_display.freedom.display_week` / `benchmarks.saturation.score_threshold`
## / `clock.run_weeks`），代码零硬编码（红线 3）。

const CLOCK_PATH: String = "res://src/data/clock.json"
const UI_DISPLAY_PATH: String = "res://src/data/ui_display.json"
const BENCHMARKS_PATH: String = "res://src/data/benchmarks.json"
const SEED: int = 82
## 六项 / 回溯 3 条（issue #82 验收点 3；需求 §11.3 RF-03）。
const SIX_FIELD_COUNT: int = 6
const REVIEW_COUNT: int = 3
## 封顶后三线进度变化下界（RF-04：GDD §18「封顶后 ≥3 次三线进度变化」）。
const POST_CAP_MIN_CHANGES: int = 3
## 封顶后观察窗口（周；≥POST_CAP_MIN_CHANGES 才有判定余量）。
const POST_CAP_WEEKS: int = 4
## 单局时长容差（秒）：160 周 × 10s 的理论值 1600s 的允许偏差。
const DURATION_TOLERANCE_SECONDS: float = 60.0


func test_freedom_three_lines_counters() -> void:
	# [T] 验收点 1：三线计数器 —— 霸榜周 +1 / 树 n（读现成真源）/ 影响力存量，入 flags 开放容器零迁移。
	var tracker := FreedomTracker.new()
	autofree(tracker)
	tracker.setup(_freedom_cfg())
	# 连续 5 周霸榜 + 树逐周探明 + 影响力累积：仅霸榜周为自增计数器，树/影响力读入参真源。
	for week_no: int in range(1, 6):
		var settled: Dictionary = tracker.settle_week(
			_ctx(week_no, 10.0, true, week_no, week_no * 100)
		)
		assert_eq(int(settled["king_weeks"]), week_no, "第 %d 周霸榜周数应累加" % week_no)
	assert_eq(tracker.king_weeks, 5, "连续 5 周霸榜 ⇒ 霸榜周数 5（保霸周 +1）")
	assert_eq(
		tracker.get_stage_id(), FreedomTracker.STAGE_HIDDEN, "W5 未到可见时点（%d）⇒ 三线不显" % _display_week()
	)
	# 非霸主周不 +1（保霸语义：仅"仍为霸主"当周 +1）
	var lost: Dictionary = tracker.settle_week(_ctx(6, 10.0, false, 6, 600))
	assert_eq(int(lost["king_delta"]), 0, "非霸主周 king_delta 应为 0")
	assert_eq(tracker.king_weeks, 5, "非霸主周不累加霸榜周数")

	# 真表集成：三线值读现成真源（不新增计数器）+ 存档 flags 开放容器零迁移。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var view: Dictionary = world.get_freedom_view()
	assert_eq(int(view["king_weeks"]), 0, "开局霸榜周数归零")
	assert_eq(
		int(view["tree_n"]), world.tech_fog.get_discovered_count(), "树 n 读 TechFog 域计数（不新增计数器）"
	)
	assert_eq(
		int(view["tree_total"]),
		world.tech_fog.get_total_nodes(),
		"树分母 = techs.json total_nodes（单点真源）"
	)
	assert_eq(int(view["influence"]), world.get_influence(), "影响力存量读 Economy 快照（不新增计数器）")
	var save: Dictionary = SnapshotCodec.to_save(world)
	var flags: Dictionary = save["flags"]
	for key: String in world.freedom.to_save().keys():
		assert_true(flags.has(key), "存档 flags 应含三线计数器键 %s（开放容器）" % key)

	# 旧档零迁移：抹掉全部 freedom_* 键后 restore 不报错、三线归零（红线 4）。
	var legacy: Dictionary = save.duplicate(true)
	for key: String in (legacy["flags"] as Dictionary).keys():
		if key.begins_with("freedom_"):
			(legacy["flags"] as Dictionary).erase(key)
	world.restore(legacy)
	assert_eq(world.freedom.king_weeks, 0, "旧档缺键 ⇒ 霸榜周数兜底 0（零迁移）")
	assert_eq(world.freedom.sota_times, 0, "旧档缺键 ⇒ SOTA 次数兜底 0（零迁移）")
	assert_false(world.freedom.is_finale_shown(), "旧档缺键 ⇒ 终局未弹标记兜底 false（零迁移）")

	# 保霸判定真跑：restore 携带榜首分 ⇒ 周结当周判霸主 +1。
	var champion: Dictionary = save.duplicate(true)
	(champion["flags"] as Dictionary)["player_best_score"] = _score_threshold() + 0.5
	world.restore(champion)
	world.settle_week()
	assert_eq(world.freedom.king_weeks, 1, "榜首分在场 ⇒ 周结当周判保霸 +1")
	assert_eq(int(world.get_freedom_view()["king_weeks"]), 1, "只读数据面与计数器同源（单点真源）")


func test_three_line_visible_from_week25() -> void:
	# [T] 验收点 2：W25 起资源栏副行弱展示（不弹横幅）；与"封顶升主权重"两时点分离。
	var display_week: int = _display_week()
	assert_eq(display_week, 25, "可见时点 = ui_display.freedom.display_week（需求 §11.3 RF-02：W25 起常显）")
	var tracker := FreedomTracker.new()
	autofree(tracker)
	tracker.setup(_freedom_cfg())
	for week_no: int in range(1, display_week):
		var settled: Dictionary = tracker.settle_week(_ctx(week_no, 10.0, false, 0, 0))
		assert_eq(
			str(settled["stage_id"]), FreedomTracker.STAGE_HIDDEN, "W%d 未到可见时点 ⇒ 三线不显" % week_no
		)
		assert_false(bool(settled["banner"]), "隐藏期不得弹横幅")
	var at_display: Dictionary = tracker.settle_week(_ctx(display_week, 10.0, false, 0, 0))
	assert_eq(str(at_display["stage_id"]), FreedomTracker.STAGE_WEAK, "W%d 起弱展示" % display_week)
	assert_false(bool(at_display["banner"]), "弱展示阶段不弹横幅（两时点分离）")
	var next_week: Dictionary = tracker.settle_week(_ctx(display_week + 1, 10.0, false, 0, 0))
	assert_eq(str(next_week["stage_id"]), FreedomTracker.STAGE_WEAK, "未封顶前保持弱展示（单调不回退）")

	# 真表集成：真 GameWorld 经存档契约落到 W(display_week-1) 后单步周结 ⇒ 视图可见性翻转。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var save: Dictionary = SnapshotCodec.to_save(world)
	save["week"] = display_week - 1
	world.restore(save)
	assert_false(bool(world.get_freedom_view()["visible"]), "W%d 三线不显（未到可见时点）" % (display_week - 1))
	world.settle_week()
	assert_eq(world.week, display_week, "单步周结应推进到 W%d" % display_week)
	var view: Dictionary = world.get_freedom_view()
	assert_true(bool(view["visible"]), "W%d 三线可见（资源栏副行弱展示）" % display_week)
	assert_false(bool(view["primary"]), "未封顶 ⇒ 不升主权重")
	assert_eq(int(view["display_week"]), display_week, "可见时点由数据表注入（非代码常量）")
	assert_eq((view["lines"] as Array).size(), 3, "三线 = 霸榜周数 / 树 n / 影响力存量")


func test_three_line_takes_over_after_saturation() -> void:
	# [T] 验收点 3：首达饱和阈值当周弹横幅一次 + 三线升主权重；周报携带三线行；封顶后 ≥3 次三线变化。
	var threshold: float = _score_threshold()
	assert_gt(threshold, 0.0, "饱和阈值应由 benchmarks.saturation 提供")
	var tracker := FreedomTracker.new()
	autofree(tracker)
	tracker.setup(_freedom_cfg())
	tracker.settle_week(_ctx(_display_week() - 1, threshold - 10.0, false, 0, 0))
	var below: Dictionary = tracker.settle_week(_ctx(_display_week(), threshold - 1.0, false, 0, 0))
	assert_eq(str(below["stage_id"]), FreedomTracker.STAGE_WEAK, "未达阈值 ⇒ 仅弱展示")
	assert_false(bool(below["banner"]), "未达阈值不得弹横幅")
	var first_cap: Dictionary = tracker.settle_week(
		_ctx(_display_week() + 1, threshold, false, 0, 0)
	)
	assert_eq(str(first_cap["stage_id"]), FreedomTracker.STAGE_PRIMARY, "首达阈值 ⇒ 三线升主权重")
	assert_true(bool(first_cap["banner"]), "封顶当周弹横幅一次")
	var after_cap: Dictionary = tracker.settle_week(
		_ctx(_display_week() + 2, threshold + 0.1, false, 0, 0)
	)
	assert_eq(str(after_cap["stage_id"]), FreedomTracker.STAGE_PRIMARY, "阶段单调不回退")
	assert_false(bool(after_cap["banner"]), "横幅只弹一次（不重复骚扰）")

	# 真表集成：经存档契约注入榜首分 ⇒ 封顶当周起周报携带三线行，且封顶后 ≥3 次三线变化。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var save: Dictionary = SnapshotCodec.to_save(world)
	(save["flags"] as Dictionary)["player_best_score"] = threshold + 0.5
	world.restore(save)
	var tasks := AutoTaskPolicy.new()
	var policy := AutoDecisionPolicy.new()
	var changed_weeks: int = 0
	var freedom_row: String = ""
	for _week_index: int in range(POST_CAP_WEEKS):
		tasks.fill(world)
		world.simulate_weeks(1, policy)
		assert_false(world.game_over_flag, "封顶后观察窗口内不应破产（任务流在场）")
		var report: Dictionary = world.get_last_report()
		var freedom_week: Dictionary = report.get("freedom", {})
		assert_eq(
			str(freedom_week.get("stage_id", "")),
			FreedomTracker.STAGE_PRIMARY,
			"封顶后每周报都应带三线阶段（升主权重）"
		)
		if not (freedom_week.get("changed_lines", []) as Array).is_empty():
			changed_weeks += 1
		if freedom_row.is_empty():
			freedom_row = _freedom_report_row(report)
	assert_false(freedom_row.is_empty(), "封顶后周报应携带三线行（RF-02 升主权重）")
	assert_true(
		freedom_row.contains(FreedomTracker.LINE_KING_WEEKS) or freedom_row.contains("霸榜"),
		"三线行应含霸榜周数（实测：%s）" % freedom_row
	)
	assert_gte(
		changed_weeks,
		POST_CAP_MIN_CHANGES,
		"封顶后 %d 周内三线进度变化应 ≥%d 次（否则=后半空转，GDD §18）" % [POST_CAP_WEEKS, POST_CAP_MIN_CHANGES]
	)


func test_final_summary_has_six_fields() -> void:
	# [T] 验收点 3（终局屏）：summary 六项 + 关键决策回溯 3 条 + 一句话评价；破产卡两套并存。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var summary: Dictionary = world.get_finale_summary()
	assert_eq(str(summary.get("reason", "")), "final_week", "终局屏非破产专属（Q-R3：两套并存）")
	var fields: PackedStringArray = summary.get("six_fields", PackedStringArray())
	assert_eq(fields.size(), SIX_FIELD_COUNT, "summary 必须为六项")
	for field_index: int in range(GameWorld.FINAL_SUMMARY_FIELDS.size()):
		assert_eq(
			str(fields[field_index]),
			str(GameWorld.FINAL_SUMMARY_FIELDS[field_index]),
			"第 %d 项键序与 FINAL_SUMMARY_FIELDS 单点真源一致" % field_index
		)
	# 六项语义（issue #82）：周数 / SOTA 次数 / 最高分 / 霸榜周数 / 树 n（含分母）/ 影响力存量。
	assert_true(fields.has("week"), "① 周数")
	assert_true(fields.has("sota_times"), "② SOTA 次数")
	assert_true(fields.has("player_best_score"), "③ 最高分")
	assert_true(fields.has("king_weeks"), "④ 霸榜周数")
	assert_true(fields.has("tree_n"), "⑤ 树 n")
	assert_true(fields.has("influence"), "⑥ 影响力存量")
	for key: String in fields:
		assert_true(summary.has(key), "六项键 %s 应有值" % key)
	assert_eq(int(summary["week"]), world.week, "周数与世界同源")
	assert_eq(int(summary["tree_total"]), world.tech_fog.get_total_nodes(), "树分母与单点真源同源")
	assert_eq(int(summary["influence"]), world.get_influence(), "影响力与 Economy 同源")

	# 零状态边界（需求 §11.3 边界）：0 霸榜 / 0 探明 / 0 影响力 ⇒ 显 0，不 NaN、不空行。
	var rows: Array = summary.get("rows", [])
	assert_eq(rows.size(), SIX_FIELD_COUNT, "终局屏应有六行（一屏内可截图）")
	for row_variant: Variant in rows:
		var row: String = str(row_variant)
		assert_false(row.is_empty(), "六项不得出现空行")
		assert_false(row.to_lower().contains("nan"), "六项不得出现 NaN（实测：%s）" % row)
	assert_true(str(rows[0]).contains("0"), "零状态下周数应显 0（实测：%s）" % str(rows[0]))
	assert_true(
		str(rows[4]).contains("/") and str(rows[4]).contains(str(world.tech_fog.get_total_nodes())),
		"树项应显 n/分母（实测：%s）" % str(rows[4])
	)
	var review: Array = summary.get("review", [])
	assert_eq(review.size(), REVIEW_COUNT, "关键决策回溯 3 条（最贵训练/最晚点树/最险破产边缘）")
	for row_variant: Variant in review:
		assert_false(str(row_variant).is_empty(), "回溯行不得为空（无记录应显占位文案）")
	assert_false(str(summary.get("verdict", "")).is_empty(), "一句话评价不得为空")
	var display: Dictionary = summary.get("display", {})
	assert_false(str(display.get("title", "")).is_empty(), "终局屏标题文案键来自 ui_display.finale")
	assert_eq((display.get("labels", {}) as Dictionary).size(), SIX_FIELD_COUNT, "六项标签文案键齐全（L4 真源）")

	# 破产卡与终局屏两套并存：破产卡 reason 语义不变，且同源携带六项。
	var bankruptcy: Dictionary = world.get_game_over_summary()
	assert_eq(str(bankruptcy.get("reason", "")), "bankruptcy", "破产卡 reason 语义不变")
	assert_eq(
		(bankruptcy.get("six_fields", []) as Array).size(), SIX_FIELD_COUNT, "破产卡与终局屏六项同源（避免双真源）"
	)

	# 自动弹（RF-03 / Q-R3）：走满单局周数当周，presenter 应把 FINALE 压入 z2 栈顶（非破产专属）。
	var last_week := GameWorld.new()
	autofree(last_week)
	last_week.start_new_game(SEED)
	var endgame_save: Dictionary = SnapshotCodec.to_save(last_week)
	endgame_save["week"] = _run_weeks() - 1
	(endgame_save["flags"] as Dictionary)["freedom_finale_shown"] = false
	last_week.restore(endgame_save)
	var stack := PanelStack.new()
	var presenter := DashboardPresenter.new()
	presenter.setup(last_week, stack)
	last_week.settle_week()
	assert_eq(stack.get_z2_stack().back(), PanelStack.PanelId.FINALE, "走满单局周数当周自动弹终局屏（z2 栈顶）")
	assert_false(stack.is_tick_feeding_allowed(), "终局屏为 z2 阻塞面板（世界等玩家）")
	assert_false(presenter.get_finale_summary().is_empty(), "presenter 应透传 L2 终局数据面")
	assert_eq(
		(presenter.get_finale_summary().get("rows", []) as Array).size(),
		SIX_FIELD_COUNT,
		"终局屏渲染六项（一屏内可截图）"
	)


func test_single_run_duration_guard() -> void:
	# [T] 验收点 4：单局时长守卫 —— 160 周 × 10s ≈1600s；变速不改变决策数；终局只触发一次。
	var clock_cfg: Dictionary = DataLoader.load_json(CLOCK_PATH)
	var tick_seconds: float = float(clock_cfg["tick_seconds"])
	var ticks_per_week: int = int(clock_cfg["ticks_per_week"])
	var run_weeks: int = int(clock_cfg.get("run_weeks", 0))
	assert_eq(run_weeks, 160, "单局周数 = clock.json.run_weeks（纪要 §十二：一局 160 周）")
	var seconds_per_week: float = tick_seconds * float(ticks_per_week)
	assert_almost_eq(seconds_per_week, 10.0, 0.001, "10s/周（tick_seconds × ticks_per_week）")
	var total_seconds: float = seconds_per_week * float(run_weeks)
	assert_almost_eq(
		total_seconds, 1600.0, DURATION_TOLERANCE_SECONDS, "160 周 ≈1600s（需求 §11.1 E11-1）"
	)
	assert_between(
		total_seconds / 60.0, 25.0, 30.0, "单局时长应落在 25–30 分钟（实测 %.1f 分钟）" % (total_seconds / 60.0)
	)

	# 变速不改变"周数→决策数"映射：同一游戏时长在 1x/4x 档推进的周数必须一致。
	var weeks_at_1x: int = _weeks_fed_at_speed(0, seconds_per_week * 3.0)
	var weeks_at_4x: int = _weeks_fed_at_speed(2, seconds_per_week * 3.0)
	assert_eq(weeks_at_1x, 3, "30s 游戏时长 ⇒ 3 周（1x）")
	assert_eq(weeks_at_4x, weeks_at_1x, "变速档只改喂帧步长，不改周数→周结（决策）映射")

	# 终局只触发一次：未走满不触发，走满当周触发，弹过后不再触发（可继续自由期）。
	var tracker := FreedomTracker.new()
	autofree(tracker)
	tracker.setup(_freedom_cfg())
	assert_false(tracker.is_finale_due(run_weeks - 1), "未走满单局周数不触发终局")
	assert_true(tracker.is_finale_due(run_weeks), "走满单局周数当周触发终局")
	tracker.mark_finale_shown()
	assert_false(tracker.is_finale_due(run_weeks + 1), "终局只弹一次（Q-R3：可继续自由期）")

	# 真表集成：经存档契约落到 W(run_weeks-1)，单步周结的载荷应携带 finale 段且只带一次。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var save: Dictionary = SnapshotCodec.to_save(world)
	save["week"] = run_weeks - 1
	(save["flags"] as Dictionary)["freedom_finale_shown"] = false
	world.restore(save)
	world.settle_week()
	assert_eq(world.week, run_weeks, "单步周结应推进到单局末周")
	var report: Dictionary = world.get_last_report()
	assert_true(report.has("finale"), "走满单局周数当周，周结载荷应携带终局段")
	var finale: Dictionary = report.get("finale", {})
	assert_eq(str(finale.get("reason", "")), "final_week", "终局段 reason 应为 final_week")
	assert_eq((finale.get("rows", []) as Array).size(), SIX_FIELD_COUNT, "终局段携带六项（同一数据面）")
	assert_true(world.freedom.is_finale_shown(), "弹过后应标记已弹（不重复骚扰）")
	world.settle_week()
	assert_false(world.get_last_report().has("finale"), "终局只弹一次：次周载荷不再携带终局段")


## ============ 内部：数据派生 ============


## 自由期三线参数（真源：ui_display.freedom / benchmarks.saturation / clock.run_weeks）。
func _freedom_cfg() -> Dictionary:
	return {
		"display_week": _display_week(),
		"score_threshold": _score_threshold(),
		"run_weeks": _run_weeks(),
	}


func _display_week() -> int:
	var freedom_cfg: Dictionary = DataLoader.load_json(UI_DISPLAY_PATH).get("freedom", {})
	return int(freedom_cfg.get("display_week", 0))


func _score_threshold() -> float:
	var saturation: Dictionary = DataLoader.load_json(BENCHMARKS_PATH).get("saturation", {})
	return float(saturation.get("score_threshold", 0.0))


func _run_weeks() -> int:
	return int(DataLoader.load_json(CLOCK_PATH).get("run_weeks", 0))


## 周结上下文（FreedomTracker.settle_week 入参契约）。
func _ctx(
	week_no: int, player_best_score: float, champion: bool, tree_n: int, influence: int
) -> Dictionary:
	return {
		"week": week_no,
		"player_best_score": player_best_score,
		"player_is_champion": champion,
		"tree_n": tree_n,
		"tree_total": int(DataLoader.load_json(TechFog.DEFAULT_TECHS_PATH)["total_nodes"]),
		"influence": influence,
	}


## 周报三线行（按 ui_display.freedom.report_prefix 识别，避免测试写死文案）。
func _freedom_report_row(report: Dictionary) -> String:
	var freedom_cfg: Dictionary = DataLoader.load_json(UI_DISPLAY_PATH).get("freedom", {})
	var prefix: String = str(freedom_cfg.get("report_prefix", ""))
	if prefix.is_empty():
		return ""
	for row_variant: Variant in report.get("rows", []):
		if str(row_variant).begins_with(prefix):
			return str(row_variant)
	return ""


## 以指定变速档喂入"同一游戏时长"，返回推进的周数（变速系数属 View，只改喂帧步长）。
func _weeks_fed_at_speed(speed_index: int, game_seconds: float) -> int:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var driver := GameLoopDriver.new()
	autofree(driver)
	driver.setup(world)
	driver.speed_index = speed_index
	var speed: float = driver.get_speed_multiplier()
	assert_gt(speed, 0.0, "变速档系数应为正")
	var frame_count: int = 120
	var frame_delta: float = game_seconds / (float(frame_count) * speed)
	for _frame: int in range(frame_count):
		driver.feed_frame(frame_delta)
	return world.week
