extends GutTest

## #79（v0.1.5）饱和护栏 + θ/k 参数通路专项测试（DR-031/B1、需求 §8 RS-04/05/06）。
## 覆盖 3 个 [T] 验收点 + RS-06 元数据：
## 1. test_saturation_first99_week —— 首达 99 分周次 ≥ benchmarks.saturation.first99_week_min（~50）
## 2. test_score_params_injectable_from_data —— stages.json 可选键 score_params 可注入 θ/k（改表即改映射）
## 3. test_score_monotonic_across_stages —— 跨阶段同一 A 分数不倒退（阶段化前的安全边界）
## 4. test_saturation_trigger_metadata_present —— RS-06 透明化元数据 + tier2/非深渊基座永不饱和实算
##
## 饱和口径（纪要 §2.4 实算）：score=99 ⇔ A ≥ θ + k·ln99 = 154.74（θ95/k13）；
## 饱和旋钮 = tier3+ × 深渊 q=1.0 × 3 人上桌（eff=187）——tier3 时 tb=0 即 97.1 分、
## tb ≥ 0.3748 即 99 分（= 成本升序第 6 个节点，累计 3310 RP）。
##
## 路径披露（issue #79 实施提示 ①②）：本用例同时跑「真跑」与「进度上界路径」两条，
## 均断言 ≥ first99_week_min。实测（seed=79，真表，无任何夹具）：
##   真跑 = 事件 RP 供给原样（当前 main）W61；事件 rp_grant 归零（模拟 #75 闸后）W109；
##   上界路径 = 任务池单槽 RP 供给口径 W89。
## 注：若改用「资金夹具（+50 万）+ 只挑最高 RP 任务」的极限配置，当前未闸的事件 RP 会把
## 首达提前到 ~W45——该配置不是真实经营（资金由 #80 窗口负责），故不作为断言路径。

const BENCHMARKS_PATH: String = "res://src/data/benchmarks.json"
const STAGES_PATH: String = "res://src/data/stages.json"
const TECHS_PATH: String = "res://src/data/techs.json"
const BASES_PATH: String = "res://src/data/model_bases.json"
const TASKS_PATH: String = "res://src/data/tasks.json"
const STAFF_PATH: String = "res://src/data/staff.json"
const ECONOMY_PATH: String = "res://src/data/economy.json"

## 饱和护栏下界（与 benchmarks.json 的 saturation.first99_week_min 必须一致）。
const FIRST99_WEEK_MIN: int = 50
## 单局长度（纪要 §十二：一局 160 周 ≈ 26.7 分钟）。
const HORIZON_WEEKS: int = 160
const SEED: int = 79
## tier2 档位号（纪要 §2.4「tier2 永不饱和」口径）。
const TIER2: int = 2
## 任务配比安全垫（周固定工资倍数）：低于该垫子改接现金流任务（先攒钱、再点树）。
const CUSHION_WEEKS: int = 20
## 测试夹具资金（TrainingProject 启动训练的资金门槛，与数值平衡无关）。
const FIXTURE_MONEY: int = 1000000


