extends GutTest
## #150 金框预算/显示分级/n 维条形图验收 GUT（用例名=issue body 逐字）：
## - test_l3_budget_never_exceeds_3：L3 计数硬断言（单局 ≤3 次：晋升×2+终局）
## - test_score_display_tiering：score<10 主台只显档位标签/≥10 显真值/周报恒显
## - test_ndim_bars_reveal：n 维条形图数值+条形双通道，逐条揭晓 ≤0.2s/维
## - test_l2_headline_priority_queue：L2 金框并发队列（破纪录>被反超>顶会>大赏>
##   首出分>融资>满树）
## 被测=src/ui/l3_budget.gd + src/ui/widgets/ndim_bars.gd + presenter 显示分级/
## n 维条形适配 + src/entities/headline_queue.gd。
## 真源=ui-ux B.4 动画预算总表（L3 恒 3 硬断言/L2 并发优先级）+
## B.2 显示分级/n 维揭晓（0.2s/维）+ D.2（ui_anim_l3_count/ui_anim_l2_dur/
## ui_ndim_reveal_dur/ui_score_grade_threshold）。

const UI_PATH: String = "res://src/data/ui.json"


## ===== 验收点 1：L3 全屏计数硬断言（单局 ≤3 次） =====
func test_l3_budget_never_exceeds_3() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_eq(int(table["ui_anim_l3_count"]), 3, "ui_anim_l3_count=3（恒 3 硬断言）")
	assert_eq(L3Budget.L3_CAP, int(table["ui_anim_l3_count"]), "L3 上限镜像=表值")
	var budget := L3Budget.new()
	for i: int in 3:
		assert_true(budget.request(), "第 %d 次 L3 申请=放行（晋升×2+终局）" % (i + 1))
	assert_false(budget.request(), "第 4 次 L3 申请=拒绝（≤3 硬断言）")
	assert_eq(budget.get_used(), 3, "已用=3（封顶）")
	assert_eq(budget.get_cap(), 3, "上限=3")
	# ui_anim_l2_dur 预算同时落盘（并发串行时长 L3 消费用）
	assert_true(
		float(table["ui_anim_l2_dur"]) >= 1.2 and float(table["ui_anim_l2_dur"]) <= 2.0,
		"L2 金框时长 1.2-2.0s/条（B.4）",
	)


## ===== 验收点 2：显示分级（<10 档位标签 / ≥10 真值 / 周报恒显） =====
func test_score_display_tiering() -> void:
	# 主台：<10 只显档位标签（不显裸数字）
	var low_main: Dictionary = DashboardPresenter.score_display(
		5.0, DashboardPresenter.SURFACE_MAIN
	)
	assert_false(bool(low_main["show_number"]), "主台 5 分不显裸数字")
	assert_eq(low_main["number"], "", "主台 <10 无数字")
	assert_eq(low_main["grade_text"], TextService.text("ui_grade_0"), "<10 显起步档·榜外标签")
	# 主台：≥10 显真值（不显档位标签）
	var mid_main: Dictionary = DashboardPresenter.score_display(
		50.0, DashboardPresenter.SURFACE_MAIN
	)
	assert_true(bool(mid_main["show_number"]), "主台 50 分显真值")
	assert_eq(mid_main["number"], "50", "显裸数字 50")
	assert_eq(mid_main["grade_text"], "", "≥10 不显档位标签")
	var high_main: Dictionary = DashboardPresenter.score_display(
		120.0, DashboardPresenter.SURFACE_MAIN
	)
	assert_eq(high_main["number"], "120", "120 分也显真值（≥10 恒显）")
	# 周报：恒显真值（无裸数字禁令；<10 也显数字）
	var low_report: Dictionary = DashboardPresenter.score_display(
		5.0, DashboardPresenter.SURFACE_REPORT
	)
	assert_true(bool(low_report["show_number"]), "周报 <10 也显真值（周报恒显）")
	assert_eq(low_report["number"], "5", "周报显 5")
	# 未出分：has_data=false（不渲染假数据）
	var none: Dictionary = DashboardPresenter.score_display(-1.0, DashboardPresenter.SURFACE_MAIN)
	assert_false(bool(none["has_data"]), "未出分=无数据（不渲染）")
	assert_eq(none["number"], "", "未出分无数字")


