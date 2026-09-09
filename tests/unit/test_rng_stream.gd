extends GutTest
## #125 RNG 六域登记 unit 测试（randomness-spec 验收点落地）：
## - 六域独立流：同种子六域序列各自可复现且互不相关（A.1/ADR-0008）
## - 任务壳参数护栏：触发率∈[0.10,0.20]、冷却∈[4,8]、波动≤±10%（D.2 行）
## - 状态带期望≈1.00±0.02 且 pity 生效（rnd_staff_exp/rnd_staff_pity）
## - 计数器入档（savegame.rng 开放 dict 形状，ADR-0008 决策 2）
## 参数断言全部读 rng.json 键（代码零硬编码）；状态带概率输入分布=staff-spec
## D.2 staff_state_weights 建议行（专注 0.60/摸鱼 0.25/灵感 0.15），staff.json
## 由 #130 落表后其真实状态机在 staff 模块测试另行断言（本测试只验载体中性+保底）。

const RNG_TABLE_PATH: String = "res://src/data/rng.json"
## randomness-spec A.1 六域登记表精确拼写（顺序即登记序）
const SOURCE_DOMAINS: Array[String] = [
	"event",
	"insight",
	"rival",
	"task",
	"staff",
	"recruit",
]
## staff-spec D.2 staff_state_weights 建议行（摸鱼权重 0.25=0.20–0.30 带中点）。
## 输入分布真源=staff.json（#130 落表），本单为批 0 验收在载体层验证保底机制；
## #130 合入后三态分布断言由 staff 模块测试（test_staff_state_week_granularity_and_pity）
## 接管，本测试的摸鱼率断言仅作防回归载体证据。
const STAFF_SLACK_PROB: float = 0.25


func test_rng_domains_independent_reproducible() -> void:
	# 同种子双实例：六域 64 个样本逐点一致（各自可复现）
	for seed: int in [1, 7, 42]:
		var rng_a := RngStream.new()
		var rng_b := RngStream.new()
		rng_a.setup(seed)
		rng_b.setup(seed)
		var domains: Array[String] = rng_a.get_registered_domains()
		var seq_a := {}
		for domain: String in domains:
			var row_a: Array[float] = []
			var row_b: Array[float] = []
			for i: int in 64:
				row_a.append(rng_a.randf_domain(domain))
				row_b.append(rng_b.randf_domain(domain))
			seq_a[domain] = row_a
			for i: int in 64:
				assert_almost_eq(
					row_a[i],
					row_b[i],
					1e-12,
					"同种子同域序列逐点可复现（seed=%d domain=%s idx=%d）" % [seed, domain, i],
				)
		# 互不相关：任意两域样本序列不得相同（首样本与全序列双校验）
		for i: int in domains.size():
			for j: int in domains.size():
				if i == j:
					continue
				var row_i: Array = seq_a[domains[i]]
				var row_j: Array = seq_a[domains[j]]
				assert_ne(
					row_i[0],
					row_j[0],
					"域间首样本互异（%s vs %s）" % [domains[i], domains[j]],
				)
				var identical := true
				for k: int in 64:
					if not is_equal_approx(row_i[k], row_j[k]):
						identical = false
						break
				assert_false(identical, "域间全序列不得相同（%s vs %s）" % [domains[i], domains[j]])
		# 消费不串扰：先抽满 event 域再抽 rival == 干净实例 rival 流
		var polluted := RngStream.new()
		var clean := RngStream.new()
		polluted.setup(seed)
		clean.setup(seed)
		for i: int in 16:
			polluted.randf_domain("event")
		for i: int in 8:
			assert_almost_eq(
				polluted.randf_domain("rival"),
				clean.randf_domain("rival"),
				1e-12,
				"event 域消费不扰动 rival 域流（seed=%d idx=%d）" % [seed, i],
			)


func test_six_domains_registered_table_driven() -> void:
	# 域清单=登记表驱动且与 randomness-spec A.1 精确拼写一致
	var rng := RngStream.new()
	var domains: Array[String] = rng.get_registered_domains()
	assert_eq(domains.size(), 6, "六域登记（A.1 六源登记表）")
	assert_eq(domains, SOURCE_DOMAINS, "域 id 与 randomness-spec A.1 精确一致（顺序含登记序）")
	for domain: String in domains:
		assert_eq(rng.get_counter(domain), 0, "setup 后各域计数器清零（%s）" % domain)


func test_registered_domains_table_driven_only() -> void:
	# 表驱动纪律：域清单 100% 来自 rng.json；给表加第 7 域（含 _order）后
	# 代码零改即识别新域（新增域=表加行+供给口径+万周断言三件套的落地前提）
	var rng := RngStream.new()
	assert_eq(rng.get_registered_domains(), SOURCE_DOMAINS, "默认域清单=A.1 六域")
	var patched: Dictionary = rng._params.duplicate(true)
	var registry: Dictionary = patched["rng_domains"]
	var order: Array = registry["_order"].duplicate()
	order.append("new_domain")
	registry["_order"] = order
	registry["new_domain"] = {"supply_note": "测试加行"}
	patched["rng_domains"] = registry
	rng._params = patched
	var extended: Array[String] = rng.get_registered_domains()
	assert_eq(extended.size(), 7, "登记表加行后域清单随表扩展（代码零改）")
	assert_true(extended.has("new_domain"), "新增域被表驱动识别")
	rng.setup(1)
	assert_eq(rng.get_counter("new_domain"), 0, "新增域计数器随 setup 清零")