func test_saturation_first99_week() -> void:
	# [T] 验收点 1：首达 99 分周次 ≥~50（实算现状 W54，纪要 §2.4）。
	var benchmarks: Dictionary = DataLoader.load_json(BENCHMARKS_PATH)
	var saturation: Dictionary = benchmarks.get("saturation", {})
	assert_false(saturation.is_empty(), "benchmarks.json 应含 saturation 元数据块")
	var threshold: float = float(saturation.get("score_threshold", 0.0))
	var week_min: int = int(saturation.get("first99_week_min", 0))
	assert_gt(threshold, 0.0, "饱和阈值应由数据表提供")
	assert_gt(week_min, 0, "first99_week_min 应由数据表提供")

	# 路径 A（真跑）：真 GameWorld（无夹具：真实经济/事件/迷雾前置门）+ 标准策略
	# （3 人上桌 / 升到深渊所需 tier / 成本升序点树 / 先攒钱再点树配比接任务），
	# 逐周复算「当前状态可出的最高分」。
	var real_week: int = _real_run_first99_week(threshold)
	gut.p("[真跑] 首达 %.1f 分周次 = W%d（seed=%d）" % [threshold, real_week, SEED])
	assert_gt(real_week, 0, "160 周内应出现首达饱和分数的周次（否则护栏失去意义）")
	assert_gte(real_week, week_min, "真跑首达饱和分数周次应 ≥ %d（实测 W%d）" % [week_min, real_week])

	# 路径 B（进度上界路径，issue #79 实施提示 ②）：真表 Σtb 曲线 + 满配 eff/tier/q +
	# 任务池 RP 供给上界逐周推进，求首达饱和分数的周次（= 饱和周次下界）。
	# 供给口径：tasks.json enabled 任务的 max(rp_output/duration_weeks)（§2.9：RP 唯一来源 = 任务 rp_output；
	# 事件 rp_grant 供给属并行窗口 #75，本路径不纳入）。
	var bound_week: int = _upper_bound_first99_week(threshold)
	gut.p("[上界路径] 首达 %.1f 分周次 = W%d" % [threshold, bound_week])
	assert_gt(bound_week, 0, "上界路径应能触达饱和分数")
	assert_gte(bound_week, week_min, "上界路径首达饱和分数周次应 ≥ %d（实测 W%d）" % [week_min, bound_week])


