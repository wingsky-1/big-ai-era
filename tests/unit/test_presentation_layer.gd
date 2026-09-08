class_name TestPresentationLayer
extends GutTest

## #78 [0.1.5-1g] 呈现层专项测试（显示分级 + 净流入预告 + 命名仪式 UI 落点）：
## 1. [T] test_forecast_view_matches_ledger —— 预告 = 实际（逐项一致）
## 2. [T] test_score_display_tiering —— 显示分级（主台标签 / 周报留真值）
## 3. [T] test_naming_dialog_mounted_and_submits —— 命名仪式可触发并提交
## 4. [T] test_snapshot_includes_forecast_without_new_command —— 契约面不变
## 5. test_l3_no_business_math —— ADR-0016 分层 grep 断言（L3 零业务计算/禁读 L4）
## 6. test_domain_progress_matches_fog / test_rival_view_fields_populated —— 数据面随行断言

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const MODEL_BASES_PATH: String = "res://src/data/model_bases.json"
const UI_DISPLAY_PATH: String = "res://src/data/ui_display.json"

var _world: GameWorld
var _stack: PanelStack
var _presenter: DashboardPresenter


func before_each() -> void:
	_world = GameWorld.new()
	autofree(_world)
	_world.start_new_game(42)
	_stack = PanelStack.new()
	autofree(_stack)
	_presenter = DashboardPresenter.new()
	autofree(_presenter)
	_presenter.setup(_world, _stack)


func test_forecast_view_matches_ledger() -> void:
	# [T] 预告 = 实际：get_income_forecast() 预测值与下一周结 ledger 逐项一致。
	# 场景 A：无在途任务（仅固定工资）
	var forecast_a: Dictionary = _world.get_income_forecast()
	_world.settle_week()
	var ledger_a: Dictionary = _world.get_last_ledger()
	assert_eq(int(forecast_a["income"]), int(ledger_a["income"]), "收入项一致")
	assert_eq(int(forecast_a["expense"]), int(ledger_a["expense"]), "支出项一致")
	assert_eq(int(forecast_a["net"]), int(ledger_a["net"]), "净流入一致")
	assert_eq(int(forecast_a["influence_delta"]), int(ledger_a["influence_delta"]), "影响力项一致")
	assert_lt(int(forecast_a["net"]), 0, "开局无收入，净流入应为负（工资支出）")

	# 场景 B：在途任务下周完成（任务收入 + 声望 + 工资）
	_world.enqueue_task("task_reproduce_paper_0")
	_world.settle_week()  # weeks_left 3 -> 2
	_world.settle_week()  # 3 -> 1（下周结算完成）
	var forecast_b: Dictionary = _world.get_income_forecast()
	assert_gt(int(forecast_b["income"]), 0, "预告应含下周任务结算收入")
	_world.settle_week()
	var ledger_b: Dictionary = _world.get_last_ledger()
	assert_eq(int(forecast_b["income"]), int(ledger_b["income"]), "任务收入项一致")
	assert_eq(int(forecast_b["expense"]), int(ledger_b["expense"]), "支出项一致")
	assert_eq(int(forecast_b["net"]), int(ledger_b["net"]), "净流入一致")
	assert_eq(int(forecast_b["influence_delta"]), int(ledger_b["influence_delta"]), "任务声望项一致")

	# 场景 C：非周结过账（买卡）计入下一周账期，预告同样吸收（ADR-0015 账期契约）
	var forecast_c: Dictionary = _world.get_income_forecast()
	assert_true(_world.upgrade_compute(int(_world.get_compute_upgrade_view()["next_tier"])))
	var forecast_c2: Dictionary = _world.get_income_forecast()
	_world.settle_week()
	var ledger_c: Dictionary = _world.get_last_ledger()
	assert_eq(int(forecast_c2["expense"]), int(ledger_c["expense"]), "含在途买卡支出")
	assert_eq(int(forecast_c2["net"]), int(ledger_c["net"]), "买卡后净流入一致")
	assert_ne(int(forecast_c2["net"]), int(forecast_c["net"]), "买卡应改变预告（数据面重算）")


