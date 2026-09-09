extends GutTest
## #139 验收点 1：周预算纪律（GUT 用例名=issue 逐字）：
## test_card_hours_weekly_budget_reset——消耗>供给=拒绝+提示，
## 周结重置剩余不清零（供给语义：用剩作废不滚存，重置=回到档位供给）。
## 账本落位 Resources（architecture §③"CardHoursBudget 可并入 Resources"；
## #135 已留 reset_weekly_card_hours 由 Settlement phase 1 调用）。

var _res: Resources


func before_each() -> void:
	_res = Resources.new(200000, 0)
	autofree(_res)
	# 供给 provider 注入（模拟档位 t1 供给 16；装配方真接 ChipYard）
	_res.weekly_supply_provider = func() -> int: return 16
	_res.reset_weekly_card_hours()


func test_card_hours_weekly_budget_reset() -> void:
	# 周预算=供给 16；消耗逐笔扣减，剩余可见
	assert_eq(_res.get_card_hours_supply(), 16, "周供给 16")
	assert_eq(_res.get_card_hours_remaining(), 16, "重置后剩余=供给 16")
	var r1 := _res.consume_card_hours(10)
	assert_true(r1.ok, "耗 10 通过")
	assert_eq(_res.get_card_hours_remaining(), 6, "剩余 6")
	# 消耗>供给=拒绝+提示（missing=还差量；不静默卡死）
	var over := _res.consume_card_hours(10)
	assert_false(over.ok, "耗 10 > 剩 6 拒绝")
	assert_eq(int(over.get("missing", 0)), 4, "missing=10-6=4（还差 4）")
	assert_true(_res.has_overdraw_hint(), "超分配提示位置位")
	assert_eq(_res.get_card_hours_remaining(), 6, "拒绝不扣剩余（余额保留）")
	# 周结重置：剩余=供给 16（不清零不累积——上周剩 6 作废，不滚存 16+6）
	_res.reset_weekly_card_hours()
	assert_eq(_res.get_card_hours_remaining(), 16, "周结重置=供给 16（用剩作废不累积）")
	assert_false(_res.has_overdraw_hint(), "超分配提示位随周结清零（新周可重试）")
	assert_eq(_res.get_card_hours_used(), 0, "周内已用清零")


func test_consume_rejects_illegal_amount() -> void:
	# 防御：非法消费量（<1）拒绝且不置超分配提示（非预算语义）
	var bad := _res.consume_card_hours(0)
	assert_false(bad.ok, "耗 0 拒绝（防御）")
	assert_false(_res.has_overdraw_hint(), "非法量不置超分配提示")


func test_budget_used_accumulates_and_counts() -> void:
	# 已用计数=供给-剩余（预算口径；#135 存量语义保留）
	var r1 := _res.consume_card_hours(6)
	assert_true(r1.ok, "耗 6 通过")
	assert_eq(_res.get_card_hours_used(), 6, "已用 6")
	var r2 := _res.consume_card_hours(4)
	assert_true(r2.ok, "耗 4 通过")
	assert_eq(_res.get_card_hours_used(), 10, "累计已用 10")
	assert_eq(_res.get_card_hours_remaining(), 6, "剩余 16-10=6")
