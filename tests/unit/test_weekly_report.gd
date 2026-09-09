extends GutTest
## #149 周报双挂载验收 GUT（用例名=issue body 逐字）：
## - test_report_significant_predicate：自动弹=显著周（变化≥5% 或符号翻转），
##   平淡周=灰点一次消失
## - test_report_suppressed_at_4x：4x 下不弹自动周报（灰点累积，退出 4x 补看）
## - test_report_archive_isomorphic：归档重看=同构渲染（与自动弹同数据源）
## 被测=L2 WeeklyReport（显著谓词/行序/自动弹门控）+ L3 ReportDual（双挂载
## 决策/灰点状态/归档）+ WeeklyReportDialog（同构渲染器）+ Settlement 论文槽
## 释放接线（#143 留口收口）。
## 真源=ui-ux A.3 OP-UX-03/B.2 ui_report_dual 行 + time-spec D.2（变化<5% 为
## 平淡周，阈值 time_bland_threshold=5 表驱动）+ ui.json ui_report_significant。

const UI_PATH: String = "res://src/data/ui.json"


## ===== 验收点 1：显著变化谓词（≥5% 或符号翻转）+ 平淡周灰点一次消失 =====
func test_report_significant_predicate() -> void:
	# 谓词边界：4%=不显著；5%=显著；10%=显著；符号翻转=显著；0 侧=显著；相等=不显著
	assert_false(
		WeeklyReport.is_significant_change(100.0, 104.0, 5),
		"4% 变化 < 5% 阈值=不显著（平淡周）",
	)
	assert_true(WeeklyReport.is_significant_change(100.0, 105.0, 5), "5% 变化=显著（阈值含）")
	assert_true(WeeklyReport.is_significant_change(100.0, 90.0, 5), "10% 变化=显著")
	assert_true(WeeklyReport.is_significant_change(100.0, -5.0, 5), "正→负=符号翻转显著")
	assert_true(WeeklyReport.is_significant_change(-10.0, 5.0, 5), "负→正=符号翻转显著")
	assert_true(WeeklyReport.is_significant_change(0.0, 10.0, 5), "从无到有=显著")
	assert_true(WeeklyReport.is_significant_change(10.0, 0.0, 5), "到无=显著")
	assert_false(WeeklyReport.is_significant_change(100.0, 100.0, 5), "相等=不显著")
	# 平淡周（无显著行）→ 灰点（不弹）；显著行 → 显著周
	var report := WeeklyReport.new()
	report.begin_week(3)
	report.add_delta_row(WeeklyReport.RowKind.LEDGER, "工资 -¥400", 400.0, 410.0)
	var bland_view: Dictionary = report.get_report_view()
	assert_false(bool(bland_view["significant"]), "平淡周=不显著（变化<5%）")
	var dual := ReportDual.new()
	var bland_decision: Dictionary = dual.ingest(bland_view, GameClock.SpeedIndex.ONE_X)
	assert_false(bool(bland_decision["pop"]), "平淡周不自动弹（不打扰）")
	assert_true(bool(bland_decision["dot"]), "平淡周=灰点")
	assert_true(dual.is_dot_active(), "灰点活跃")
	dual.dismiss_dot()
	assert_false(dual.is_dot_active(), "灰点点一次消失（本周）")
	# 显著行（10% 变化）→ 显著周
	report.add_delta_row(WeeklyReport.RowKind.LEDGER, "论文影响力 +10", 0.0, 10.0)
	var significant_view: Dictionary = report.get_report_view()
	assert_true(bool(significant_view["significant"]), "显著行=显著周")
	assert_true(
		WeeklyReport.is_significant_change(0.0, 10.0, report.get_bland_threshold()),
		"谓词阈值=time.json time_bland_threshold（表驱动）",
	)


## ===== 验收点 2：4x 下不弹自动周报（灰点累积，退出 4x 补看） =====
func test_report_suppressed_at_4x() -> void:
	var report := WeeklyReport.new()
	report.begin_week(5)
	report.add_row(WeeklyReport.RowKind.EVENT, "融资到账 ¥50 万")
	var view: Dictionary = report.get_report_view()
	assert_true(bool(view["significant"]), "事件行=显著周")
	# 门控：仅 1x 弹；2x/4x 同为加速档不弹
	assert_true(report.should_auto_pop(GameClock.SpeedIndex.ONE_X), "1x=自动弹（显著周）")
	assert_false(report.should_auto_pop(GameClock.SpeedIndex.TWO_X), "2x 不弹（加速档）")
	assert_false(report.should_auto_pop(GameClock.SpeedIndex.FOUR_X), "4x 不弹（ui-ux A.2）")
	# 双挂载：4x 抑制=灰点（灰点累积：抑制周也留点）；退出 4x（1x）=弹
	var dual := ReportDual.new()
	var suppressed: Dictionary = dual.ingest(view, GameClock.SpeedIndex.FOUR_X)
	assert_false(bool(suppressed["pop"]), "4x 抑制自动弹")
	assert_true(bool(suppressed["dot"]), "4x 抑制=灰点（累积不丢）")
	assert_true(dual.is_dot_active(), "抑制周灰点活跃（退出 4x 补看入口）")
	var resumed: Dictionary = dual.ingest(view, GameClock.SpeedIndex.ONE_X)
	assert_true(bool(resumed["pop"]), "退出 4x（1x）=自动弹补看")
	assert_false(bool(resumed["dot"]), "弹起后无灰点")