func test_score_display_tiering() -> void:
	# [T] 显示分级：score<10 主台只显"起步档·榜外"标签，周报留真值。
	var low: Dictionary = _world.get_score_display(5.0)
	assert_eq(str(low["label"]), "起步档·榜外", "低分档位标签")
	assert_false(bool(low["reveal_truth"]), "低分主台不显真值")

	# 主台：presenter 的 score_line 只含档位标签，不含裸数字
	var main_line: String = str(_presenter.get_rival_view().get("score_line", ""))
	assert_eq(main_line, "起步档·榜外", "主台只显档位标签")
	assert_false(main_line.contains("5"), "主台不得出现裸数字")

	# 阈值边界（数据表驱动）：9.9 仍隐藏真值，10.0 起显真值
	assert_eq(str(_world.get_score_display(9.9)["label"]), "起步档·榜外", "9.9 仍在起步档")
	assert_eq(str(_world.get_score_display(10.0)["label"]), "新星档", "10.0 进新星档")
	assert_true(bool(_world.get_score_display(10.0)["reveal_truth"]), "≥阈值显真值")

	# 真实出分路径（分配训练位 → 启动训练 → 周结到出分）
	_world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	_world.start_training("base_pushi_1b")
	for _i: int in _training_weeks("base_pushi_1b"):
		_world.settle_week()
	var player_score: float = float(_world.get_rival_view()["player_score"])
	assert_lt(player_score, 10.0, "开局首分应落在起步档（<10）")
	var score_display: Dictionary = _world.get_score_display(player_score)
	assert_eq(str(score_display["label"]), "起步档·榜外", "出分后主台仍只显档位标签")

	# 周报留真值：周报载荷含真值分数行（主台隐藏不等于真值消失）
	var rows: Array = _world.get_last_report()["rows"]
	var score_row: String = ""
	for row: Variant in rows:
		if str(row).contains(str(score_display["score_text"])):
			score_row = str(row)
	assert_false(score_row.is_empty(), "周报必须保留真值分数行（rows=%s）" % str(rows))


func test_naming_dialog_mounted_and_submits() -> void:
	# [T] 命名仪式可触发：出分且未命名时推 NAMING_DIALOG，提交后 model_named 发射、榜单显示新名。
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var scene := main as MainScene
	assert_not_null(scene, "根脚本应为 MainScene")
	var world: GameWorld = scene.get_world()
	var stack: PanelStack = scene.get_stack()
	world.set_paused(true)  # 冻结时钟，周数只由测试显式推进（确定性）
	stack.pop_panel(PanelStack.PanelId.INTRO)

	assert_false(stack.get_z2_stack().has(PanelStack.PanelId.NAMING_DIALOG), "未出分时不得推命名框")

	world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	world.start_training("base_pushi_1b")
	for _i: int in _training_weeks("base_pushi_1b"):
		world.settle_week()
		stack.pop_panel(PanelStack.PanelId.AUTO_REPORT)
	await get_tree().process_frame

	assert_true(
		stack.get_z2_stack().has(PanelStack.PanelId.NAMING_DIALOG), "出分且未命名应推 NAMING_DIALOG（z2 阻塞层）"
	)
	assert_eq(world.model_name, "", "此时尚未命名")

	var dialog: NamingDialog = null
	for modal: Node in main.get_node("%ModalContainer").get_children():
		if modal is NamingDialog:
			dialog = modal
	assert_not_null(dialog, "命名弹窗应挂载到 %ModalContainer")
	assert_eq(
		dialog.get_meta("modal_design_size", Vector2.ZERO),
		Vector2(360, 260),
		"命名弹窗设计尺寸由场景 meta 提供（ModalSizing 收敛基准）"
	)

	watch_signals(world)
	dialog.submitted.emit("逐光")
	assert_signal_emitted_with_parameters(world, "model_named", ["逐光"])
	assert_eq(world.model_name, "逐光", "提交后世界模型名为新名")
	assert_eq(str(world.get_rival_view()["player_model"]), "逐光", "榜单显示新名（主台名次行数据面）")
	assert_false(stack.get_z2_stack().has(PanelStack.PanelId.NAMING_DIALOG), "提交成功后弹窗关闭")
	assert_false(bool(world.get_naming_view()["pending"]), "命名完成后不再 pending（防重复弹框）")


