class_name TestEconomy
extends GutTest

## Economy 经济系统单元测试（issue #6 验收点）
## 覆盖 5 个 [T] 验收点：
## 1. apply_delta 唯一写点：全库 grep 验证除 Economy 内部外无直接写字段
## 2. 周固定支出与账期契约断言（批 1a：脉冲源退役，收入改占槽任务结算）
## 3. 双线分支断言（警告线提示；-200k 破产判负，Game Over 短路接线在 PR8 #17）
## 4. r 曲线/stage_depr 两参独立扰动断言
## 5. 算力升档/余量扣除断言（超分配拒绝）

var _economy: Economy
var _config: Dictionary


class MockRandomSource:
	extends RefCounted

	var fixed_val: int = 0

	func _init(val: int = 0) -> void:
		fixed_val = val

	func randi_in_range(low: int, high: int) -> int:
		if fixed_val != 0:
			return clampi(fixed_val, low, high)
		return (low + high) / 2


func before_each() -> void:
	_economy = Economy.new()
	_config = DataLoader.load_json("res://src/data/economy.json")
	_economy.setup(_config)
	_economy.init_resources(50000, 0, 1, 40.0)


func test_apply_delta_is_sole_resource_mutator() -> void:
	# [T] 验收点 1：apply_delta 资源变动唯一写点
	# 正常加减资金
	var ok: bool = _economy.apply_delta("money", 1000, "test_gain")
	assert_true(ok, "money 增加应成功")
	assert_eq(_economy.get_money(), 51000, "资金应增加 1000")

	ok = _economy.apply_delta("money", -5000, "test_loss")
	assert_true(ok, "money 减少应成功")
	assert_eq(_economy.get_money(), 46000, "资金应减少 5000")

	# 影响力量变动
	ok = _economy.apply_delta("influence", 10, "paper")
	assert_true(ok, "influence 增加应成功")
	assert_eq(_economy.get_influence(), 10, "声望应为 10")

	# 算力卡时扣除与拒绝超额扣除
	ok = _economy.apply_delta("compute", -15, "train")
	assert_true(ok, "扣除 15 卡时应成功")
	assert_eq(_economy.get_compute()["hours_remaining"], 25.0, "余量应为 25.0")

	# 扣除超出余量应拒绝
	ok = _economy.apply_delta("compute", -30, "train_excess")
	assert_false(ok, "扣除超额卡时应返回 false 拒绝")
	assert_eq(_economy.get_compute()["hours_remaining"], 25.0, "余量应保持 25.0")

	# 充值超出容量应拒绝
	ok = _economy.apply_delta("compute", 50, "recharge_overflow")
	assert_false(ok, "充值超容量应拒绝")
	assert_eq(_economy.get_compute()["hours_remaining"], 25.0, "余量应保持 25.0")

	# 未知资源拒绝
	ok = _economy.apply_delta("crypto", 100, "invalid")
	assert_false(ok, "非法资源类型应返回 false")
	assert_push_error("未知资源", "非法资源类型应报错")


func test_weekly_fixed_expense_and_ledger_closure() -> void:
	# [T] 验收点 2（批 1a + #80）：周固定支出 = 工资×人数 + 固定运维；脉冲源退役后周结本身不产收入
	_economy.reset_week_ledger()
	_economy.accrue_fixed_expense(3)
	var ledger: Dictionary = _economy.get_week_ledger()
	assert_eq(int(ledger["expense"]), 9000, "3 人工资 6000 + 固定运维 3000 = 9000（#80 标定）")
	assert_eq(int(ledger["income"]), 0, "脉冲源退役后周结不产生经营收入")
	assert_eq(int(ledger["net"]), -9000, "净结余应为 -9000")
	assert_eq(_economy.get_money(), 41000, "固定支出应经 apply_delta 过账")
	assert_eq(
		int(ledger["income"]) - int(ledger["expense"]),
		int(ledger["net"]),
		"收支必须闭合（income - expense == net）"
	)


func test_weekly_ledger_period_contract() -> void:
	# [T] 验收点 4（#72）：账期契约——非周结过账（买卡/研究/入队/事件）计入当前未结算周
	_economy.init_resources(50000, 0, 1, 8.0)
	_economy.reset_week_ledger()
	_economy.apply_delta("money", -2000, "task_cost")
	_economy.apply_delta("influence", 30, "event_rp_grant")
	_economy.accrue_fixed_expense(3)
	var ledger: Dictionary = _economy.get_week_ledger()
	assert_eq(int(ledger["expense"]), 11000, "非周结支出 + 固定支出（9000）应计入本周未结算账")
	assert_eq(int(ledger["influence_delta"]), 30, "非周结影响力过账应计入本周")
	assert_eq(int(ledger["income"]) - int(ledger["expense"]), int(ledger["net"]), "收支必须闭合")
	_economy.reset_week_ledger()
	assert_eq(int(_economy.get_week_ledger()["expense"]), 0, "账期翻页后支出归零")
	assert_eq(int(_economy.get_week_ledger()["influence_delta"]), 0, "账期翻页后影响力增量归零")