func test_score_params_injectable_from_data() -> void:
	# [T] 验收点 2：θ/k 参数通路可注入（改数据表即改分数映射；v1.0 真表零数值变更）。
	var benchmarks: Dictionary = DataLoader.load_json(BENCHMARKS_PATH)
	var base: Dictionary = ScoreMath.normalize_params(benchmarks[GameWorld.BENCHMARK_KEY])
	assert_false(base.is_empty(), "基准出分参数应从 benchmarks.json 规范化成功")

	# 1. 真表零数值变更：现有阶段行均未写入会让分数变化的覆盖值 → 合并结果逐值等于基准
	var stages_cfg: Dictionary = DataLoader.load_json(STAGES_PATH)
	for stage_key: String in stages_cfg["stages"]:
		var merged: Dictionary = ScoreMath.merge_stage_params(base, stages_cfg["stages"][stage_key])
		assert_false(merged.is_empty(), "%s 合并参数应有效" % stage_key)
		_assert_params_equal(merged, base, "%s 无覆盖值时应逐值等于基准（v1.0 零数值变更）" % stage_key)

	# 2. 缺键沿用基准：只覆盖 θ / 只覆盖 k
	var theta_only: Dictionary = ScoreMath.merge_stage_params(
		base, {"score_params": {"theta": 150.0}}
	)
	assert_eq(float(theta_only["theta"]), 150.0, "θ 覆盖生效")
	assert_eq(float(theta_only["k"]), float(base["k"]), "未覆盖的 k 沿用基准")
	var k_only: Dictionary = ScoreMath.merge_stage_params(base, {"score_params": {"k": 18.0}})
	assert_eq(float(k_only["k"]), 18.0, "k 覆盖生效")
	assert_eq(float(k_only["theta"]), float(base["theta"]), "未覆盖的 θ 沿用基准")

	# 3. 改数据表即改分数映射（同一 A 分数随 θ/k 变化）
	var ability: float = 100.0
	var base_score: float = ScoreMath.calculate_score(ability, base)
	var theta_up: Dictionary = ScoreMath.merge_stage_params(
		base, {"score_params": {"theta": 150.0}}
	)
	assert_lt(ScoreMath.calculate_score(ability, theta_up), base_score, "θ↑ ⇒ 同一 A 分数下降（改表即改映射）")
	var theta_down: Dictionary = ScoreMath.merge_stage_params(
		base, {"score_params": {"theta": 85.0}}
	)
	assert_gt(ScoreMath.calculate_score(ability, theta_down), base_score, "θ↓ ⇒ 同一 A 分数上升（改表即改映射）")
	var k_up: Dictionary = ScoreMath.merge_stage_params(base, {"score_params": {"k": 26.0}})
	assert_lt(
		ScoreMath.calculate_score(ability, k_up), base_score, "A>θ 时 k↑ ⇒ 分数向 50 回落（心跳变缓，改表即改映射）"
	)
	var low_ability: float = 80.0
	assert_gt(
		ScoreMath.calculate_score(low_ability, k_up),
		ScoreMath.calculate_score(low_ability, base),
		"A<θ 时 k↑ ⇒ 分数向 50 抬升（改表即改映射）"
	)
	var both: Dictionary = ScoreMath.merge_stage_params(
		base, {"score_params": {"theta": 220.0, "k": 25.0}}
	)
	assert_eq(float(both["theta"]), 220.0, "两者同时覆盖：θ 生效")
	assert_eq(float(both["k"]), 25.0, "两者同时覆盖：k 生效")
	# 覆盖只作用于白名单键（K/m/score_max… 仍来自基准）
	assert_eq(float(both["ability_scale"]), float(base["ability_scale"]), "覆盖不改 K")
	assert_eq(float(both["score_max"]), float(base["score_max"]), "覆盖不改 score_max")
	assert_eq(
		(both["compute_multipliers"] as Dictionary).size(),
		(base["compute_multipliers"] as Dictionary).size(),
		"覆盖不改 m 表键数"
	)

	# 4. 空覆盖 / 缺键：等价于基准
	var empty_override: Dictionary = ScoreMath.merge_stage_params(base, {"score_params": {}})
	_assert_params_equal(empty_override, base, "空覆盖等价于基准")
	var no_key: Dictionary = ScoreMath.merge_stage_params(base, {})
	_assert_params_equal(no_key, base, "缺 score_params 键等价于基准")

	# 5. 非法覆盖熔断（零默认值纪律：push_error + 返回空字典）
	assert_true(
		ScoreMath.merge_stage_params(base, {"score_params": 95.0}).is_empty(),
		"score_params 非字典应熔断返回 {}"
	)
	assert_push_error("score_params 必须是字典", "非字典应 push_error")
	assert_true(
		ScoreMath.merge_stage_params(base, {"score_params": {"score_max": 120.0}}).is_empty(),
		"非白名单键应熔断返回 {}"
	)
	assert_push_error("非法覆盖键", "非白名单键应 push_error")
	assert_true(
		ScoreMath.merge_stage_params(base, {"score_params": {"theta": "高"}}).is_empty(),
		"θ 非数值应熔断返回 {}"
	)
	assert_push_error("必须为数值", "非数值应 push_error")
	assert_true(
		ScoreMath.merge_stage_params(base, {"score_params": {"k": 0.0}}).is_empty(), "k=0 应熔断返回 {}"
	)
	assert_push_error("k 不得为 0", "k=0 应 push_error")
	assert_true(
		ScoreMath.merge_stage_params({}, {"score_params": {"theta": 1.0}}).is_empty(),
		"基准参数为空应熔断返回 {}"
	)
	assert_push_error("基准出分参数为空", "基准为空应 push_error")

	# 6. L2 消费链路：TrainingProject 注入覆盖参数 → 同一次训练出分随数据表变化（非仅纯函数）
	var bases: Dictionary = DataLoader.load_json(BASES_PATH)
	var best_base_id: String = _highest_quality_base_id(bases)
	var baseline_score: float = _training_completed_score(bases, best_base_id, base)
	var overridden_score: float = _training_completed_score(bases, best_base_id, both)
	assert_gt(baseline_score, overridden_score, "注入阶段覆盖后同一次训练出分应随数据表变化")
	assert_almost_eq(
		overridden_score,
		ScoreMath.calculate_score(
			ScoreMath.calculate_ability(
				_sum_staff_research(),
				_full_tree_tech_bonus(),
				int(bases[best_base_id]["min_tier"]),
				float(bases[best_base_id]["quality"]),
				both
			),
			both
		),
		0.0001,
		"出分与 ScoreMath 公式逐值一致（注入链路无旁路）"
	)

	# 7. GameWorld 注入链路：开局 = 基准；晋升到含覆盖的阶段 → 生效参数随之刷新
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	_assert_params_equal(world.get_score_params(), base, "开局生效出分参数 = 基准（真表零覆盖）")
	world.stages.setup(_staged_override_config())
	var advance: Dictionary = world.stages.reevaluate({})
	assert_true(bool(advance.get("advanced", false)), "空 gate 阶段应单步晋升")
	assert_eq(
		float(world.get_score_params()["theta"]), 220.0, "阶段晋升后 GameWorld 应刷新注入阶段覆盖 θ（改数据表即改映射）"
	)
	assert_eq(float(world.get_score_params()["k"]), 25.0, "阶段晋升后应刷新注入阶段覆盖 k")


