class_name TestTrainingAndSota
extends GutTest

## PR6 (issue #12) 训练出分、SOTA 判定与命名通路专项测试
## 覆盖 issue #12 验收点：
## 1. 公式边界向量断言（eff=0/m 档位边界/sigmoid 端点）
## 2. sigmoid 真值断言：A=80→24.0 / 95→50.0 / 110→76.0（k=13；旧示例作废）
## 3. 平局+首冠分支断言（严格大于/平局归霸主/仅周结判定）
## 4. 命名注入样例+敏感词拒绝+跳过默认名池确定性轮转断言（游标入 flags 零 RNG）
## 5. research_eff=0 不可训练断言

var _world: GameWorld
var _params: Dictionary


func before_each() -> void:
	_world = GameWorld.new()
	_world.start_new_game(42)
	# 出分参数真源 = benchmarks.json（批 0 数据化后 ScoreMath 零数值字面量）
	var benchmarks := DataLoader.load_json("res://src/data/benchmarks.json")
	_params = ScoreMath.normalize_params(benchmarks[GameWorld.BENCHMARK_KEY])


func test_acceptance_point_1_formula_boundary_vectors() -> void:
	# [T] 验收点 1：公式边界向量断言（eff=0 / m 档位边界 / sigmoid 端点）
	# 1. eff=0 边界
	var a_eff0: float = ScoreMath.calculate_ability(0, 0.0, 1, 0.55, _params)
	# A = ability_scale * (1+0)^e_eff * (1+0)^e_tech * m(1) * q = 4 * 1 * 1 * 0.6 * 0.55 = 1.32
	assert_almost_eq(a_eff0, 1.32, 0.01, "eff=0 边界计算正确")

	# 2. m(compute_tier) 四档乘子边界 [0.6, 0.75, 0.9, 1.05]（数据键驱动）
	assert_eq(ScoreMath.get_compute_multiplier(_params, 1), 0.6)
	assert_eq(ScoreMath.get_compute_multiplier(_params, 2), 0.75)
	assert_eq(ScoreMath.get_compute_multiplier(_params, 3), 0.9)
	assert_eq(ScoreMath.get_compute_multiplier(_params, 4), 1.05)

	# 3. sigmoid 端点（防越界溢出）：超高值逼近 100，极低值逼近 0
	var s_high: float = ScoreMath.calculate_score(1000.0, _params)
	assert_eq(s_high, 100.0, "超高能力值分数为 100")
	var s_low: float = ScoreMath.calculate_score(-1000.0, _params)
	assert_eq(s_low, 0.0, "极低能力值分数为 0")


func test_acceptance_point_2_sigmoid_truth_values() -> void:
	# [T] 验收点 2：sigmoid 真值断言（theta/k 来自 benchmarks.json：95/13）
	# A=80 -> 24.0 / 95 -> 50.0 / 110 -> 76.0
	var s_80: float = ScoreMath.calculate_score(80.0, _params)
	assert_almost_eq(s_80, 24.0, 0.1, "A=80 时 score 必须精确为 24.0")

	var s_95: float = ScoreMath.calculate_score(95.0, _params)
	assert_almost_eq(s_95, 50.0, 0.1, "A=95 时 score 必须精确为 50.0")

	var s_110: float = ScoreMath.calculate_score(110.0, _params)
	assert_almost_eq(s_110, 76.0, 0.1, "A=110 时 score 必须精确为 76.0")


func test_acceptance_point_3_sota_board_tie_and_strict_greater() -> void:
	# [T] 验收点 3：平局+首冠分支断言（严格大于/平局归霸主）
	var board := SotaBoard.new()
	board.setup({"rival_best": 50.0, "rival_model_name": "灵犀 Chat"})

	assert_eq(board.get_best_score(), 50.0)
	assert_eq(board.get_best_model(), "灵犀 Chat")

	# 1. 低于霸主：拒绝刷新
	var broken_low: bool = board.submit_score("劣质模型", 48.0)
	assert_false(broken_low, "低于霸主拒绝刷新")
	assert_eq(board.get_best_score(), 50.0)

	# 2. 平局：严格平局归霸主，拒绝刷新！
	var broken_tie: bool = board.submit_score("平局模型", 50.0)
	assert_false(broken_tie, "平局归霸主，拒绝刷新！")
	assert_eq(board.get_best_model(), "灵犀 Chat")

	# 3. 严格大于：成功刷新纪录，成为新霸主
	watch_signals(board)
	var broken_high: bool = board.submit_score("卓越 1 号", 50.1)
	assert_true(broken_high, "严格大于成功登顶")
	assert_eq(board.get_best_score(), 50.1)
	assert_eq(board.get_best_model(), "卓越 1 号")
	assert_signal_emitted(board, "sota_record_broken", "发射纪录打破信号")


func test_acceptance_point_4_naming_pipeline_and_safety() -> void:
	# [T] 验收点 4：命名注入样例+敏感词拒绝+跳过默认名池确定性轮转断言
	watch_signals(_world)

	# 1. 敏感词拒绝（如 ChatGPT, 灵犀 等敏感词）
	_world.submit_model_name("ChatGPT")
	assert_eq(_world.model_name, "", "敏感词命名必须拒绝")

	# 2. 正常命名与单大括号防注入转义（将 {week} 转义为 {{week}}）
	# 注意：Unicode 白名单需符合 [0-9A-Za-z_一-鿿]+，输入带大括号不能在白名单前被毙
	_world.submit_model_name("星辰AI")
	assert_eq(_world.model_name, "星辰AI", "合法命名成功")

	# 单大括号转义单独验证（输入含 {week} 时防注入）
	_world.submit_model_name("模型_{week}")
	assert_eq(_world.model_name, "模型_{{week}}", "单大括号转义防二次解析")

	# 3. 空白/跳过命名：从默认名池确定性轮转，游标自增
	var cursor_before: int = _world._named_cursor
	_world.submit_model_name("")
	assert_false(_world.model_name.is_empty(), "跳过命名应从名池自动分配")
	assert_eq(_world._named_cursor, cursor_before + 1, "游标自增，零 RNG")


func test_acceptance_point_5_zero_research_eff_rejection() -> void:
	# [T] 验收点 5：research_eff=0 不可训练断言
	assert_eq(_world.research_eff, 0, "开局未分配训练位，research_eff=0")

	# 尝试启动训练
	_world.start_training("base_pushi_1b")
	assert_false(_world.training.is_training(), "research_eff=0 时必须拒绝启动训练")

	# 分配员工入训练位
	_world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	assert_true(_world.research_eff > 0, "分配后 research_eff > 0")

	# 启动训练成功
	_world.start_training("base_pushi_1b")
	assert_true(_world.training.is_training(), "research_eff > 0 允许启动训练")