func test_weekly_compute_supply_reset() -> void:
	# [T] 验收点（#74）：连续 3 周结后每周卡时都重置为供给值，不累计不递减
	_economy.init_resources(50000, 0, 1, 8.0)
	for i: int in range(3):
		_economy.apply_delta("compute", -3, "spend")
		_economy.recharge_weekly()
		assert_eq(
			int(_economy.get_compute()["hours_remaining"]),
			_economy.get_compute_supply(),
			"第 %d 次周结后卡时应重置为供给值" % (i + 1)
		)
	# 升档后周供给升档（ADR-0011：供给与容量分键）
	_economy.init_resources(100000, 0, 1, 8.0)
	_economy.upgrade_compute(3)
	assert_eq(_economy.get_compute_supply(), 32, "tier3 周供给应为 32")


func test_warn_and_bankruptcy_lines() -> void:
	# [T] 验收点 3：双线分支断言（警告线提示；-200k 破产判负）
	assert_eq(_economy.check_lines(), Economy.WARNED_NONE, "开局 50k 资金应为正常线")

	# 降至 -30000 警告线
	_economy.init_resources(-30000, 0, 1, 40.0)
	assert_eq(_economy.check_lines(), Economy.WARNED_SOFT, "-30k 触发软警告")

	# 降至 -30001
	_economy.init_resources(-30001, 0, 1, 40.0)
	assert_eq(_economy.check_lines(), Economy.WARNED_SOFT, "-30001 触发软警告")

	# 降至 -200000 破产线
	_economy.init_resources(-200000, 0, 1, 40.0)
	assert_eq(_economy.check_lines(), Economy.WARNED_BANKRUPT, "-200k 判定破产")

	# 低于 -200000 破产线
	_economy.init_resources(-250000, 0, 1, 40.0)
	assert_eq(_economy.check_lines(), Economy.WARNED_BANKRUPT, "低于 -200k 判定破产")

	# 验证在周结触发警告时发射 warned 信号
	_economy.init_resources(-25000, 0, 1, 8.0)
	watch_signals(_economy)
	# 固定支出扣除 9000 后资金变为 -34000，触发 WARNED_SOFT
	_economy.accrue_fixed_expense(3)
	_economy.emit_week_warning(_economy.get_week_ledger())
	assert_signal_emitted(_economy, "warned", "周结越过警告线应发射 warned 信号")


func test_r_curve_and_stage_depr_independence() -> void:
	# [T] 验收点 4：r 曲线/stage_depr 两参独立扰动断言
	assert_eq(_economy.get_r_curve(), 1.0, "初始 r 曲线为 1.0")
	var initial_depr: Dictionary = _economy.get_stage_depr_params()
	assert_eq(float(initial_depr["reproduce_factor"]), 1.0, "初始 reproduce_factor 为 1.0")
	assert_eq(int(initial_depr["grant_interval_add_weeks"]), 0, "初始课题增加周为 0")

	# 扰动 r_curve 不影响 stage_depr
	_economy.set_r_curve(1.35)
	assert_eq(_economy.get_r_curve(), 1.35, "r 曲线已更新")
	var depr_after_r: Dictionary = _economy.get_stage_depr_params()
	assert_eq(float(depr_after_r["reproduce_factor"]), 1.0, "stage_depr 不受 r 影响")
	assert_eq(int(depr_after_r["grant_interval_add_weeks"]), 0, "stage_depr 不受 r 影响")

	# 扰动 stage_depr 不影响 r_curve
	_economy.set_stage_depr(0.75, 2)
	assert_eq(_economy.get_r_curve(), 1.35, "r 曲线保持独立")
	var depr_updated: Dictionary = _economy.get_stage_depr_params()
	assert_eq(float(depr_updated["reproduce_factor"]), 0.75, "reproduce_factor 独立更新")
	assert_eq(int(depr_updated["grant_interval_add_weeks"]), 2, "grant_interval_add_weeks 独立更新")


func test_compute_upgrade_and_capacity_refusal() -> void:
	# [T] 验收点 5：算力升档/余量扣除断言（超分配拒绝）
	assert_eq(_economy.get_compute_capacity(), 40, "档位 1 初始容量 40")
	assert_eq(_economy.get_compute()["tier"], 1, "初始档位为 1")

	# 资金不足升档失败
	_economy.init_resources(10000, 0, 1, 20.0)
	var up_fail: bool = _economy.upgrade_compute(2)  # tier 2 价格 19000
	assert_false(up_fail, "资金不足不能升档")
	assert_eq(_economy.get_compute()["tier"], 1, "档位未变")

	# 升到同档或降档拒绝
	_economy.init_resources(100000, 0, 2, 40.0)
	assert_false(_economy.upgrade_compute(2), "同档升档拒绝")
	assert_false(_economy.upgrade_compute(1), "降档拒绝")

	# 正常升档
	watch_signals(_economy)
	var up_ok: bool = _economy.upgrade_compute(3)  # tier 3 价格 38000, 容量 160
	assert_true(up_ok, "满足条件升档成功")
	assert_eq(_economy.get_money(), 100000 - 38000, "升档扣除 38000 资金")
	assert_eq(_economy.get_compute()["tier"], 3, "档位变为 3")
	assert_eq(_economy.get_compute_capacity(), 160, "容量提升至 160")
	assert_eq(_economy.get_compute()["hours_remaining"], 32.0, "升档后本周预算重置为新档供给")
	assert_signal_emitted(_economy, "compute_upgraded", "升档成功应发射 compute_upgraded 信号")

	# 算力余量超额扣除拒绝
	var ok: bool = _economy.apply_delta("compute", -200, "over_consume")
	assert_false(ok, "扣除 200 卡时超过现有 160 应被拒绝")
	assert_eq(_economy.get_compute()["hours_remaining"], 32.0, "余量不受非法操作影响")