func test_score_monotonic_across_stages() -> void:
	# [T] 验收点 3：同一 A 在不同阶段参数下分数不倒退（阶段化前的安全边界）。
	# 口径：① 任一阶段参数集下 A↑ ⇒ score↑（映射不倒挂）；
	#      ② 真表无覆盖 → 各阶段与基准逐值等值，相邻阶段同一 A 分数不降；
	#      ③ 未来覆盖（内存构造，出处纪要 §2.4 阶段 2/3）仍保持 ① 且 k>0、收敛到 score_max。
	var benchmarks: Dictionary = DataLoader.load_json(BENCHMARKS_PATH)
	var base: Dictionary = ScoreMath.normalize_params(benchmarks[GameWorld.BENCHMARK_KEY])
	var stages_cfg: Dictionary = DataLoader.load_json(STAGES_PATH)
	var ability_grid: Array[float] = _ability_grid()

	# ① + ②：真表各阶段
	for stage_key: String in stages_cfg["stages"]:
		var merged: Dictionary = ScoreMath.merge_stage_params(base, stages_cfg["stages"][stage_key])
		_assert_score_monotonic(merged, ability_grid, stage_key)
		for ability: float in ability_grid:
			assert_almost_eq(
				ScoreMath.calculate_score(ability, merged),
				ScoreMath.calculate_score(ability, base),
				0.0001,
				"%s：无覆盖时同一 A 分数应与基准等值" % stage_key
			)

	# ②：相邻阶段同一 A 分数不降（现状等值；若未来写入覆盖值使分数倒退，本断言会亮红，
	# 提示「θ/k 阶段化须同批重标本用例」——即"阶段化前的安全边界"）
	var stage_keys: Array[String] = ["stage_0", "stage_1", "stage_2"]
	for stage_index: int in range(1, stage_keys.size()):
		var previous: Dictionary = ScoreMath.merge_stage_params(
			base, stages_cfg["stages"][stage_keys[stage_index - 1]]
		)
		var current: Dictionary = ScoreMath.merge_stage_params(
			base, stages_cfg["stages"][stage_keys[stage_index]]
		)
		for ability: float in ability_grid:
			assert_gte(
				ScoreMath.calculate_score(ability, current),
				ScoreMath.calculate_score(ability, previous),
				(
					"%s → %s：同一 A=%.1f 分数不应倒退"
					% [stage_keys[stage_index - 1], stage_keys[stage_index], ability]
				)
			)

	# ③：未来阶段覆盖（v0.2 复议队列第 3 项，数值仅内存构造、不入真表）
	var future_overrides: Array[Dictionary] = [
		ScoreMath.merge_stage_params(base, {"score_params": {"theta": 150.0, "k": 18.0}}),
		ScoreMath.merge_stage_params(base, {"score_params": {"theta": 220.0, "k": 25.0}}),
	]
	for params: Dictionary in future_overrides:
		assert_false(params.is_empty(), "未来覆盖合并应有效")
		assert_gt(float(params["k"]), 0.0, "覆盖后 k 必须为正（sigmoid 分母）")
		_assert_score_monotonic(
			params,
			ability_grid,
			"未来阶段覆盖 θ=%.0f/k=%.0f" % [float(params["theta"]), float(params["k"])]
		)
		assert_almost_eq(
			ScoreMath.calculate_score(1000000000.0, params),
			float(params["score_max"]),
			0.01,
			"满配仍收敛到 score_max（防越界）"
		)


