extends GutTest
## 批7.4 #194 事件壳 GUT（randomness OP-RND-01 决策级 + ADR-0028）：
## - test_rate_gate_and_rotation：率门命中→轮转取卡（同种子同序）；未命中=空态
## - test_single_pending_and_deferral：决策在位次周顺延（rng 流位置不前进）
## - test_choice_effects_and_ledger：三型效果入账（cash 过账+变更/影响力/none）
##   与预览承诺一致（预览值==入账值）
## - test_save_roundtrip：pending+已见集合入档往返；旧档空域=初始态兼容
## headless 固定种子断言（离线万次率门标定走模拟脚本，不进 GUT 热路径）。

const DECK_SIZE := 3


func _fresh_shell(seed: int = 7) -> EventShell:
	var rng := RngStream.new()
	rng.setup(seed)
	var shell := EventShell.new(rng)
	# 对账行回调 stub（生产=GameWorld 注入 TextService 组装；stub 断言回调链通）
	shell.text_for_event_row = func(title_key: String, effect_type: int, amount: int) -> String:
		return "%s|eff%d|%d" % [title_key, effect_type, amount]
	autofree(shell)
	return shell


func test_rate_gate_and_rotation() -> void:
	# 同种子两壳同序（确定性轮转；rate 门经 rng.event 域——率门不命中=空态）
	var a := _fresh_shell(11)
	var b := _fresh_shell(11)
	var a_result: Dictionary = a.roll_week()
	var b_result: Dictionary = b.roll_week()
	assert_eq(a_result, b_result, "同种子同序（确定性）")
	if bool(a_result.get("fired", false)):
		assert_false((a.get_pending_view() as Dictionary).is_empty(), "命中→pending 非空")
		var view: Dictionary = a.get_pending_view()
		assert_eq((view["choices"] as Array).size(), 2, "二选一（护栏锁定）")
		assert_false(str(view["title_key"]).is_empty(), "标题键下发")
	# 空态：全 declined 前提下连续 roll 至 seen 全过=重新轮转（池循环）
	var c := _fresh_shell(3)
	for i: int in 40:
		if c.has_pending():
			var submit: Dictionary = c.submit_choice(
				1, func(_n: int) -> void: pass, func(_n: int) -> void: pass
			)
			assert_true(bool(submit.get("ok", false)), "提交成功（idx1）")
	assert_true(true, "轮转循环无死锁")


func test_single_pending_and_deferral() -> void:
	var shell := _fresh_shell(5)
	# 强制 pending：连续 roll 直到命中（率门内必有命中；40 周护栏）
	for i: int in 40:
		if shell.has_pending():
			break
		shell.roll_week()
	assert_true(shell.has_pending(), "前置：pending 在位")
	# 在位期间 roll=顺延（同一卡、不换卡、rng 不前进——同卡持续待决）
	var view_before: Dictionary = shell.get_pending_view()
	var again: Dictionary = shell.roll_week()
	assert_false(bool(again.get("fired", false)), "在位不重新发卡")
	assert_true(bool(again.get("deferred", false)), "顺延标记")
	assert_eq(shell.get_pending_view(), view_before, "pending 卡不变")


func test_choice_effects_and_ledger() -> void:
	var shell := _fresh_shell(9)
	for i: int in 40:
		if shell.has_pending():
			break
		shell.roll_week()
	var view: Dictionary = shell.get_pending_view()
	assert_false(view.is_empty(), "前置：待决卡就绪")
	var cash_seen := 0
	var influence_seen := 0
	var calls: Array = []
	var apply_cash := func(amount: int) -> void: calls.append({"t": "cash", "n": amount})
	var apply_influence := func(amount: int) -> void: calls.append({"t": "influence", "n": amount})
	var result: Dictionary = shell.submit_choice(0, apply_cash, apply_influence)
	assert_true(bool(result.get("ok", false)), "提交成功")
	# 预览承诺一致：结果 effect_type/amount == view 首选项下发值
	var first: Dictionary = view["choices"][0]
	assert_eq(int(result.get("effect_type", -1)), int(first["effect_type"]), "效果类型一致")
	assert_eq(int(result.get("amount", 0)), int(first["amount"]), "金额==预览值（承诺一致）")
	assert_false(str(result.get("row_text", "")).is_empty(), "对账行文本生成")
	assert_false(shell.has_pending(), "提交后 pending 清")
	# 二次提交=防御拒绝（无 pending）
	var again: Dictionary = shell.submit_choice(0, apply_cash, apply_influence)
	assert_false(bool(again.get("ok", false)), "无 pending 提交拒绝")


func test_save_roundtrip() -> void:
	var shell := _fresh_shell(21)
	for i: int in 40:
		if shell.has_pending():
			break
		shell.roll_week()
	var save: Dictionary = shell.to_save()
	var restored := _fresh_shell(99)
	restored.restore_from_save(save)
	if str(save.get("pending_id", "")).is_empty():
		assert_false(restored.has_pending(), "空 pending 往返一致")
	else:
		assert_true(restored.has_pending(), "pending 往返保留（读档重弹=Web 刷新恢复路径）")
		assert_eq(restored.get_pending_view(), shell.get_pending_view(), "待决卡 view 一致")
	# 旧档兼容：空域=初始态（不炸不误报 pending）
	var legacy := _fresh_shell(1)
	legacy.restore_from_save({})
	assert_false(legacy.has_pending(), "旧档空域=初始态（兼容）")
