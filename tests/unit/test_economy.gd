class_name TestEconomy
extends GutTest

## Economy 经济系统单元测试（issue #6 验收点）
## 覆盖 5 个 [T] 验收点：
## 1. apply_delta 唯一写点：全库 grep 验证除 Economy 内部外无直接写字段
## 2. 周收支曲线断言（课题 U(30,80)k/4–8 周+复现 U(5,12)k/3–5 周，占位参数）
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


func test_weekly_revenue_and_expense_curve() -> void:
	# [T] 验收点 2：周收支曲线断言（课题 U(30,80)k/4–8 周 + 复现 U(5,12)k/3–5 周）
	# 验证配置中的参数区间
	var rep: Dictionary = _config.get("reproduce", {})
	assert_eq(int(rep.get("amount_min")), 5000, "复现收入下限 5k")
	assert_eq(int(rep.get("amount_max")), 12000, "复现收入上限 12k")
	assert_eq(int(rep.get("duration_min")), 3, "复现周期下限 3 周")
	assert_eq(int(rep.get("duration_max")), 5, "复现周期上限 5 周")

	var grant: Dictionary = _config.get("grant", {})
	assert_eq(int(grant.get("amount_min")), 30000, "课题收入下限 30k")
	assert_eq(int(grant.get("amount_max")), 80000, "课题收入上限 80k")
	assert_eq(int(grant.get("duration_min")), 4, "课题周期下限 4 周")
	assert_eq(int(grant.get("duration_max")), 8, "课题周期上限 8 周")

	# 使用 mock 随机源验证单周聚合收支结算
	var mock_min := MockRandomSource.new(1)  # 强制抽样下界
	var ledger_min: Dictionary = _economy.accrue_week(3, mock_min)
	# 工资 3 人 * 2000 = 6000
	assert_eq(int(ledger_min["expense"]), 6000, "3 人工资支出应为 6000")
	# 收入下界：复现 5000 + 课题 30000 = 35000
	assert_eq(int(ledger_min["income"]), 35000, "收入下限聚合应为 35000")
	assert_eq(int(ledger_min["net"]), 29000, "净结余应为 29000")

	var mock_max := MockRandomSource.new(999999)  # 强制抽样上界
	var ledger_max: Dictionary = _economy.accrue_week(3, mock_max)
	# 收入上界：复现 12000 + 课题 80000 = 92000
	assert_eq(int(ledger_max["income"]), 92000, "收入上限聚合应为 92000")


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
	_economy.init_resources(-25000, 0, 1, 40.0)
	watch_signals(_economy)
	# 工资扣除 6000 后资金变为 -31000，触发 WARNED_SOFT
	var disabled_source := MockRandomSource.new(0)
	# 把 reproduce 和 grant 关闭以纯测支出超线
	var config_no_income := _config.duplicate(true)
	config_no_income["sources"]["reproduce"]["enabled"] = false
	config_no_income["sources"]["grant"]["enabled"] = false
	_economy.setup(config_no_income)
	_economy.init_resources(-25000, 0, 1, 40.0)
	_economy.accrue_week(3, disabled_source)
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
	assert_eq(_economy.get_compute()["hours_remaining"], 160.0, "升档余量补齐为新档容量")
	assert_signal_emitted(_economy, "compute_upgraded", "升档成功应发射 compute_upgraded 信号")

	# 算力余量超额扣除拒绝
	var ok: bool = _economy.apply_delta("compute", -200, "over_consume")
	assert_false(ok, "扣除 200 卡时超过现有 160 应被拒绝")
	assert_eq(_economy.get_compute()["hours_remaining"], 160.0, "余量不受非法操作影响")