func test_saturation_trigger_metadata_present() -> void:
	# RS-06 透明化：benchmarks.json 的 saturation 元数据 + tier2/非深渊基座永不饱和实算。
	var benchmarks: Dictionary = DataLoader.load_json(BENCHMARKS_PATH)
	var saturation: Dictionary = benchmarks.get("saturation", {})
	assert_false(saturation.is_empty(), "benchmarks.json 应含 saturation 键（RS-05/06 元数据）")
	assert_eq(
		int(saturation.get("first99_week_min", 0)),
		FIRST99_WEEK_MIN,
		"first99_week_min 应与饱和护栏测试常量一致"
	)
	assert_true(
		bool(saturation.get("tier2_never_saturates", false)),
		"tier2_never_saturates 应为 true（DR-031/B1 第 3 条：tier3+ 才是饱和旋钮）"
	)
	assert_false(
		str(saturation.get("_comment", "")).is_empty(), "saturation 应注明出处（DR-029 C-4 出处纪律）"
	)

	var threshold: float = float(saturation.get("score_threshold", 0.0))
	var params: Dictionary = ScoreMath.normalize_params(benchmarks[GameWorld.BENCHMARK_KEY])
	var bases: Dictionary = DataLoader.load_json(BASES_PATH)
	var best_base_id: String = _highest_quality_base_id(bases)
	var best_quality: float = float(bases[best_base_id]["quality"])
	var eff: int = _sum_staff_research()
	var full_tb: float = _full_tree_tech_bonus()
	assert_gt(full_tb, 0.0, "满树 tb 应由 techs.json 汇总得出")

	# tier2 永不饱和：满树 tb + tier2(m) + 最高质量基座仍 < 阈值
	var tier2_score: float = ScoreMath.calculate_score(
		ScoreMath.calculate_ability(eff, full_tb, TIER2, best_quality, params), params
	)
	assert_lt(tier2_score, threshold, "tier2 + 满树 tb 仍达不到阈值（永不饱和，实测 %.2f 分）" % tier2_score)

	# 非最高质量基座（含玄冰 q=0.8）永不饱和：各自 min_tier + 满树 tb 仍 < 阈值
	for base_id: String in bases:
		if base_id == best_base_id:
			continue
		var row: Dictionary = bases[base_id]
		var score: float = ScoreMath.calculate_score(
			ScoreMath.calculate_ability(
				eff, full_tb, int(row["min_tier"]), float(row["quality"]), params
			),
			params
		)
		assert_lt(
			score,
			threshold,
			"基座 %s（q=%.2f）+ 满树 tb 仍达不到阈值（永不饱和，实测 %.2f 分）" % [base_id, float(row["quality"]), score]
		)

	# 正例：最高质量基座（深渊 q=1.0）+ tier3 + 满树 tb 必须饱和
	var peak_score: float = ScoreMath.calculate_score(
		ScoreMath.calculate_ability(
			eff, full_tb, int(bases[best_base_id]["min_tier"]), best_quality, params
		),
		params
	)
	assert_gte(
		peak_score, threshold, "深渊 q=1.0 + tier3 + 满树 tb 应达到阈值（饱和旋钮正例，实测 %.2f 分）" % peak_score
	)


## ============ 内部：真跑路径 ============