## ===== 验收点 3：归档重看=同构渲染（与自动弹同数据源） =====
func test_report_archive_isomorphic() -> void:
	var report := WeeklyReport.new()
	report.begin_week(7)
	report.add_delta_row(WeeklyReport.RowKind.LEDGER, "论文影响力 +10", 0.0, 10.0)
	report.add_row(WeeklyReport.RowKind.EVENT, "挖人传闻：深巷出价")
	report.add_row(WeeklyReport.RowKind.RIVAL, "深巷发版 55.0")
	var view: Dictionary = report.get_report_view()
	# 自动弹渲染（z2）
	var dialog := WeeklyReportDialog.new()
	add_child_autofree(dialog)
	await get_tree().process_frame
	dialog.render(view)
	var auto_count: int = dialog.get_row_count()
	var auto_texts: Array[String] = []
	var auto_significant: Array[bool] = []
	for i: int in auto_count:
		auto_texts.append(dialog.get_row_text(i))
		auto_significant.append(dialog.get_row_significant(i))
	# 归档（同数据源；重看=同一 view 字典）
	var dual := ReportDual.new()
	dual.ingest(view, GameClock.SpeedIndex.ONE_X)
	assert_eq(dual.get_archive_count(), 1, "归档含本周报")
	# 归档重看渲染（z1）→ 同构：行数/文本/显著标记逐位一致
	dialog.render(dual.get_archive()[0])
	assert_eq(dialog.get_row_count(), auto_count, "归档同构=行数一致")
	assert_eq(dialog.get_row_count(), int(view["row_count"]), "行数=L2 view 行数")
	for i: int in auto_count:
		assert_eq(dialog.get_row_text(i), auto_texts[i], "归档同构=第 %d 行文本一致" % i)
		assert_eq(dialog.get_row_significant(i), auto_significant[i], "归档同构=第 %d 行显著一致" % i)
	# 呈现序=RowKind 秩（账本→事件→竞对；同构渲染序与 view 序一致）
	assert_eq(int(view["rows"][0]["kind_rank"]), 0, "首行=账本对账（LEDGER 秩0）")


## ===== 补充：#143 留口收口——论文完成槽经路由后释放 + 周报行 =====
func test_paper_slot_released_after_route() -> void:
	var ledger := Ledger.new(1)
	autofree(ledger)
	var resources := Resources.new(200000, 0)
	autofree(resources)
	var economy := Economy.new()
	autofree(economy)
	var board := TaskBoard.new()
	autofree(board)
	var archive := PaperArchive.new()
	autofree(archive)
	var report := WeeklyReport.new()
	autofree(report)
	var pool := PaperPool.new()
	autofree(pool)
	var paper := PaperProject.from_topic(pool.get_topics_in_domain("align")[0])
	board.start_paper(paper, 0)
	var settlement := Settlement.new(ledger, resources, economy, board, archive, report)
	autofree(settlement)
	assert_eq(board.get_slot_state(0), CoreEnums.ProjectState.IN_PROGRESS, "论文运行中（槽0）")
	for i: int in paper.get_duration_weeks():
		var result: Dictionary = settlement.run_settle(1 + i)
		assert_false(result.skipped, "第 %d 周可结算" % (i + 1))
	# 论文完成槽释放（防 4 槽死局：#143 模型侧仪式消费，论文侧本批收口）
	assert_eq(board.get_slot_state(0), CoreEnums.ProjectState.EMPTY, "论文完成槽已释放可复用")
	assert_eq(board.get_empty_slot_count(), 4, "槽释放后 4 槽全空")
	# 周报行（账本对账：论文影响力到账，#153 校准 repro=18）+ 显著周
	var view: Dictionary = report.get_report_view()
	assert_eq(view["row_count"], 1, "周报含 1 行（论文影响力）")
	assert_true(bool(view["significant"]), "论文完成周=显著周（0→影响力）")
	var papers_table := DataLoader.load_json("res://src/data/papers.json")
	var expected_influence := str(int((papers_table["paper_influence"] as Dictionary)["repro"]))
	assert_true(
		str(view["rows"][0]["text"]).contains(expected_influence),
		"行文本含影响力数值 %s（L2 格式化，papers.json 表驱动）" % expected_influence,
	)