func test_snapshot_includes_forecast_without_new_command() -> void:
	# [T] 契约面不变：命令数仍 12、快照字段扩展经一致性断言。
	var snap: Dictionary = _world.get_ui_snapshot()
	for key: String in ["forecast", "staff_view", "domain_progress", "rival_view", "naming"]:
		assert_true(snap.has(key), "快照应含呈现层数据面字段 %s" % key)

	# 契约面不变：命令 12 / 信号 11，预告不进命令面（DR-031/P1 裁决）
	assert_eq(GameWorld.CONTRACT_COMMANDS.size(), 12, "命令数仍 12")
	assert_eq(GameWorld.CONTRACT_SIGNALS.size(), 11, "信号数仍 11")
	assert_false(GameWorld.CONTRACT_COMMANDS.has("get_income_forecast"), "净流入预告不得进命令面")
	assert_false(GameWorld.CONTRACT_SIGNALS.has("forecast_updated"), "不得新增预告信号")

	# 快照字段与数据面一致性断言
	assert_eq(
		int(snap["forecast"]["net"]), int(_world.get_income_forecast()["net"]), "快照预告 = 数据面预告"
	)
	assert_eq(int(snap["staff_view"]["total"]), _world.staff.size(), "快照员工三口径 = 名册规模")
	assert_eq(
		int(snap["staff_view"]["total"]),
		int(snap["staff_view"]["assigned"]) + int(snap["staff_view"]["idle"]),
		"三口径自洽"
	)
	assert_eq(float(snap["rival_view"]["rival_best"]), _world.rival_best, "快照竞对视图 = 数据面")
	assert_eq(
		int(snap["domain_progress"]["total_nodes"]),
		_world.tech_fog.get_total_nodes(),
		"快照域进度分母 = 节点总数真源"
	)
	# 死代码 staff_list 已删（快照 staff 仍为名册数组，兼容既有渲染）
	assert_false(snap.has("staff_list"), "死代码 staff_list 必须删除")
	assert_eq(int(snap["staff"].size()), 3, "名册快照仍为 3 人数组")


func test_l3_no_business_math() -> void:
	# ADR-0016：L3 只格式化与布局——禁读 L4 数据表、禁自算统计/预测/分级阈值。
	var l3_paths: Array[String] = [
		"res://src/ui/dashboard_presenter.gd",
		"res://src/ui/main/main.gd",
		"res://src/ui/modals/tech_tree_dialog.gd",
		"res://src/ui/modals/naming_dialog.gd",
	]
	var forbidden: Array[String] = [
		"DataLoader.load_json(",
		"ui_display.json",
		"score_tiers",
		"get_domain_counts(",
		"get_week_ledger(",
		"economy.json",
		"techs.json",
	]
	for path: String in l3_paths:
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), "%s 应可读取" % path)
		for token: String in forbidden:
			assert_false(source.contains(token), "%s 不得出现 '%s'（L3 零业务计算/禁读 L4）" % [path, token])

	# 正向：L2 数据面方法齐备（L3 消费面）
	for method: String in [
		"get_income_forecast", "get_staff_view", "get_domain_progress", "get_rival_view"
	]:
		assert_true(_world.has_method(method), "L2 应提供只读数据面 %s" % method)
	assert_true(_world.has_method("get_score_display"), "分级判定归 L2（get_score_display）")


func test_domain_progress_matches_fog() -> void:
	# 数据面随行断言：域进度与迷雾域计数同源，逐域分母之和 = 节点总数。
	var progress: Dictionary = _world.get_domain_progress()
	var counts: Dictionary = _world.tech_fog.get_domain_counts()
	var lit_total: int = 0
	var total_sum: int = 0
	for domain_variant: Variant in progress["domains"]:
		var domain: Dictionary = domain_variant
		assert_eq(
			int(domain["lit"]),
			int(counts.get(str(domain["id"]), 0)),
			"域 %s 探明数应与迷雾一致" % domain["id"]
		)
		lit_total += int(domain["lit"])
		total_sum += int(domain["total"])
	assert_eq(lit_total, int(progress["lit_total"]), "逐域探明数之和 = 汇总")
	assert_eq(total_sum, int(progress["total_nodes"]), "逐域分母之和 = 节点总数")
	assert_eq(int(progress["total_nodes"]), _world.tech_fog.get_total_nodes(), "分母真源单点")


