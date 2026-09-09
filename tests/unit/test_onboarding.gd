extends GutTest
## #152 验收点 GUT（issue #152 四条 [T]）：
## - test_onboarding_steps_advance_in_order：六步顺序 advance + 任一步跳过不阻塞；
## - test_goal_card_week_hint_matches_clock：目标卡"约再跑 X 周"与周结周号一致；
## - test_first_loop_cadence_weeks：教学节拍三护栏 + 跨表镜像断言（防双源漂移）；
## - test_fail_no_punish：平庸出分无失败语/无 error 信号，目标卡仍指向下一步。
## 真源：onboarding-spec A.1/D.2 + numerics-master §〇 + architecture §2.1 onboarding。

const ONBOARDING_PATH: String = "res://src/data/onboarding.json"
const PAPERS_PATH: String = "res://src/data/papers.json"
const TREE_PATH: String = "res://src/data/tech_tree.json"
const MODELS_PATH: String = "res://src/data/models.json"
const RIVALS_PATH: String = "res://src/data/rivals.json"
const TIME_PATH: String = "res://src/data/time.json"
const TEXTS_PATH: String = "res://src/data/texts.json"

var _machine: TutorialMachine


func before_each() -> void:
	_machine = TutorialMachine.new()


func after_each() -> void:
	_machine = null


## ---------- 验收点 1：六步顺序 advance，任一步跳过不阻塞 ----------


func test_onboarding_steps_advance_in_order() -> void:
	watch_signals(_machine)
	# 轮次剧本：逐轮翻真当前步谓词，断言每轮恰点亮一个、载荷索引严格递增
	var rounds := [
		{"set": 0, "week": 1, "expect": [0]},
		{"set": 1, "week": 3, "expect": [1]},
		{"set": 2, "week": 3, "expect": [2]},
		{"set": 3, "week": 4, "expect": [3]},
		{"set": 4, "week": 8, "expect": [4]},
		{"set": 5, "week": 10, "expect": [5]},
	]
	var emitted_indices: Array[int] = []
	for round_cfg: Dictionary in rounds:
		_set_predicate(int(round_cfg["set"]), true)
		var advanced := _machine.advance_check(int(round_cfg["week"]))
		assert_eq(
			advanced,
			(round_cfg["expect"] as Array).duplicate(),
			"轮次点亮步序（谓词序=%d）" % int(round_cfg["set"]),
		)
		for idx: int in advanced:
			emitted_indices.append(idx)
	# 信号载荷与扫描序一致（顺序性由 advance_check 载荷升序+逐轮断言保证）
	assert_signal_emit_count(_machine, "step_advanced", 6, "六步各发一次 step_advanced")
	for i: int in emitted_indices.size():
		var params: Array = get_signal_parameters(_machine, "step_advanced", i)
		assert_eq(
			int(params[0]["step_index"]),
			emitted_indices[i],
			"载荷 step_index 与点亮顺序一致（第 %d 次）" % i,
		)
		assert_eq(str(params[0]["goal_key"]), "onb_goal_%d" % (emitted_indices[i] + 1))
	# 六步全亮 → 链完成信号恰一次
	assert_signal_emitted(_machine, "chain_completed", "六步全点亮触发链完成")
	assert_signal_emit_count(_machine, "chain_completed", 1)
	assert_eq(_machine.get_progress()["all_done"], true)


func test_onboarding_steps_skip_does_not_block() -> void:
	watch_signals(_machine)
	# 跳步不阻塞：前四步永假（玩家绕行/未达成），后两步照常点亮（升序）
	_set_predicate(4, true)
	_set_predicate(5, true)
	var advanced := _machine.advance_check(10)
	assert_eq(advanced, [4, 5], "前四步 pending 不阻塞后两步点亮（升序）")
	assert_signal_emit_count(_machine, "onboarding_error", 0, "谓词未达成≠错误态")
	assert_eq(_machine.get_progress()["all_done"], false, "未跳过时链不误报完成")
	# 错误态兜底：skip_current 显式跳过卡住步 → error 上报 + 步点亮 + 链闭环
	for i: int in 4:
		assert_true(_machine.skip_current(10), "跳过卡住步（第 %d 次）" % (i + 1))
	assert_eq(_machine.get_progress()["all_done"], true, "四步跳过后链完成")
	assert_signal_emit_count(_machine, "onboarding_error", 4, "每次跳过一次上报")
	# 谓词故障：返回非 bool → error 上报 + 该步当轮未达成，后续步照常
	var faulty := TutorialMachine.new()
	watch_signals(faulty)
	faulty.is_task_started = func() -> Variant: return "not_a_bool"
	var rest: Array[int] = faulty.advance_check(1)
	assert_eq(rest, [], "谓词故障步不点亮")
	var params: Array = get_signal_parameters(faulty, "onboarding_error", 0)
	assert_eq(str(params[0]["reason"]), "predicate_not_bool", "错误面携带原因")
	faulty.is_tree_lit = func() -> bool: return true
	var after_fault: Array[int] = faulty.advance_check(3)
	assert_eq(after_fault, [1], "故障步不阻塞后续步（跳过不阻塞世界）")


