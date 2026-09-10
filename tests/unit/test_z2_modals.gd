extends GutTest
## #151 z2 决策卡/命名框/解锁弹卡通道验收 GUT（用例名=issue body 逐字）：
## - test_z2_modal_blocking：决策卡遮罩点击不关闭（强迫处理）
## - test_decision_before_report_order：决策卡先于周报（同帧信号到达序串行）
## - test_naming_dialog_three_layers：输入≤12 字三层过滤，被拒弹层不关闭可重输
## - test_unlock_popup_autoclose：解锁弹卡 ≤3s 自动收（非金框非阻塞）
## 被测=PanelStack backdrop 语义 + ModalScheduler + NamingDialogLogic +
## UnlockPopupLogic（全部 RefCounted/纯逻辑，headless 可单测）。
## 真源=ui-ux A.2（z2 层语义/决策先于周报/解锁弹卡）+ A.3 OP-UX-05（命名框）。
## #151 裁决：命名框=长度≤12+字符白名单+空校验（NameFilter L1 单入口）；
## 敏感词 blocklist/homophone 词表层=#143 既有内容不动，留后续批——本批测试
## 不触词表条目（真实词表为内容席示例数据）。

const UI_PATH: String = "res://src/data/ui.json"

var _skip_hit: bool = false


func _mark_skipped() -> void:
	_skip_hit = true


## ===== 验收点 1：z2 阻塞——遮罩点击不关闭（强迫处理） =====
func test_z2_modal_blocking() -> void:
	# 遮罩点击语义（ui-ux A.2）：z1 轻遮罩可点外关闭；z2 阻塞=点击不关闭
	assert_true(
		PanelStack.backdrop_dismissable(PanelStack.PanelId.TASK_BOARD),
		"z1 任务板=可点外关闭（轻遮罩）",
	)
	assert_true(PanelStack.backdrop_dismissable(PanelStack.PanelId.TECH_TREE), "z1 科技树可点外关闭")
	for panel: PanelStack.PanelId in [
		PanelStack.PanelId.DECISION_CARD,
		PanelStack.PanelId.WEEKLY_REPORT,
		PanelStack.PanelId.NAMING_DIALOG,
	]:
		assert_false(
			PanelStack.backdrop_dismissable(panel),
			"z2 阻塞=遮罩点击不关闭（强迫处理）: %s" % panel,
		)
	# 栈语义：z2 决策卡打开后顶层阻塞（世界等待）；backdrop 不触发 close
	var stack := PanelStack.new()
	assert_true(stack.open(PanelStack.PanelId.DECISION_CARD).ok, "决策卡可开")
	assert_true(stack.has_blocking_top(), "决策卡在位=z2 阻塞")
	assert_eq(stack.top(), PanelStack.PanelId.DECISION_CARD, "决策卡=顶层")
	assert_true(stack.is_open(PanelStack.PanelId.DECISION_CARD), "决策卡保持打开")
	# 阻塞期 z1 不可开（决策等待中世界停）；显式 close 才关闭
	var z1_try: Dictionary = stack.open(PanelStack.PanelId.TASK_BOARD)
	assert_false(bool(z1_try.ok), "z2 在位时 z1 不可开（决策先处理）")
	assert_true(stack.close(PanelStack.PanelId.DECISION_CARD), "显式关闭决策卡")
	assert_false(stack.has_blocking_top(), "关闭后解除阻塞")


## ===== 验收点 2：决策卡先于周报（同帧信号到达序串行） =====
func test_decision_before_report_order() -> void:
	# 优先级：决策(0)>周报(1)>解锁(2)>toast(3)
	assert_eq(int(ModalScheduler.KIND_PRIORITY[ModalScheduler.ModalKind.DECISION]), 0, "决策最高优先")
	assert_eq(
		int(ModalScheduler.KIND_PRIORITY[ModalScheduler.ModalKind.REPORT]),
		2,
		"周报第三（#194 ADR-0028 契约演进：NAMING 插入秩 1）"
	)
	var scheduler := ModalScheduler.new()
	# 同帧并发：week_settled 先到、decision_pending 后到 → 决策仍先出
	scheduler.push(ModalScheduler.ModalKind.REPORT, {"week": 3})
	scheduler.push(ModalScheduler.ModalKind.DECISION, {"card_id": "visit"})
	scheduler.push(ModalScheduler.ModalKind.UNLOCK, {"node": "align"})
	assert_eq(scheduler.size(), 3, "同帧 3 请求排队")
	var first: Dictionary = scheduler.pop_next()
	assert_eq(int(first["kind"]), int(ModalScheduler.ModalKind.DECISION), "决策卡先于周报（同帧串行）")
	var second: Dictionary = scheduler.pop_next()
	assert_eq(int(second["kind"]), int(ModalScheduler.ModalKind.REPORT), "决策处理后周报弹出")
	var third: Dictionary = scheduler.pop_next()
	assert_eq(int(third["kind"]), int(ModalScheduler.ModalKind.UNLOCK), "解锁弹卡尾随")
	assert_true(scheduler.is_empty(), "串行出完")
	# 载荷随行（装配方按 payload open 对应 PanelId）
	assert_eq(str(first["payload"]["card_id"]), "visit", "决策卡载荷可达")


