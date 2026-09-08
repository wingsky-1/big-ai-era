extends GutTest

## GameWorld 骨架测试（issue #5 / PR3 后半）：
## 命令-信号契约对账（B1）、快照一致性（GW6）、开局字段（GW8）、
## 带卡不结周、GW3 同帧应答、万周模拟性能与确定性（M6）、存档 roundtrip。

const START_GAME_TIMEOUT: float = 5.0

var _world: GameWorld
var _emitted: Dictionary = {}


func before_each() -> void:
	_world = GameWorld.new()
	autofree(_world)
	_emitted = {}
	_world.resources_changed.connect(_rec3.bind(&"resources_changed"))
	_world.task_state_changed.connect(_rec2.bind(&"task_state_changed"))
	for one_arg_signal: StringName in [
		&"week_settled",
		&"decision_pending",
		&"sota_updated",
		&"fog_changed",
		&"stage_advanced",
		&"model_named",
		&"game_over",
		&"toast_queued",
		&"progress_ticked",
	]:
		_world.connect(one_arg_signal, _rec1.bind(one_arg_signal))
	_world.start_new_game(12345)


func _rec1(a: Variant, signal_name: StringName) -> void:
	_push(signal_name, [a])


func _rec2(a: Variant, b: Variant, signal_name: StringName) -> void:
	_push(signal_name, [a, b])


func _rec3(a: Variant, b: Variant, c: Variant, signal_name: StringName) -> void:
	_push(signal_name, [a, b, c])


func _push(signal_name: StringName, args: Array) -> void:
	if not _emitted.has(signal_name):
		_emitted[signal_name] = []
	(_emitted[signal_name] as Array).append(args)


func _poured(name_string: String) -> Array:
	return _emitted.get(name_string, [])


func test_command_and_signal_contract_accounting() -> void:
	# 12 命令+11 信号对账（v1.1 §B / DR-026 / 批 1c 买卡命令）：方法存在+信号声明+清单一致。
	for command: String in GameWorld.CONTRACT_COMMANDS:
		assert_true(_world.has_method(command), "GameWorld 应有命令 %s" % command)
	for signal_name: String in GameWorld.CONTRACT_SIGNALS:
		assert_true(_world.has_signal(signal_name), "GameWorld 应声明信号 %s" % signal_name)
	assert_eq(GameWorld.CONTRACT_COMMANDS.size(), 12, "契约命令数=12（批 1c 加买卡命令）")
	assert_eq(GameWorld.CONTRACT_SIGNALS.size(), 11, "契约信号数=11")
	assert_true(GameWorld.CONTRACT_SIGNALS.has("progress_ticked"), "progress_ticked（M7）应在契约")


func test_start_new_game_opening_fields() -> void:
	# 开局口径硬锚（issue #1 / 预演报告）：资金 50k；W0；三研究员；灵犀 Chat 已发布。
	assert_eq(_world.week, 0, "开局应为 W0")
	assert_eq(_world.get_money(), 50000, "开局资金应为 50k（口径硬锚）")
	assert_eq(_world.staff.size(), 3, "开局应有三研究员（ST1 种子表）")
	assert_gt(_world.rival_best, 0.0, "竞对基线分应已就位（灵犀 Chat 已发布）")
	var poured := _poured("sota_updated")
	assert_eq(poured.size(), 1, "开局应发一次 sota_updated（W0 假头条）")
	assert_string_contains(str(poured[0][0].get("model", "")), "灵犀", "假头条应为灵犀 Chat")
	assert_true(bool(poured[0][0].get("rival")), "W0 头条应标记为竞对纪录")


func test_ui_snapshot_matches_signal_terminal_state() -> void:
	# 快照=信号终态一致（GW6）：资源/周数/暂停三处双通道对账。
	_world.set_paused(true)
	_world.settle_week()
	_world.settle_week()
	var snapshot := _world.get_ui_snapshot()
	assert_eq(int(snapshot["week"]), 2, "快照周数应等于信号终态")
	assert_eq(int(snapshot["resources"]["money"]), _world.get_money(), "快照资金应与世界一致")
	assert_eq(
		int(snapshot["resources"]["money"]),
		int(_poured("resources_changed").back()[0]),
		"快照资金应等于最后一次 resources_changed 广播值"
	)
	assert_eq(bool(snapshot["user_paused"]), true, "快照暂停态应与世界一致")
	assert_eq(int(snapshot["staff"].size()), 3, "快照应含名册")


func test_snapshot_has_no_rng_or_flags_leak() -> void:
	# 快照不含 rng 计数器与 flags 全量（v1.1 §B 防误用约定）。
	var snapshot := _world.get_ui_snapshot()
	assert_false(snapshot.has("rng"), "快照不应含 rng")
	assert_false(snapshot.has("flags"), "快照不应含 flags")