## 真 GameWorld + 标准策略逐周推进，返回首达阈值分数的周次（未达则 0）。
## 策略（issue #79 DoD）：3 人上桌（全员入训练位）+ 升到最高质量基座所需算力档 +
## 成本升序点树 + 「先攒钱、再点树」配比接任务（§2.9 结论：单槽下钱与 RP 需配比而非互斥）。
## 无任何测试夹具：真实经济、真实事件表、真实迷雾/前置门（min_week/parents 全部生效）。
func _real_run_first99_week(threshold: float) -> int:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	for staff_id: String in world.staff:
		world.assign_staff(staff_id, StaffRoster.SLOT_TRAINING)
	var techs: Dictionary = DataLoader.load_json(TECHS_PATH)
	var bases: Dictionary = DataLoader.load_json(BASES_PATH)
	var target_tier: int = int(bases[_highest_quality_base_id(bases)]["min_tier"])
	var cushion: int = _task_cushion_money()
	var policy := AutoDecisionPolicy.new()
	for _week_index: int in range(HORIZON_WEEKS):
		if int(world.economy.get_compute()["tier"]) < target_tier:
			world.upgrade_compute(target_tier)
		_research_cost_ascending(world, techs)
		_fill_task_balanced(world, cushion)
		world.simulate_weeks(1, policy)
		if world.game_over_flag:
			break
		if _potential_score(world, bases) >= threshold:
			return world.week
	return 0


## 任务配比安全垫：CUSHION_WEEKS 周固定工资（工资口径取自 economy.json × 在册人数）。
func _task_cushion_money() -> int:
	var economy_cfg: Dictionary = DataLoader.load_json(ECONOMY_PATH)
	var staff_count: int = DataLoader.load_json(STAFF_PATH).size()
	return int(economy_cfg.get("wage_per_staff", 0)) * staff_count * CUSHION_WEEKS


## 「先攒钱、再点树」任务配比（数据驱动，无硬编码任务 id）：
## 资金 > 安全垫 → 接 RP/周 最高的可接任务；否则接 收入/周 最高的可接任务。
func _fill_task_balanced(world: GameWorld, cushion: int) -> void:
	if not world.task_queue.get_active_task().is_empty():
		return
	var tasks: Dictionary = DataLoader.load_json(TASKS_PATH)
	var prefer_rp: bool = world.get_money() > cushion
	var ids: Array[String] = []
	for task_id: String in tasks:
		if bool(tasks[task_id].get("enabled", false)):
			ids.append(task_id)
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			return _task_rate(tasks[a], prefer_rp) > _task_rate(tasks[b], prefer_rp)
	)
	for task_id: String in ids:
		world.enqueue_task(task_id)
		if not world.task_queue.get_active_task().is_empty():
			return


## 任务周均速率（prefer_rp ? rp_output : income）/ duration_weeks。
func _task_rate(task_row: Dictionary, prefer_rp: bool) -> float:
	var weeks: int = int(task_row.get("duration_weeks", 0))
	if weeks <= 0:
		return 0.0
	var key: String = "rp_output" if prefer_rp else "income"
	return float(task_row.get(key, 0)) / float(weeks)


## 当前状态可出的最高分（取可达基座中质量最高者；档位/上桌人数不满足则 0 分）。
func _potential_score(world: GameWorld, bases: Dictionary) -> float:
	var tier: int = int(world.economy.get_compute()["tier"])
	var headcount: int = world.roster.get_slot_count(StaffRoster.SLOT_TRAINING)
	var quality: float = 0.0
	for base_id: String in bases:
		var row: Dictionary = bases[base_id]
		if tier >= int(row.get("min_tier", 0)) and headcount <= int(row.get("max_staff", 0)):
			quality = maxf(quality, float(row.get("quality", 0.0)))
	if quality <= 0.0:
		return 0.0
	var params: Dictionary = world.get_score_params()
	var ability: float = ScoreMath.calculate_ability(
		world.research_eff, world.tech_bonus, tier, quality, params
	)
	return ScoreMath.calculate_score(ability, params)


## 成本升序点树：把当前可研节点按 rp_cost 升序尽量点亮。
func _research_cost_ascending(world: GameWorld, techs: Dictionary) -> void:
	var nodes: Dictionary = techs.get("nodes", {})
	var states: Dictionary = world.tech_fog.get_fog_states()
	var candidates: Array[String] = []
	for node_id: String in nodes:
		if str(states.get(node_id, "")) == TechFog.STATE_RESEARCHABLE:
			candidates.append(node_id)
	candidates.sort_custom(
		func(a: String, b: String) -> bool:
			return int(nodes[a]["rp_cost"]) < int(nodes[b]["rp_cost"])
	)
	for node_id: String in candidates:
		world.start_research(node_id)