## ===== 验收点 3：命名框 ≤12 字三层过滤，被拒不关闭可重输 =====
func test_naming_dialog_three_layers() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var sensitive := DataLoader.load_json("res://src/data/sensitive_words.json")
	assert_eq(
		int(table["ui_naming_max_len"]),
		int(sensitive["name_filter_max_len"]),
		"ui_naming_max_len == name_filter_max_len（同源镜像）",
	)
	assert_eq(NamingDialogLogic.NAMING_MAX_LEN, int(table["ui_naming_max_len"]), "镜像=表值")
	var submitted: Array[String] = []
	var logic := NamingDialogLogic.new()
	# skip 命中用成员方法记（GDScript lambda 对函数局部标量=只读捕获，写回无效）
	_skip_hit = false
	logic.bind(
		func(name: String) -> void: submitted.append(name),
		func() -> void: _mark_skipped(),
		func() -> Dictionary: return {"pending": true},
	)
	logic.open()
	assert_true(logic.is_open(), "命名框弹开等待输入")
	# 长度层：>12 字被拒（≤12 字上限），弹层不关闭可重输
	var too_long: Dictionary = logic.submit("这是一个非常非常非常长的名字超过十二字")
	assert_false(bool(too_long["accepted"]), "超长被拒（>12 字）")
	assert_eq(too_long["reason"], "too_long", "超长=单一原因")
	assert_true(logic.is_open(), "被拒弹层不关闭（可重输）")
	# 空层：空输入被拒
	var empty_try: Dictionary = logic.submit("   ")
	assert_false(bool(empty_try["accepted"]), "空输入被拒")
	assert_eq(empty_try["reason"], "empty", "空=单一原因")
	assert_true(logic.is_open(), "空被拒不关闭")
	# 白名单层：非法字符被拒（非 CJK/拉丁/数字/常用标点）
	var illegal: Dictionary = logic.submit("模型@名字#")
	assert_false(bool(illegal["accepted"]), "非法字符被拒（白名单层）")
	assert_eq(illegal["reason"], "whitelist", "白名单=单一原因")
	assert_true(logic.is_open(), "非法被拒不关闭")
	# 通过：≤12 字合法名 → accepted + 注入 submit_name（clean 文本）
	var good: Dictionary = logic.submit("文曲星-1")
	assert_true(bool(good["accepted"]), "合法名通过")
	assert_eq(submitted, ["文曲星-1"], "提交名经注入 submit_name 送达")
	assert_false(logic.is_open(), "通过后弹层关闭")
	# 交给命运（独立口）
	logic.open()
	var skipped_result: Dictionary = logic.skip()
	assert_true(bool(skipped_result["accepted"]), "交给命运可跳过命名")
	assert_true(_skip_hit, "skip_naming 注入被调")
	assert_false(logic.is_open(), "跳过=关闭")
	# 待命名数据面经注入可达
	assert_true(bool(logic.peek_pending().get("pending", false)), "peek_pending 注入可达")


## ===== 验收点 4：解锁弹卡 ≤3s 自动收（非金框非阻塞） =====
func test_unlock_popup_autoclose() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_almost_eq(
		UnlockPopupLogic.AUTO_CLOSE_DUR, float(table["ui_unlock_popup_dur"]), 0.001, "自动收时长镜像=表值"
	)
	assert_true(UnlockPopupLogic.AUTO_CLOSE_DUR <= 3.0, "解锁弹卡 ≤3s 自动收（A.2）")
	var popup := UnlockPopupLogic.new()
	assert_false(popup.is_visible(), "初始未显")
	popup.show()
	assert_true(popup.is_visible(), "解锁弹卡展示")
	popup.auto_close()
	assert_false(popup.is_visible(), "≤3s 自动收（状态机到点）")
	assert_true(popup.is_consumed(), "一次消费=收完不可复关")
	# 非金框：不消耗 L3 全屏预算（不占 L3Budget 名额）
	var budget := L3Budget.new()
	budget.request()
	budget.request()
	budget.request()
	assert_false(budget.request(), "L3 全屏预算仅晋升×2+终局（解锁弹卡不占）")
	# 注册语义：解锁弹卡=z2 注册（A.2 注册表）且可重复展示
	assert_eq(PanelStack.z_of(PanelStack.PanelId.UNLOCK_POPUP), 2, "解锁弹卡=z2（注册表）")
	popup.show()
	assert_true(popup.is_visible(), "可再次展示（轻量自动收通道）")
