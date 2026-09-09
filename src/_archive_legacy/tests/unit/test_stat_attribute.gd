extends GutTest

## StatAttribute 单元测试：纯逻辑、无场景依赖。

const EPSILON: float = 0.0001


func test_initial_value_returns_base() -> void:
	var stat := StatAttribute.new(50.0)
	assert_almost_eq(stat.get_value(), 50.0, EPSILON, "初始值应等于基础值")


func test_negative_base_clamped_to_zero() -> void:
	var stat := StatAttribute.new(-10.0)
	assert_almost_eq(stat.get_value(), 0.0, EPSILON, "负基础值应钳制为 0")


func test_flat_bonus_adds_linearly() -> void:
	var stat := StatAttribute.new(100.0)
	stat.add_flat_bonus(20.0)
	assert_almost_eq(stat.get_value(), 120.0, EPSILON, "flat 修正应线性叠加")


func test_percent_bonus_multiplies_base_plus_flat() -> void:
	var stat := StatAttribute.new(100.0)
	stat.add_flat_bonus(10.0)
	stat.add_percent_bonus(0.5)
	assert_almost_eq(stat.get_value(), 165.0, EPSILON, "最终值应为 (100+10)*(1+0.5)")


func test_clear_modifiers_restores_base() -> void:
	var stat := StatAttribute.new(100.0)
	stat.add_flat_bonus(50.0)
	stat.add_percent_bonus(1.0)
	stat.clear_modifiers()
	assert_almost_eq(stat.get_value(), 100.0, EPSILON, "清除修正后应回到基础值")


func test_changed_signal_emits_final_value() -> void:
	var stat := StatAttribute.new(10.0)
	watch_signals(stat)
	stat.add_flat_bonus(5.0)
	assert_signal_emitted(stat, "changed", "修改修正值后应发出 changed 信号")
	# 注：assert_signal_emitted_with_parameters 在 GUT 9.7 对 float 参数
	# 存在类型混淆问题，此处手动取参数校验更稳。
	var params: Array = get_signal_parameters(stat, "changed")
	assert_eq(params.size(), 1, "changed 信号应携带 1 个参数")
	assert_almost_eq(float(params[0]), 15.0, EPSILON, "参数应为计算后的最终值 15.0")