## ============ 内部：进度上界路径 ============


## 进度上界路径（issue #79 实施提示 ②）：忽略迷雾/资金/在训等约束，只按「任务池单槽 RP
## 供给上界」逐周推进成本升序点树，逐周复算 A→score，返回首达阈值分数的周次。
## 该周次是饱和周次的下界（真实路径只会更晚），故可作为「不得早于 ~W50」的护栏。
func _upper_bound_first99_week(threshold: float) -> int:
	var benchmarks: Dictionary = DataLoader.load_json(BENCHMARKS_PATH)
	var params: Dictionary = ScoreMath.normalize_params(benchmarks[GameWorld.BENCHMARK_KEY])
	var bases: Dictionary = DataLoader.load_json(BASES_PATH)
	var best_base_id: String = _highest_quality_base_id(bases)
	var best_base: Dictionary = bases[best_base_id]
	var eff: int = _sum_staff_research()
	var tier: int = int(best_base["min_tier"])
	var quality: float = float(best_base["quality"])
	var weekly_rp: float = _max_weekly_rp()
	assert_gt(weekly_rp, 0.0, "任务池应存在 enabled 且 rp_output>0 的任务（RP 供给上界真源）")

	var ordered: Array[Dictionary] = _tech_nodes_by_cost()
	var cumulative_cost: int = 0
	var tech_bonus: float = 0.0
	for node: Dictionary in ordered:
		cumulative_cost += int(node["rp_cost"])
		tech_bonus += float(node["bonus"])
		var ability: float = ScoreMath.calculate_ability(eff, tech_bonus, tier, quality, params)
		if ScoreMath.calculate_score(ability, params) >= threshold:
			return int(ceil(float(cumulative_cost) / weekly_rp))
	return 0


## 任务池单槽 RP 供给上界：enabled 任务中 rp_output / duration_weeks 的最大值。
func _max_weekly_rp() -> float:
	var tasks: Dictionary = DataLoader.load_json(TASKS_PATH)
	var best: float = 0.0
	for task_id: String in tasks:
		var row: Dictionary = tasks[task_id]
		if not bool(row.get("enabled", false)):
			continue
		var weeks: int = int(row.get("duration_weeks", 0))
		if weeks <= 0:
			continue
		best = maxf(best, float(row.get("rp_output", 0)) / float(weeks))
	return best


## 可研节点的 tech_bonus 节点序列（按 rp_cost 升序；域不可研或 effect 未启用者剔除）。
func _tech_nodes_by_cost() -> Array[Dictionary]:
	var techs: Dictionary = DataLoader.load_json(TECHS_PATH)
	var nodes: Dictionary = techs.get("nodes", {})
	var domain_flags: Dictionary = techs.get("domain_flags", {})
	var rows: Array[Dictionary] = []
	for node_id: String in nodes:
		var node: Dictionary = nodes[node_id]
		var flags: Dictionary = domain_flags.get(str(node.get("domain", "")), {})
		if not bool(flags.get("researchable", true)):
			continue
		var effect: Dictionary = node.get("effect", {})
		if str(effect.get("type", "")) != "tech_bonus" or not bool(effect.get("enabled", false)):
			continue
		(
			rows
			. append(
				{
					"id": node_id,
					"rp_cost": int(node.get("rp_cost", 0)),
					"bonus": float(effect.get("value", 0.0)),
				}
			)
		)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["rp_cost"]) < int(b["rp_cost"])
	)
	return rows


## ============ 内部：数据派生与断言工具 ============


## 最高质量基座 id（数据驱动：不硬编码基座名）。
func _highest_quality_base_id(bases: Dictionary) -> String:
	var best_id: String = ""
	var best_quality: float = -1.0
	for base_id: String in bases:
		var quality: float = float(bases[base_id].get("quality", 0.0))
		if quality > best_quality:
			best_quality = quality
			best_id = base_id
	return best_id