func test_rival_view_fields_populated() -> void:
	# 数据面随行断言：竞对视图字段齐备（名称/差距/进度/预警等级/分级显示）。
	var view: Dictionary = _world.get_rival_view()
	assert_eq(str(view["rival_name"]), "深巷科技", "竞对名取自 rivals.json")
	assert_gt(float(view["rival_best"]), 0.0, "竞对基线分应就位")
	assert_eq(float(view["rival_progress"]), 0.0, "开局时间线游标为 0")
	assert_eq(str(view["warn_level"]), RivalTrack.WARN_NONE, "开局无预警")
	assert_true(view.has("score_display"), "应含分级显示结构")
	assert_eq(str(view["score_display"]["label"]), "起步档·榜外", "未出分时主台显起步档")

	# 推进到竞对论文动作后，时间线进度递增
	for _i: int in 6:
		_world.settle_week()
	assert_gt(float(_world.get_rival_view()["rival_progress"]), 0.0, "竞对时间线推进后进度 > 0")


func test_forecast_unavailable_placeholder() -> void:
	# 禁止态（ui-feedback-checklist §1）：无预测数据时显 "—" 而非 0。
	var display: Dictionary = DataLoader.load_json(UI_DISPLAY_PATH)["forecast"]
	var unavailable: Dictionary = {"available": false, "display": display}
	var text: String = str(_presenter.call("_format_forecast_row", unavailable))
	assert_eq(text, str(display["unavailable_text"]), "禁止态应显占位符")
	assert_false(text.contains("0"), "禁止态不得显 0")

	# 正常态：预告副行含净流入与近似号（数值来自 L2）
	var normal: Dictionary = _presenter.get_resource_view()
	assert_true(normal.has("forecast_text"), "presenter 应提供预告副行文本")
	assert_true(str(normal["forecast_text"]).contains(str(display["row_label"])), "副行应含行标签")
	var lines: Array = normal["forecast_lines"]
	assert_gt(lines.size(), 0, "收支结构应至少一行")
	assert_true(str(lines[0]).contains(str(display["net_label"])), "结构行应含净流入汇总")


func test_week_report_forecast_check_row() -> void:
	# 结果态：周结对账一致——周报载荷含预告对账尾注（Δ-06）。
	var forecast: Dictionary = _world.get_income_forecast()
	_world.settle_week()
	var rows: Array = _world.get_last_report()["rows"]
	var check_label: String = str(DataLoader.load_json(UI_DISPLAY_PATH)["forecast"]["check_label"])
	var check_row: String = ""
	for row: Variant in rows:
		if str(row).begins_with(check_label):
			check_row = str(row)
	assert_false(check_row.is_empty(), "周报应含预告对账尾注")
	assert_true(check_row.contains("✓"), "预告=实际 时应标 ✓")
	assert_eq(
		int(forecast["net"]), int(_world.get_last_ledger()["net"]), "对账锚：预告 net = 周结 ledger net"
	)


func test_forecast_subrow_survives_portrait_fold() -> void:
	# 界面类附加段（issue-spec §4）：副行常显弱权重 + 点开显收支结构 + 竖屏保留不折叠。
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var forecast_row: Control = main.find_child("ForecastRow", true, false) as Control
	assert_not_null(forecast_row, "资源栏应挂载净流入预告副行")
	var forecast_label: Label = forecast_row.get_node("ForecastLabel") as Label
	var detail_label: Label = forecast_row.get_node("ForecastDetailLabel") as Label
	assert_false(forecast_label.text.is_empty(), "副行常显净流入预告文本")
	assert_false(detail_label.visible, "未点开时结构行不占位")

	# 交互句式：点开副行 → 「工资 … / 运维 … / 任务 … = 净 …」
	forecast_label.gui_input.emit(_mouse_pressed_event())
	await get_tree().process_frame
	assert_true(detail_label.visible, "点开副行应展开收支结构")
	assert_true(detail_label.text.contains("工资"), "结构行应含工资项")
	assert_true(detail_label.text.contains("净"), "结构行应含净流入汇总")

	# 竖屏第一折：%ResourceSubrow 折叠，预告副行保留（文本不省）
	(main as MainScene).get_layout_manager().update_viewport(Vector2(390, 844))
	await get_tree().process_frame
	assert_false((main.get_node("%ResourceSubrow") as Control).visible, "竖屏折叠 %ResourceSubrow")
	assert_true(forecast_row.visible, "竖屏下预告副行保留不折叠")
	assert_false(forecast_label.text.is_empty(), "竖屏下预告文本不省（文本通道保留）")