## ---------- 验收点 2：目标卡"约再跑 X 周"与周结/周报同周号一致 ----------


func test_goal_card_week_hint_matches_clock() -> void:
	var card := GoalCard.new(_machine)
	# W1：接单即刻（hint=0，"就这一两天"口径）
	var view_w1 := card.get_goal_card_view(1)
	assert_eq(int(view_w1["step_index"]), 0, "W1 当前步=接单")
	assert_eq(int(view_w1["weeks_hint"]), 0, "接单预期 W1 → hint=0")
	assert_eq(str(view_w1["stage"]), GoalCard.STAGE_ONBOARDING)
	# W2：接单仍未达成（预期 W1 已过）→ hint 下限 0（"就这一两天"）
	assert_eq(int(card.get_goal_card_view(2)["weeks_hint"]), 0)
	# W3：lit 与影响力结算周（节拍：研究 W1 启动 +2 周、首任务 +2 周结算）
	_set_predicate(0, true)
	_machine.advance_check(1)
	_set_predicate(1, true)
	_set_predicate(2, true)
	var advanced := _machine.advance_check(3)
	assert_eq(advanced, [1, 2], "W3 同周点亮 lit+影响力（结算同周）")
	# W4：排训练（结算次周）；当前步=出分，预期 W8 → hint=4
	_set_predicate(3, true)
	_machine.advance_check(4)
	var view_w4 := card.get_goal_card_view(4)
	assert_eq(str(view_w4["step_id"]), "first_score", "W4 当前步=出分")
	assert_eq(int(view_w4["weeks_hint"]), 4, "W4 视角出分还差 4 周")
	assert_eq(int(card.get_goal_card_view(5)["weeks_hint"]), 3, "W5 → 3 周")
	# W8：出分并命名（命名=达成谓词；平庸分同口径，见 fail_no_punish）
	_set_predicate(4, true)
	_machine.advance_check(8)
	var view_w8 := card.get_goal_card_view(8)
	assert_eq(str(view_w8["step_id"]), "first_rival", "W8 当前步=首对手")
	assert_eq(int(view_w8["weeks_hint"]), 2, "W8 视角首对手还差 2 周")
	# W10：首对手 → 全完成空态
	_set_predicate(5, true)
	_machine.advance_check(10)
	var view_done := card.get_goal_card_view(10)
	assert_eq(bool(view_done["all_done"]), true)
	assert_eq(str(view_done["goal_key"]), "", "全完成=空态键")
	# 进度点视图（6 点条数据面）：completed_count 单调递增至 6
	var progress := card.get_progress_view()
	assert_eq(int(progress["completed_count"]), 6)
	assert_eq(int(progress["total"]), 6)


## ---------- 验收点 3：教学节拍三护栏 + 跨表镜像 ----------