## 全员 Σresearch（3 人上桌口径；数据驱动：staff.json）。
func _sum_staff_research() -> int:
	var staff_table: Dictionary = DataLoader.load_json(STAFF_PATH)
	var total: int = 0
	for staff_id: String in staff_table:
		total += int(staff_table[staff_id].get("research", 0))
	return total


## 满树 Σtb（techs.json 全部可研 tech_bonus 节点之和）。
func _full_tree_tech_bonus() -> float:
	var total: float = 0.0
	for node: Dictionary in _tech_nodes_by_cost():
		total += float(node["bonus"])
	return total


## 一次完整训练的出分（L2 消费链路：TrainingProject 注入参数 → settle_week 出分）。
func _training_completed_score(bases: Dictionary, base_id: String, params: Dictionary) -> float:
	var training := TrainingProject.new()
	autofree(training)
	training.setup(bases, params)
	var row: Dictionary = bases[base_id]
	var context: Dictionary = {
		"research_eff": _sum_staff_research(),
		"compute_tier": int(row["min_tier"]),
		"money": FIXTURE_MONEY,
		"training_headcount": int(row["max_staff"]),
	}
	var started: Dictionary = training.start_training(base_id, context)
	assert_true(bool(started.get("ok", false)), "训练应能启动（%s）" % base_id)
	var result: Dictionary = {}
	for _week: int in range(int(row["train_weeks"])):
		result = training.settle_week(
			_sum_staff_research(), _full_tree_tech_bonus(), int(row["min_tier"])
		)
		if bool(result.get("completed", false)):
			break
	assert_true(bool(result.get("completed", false)), "训练应完成")
	return float(result.get("score", 0.0))


## 内存构造的「阶段化」配置（仅测试用；真表零数值变更）。
func _staged_override_config() -> Dictionary:
	return {
		"stages":
		{
			"stage_0":
			{
				"name": "测试阶段0",
				"enabled": true,
				"gate": [],
				"score_params": {"theta": 150.0, "k": 18.0},
			},
			"stage_1":
			{
				"name": "测试阶段1",
				"enabled": true,
				"gate": [],
				"score_params": {"theta": 220.0, "k": 25.0},
			},
		},
	}


## A 值网格（0…260，步长 10；覆盖 sigmoid 两端与满配 A≈213.4）。
func _ability_grid() -> Array[float]:
	var grid: Array[float] = []
	for step: int in range(27):
		grid.append(float(step * 10))
	return grid


## 映射单调性：同一参数集下 A↑ ⇒ score 不降（不倒挂）。
func _assert_score_monotonic(params: Dictionary, grid: Array[float], label: String) -> void:
	var previous: float = -1.0
	for ability: float in grid:
		var score: float = ScoreMath.calculate_score(ability, params)
		assert_gte(score, previous, "%s：A=%.1f 分数不应低于更小 A 的分数（映射不倒挂）" % [label, ability])
		previous = score


## 出分参数逐值比对（避免依赖 Dictionary 相等语义）。
func _assert_params_equal(actual: Dictionary, expected: Dictionary, message: String) -> void:
	for key: String in ScoreMath.REQUIRED_KEYS:
		assert_true(actual.has(key), "%s（缺键 %s）" % [message, key])
		if key == "ability_exponents":
			for exponent_key: String in expected[key]:
				assert_eq(
					float(actual[key][exponent_key]),
					float(expected[key][exponent_key]),
					"%s（%s.%s）" % [message, key, exponent_key]
				)
		elif key == "compute_multipliers":
			for tier_key: Variant in expected[key]:
				assert_eq(
					float(actual[key][tier_key]),
					float(expected[key][tier_key]),
					"%s（%s.%s）" % [message, key, str(tier_key)]
				)
		else:
			assert_eq(float(actual[key]), float(expected[key]), "%s（%s）" % [message, key])
