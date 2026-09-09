extends GutTest
## #142 SotaBoard 独立判定权威测试（验收点 1/2/3 逐字用例名）：
## - test_sota_semantics_strict：严格大于=破纪录/平局归霸主（models-spec
##   model_score_sota 硬语义）；
## - test_sotaboard_independent_rebuild：SotaBoard 独立——榜语义独立于
##   ModelLibrary 收藏、读档重建无环（纯 RefCounted 状态注入重建零环）；
## - test_guardband_never_exceeds_cap：守卫带 L1-L4 逼近不超玩家封顶 100。
## 真源：architecture A3 + models-spec model_score_sota + rivals-spec
## rival_guard_L1-L4（20-40/40-60/60-80/80-100）。


func test_sota_semantics_strict() -> void:
	var board := SotaBoard.new()
	autofree(board)
	watch_signals(board)
	# 首分直接入榜（空榜=玩家纪录）
	var first := board.submit_player_score(55.0, 3)
	assert_true(first.broke_record, "首分入榜（破纪录=无前纪录）")
	assert_eq(board.get_record_holder(), SotaBoard.HOLDER_PLAYER, "纪录持有者=player")
	assert_almost_eq(board.get_record_score(), 55.0, 0.001, "纪录=55")
	# 严格大于=破纪录
	var higher := board.submit_player_score(72.0, 8)
	assert_true(higher.broke_record, "72>55 破纪录")
	assert_eq(board.get_break_count(), 2, "破纪录 2 次")
	# 平局=霸主保持（不破）
	var tie := board.submit_player_score(72.0, 9)
	assert_false(tie.broke_record, "平局不破纪录（霸主保持）")
	assert_almost_eq(board.get_record_score(), 72.0, 0.001, "纪录仍 72")
	# 低于=不破
	var lower := board.submit_player_score(50.0, 10)
	assert_false(lower.broke_record, "低于不破")
	# 竞对判定：#144 留接口；严格大于玩家=反超、平局=玩家霸主保持
	var rival_beats := board.submit_rival_score(85.0, 12)
	assert_true(rival_beats.outclassed, "竞对 85>72 反超玩家")
	assert_eq(board.get_record_holder(), SotaBoard.HOLDER_RIVAL, "纪录持有者=竞对")
	var player_tie := board.submit_player_score(85.0, 13)
	assert_false(player_tie.broke_record, "玩家平竞对=平局归霸主（竞对保持）")
	assert_eq(board.get_record_holder(), SotaBoard.HOLDER_RIVAL, "平局霸主=竞对")
	var player_reclaim := board.submit_player_score(86.0, 14)
	assert_true(player_reclaim.broke_record, "86>85 玩家夺回")


func test_sotaboard_independent_rebuild() -> void:
	# 独立：榜状态可经视图快照重建（读档重建无环——纯数据无对象引用）
	var board := SotaBoard.new()
	autofree(board)
	board.submit_player_score(66.0, 7)
	board.submit_rival_score(78.0, 20)
	var snapshot: Dictionary = board.get_sota_view()
	# 重建=新实例注入快照状态（读档路径：无引用环，纯值重建）
	var rebuilt := SotaBoard.new()
	autofree(rebuilt)
	rebuilt.restore_from_view(snapshot)
	assert_almost_eq(rebuilt.get_record_score(), 78.0, 0.001, "重建后纪录=快照值")
	assert_eq(rebuilt.get_record_holder(), SotaBoard.HOLDER_RIVAL, "重建后持有者=快照值")
	assert_eq(rebuilt.get_record_week(), 20, "重建后周=快照值")
	assert_eq(rebuilt.get_break_count(), 2, "重建后破纪录次数=快照值")
	# 判定权威单一：重建实例继续独立判定不污染原榜
	var continue_submit := rebuilt.submit_player_score(90.0, 30)
	assert_true(continue_submit.broke_record, "重建实例可继续判定（无环独立）")
	assert_almost_eq(board.get_record_score(), 78.0, 0.001, "原榜不受重建实例影响（独立）")


func test_guardband_never_exceeds_cap() -> void:
	# 守卫带护栏：L1-L4 逼近不超玩家封顶 100（硬红线）
	var table := DataLoader.load_json("res://src/data/rivals.json")
	var expected := {
		"rival_guard_L1": {"min": 20.0, "max": 40.0},
		"rival_guard_L2": {"min": 40.0, "max": 60.0},
		"rival_guard_L3": {"min": 60.0, "max": 80.0},
		"rival_guard_L4": {"min": 80.0, "max": 100.0},
	}
	var board := SotaBoard.new()
	autofree(board)
	for band_key: String in expected.keys():
		var range_v: Dictionary = table[band_key]
		assert_almost_eq(
			float(range_v["min"]), expected[band_key]["min"], 0.001, "%s min 表真源" % band_key
		)
		assert_almost_eq(
			float(range_v["max"]), expected[band_key]["max"], 0.001, "%s max 表真源" % band_key
		)
	# L4 max=100（永不超封顶）；表断言：所有带 max ≤100
	for band_key: String in expected.keys():
		assert_true(
			float((table[band_key] as Dictionary)["max"]) <= 100.0, "%s max≤100 封顶" % band_key
		)
	# band_of 分级映射（表驱动带）
	assert_eq(board.band_of(25.0), SotaBoard.GuardBand.L1, "25→L1")
	assert_eq(board.band_of(50.0), SotaBoard.GuardBand.L2, "50→L2")
	assert_eq(board.band_of(70.0), SotaBoard.GuardBand.L3, "70→L3")
	assert_eq(board.band_of(95.0), SotaBoard.GuardBand.L4, "95→L4")
	# 边界语义：[min,max)；100 含 100（封顶）
	assert_eq(board.band_of(40.0), SotaBoard.GuardBand.L2, "40→L2（[min,max)）")
	assert_eq(board.band_of(100.0), SotaBoard.GuardBand.L4, "100→L4（含封顶）")
	# 带 cap 不越 100
	assert_almost_eq(board.band_cap(SotaBoard.GuardBand.L4), 100.0, 0.001, "L4 cap=100")
	# 提交非法分防御（先触发，assert_push_error 后检查缓冲）
	var bad := board.submit_player_score(150.0)
	assert_false(bad.ok, "score>100 拒绝（防越封顶）")
	assert_push_error(
		"SotaBoard.submit_player_score: score 非法",
		"score>100 必须 push_error（Error Tracker 消费）",
	)