func test_pending_card_blocks_week_settlement() -> void:
	# 带卡不结周（M1）：pending 非空时 advance 不跨周、无周结信号。
	_world.set_pending_decision({"pending_id": "p1", "options": [{"idx": 0}, {"idx": 1}]})
	var settled_count := _poured("week_settled").size()
	_world.simulate_weeks(3)  # 无策略注入：卡不消费，模拟停摆
	assert_eq(_world.week, 0, "带卡期间不应跨周")
	assert_eq(_poured("week_settled").size(), settled_count, "带卡期间不应发周结信号")
	assert_true(_world.clock.paused, "带卡应合成 paused（双源 OR）")


func test_auto_decision_policy_resolves_same_frame() -> void:
	# GW3：注入策略后同帧应答，模拟继续推进。
	_world.set_pending_decision({"pending_id": "p1", "options": [{"idx": 0}]})
	var policy := AutoDecisionPolicy.new()
	var reports := _world.simulate_weeks(2, policy)
	assert_eq(_world.pending_decision, {}, "策略应同帧消费决策卡")
	assert_eq(_world.week, 2, "应答后模拟应正常推进")
	assert_eq(reports.size(), 2, "应返回逐周报告")


func test_ten_thousand_week_simulation_deterministic_and_fast() -> void:
	# M6：万周纯步进防呆限时 + 同 seed 双跑哈希一致（verify.sh 内嵌，nightly 复用）。
	var digest_a := _run_thousand_week_digest()
	var digest_b := _run_thousand_week_digest()
	assert_eq(digest_a, digest_b, "同 seed 双跑状态摘要应一致（确定性）")
	var start_time: float = Time.get_ticks_msec() as float
	# 批 1a：经营收入只来自占槽任务结算 → 万周回归需持续接任务（否则 290 周内破产）
	var tasks := AutoTaskPolicy.new()
	var policy := AutoDecisionPolicy.new()
	var reports: Array[Dictionary] = []
	for i: int in range(10000):
		tasks.fill(_world)
		reports.append_array(_world.simulate_weeks(1, policy))
	assert_eq(_world.week, 10000, "万周模拟应完整推进")
	assert_eq(reports.size(), 10000, "逐周报告应完整")
	# 30s 防呆线：本地实测 ~10s；曾因自测残留 Chrome 抢 CPU 触发 15s 线 flaky，
	# 性能真门禁是哈希确定性与 nightly 蒙卡，此处只拦截量级劣化。
	assert_lt((Time.get_ticks_msec() as float) - start_time, 30000.0, "万周纯步进用时应合理")


func _run_thousand_week_digest() -> String:
	var fresh := GameWorld.new()
	autofree(fresh)
	fresh.start_new_game(42)
	var tasks := AutoTaskPolicy.new()
	var policy := AutoDecisionPolicy.new()
	for i: int in range(1000):
		tasks.fill(fresh)
		fresh.simulate_weeks(1, policy)
	return SnapshotCodec.state_digest(fresh)


func test_save_and_restore_roundtrip() -> void:
	# 存档机制闭环：request_save → 全新世界 restore → 快照渲染一致。
	_world.settle_week()
	_world.submit_model_name("逐光")
	_world.set_paused(true)
	assert_true(_world.request_save("test"), "存档应成功（SaveSystem 唯一写入口）")
	var loaded := SaveSystem.load_game()
	assert_eq(int(loaded.get("week")), 1, "读档周数应一致")
	assert_true(loaded.has("player_model_names"), "存档应含命名纪录")
	var fresh := GameWorld.new()
	autofree(fresh)
	fresh.restore(loaded)
	assert_eq(fresh.week, _world.week, "恢复后周数应一致")
	assert_eq(fresh.model_name, "逐光", "恢复后命名应一致")
	assert_eq(
		fresh.get_ui_snapshot()["resources"]["money"],
		_world.get_ui_snapshot()["resources"]["money"],
		"恢复后快照应与原世界一致"
	)


func test_set_paused_blocked_state_defense() -> void:
	# Q4 防御第一半：带卡期间请求解除暂停被拒。
	_world.set_pending_decision({"pending_id": "p1", "options": [{"idx": 0}]})
	_world.set_paused(true)
	assert_true(_world.user_paused, "用户暂停应生效")
	_world.set_paused(false)
	assert_true(_world.user_paused, "带卡期间解除请求应被拒（Q4）")
	_world.set_pending_decision({})
	_world.set_paused(false)
	assert_false(_world.user_paused, "卡清空后可解除")


func test_week_counter_consistency_with_clock() -> void:
	# 权威周数（world.week）与触发器内部计数（clock.week）一致性锁定。
	_world.simulate_weeks(5)
	assert_eq(_world.week, _world.clock.week, "双周计数应一致（漂移=周结序 bug）")