func test_task_var_guardrails() -> void:
	# 参数护栏：表值 ∈ spec 固定带（表即真源；护栏随表同存）
	var table: Dictionary = DataLoader.load_json(RNG_TABLE_PATH)
	var trigger_rate := float(table["rnd_task_var_rate"])
	var cd_weeks := int(table["rnd_task_var_cd"])
	var range_p := float(table["rnd_task_var_range"])
	assert_true(
		trigger_rate >= 0.10 and trigger_rate <= 0.20,
		"任务壳触发率 ∈[0.10,0.20]（表值 %.3f）" % trigger_rate,
	)
	assert_true(cd_weeks >= 4 and cd_weeks <= 8, "任务壳冷却 ∈[4,8] 周（表值 %d）" % cd_weeks)
	assert_true(
		range_p > 0.0 and range_p <= 0.10,
		"任务壳结算波动 ≤±10%% 硬上限（表值 %.3f）" % range_p,
	)
	# 波动载体：单次幅度永不越带、长程均值 ≈0（rnd_task_var_net≈0 白噪音）
	var rng := RngStream.new()
	rng.setup(2026)
	var total := 0.0
	var max_abs := 0.0
	for i: int in 20000:
		var v := rng.symmetric_domain("task", range_p)
		total += v
		max_abs = maxf(max_abs, absf(v))
	assert_true(max_abs <= range_p + 1e-9, "单次波动幅度不越带（max %.4f ≤ %.4f）" % [max_abs, range_p])
	assert_true(
		absf(total / 20000.0) < 0.002,
		"任务壳波动均值≈0 不吸血（实测 %.5f）" % (total / 20000.0),
	)
	# 触发率统计：10000 次判定命中率 ∈ 理论率 ±20%
	var trigger_rng := RngStream.new()
	trigger_rng.setup(2026)
	var hits := 0
	for i: int in 10000:
		if trigger_rng.hit_domain("task", trigger_rate):
			hits += 1
	var observed := float(hits) / 10000.0
	assert_true(
		observed >= trigger_rate * 0.8 and observed <= trigger_rate * 1.2,
		"触发判定频率 ∈ 理论 ±20%%（实测 %.4f，理论 %.3f）" % [observed, trigger_rate],
	)
	# 冷却可达性：触发后冷却期内零触发（载体可支撑 spec OP-RND-04 冷却语义）
	var cd_rng := RngStream.new()
	cd_rng.setup(2026)
	var cd_left := 0
	var trigger_weeks: Array[int] = []
	for week: int in 40000:
		if cd_left > 0:
			cd_left -= 1
			continue
		if cd_rng.hit_domain("task", trigger_rate):
			trigger_weeks.append(week)
			cd_left = cd_weeks
	for i: int in range(1, trigger_weeks.size()):
		assert_true(
			trigger_weeks[i] - trigger_weeks[i - 1] > cd_weeks,
			(
				"冷却内零触发（第 %d 与 %d 触发间隔 %d > 冷却 %d）"
				% [i - 1, i, trigger_weeks[i] - trigger_weeks[i - 1], cd_weeks]
			),
		)


func test_staff_state_expected_neutral() -> void:
	# 状态带参数护栏：乘数 ≤±10%（与任务波动同量级）、期望目标 ≈1.00、保底 2–3 周
	var table: Dictionary = DataLoader.load_json(RNG_TABLE_PATH)
	var mod_range := float(table["rnd_staff_mod_range"])
	var expected_mean := float(table["rnd_staff_exp"])
	var pity_max := int(table["rnd_staff_pity"])
	assert_true(mod_range > 0.0 and mod_range <= 0.10, "状态带乘数带 ≤±10%%（表值 %.3f）" % mod_range)
	assert_true(
		expected_mean >= 0.98 and expected_mean <= 1.02,
		"状态带期望目标 ≈1.00±0.02（表值 %.3f）" % expected_mean,
	)
	assert_true(pity_max >= 2 and pity_max <= 3, "摸鱼保底 2–3 周=连 3 必转（表值 %d）" % pity_max)
	# 期望中性：产出乘数 = 1 + 带内对称波动（白噪音不白送/不白扣），20000 周均值 ≈1.00
	var rng := RngStream.new()
	rng.setup(7)
	var sum_mod := 0.0
	var weeks := 20000
	for i: int in weeks:
		sum_mod += 1.0 + rng.symmetric_domain("staff", mod_range)
	var mean_mod := sum_mod / float(weeks)
	assert_true(
		absf(mean_mod - 1.0) < 0.005,
		"状态带产出乘数均值 ≈1.00±0.02 护栏内（实测 %.5f，n=%d）" % [mean_mod, weeks],
	)
	# pity 生效：以"非摸鱼=命中"（保底对象）连续摸鱼被截断、摸鱼率带内
	var pity_rng := RngStream.new()
	pity_rng.setup(7)
	var slack_streak := 0
	var max_streak := 0
	var slack_weeks := 0
	for i: int in 20000:
		var roll: Dictionary = pity_rng.pity_pull_domain(
			"staff", 1.0 - STAFF_SLACK_PROB, pity_max, slack_streak
		)
		if roll["hit"]:
			slack_streak = 0
		else:
			slack_streak += 1
			slack_weeks += 1
			max_streak = maxi(max_streak, slack_streak)
	assert_true(
		max_streak < pity_max,
		"摸鱼保底生效：连击 %d < pity_max %d（连摸 3 必转）" % [max_streak, pity_max],
	)
	var slack_rate := float(slack_weeks) / 20000.0
	assert_true(
		slack_rate >= 0.20 and slack_rate <= 0.30,
		"摸鱼率 ∈ 0.25±20%%（实测 %.4f，输入分布=staff-spec D.2 建议行）" % slack_rate,
	)


