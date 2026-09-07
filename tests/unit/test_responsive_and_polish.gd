class_name TestResponsiveAndPolish
extends GutTest

## PR9c (issue #19) 竖屏折叠与动画预算专项测试
## 验证全部 [T] 验收点：
## 1. 折叠序断言（第一折=资源栏副行；工作区永不折叠）
## 2. 动画预算计数断言（L3 一局<=3 次）
## 3. 术语首次触发提示断言（首次返回 true，后续返回 false 避免打扰）

var _manager: ResponsiveLayoutManager


func before_each() -> void:
	_manager = ResponsiveLayoutManager.new()


func test_acceptance_point_1_folding_order_and_workspace_unfolded() -> void:
	# [T] 验收点 1：折叠序断言（第一折=资源栏副行；工作区永不折叠）
	# 1. 横屏态：宽 1280, 高 720
	_manager.setup(Vector2(1280, 720))
	assert_false(_manager.is_portrait(), "横屏判定正确")
	assert_false(_manager.is_resource_subrow_folded(), "横屏下资源栏副行不折叠")
	assert_false(_manager.is_workspace_folded(), "工作区不折叠")

	# 2. 竖屏态：宽 720, 高 1280
	_manager.update_viewport(Vector2(720, 1280))
	assert_true(_manager.is_portrait(), "竖屏判定正确")
	assert_true(_manager.is_resource_subrow_folded(), "第一折：资源栏副行折叠")
	assert_false(_manager.is_workspace_folded(), "核心红线：工作区永不折叠！")


func test_acceptance_point_2_l3_animation_budget_cap_three() -> void:
	# [T] 验收点 2：动画预算计数断言（L3 一局<=3 次）
	_manager.setup(Vector2(1280, 720))

	assert_eq(_manager.get_l3_animation_count(), 0)
	assert_eq(_manager.get_remaining_l3_animations(), 3)

	# 播放第 1 次
	assert_true(_manager.request_l3_animation("sota_break_1"))
	assert_eq(_manager.get_l3_animation_count(), 1)
	assert_eq(_manager.get_remaining_l3_animations(), 2)

	# 播放第 2 次
	assert_true(_manager.request_l3_animation("stage_up_1"))
	assert_eq(_manager.get_l3_animation_count(), 2)
	assert_eq(_manager.get_remaining_l3_animations(), 1)

	# 播放第 3 次
	assert_true(_manager.request_l3_animation("game_over_1"))
	assert_eq(_manager.get_l3_animation_count(), 3)
	assert_eq(_manager.get_remaining_l3_animations(), 0)

	# 申请第 4 次：严格超额拒绝！
	assert_false(_manager.request_l3_animation("excess_anim"), "L3 动画一局严格上限 3 次，第 4 次必须拒绝")
	assert_eq(_manager.get_l3_animation_count(), 3)


func test_acceptance_point_3_term_hint_first_time_only() -> void:
	# [T] 术语首次触发式提示断言
	_manager.setup(Vector2(1280, 720))

	assert_true(_manager.trigger_term_hint_if_first_time("crossover"), "首次触发术语提示返回 true")
	assert_false(_manager.trigger_term_hint_if_first_time("crossover"), "第二次触发返回 false（防打扰）")
	assert_true(_manager.trigger_term_hint_if_first_time("spill"), "新术语首次触发返回 true")
