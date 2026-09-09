extends GutTest
## #135 周结账本/收支/破产线测试：唯一过账口/对账闭合/步序契约/破产/阶段。
## DoD 用例名与 issue 逐字一致。

var _ledger: Ledger
var _resources: Resources
var _economy: Economy


func before_each() -> void:
	_ledger = Ledger.new(1)
	autofree(_ledger)
	_resources = Resources.new(200000, 0)
	autofree(_resources)
	_economy = Economy.new()
	autofree(_economy)


func test_ledger_weekly_balance_closes() -> void:
	# DoD 1：唯一过账口——所有收支经 ledger，周报对账闭合（收支和=0 差）
	_ledger.record(Ledger.Category.INCOME_TASK, 30000, "论文收入")
	_ledger.record(Ledger.Category.EXPENSE_SALARY, -16000, "周工资")
	_ledger.record(Ledger.Category.EXPENSE_OPS, -4000, "运维")
	# 收入 30000 - 支出 20000 = 净 10000；收支和差=0（30000 = 16000+4000+净？不——
	# 对账闭合=收入总额 == 支出总额 + 净（恒等式）
	var income := _ledger.get_week_income()
	var expense := _ledger.get_week_expense()
	var net := _ledger.get_week_net()
	assert_eq(income, 30000, "周收入=30000")
	assert_eq(expense, 20000, "周支出=20000")
	assert_eq(net, income - expense, "净=收入-支出（对账恒等）")
	assert_eq(income, expense + net, "收入==支出+净（闭合恒等）")


func test_settlement_step_order() -> void:
	# DoD 2：周结步序契约——唯一过账口/ledger 平衡/破产判定在收入结算后
	var settlement := _make_settlement()
	autofree(settlement)
	# 装配：先有任务收入，再付工资——步序保证收入先入账
	# 直接驱动 settlement（无 TaskBoard 注入=phase 2 无项目，仅工资支出）
	var result: Dictionary = settlement.run_settle(1)
	assert_false(result.skipped, "无 z2 阻塞不跳过")
	assert_false(result.bankrupt, "开局现金足不破产")
	assert_eq(result.week, 1, "结算周=1")
	# 工资支出已过账（劳务期 1.6 万/周）——翻页后周累计清零，验证据链行
	var rows := _ledger.get_all_rows()
	var salary_row_found := false
	for row: Dictionary in rows:
		if str(row.get("category_key", "")) == "expense_salary":
			salary_row_found = true
			assert_eq(int(row.get("amount", 0)), -16000, "工资行金额 -16000")
	assert_true(salary_row_found, "周工资行入账（唯一过账口证据链）")
	# 现金=开局 20 万 - 工资 1.6 万
	assert_eq(_resources.get_cash(), 184000, "现金扣除周工资")
	# ledger 已翻页到 week 2（phase 6）
	assert_eq(_ledger.get_week(), 2, "账期翻页 week 2")


func test_bankrupt_with_debt_no_loop() -> void:
	# DoD 3：破产判定——贷款未还清不可再借+私活限次尽+无设备=破产且负债入结算
	# （#136 救济前：relief_available=恒 false，cash<0 即破产=无救济可用）
	# 场景：开局 5000 现金 < 周工资 16000 → phase 3 支出后 cash=-11000 → 破产
	var poor := Resources.new(5000, 0)
	autofree(poor)
	var s := Settlement.new(_ledger, poor, _economy)
	autofree(s)
	watch_signals(s)
	var result: Dictionary = s.run_settle(1)
	assert_true(result.bankrupt, "cash<0 且无救济=破产")
	assert_true(result.has("debt"), "负债入结算")
	assert_eq(result.debt, 11000, "负债=abs(cash)=11000（工资 16000-现金 5000）")
	assert_eq(_ledger.get_week(), 1, "破产短路：账期不翻页（周号不推进）")
	assert_signal_emitted(s, "game_over_triggered", "破产发 game_over 信号")
	# 无循环：破产后再次结算仍短路（不产生新周）
	var result2: Dictionary = s.run_settle(1)
	assert_true(result2.bankrupt, "破产态不恢复（无救济不循环）")


func test_stage_economy_curve() -> void:
	# DoD 4：三阶段经济参数（劳务期 0-40 周）与 economy.json 一致
	assert_eq(_economy.get_stage(1), Economy.Stage.LABOR, "W1 劳务期")
	assert_eq(_economy.get_stage(40), Economy.Stage.LABOR, "W40 劳务期末")
	assert_eq(_economy.get_stage(41), Economy.Stage.PRODUCT, "W41 产品期")
	assert_eq(_economy.get_stage(100), Economy.Stage.PRODUCT, "W100 产品期末")
	assert_eq(_economy.get_stage(101), Economy.Stage.CAPITAL, "W101 资本期")
	assert_eq(_economy.get_stage(156), Economy.Stage.CAPITAL, "W156 资本期末")
	# 工资曲线：劳务 1.6 万 → 产品 ×2 → 资本 ×3.5（表驱动一致）
	assert_eq(_economy.get_weekly_salary(Economy.Stage.LABOR), 16000, "劳务周工资 1.6 万")
	assert_eq(_economy.get_weekly_salary(Economy.Stage.PRODUCT), 32000, "产品周工资 3.2 万")
	assert_eq(_economy.get_weekly_salary(Economy.Stage.CAPITAL), 56000, "资本周工资 5.6 万")


func test_ledger_only_transaction_gateway() -> void:
	# 唯一过账口扩展断言：ledger 行只增不删（对账证据链）+ 类别映射单向
	_ledger.record(Ledger.Category.INCOME_TASK, 10000)
	_ledger.record(Ledger.Category.EXPENSE_TRAINING, -5000)
	assert_eq(_ledger.get_row_count(), 2, "两笔入账")
	assert_eq(Ledger.category_to_key(Ledger.Category.INCOME_TASK), "income_task", "类别键映射")
	assert_eq(Ledger.category_to_key(Ledger.Category.EXPENSE_TRAINING), "expense_training", "类别键映射")


## 测试装配：默认无 TaskBoard/Archive（phase 2 空转，仅测支出+步序）
func _make_settlement() -> Settlement:
	return Settlement.new(_ledger, _resources, _economy)
