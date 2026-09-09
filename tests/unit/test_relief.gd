extends GutTest
## #136 救济三件套测试：贷款护栏/出售折价/私活限次递减/不无限续命。
## DoD 用例名与 issue 逐字一致。

var _ledger: Ledger
var _relief: Relief


func before_each() -> void:
	_ledger = Ledger.new(1)
	autofree(_ledger)
	_relief = Relief.new(_ledger)
	autofree(_relief)


func test_loan_guardrails() -> void:
	# DoD 1：贷款护栏——宽限期>0/每期还款≤周收入×0.3/提前还清减息 50%/未还可再借禁
	var result: Dictionary = _relief.take_loan(50000)
	assert_true(result.ok, "贷款可借")
	assert_true(int(result["grace"]) > 0, "宽限期>0")
	assert_true(int(result["amount"]) > 0, "额度>0")
	assert_true(_relief.is_loan_active(), "贷款生效")
	# 未还清不可再借
	var second := _relief.take_loan(50000)
	assert_false(second.ok, "未还清不可再借（防循环套）")
	assert_eq(second["reason"], "loan_pending", "拒绝原因=loan_pending")
	# 宽限期内零还款（week_tick 返回 {} 无还款行）
	var rows_before := _ledger.get_row_count()
	var grace_tick := _relief.week_tick(50000)
	assert_true(grace_tick.is_empty(), "宽限期内零还款")
	assert_eq(_ledger.get_row_count(), rows_before, "宽限期无还款行")
	# 宽限结束→分期还款（每期≤周收入中位×0.3=15000）
	var grace: int = int(result["grace"])
	for i: int in grace:
		_relief.week_tick(50000)
	var repay_tick := _relief.week_tick(50000)
	assert_false(repay_tick.is_empty(), "宽限后开始还款")
	assert_true(int(repay_tick["repay"]) <= 15000, "每期还款≤周收入×0.3（护栏）")
	# 提前还清减息 50%
	var payoff := _relief.pay_off_early()
	assert_true(payoff.ok, "提前还清可执行")
	assert_false(_relief.is_loan_active(), "还清后贷款关闭")
	# 还清后可再借（防循环套=未还可禁；还清放开）
	var again := _relief.take_loan(50000)
	assert_true(again.ok, "还清后可再借")


func test_sell_back_guardrails() -> void:
	# DoD 2：出售折价率 ≤65% 且 T0 不可售
	var table := DataLoader.load_json("res://src/data/economy.json")
	var rate := float(table["eco_sell_back_rate"])
	assert_true(rate <= 0.65, "折价率≤65%（护栏）")
	# T0 不可售：注入资产列表不含 t0
	_relief.sellable_assets = func() -> Array[String]: return ["t1", "t2"]
	_relief.asset_value = func(tier: String) -> int:
		if tier == "t1":
			return 200000
		return 400000
	var sell_t0 := _relief.sell_asset("t0")
	assert_false(sell_t0.ok, "T0 不可售")
	assert_eq(sell_t0["reason"], "not_sellable", "拒绝原因=not_sellable")
	# t1 出售=价值×折价率
	var sell := _relief.sell_asset("t1")
	assert_true(sell.ok, "t1 可售")
	assert_eq(int(sell["proceeds"]), int(200000 * rate), "出售额=价值×折价率")
	# 折价率≥0.5（防贱卖套利反噬）
	assert_true(rate >= 0.5, "折价率≥0.5（救急不套利）")


func test_job_limits_decay() -> void:
	# DoD 3：私活全局限次+冷却+收入递减 ×0.8/次
	var job1 := _relief.take_job()
	assert_true(job1.ok, "第 1 次私活可接")
	var job2 := _relief.take_job()
	assert_false(job2.ok, "冷却中不可接（连续接拒绝）")
	assert_eq(job2["reason"], "job_cooldown", "拒绝原因=job_cooldown")
	# 冷却 6 周推进
	for i: int in 6:
		_relief.tick_cooldowns()
	var job3 := _relief.take_job()
	assert_true(job3.ok, "冷却结束可接第 2 次")
	# 收入递减 ×0.8：第 2 次=第 1 次×0.8
	var table := DataLoader.load_json("res://src/data/economy.json")
	var base := int(table["eco_job_reward"])
	var decay := float(table["eco_job_decay"])
	assert_almost_eq(float(int(job1["income"])), float(base), 1.0, "第 1 次=基础收入")
	assert_almost_eq(float(int(job3["income"])), float(base) * decay, 1.0, "第 2 次=×0.8 递减")
	# 限次 3：第 4 次拒绝
	for i: int in 6:
		_relief.tick_cooldowns()
	var job4 := _relief.take_job()
	assert_true(job4.ok, "第 3 次可接")
	for i: int in 6:
		_relief.tick_cooldowns()
	var job5 := _relief.take_job()
	assert_false(job5.ok, "限次尽拒绝")
	assert_eq(job5["reason"], "job_limit_reached", "拒绝原因=job_limit_reached")


func test_relief_no_infinite() -> void:
	# DoD 4：救济不能无限续命——私活限次尽+贷款见底后破产到来
	# 场景：贷款 active（未还清）→ 私活 3 次尽 → 无设备 → relief 不可用
	var loan := _relief.take_loan(50000)
	assert_true(loan.ok, "贷款借出")
	_relief.sellable_assets = func() -> Array[String]: return []
	# 私活 3 次接满（每次冷却推进）
	for i: int in 3:
		for c: int in 6:
			_relief.tick_cooldowns()
		var job := _relief.take_job()
		assert_true(job.ok, "第 %d 次私活" % (i + 1))
	# 此时：贷款未还清 + 私活尽 + 无设备 → 救济不可用
	assert_false(_relief.get_relief_available(), "贷款在身+私活尽+无设备=救济不可用（摆烂会死）")
	# Settlement 接线验证：relief_available=false 时 cash<0 破产
	var poor := Resources.new(3000, 0)
	autofree(poor)
	var economy := Economy.new()
	autofree(economy)
	var s := Settlement.new(_ledger, poor, economy)
	autofree(s)
	s.relief_available = _relief.get_relief_available
	watch_signals(s)
	var result: Dictionary = s.run_settle(1)
	assert_true(result.bankrupt, "救济不可用+cash<0=破产（不无限续命）")
	# 对照：贷款还清后可再借=救济可用→不破产（有救但付代价）
	assert_true(loan.ok, "前置贷款已借出")
	_relief.pay_off_early()
	assert_true(_relief.get_relief_available(), "贷款还清=救济可用（可再借）")