## ===== 验收点 3：n 维条形图（数值+条形双通道，逐条揭晓 ≤0.2s/维） =====
func test_ndim_bars_reveal() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_almost_eq(NdimBars.REVEAL_DUR, float(table["ui_ndim_reveal_dur"]), 0.001, "揭晓动效镜像=表值")
	assert_true(NdimBars.REVEAL_DUR <= 0.2, "逐条揭晓 ≤0.2s/维（B.2）")
	# presenter 适配：L2 ndim 视图{文本键:数值}→条形行（标签解析/数值保留）
	var bars: Array = (
		DashboardPresenter
		. ndim_bars_view(
			{
				"model_ndim_reasoning": 88.0,
				"model_ndim_knowledge": 75.0,
				"paper_ndim_novelty": 60.0,
			}
		)
	)
	assert_eq(bars.size(), 3, "3 维=3 条形行")
	assert_eq(bars[0]["label"], "推理", "首条=推理（值 88 最高，降序）")
	assert_eq(bars[0]["value"], 88.0, "首条值 88（数值双通道保留）")
	# 控件：逐条揭晓状态机（0.2s/维；数值+条形双通道）
	var widget := NdimBars.new()
	add_child_autofree(widget)
	await get_tree().process_frame
	widget.set_bars(bars)
	assert_eq(widget.get_bar_count(), 3, "条形行=3")
	assert_eq(widget.get_revealed_count(), 0, "初始未揭晓")
	assert_false(widget.is_bar_revealed(0), "0 维未揭晓")
	assert_true(widget.reveal_next(), "揭晓第 1 维")
	assert_true(widget.is_bar_revealed(0), "第 1 维已揭晓")
	assert_false(widget.is_bar_revealed(1), "第 2 维未揭晓（串行）")
	assert_true(widget.reveal_next(), "揭晓第 2 维")
	assert_true(widget.reveal_next(), "揭晓第 3 维")
	assert_false(widget.reveal_next(), "超维揭晓=拒绝")
	assert_eq(widget.get_revealed_count(), 3, "3/3 全揭晓")
	assert_true(widget.is_bar_revealed(2), "第 3 维已揭晓")
	# 双通道：标签+数值都可达（色盲安全）
	assert_eq(widget.get_bar_label(0), "推理", "条形标签（文字通道）")
	assert_almost_eq(widget.get_bar_value(0), 88.0, 0.001, "条形数值（数值通道）")


## ===== 验收点 4：L2 金框并发优先级队列 =====
func test_l2_headline_priority_queue() -> void:
	# 秩表=spec 顺序（B.4：破纪录>被反超>顶会>大赏>首出分>融资>满树）
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.RECORD]), 0, "破纪录=最高优先")
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.OUTCLASSED]), 1, "被反超=2 位")
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.TOPCONF]), 2, "顶会=3 位")
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.QUARTER_AWARD]), 3, "大赏=4 位")
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.FIRST_SCORE]), 4, "首出分=5 位")
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.FINANCING]), 5, "融资=6 位")
	assert_eq(int(HeadlineQueue.KIND_RANK[HeadlineQueue.Kind.FULL_TREE]), 6, "满树=最低优先")
	# 并发入队（逆序乱入）→ 按优先级串行出队
	var queue := HeadlineQueue.new()
	queue.enqueue(HeadlineQueue.Kind.FULL_TREE, {"title": "已登顶"})
	queue.enqueue(HeadlineQueue.Kind.RECORD, {"title": "破纪录！"})
	queue.enqueue(HeadlineQueue.Kind.TOPCONF, {"title": "顶会接收"})
	queue.enqueue(HeadlineQueue.Kind.FIRST_SCORE, {"title": "首出分"})
	queue.enqueue(HeadlineQueue.Kind.OUTCLASSED, {"title": "被反超"})
	queue.enqueue(HeadlineQueue.Kind.QUARTER_AWARD, {"title": "季度大赏"})
	queue.enqueue(HeadlineQueue.Kind.FINANCING, {"title": "融资到账"})
	assert_eq(queue.size(), 7, "7 头条全入队")
	var expected_order: Array = [
		HeadlineQueue.Kind.RECORD,
		HeadlineQueue.Kind.OUTCLASSED,
		HeadlineQueue.Kind.TOPCONF,
		HeadlineQueue.Kind.QUARTER_AWARD,
		HeadlineQueue.Kind.FIRST_SCORE,
		HeadlineQueue.Kind.FINANCING,
		HeadlineQueue.Kind.FULL_TREE,
	]
	var pop_index := 0
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_next()
		assert_eq(
			int(entry["kind"]),
			int(expected_order[pop_index]),
			"出队第 %d 位=spec 优先级（同帧串行）" % pop_index,
		)
		pop_index += 1
	assert_eq(pop_index, 7, "7 头条串行出完")
	assert_true(queue.is_empty(), "出空=空队列")
	assert_eq(queue.pop_next(), null, "空队列出队=null 哨兵（防御）")