func test_first_loop_cadence_weeks() -> void:
	var card := GoalCard.new(_machine)
	var expected := card.get_expected_weeks()
	# 护栏 1：首节点 lit ∈ [W2, W4]
	assert_between(expected[1], 2, 4, "首节点 lit 周 ∈[W2,W4]（实际 W%d）" % expected[1])
	# 护栏 2：首训出分 ≤ W10
	assert_lt(expected[4], 11, "首训出分周 ≤W10（实际 W%d）" % expected[4])
	# 护栏 3：首对手 ≥ 首训出分 +2 周
	assert_gte(expected[5], expected[4] + 2, "首对手 ≥ 出分+2 周（先出分再守卫）")
	# 跨表镜像断言（onboarding.json 镜像键 == 权威表真值，防双源漂移）
	var onb := DataLoader.load_json(ONBOARDING_PATH)
	var papers := DataLoader.load_json(PAPERS_PATH)
	var tree := DataLoader.load_json(TREE_PATH)
	var models := DataLoader.load_json(MODELS_PATH)
	var rivals := DataLoader.load_json(RIVALS_PATH)
	assert_eq(
		int(onb["onb_first_task_duration"]),
		int(((papers["paper_duration_weeks"] as Dictionary)["repro"] as Dictionary)["min"]),
		"首任务时长镜像=papers.json repro.min",
	)
	assert_eq(
		int(onb["onb_first_node_duration"]),
		int((tree["tree_research_weeks"] as Dictionary)["shallow"]),
		"首节点研究时长镜像=tree_research_weeks.shallow",
	)
	var first_base := _first_unlocked_base(models)
	assert_eq(
		int(onb["onb_first_train_duration"]),
		int((first_base as Dictionary)["duration_weeks"]),
		"首训时长镜像=models.json 首个可训基座 duration_weeks",
	)
	var deep_alley: Dictionary = (
		((rivals["rival_actors"] as Dictionary)["deep_alley"]) as Dictionary
	)
	var first_action: Dictionary = (deep_alley["timeline"] as Array)[0]
	assert_eq(
		int(onb["onb_first_rival_week"]),
		int(first_action["week"]),
		"首对手周镜像=rivals.json 深巷 timeline 首行周",
	)
	# 节拍日历错峰：首对手周不与季度大赏同周（time_ritual_no_overlap）
	var time_table := DataLoader.load_json(TIME_PATH)
	var award_weeks: Array = (
		(time_table["time_ritual_no_overlap"] as Dictionary)["quarter_award_weeks"] as Array
	)
	assert_false(
		award_weeks.has(int(onb["onb_first_rival_week"])),
		"首对手周 ∉ 季度大赏周（错峰）",
	)


## ---------- 验收点 4：失败不惩罚 ----------


func test_fail_no_punish() -> void:
	watch_signals(_machine)
	var card := GoalCard.new(_machine)
	# 前四步达成（引导期正常推进）
	for i: int in 4:
		_set_predicate(i, true)
	_machine.advance_check(4)
	# 首模型平庸出分：无 SOTA 破纪录、无惩罚信号域——出分命名谓词照常达成
	# （L2 装配方口径：命名完成即达成，分数不进谓词；失败语属 L3 文案域，
	# 本断言锁 L2 数据面：step 推进链无 error/failure 类信号发射）
	_set_predicate(4, true)
	var advanced := _machine.advance_check(8)
	assert_eq(advanced, [4], "平庸出分+命名=正常点亮（无失败分支）")
	assert_signal_emit_count(_machine, "onboarding_error", 0, "全程零错误信号")
	assert_signal_emit_count(_machine, "chain_completed", 0, "链未完成（还剩首对手）")
	# 目标卡仍指向下一步（迎战首个对手），不回退不阻塞
	var view := card.get_goal_card_view(8)
	assert_eq(str(view["step_id"]), "first_rival", "目标卡翻新指向下一步")
	assert_eq(str(view["goal_key"]), "onb_goal_6")
	assert_gte(int(view["weeks_hint"]), 0, "人话周提示仍在（不消失）")
	# 存档往返：引导进度可持久化（flags 开放容器设计）
	var snapshot := _machine.get_save_view()
	var restored := TutorialMachine.new()
	restored.restore_from_save(snapshot)
	assert_eq(restored.get_progress(), _machine.get_progress(), "存档往返进度一致")


## ---------- 私有辅助 ----------


## 按步序号翻真注入谓词（测试剧本驱动；与 STEP_IDS 索引对齐）
func _set_predicate(step_index: int, value: bool) -> void:
	match step_index:
		0:
			_machine.is_task_started = func() -> bool: return value
		1:
			_machine.is_tree_lit = func() -> bool: return value
		2:
			_machine.is_influence_stocked = func() -> bool: return value
		3:
			_machine.is_train_started = func() -> bool: return value
		4:
			_machine.is_score_named = func() -> bool: return value
		5:
			_machine.is_rival_arrived = func() -> bool: return value


## models.json 首个可训基座（_order 遍历首个 unlock_node 空；与装配侧口径同源）
func _first_unlocked_base(models: Dictionary) -> Dictionary:
	var bases: Dictionary = models["model_bases"]
	for key: Variant in bases["_order"] as Array:
		var row: Dictionary = bases[str(key)]
		if str(row.get("unlock_node", "")).is_empty():
			return row
	return {}
