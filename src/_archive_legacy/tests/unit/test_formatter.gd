extends GutTest

## Formatter 表驱动测试（issue #2 / DR-010）：
## 金额单真源——¥ 前缀 + 万缩写 + 负号前置；结构化数值行豁免口径。

const MONEY_CASES: Array = [
	[50000, "¥5万"],
	[12345, "¥1.2万"],
	[9999, "¥9999"],
	[1, "¥1"],
	[0, "¥0"],
	[950000, "¥95万"],
	[123450, "¥12.3万"],
	[123000, "¥12.3万"],
	[99900, "¥10万"],
	[100000, "¥10万"],
	[999990, "¥100万"],
	[1250000, "¥125万"],
	[-12000, "¥-1.2万"],
	[-800, "¥-800"],
	[-200000, "¥-20万"],
]

const DELTA_CASES: Array = [
	[12000, "+¥1.2万"],
	[50000, "+¥5万"],
	[-800, "¥-800"],
	[-12000, "¥-1.2万"],
	[0, "±¥0"],
]


func test_money_formatting_table_driven() -> void:
	for case: Array in MONEY_CASES:
		assert_eq(Formatter.format_money(int(case[0])), case[1], "format_money(%d)" % [case[0]])


func test_delta_formatting_table_driven() -> void:
	for case: Array in DELTA_CASES:
		assert_eq(Formatter.format_delta(int(case[0])), case[1], "format_delta(%d)" % [case[0]])


func test_stat_line_is_structured() -> void:
	# 结构化数值行："标签｜值"，值部分由 Formatter 单真源生成。
	assert_eq(Formatter.format_stat_line("资金", "¥1.2万"), "资金｜¥1.2万")
	assert_string_contains(
		Formatter.format_stat_line("资金", Formatter.format_money(12000)), "｜", "结构化行应使用全角分隔符"
	)


func test_stat_line_bypasses_max_len_per_dr010() -> void:
	# 结构化数值行不计字数：构造超长值，行长度超过 60 也不应成为文案失败
	#（口径豁免由调用方执行，Formatter 只负责产出结构）。
	var long_value := "x".repeat(80)
	var line := Formatter.format_stat_line("资金", long_value)
	assert_gt(line.length(), 60, "前置条件：构造的行应超长")
	assert_string_contains(line, "｜", "豁免口径下 Formatter 仍产出合法结构行")