func test_pity_pull_boundaries() -> void:
	# 边界：pity_max<=1 或连续失败已达保底线 → 必命中且标记 forced
	var rng := RngStream.new()
	rng.setup(1)
	var forced_short := rng.pity_pull_domain("insight", 0.1, 1, 0)
	assert_true(forced_short["hit"] and forced_short["forced"], "pity_max≤1 直接保底")
	var forced_at_line := rng.pity_pull_domain("insight", 0.1, 6, 5)
	assert_true(forced_at_line["hit"] and forced_at_line["forced"], "连续失败达保底线必命中")
	# 每次尝试（含保底周）该域计数器 +1
	var counter_before := rng.get_counter("insight")
	var normal := rng.pity_pull_domain("insight", 0.1, 6, 0)
	assert_true(normal is Dictionary and normal.has("forced"), "返回结构含 hit/forced")
	assert_eq(rng.get_counter("insight"), counter_before + 1, "每次 pity 尝试计数 +1（含保底周）")


func test_hit_domain_boundaries_no_consumption() -> void:
	# 概率 0/1 短路不消费样本（序列与后续抽样不漂移）
	var rng := RngStream.new()
	rng.setup(3)
	var never := rng.hit_domain("event", 0.0)
	var always := rng.hit_domain("event", 1.0)
	assert_false(never, "chance≤0 恒不命中")
	assert_true(always, "chance≥1 恒命中")
	assert_eq(rng.get_counter("event"), 0, "边界短路不消费计数器")


func test_save_restore_roundtrip() -> void:
	# 计数器入档：savegame.rng 开放 dict（root_seed + 各域计数；未消费域缺省 0）
	var rng := RngStream.new()
	rng.setup(42)
	for i: int in 5:
		rng.randf_domain("event")
	for i: int in 3:
		rng.randf_domain("staff")
	var snapshot: Dictionary = rng.to_save()
	assert_eq(int(snapshot["root_seed"]), 42, "root_seed 入档")
	assert_eq(int(snapshot["event"]), 5, "event 域计数 5 入档")
	assert_eq(int(snapshot["staff"]), 3, "staff 域计数 3 入档")
	assert_eq(int(snapshot["insight"]), 0, "未消费域计数缺省 0")
	# 读档续抽与原实例同序（读档/跳步零漂移，ADR-0008 决策 1）
	var restored := RngStream.new()
	restored.restore(snapshot)
	assert_eq(restored.get_root_seed(), 42, "读档恢复 root_seed")
	assert_eq(restored.get_counter("event"), 5, "读档恢复 event 计数")
	for i: int in 3:
		assert_almost_eq(
			restored.randf_domain("event"),
			rng.randf_domain("event"),
			1e-12,
			"读档续抽序列与原实例一致（idx=%d）" % i,
		)
	# 空数据恢复=全零 + 六域补齐（加键零迁移，ADR-0008 决策 2）
	var empty := RngStream.new()
	empty.restore({})
	assert_eq(empty.get_root_seed(), 0, "空档 root_seed 缺省 0")
	for domain: String in SOURCE_DOMAINS:
		assert_eq(empty.get_counter(domain), 0, "空档域计数缺省 0（%s，加键零迁移）" % domain)


func test_advance_domain_matches_consumed_samples() -> void:
	# 确定性跳步：advance(n) 后抽样 == 连抽 n 次后抽样（模拟对齐基础）
	var jumped := RngStream.new()
	jumped.setup(9)
	jumped.advance_domain("task", 10)
	var consumed := RngStream.new()
	consumed.setup(9)
	for i: int in 10:
		consumed.randf_domain("task")
	for i: int in 5:
		assert_almost_eq(
			jumped.randf_domain("task"),
			consumed.randf_domain("task"),
			1e-12,
			"advance(10) 后序列与连抽 10 次一致（idx=%d）" % i,
		)
	assert_eq(jumped.get_counter("task"), 15, "跳步计入计数器（10+5）")