func test_scored_state_survives_save_restore() -> void:
	# 读档还原（#78）：出分标记与玩家最高分入 flags 开放容器，读档后分级/命名判定不退化。
	_world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	_world.start_training("base_pushi_1b")
	for _i: int in _training_weeks("base_pushi_1b"):
		_world.settle_week()
	var score: float = float(_world.get_rival_view()["player_score"])
	var saved: Dictionary = SnapshotCodec.to_save(_world)
	assert_true(bool(saved["flags"]["scored"]), "出分标记应入档")
	assert_eq(float(saved["flags"]["player_best_score"]), score, "玩家最高分应入档")

	var restored := GameWorld.new()
	autofree(restored)
	restored.restore(saved)
	assert_eq(float(restored.get_rival_view()["player_score"]), score, "读档后玩家最高分还原（分级不退化）")
	assert_true(bool(restored.get_naming_view()["has_scored"]), "读档后出分标记还原")


func _mouse_pressed_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _training_weeks(base_id: String) -> int:
	var bases: Dictionary = DataLoader.load_json(MODEL_BASES_PATH)
	return int((bases.get(base_id, {}) as Dictionary).get("train_weeks", 0))


func test_rival_bar_fields_match_presenter() -> void:
	# [T] #77/X3：竞对条字段对齐——presenter 透传 gap/gap_text/进度，随周结刷新
	var view: Dictionary = _presenter.get_rival_view()
	var required: PackedStringArray = [
		"rival_name",
		"gap",
		"gap_text",
		"rival_progress",
		"has_scored",
		"rival_cursor",
		"rival_total",
	]
	for key: String in required:
		assert_true(view.has(key), "竞对条视图必须含字段 '%s'" % key)
	assert_eq(str(view["rival_name"]), "深巷科技", "竞对名取自 rivals.json")
	assert_eq(int(view["rival_cursor"]), 0, "开局时间线游标为 0")
	assert_eq(int(view["rival_total"]), 8, "时间线共 8 个动作")
	assert_false(bool(view["has_scored"]), "开局未出分")
	var bar_display: Dictionary = _world.get_rival_view()["bar_display"]
	var unavailable: String = str(bar_display.get("gap_unavailable", ""))
	assert_eq(str(view["gap_text"]), unavailable, "未出分时差距显示占位符（不再冒充玩家分数）")

	# 出分后差距文本就位，且 gap = 竞对分 − 玩家分
	_world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	_world.start_training("base_pushi_1b")
	var bases: Dictionary = DataLoader.load_json(MODEL_BASES_PATH)
	for _i: int in range(int(bases["base_pushi_1b"]["train_weeks"])):
		_world.settle_week()
	var view_after: Dictionary = _presenter.get_rival_view()
	assert_true(bool(view_after["has_scored"]), "训练完成后应已出分")
	assert_ne(str(view_after["gap_text"]), unavailable, "出分后差距文本应就位")
	assert_almost_eq(
		float(view_after["gap"]),
		_world.rival_best - float(_world.get_rival_view()["player_score"]),
		0.001,
		"gap = 竞对分 − 玩家分"
	)
	# 周结推进 → 竞对时间线进度刷新（X3 的"恒 0%"回归守卫）
	_world.simulate_weeks(20)
	assert_gt(float(_presenter.get_rival_view()["rival_progress"]), 0.0, "周结推进后进度应 > 0")
