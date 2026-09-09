extends GutTest
## #144 验收点 3：撞车判定——同周双发=撞车叙事且判定=严格大小、同分归霸主
## （GUT：`test_collision_semantics`）。
## 真源=rivals-spec OP-RIV-03/rival_collision_rule（同周双发="独立工作撞车"
## 叙事，禁"你抢到了"；发版先序≠分数平局；判定=严格大小走 SotaBoard，
## 同分归霸主 models-spec 同源）+ models-spec model_score_sota 硬语义。
## 编排语义（装配方）：同周玩家出分+竞对发版 → 玩家 submit_player_score
## 先（或后）→ 竞对 submit_rival_score → SotaBoard 判定唯一权威；撞车只
## 是叙事标记不改判定。

const RIVALS_PATH: String = "res://src/data/rivals.json"


func _deep_alley_release_at(table: Dictionary, week: int) -> float:
	var actors: Dictionary = table["rival_actors"]
	var actor: Dictionary = actors["deep_alley"]
	for entry: Variant in actor["timeline"]:
		var row: Dictionary = entry
		if int(row["week"]) == week and str(row["action"]) == "release":
			return float(row["score"])
	return -1.0


func test_collision_semantics() -> void:
	var table := DataLoader.load_json(RIVALS_PATH)
	var board := SotaBoard.new()
	autofree(board)
	# 场景 A：玩家与竞对同周发版（W40），玩家 43 分 > 竞对 42 → 撞车叙事+玩家破纪录
	var pack := RivalPack.new()
	autofree(pack)
	# 推进到 W39（无玩家发版）
	for w: int in range(1, 40):
		pack.advance_all(w)
	# W40：玩家出分 43 分提交在先
	var player_submit: Dictionary = board.submit_player_score(43.0, 40)
	assert_true(player_submit.broke_record, "玩家 43 破前纪录（入榜）")
	# 竞对 W40 发版（42 分）+ 玩家同周发版 → 撞车标记
	var fired: Array = pack.advance_all(40, true)
	# 找到 release 动作
	var collision_found := false
	for payload_v: Variant in fired:
		var payload: Dictionary = payload_v
		if str(payload["action"]) == "release":
			assert_eq(str(payload["kind"]), Rival.KIND_COLLISION, "同周双发=撞车叙事")
			collision_found = true
			# 竞对分提交 SotaBoard（判定=严格大小：42<43 不破，玩家霸主保持）
			var rival_submit: Dictionary = board.submit_rival_score(float(payload["score"]), 40)
			assert_false(rival_submit.outclassed, "竞对 42<玩家 43 未反超（严格大于）")
			assert_eq(board.get_record_holder(), SotaBoard.HOLDER_PLAYER, "玩家霸主保持（严格判定）")
	assert_true(collision_found, "W40 深巷发版动作存在")
	# 场景 B：同分=平局归霸主（玩家 42 == 竞对 42 同周，玩家先发=霸主）
	var board2 := SotaBoard.new()
	autofree(board2)
	board2.submit_player_score(42.0, 40)
	var rival_tie: Dictionary = board2.submit_rival_score(42.0, 40)
	assert_false(rival_tie.outclassed, "竞对平玩家=平局归霸主（玩家保持）")
	assert_eq(board2.get_record_holder(), SotaBoard.HOLDER_PLAYER, "同分霸主=玩家（先发保持）")
	# 场景 C：竞对更高=反超（严格大小；玩家先发 40，竞对 52 反超）
	var board3 := SotaBoard.new()
	autofree(board3)
	board3.submit_player_score(40.0, 40)
	var rival_higher: Dictionary = board3.submit_rival_score(52.0, 40)
	assert_true(rival_higher.outclassed, "竞对 52>玩家 40=反超（严格大于）")
	assert_eq(board3.get_record_holder(), SotaBoard.HOLDER_RIVAL, "竞对夺榜")
	# 撞车周不触发价格战/挖人（错峰表结构：同周无双动作——schema 已断唯一周）
	var same_week_actions := 0
	var actors: Dictionary = table["rival_actors"]
	for entry: Variant in actors["deep_alley"]["timeline"]:
		if int((entry as Dictionary)["week"]) == 40:
			same_week_actions += 1
	assert_eq(same_week_actions, 1, "撞车周（W40）深巷仅 1 动作（无价格战/挖人错峰）")


func test_collision_view_records_week() -> void:
	# 撞车后数据面可查（叙事留痕：collision_week）
	var pack := RivalPack.new()
	autofree(pack)
	for w: int in range(1, 55):
		pack.advance_all(w, w == 54)
	var view: Dictionary = pack.get_rival_view("deep_alley")
	# W54 为发版周（场景：玩家同周发版）
	var actors: Dictionary = DataLoader.load_json(RIVALS_PATH)["rival_actors"]
	var w54_action := ""
	for entry: Variant in actors["deep_alley"]["timeline"]:
		if int((entry as Dictionary)["week"]) == 54:
			w54_action = str((entry as Dictionary)["action"])
	if w54_action == "release":
		assert_eq(int(view["collision_week"]), 54, "撞车周记入视图（可查差距）")
	else:
		assert_eq(int(view["collision_week"]), 0, "非发版周无撞车留痕")
