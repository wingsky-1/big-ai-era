extends GutTest
## #146 任务槽卡验收 GUT（用例名=issue body 逐字）：
## - test_task_slot_card_visual：进度条主视觉放大（高 12px 横贯卡底）+预计
##   结账 Wx 常显（空槽=置灰空态句非假数据）
## - test_task_slot_type_visual：三类项目类型色+图标区分（色+图标双通道）
## - test_task_slot_refresh：完成顶入动画 0.5s + 0.5s 内卡刷新（信号随查随新）
## 被测=src/ui/dashboard/{task_slot_card,workspace_view}.gd +
## src/ui/presenters/dashboard_presenter.gd（L3，headless 场景化：add_child_autofree
## +推帧惯例）。数据面=真实 TaskBoard（L2 注入方向：L3 产品代码不引类，测试
## 侧把 get_task_view 包成 Callable 注入 + 连接 task_board_changed 信号）。
## 真源=ui-ux-spec B.2 ui_task_slot_card 行/B.3 第一视觉/D.2 + ui.json token +
## texts-keys.md ui_type_*/ui_task_* 键。文本键全用 texts.json 真实键（防
## TextService 熔断 push_error 未消费）。

const UI_PATH: String = "res://src/data/ui.json"
const STAFF_PATH: String = "res://src/data/staff.json"
## 真实文本键（texts.json 已落盘；防弹键致 TextService push_error）
const TITLE_KEY_PAPER: String = "paper_topic_mm_clip"
const TITLE_KEY_MODEL: String = "model_base_mini"
const TITLE_KEY_COMPUTE: String = "chip_project_rentout"


## 测试内最小算力实例（同 test_task_board 桩：与 paper/model 同接口；P2 建
## 真实 ComputeProject 后本桩可由真实类替换——本桩不入 src、不落改动面）
class ComputeStub:
	extends Project

	func _init(
		title_key: String, duration_weeks: int, card_hours_per_week: int, seat_limit: int
	) -> void:
		_initialize(
			CoreEnums.ProjectType.COMPUTE,
			title_key,
			duration_weeks,
			card_hours_per_week,
			seat_limit,
		)

	func _on_week_tick() -> void:
		_progress = 1.0 - float(_weeks_remaining) / float(_duration_weeks)


var _known: Array[String] = []


func before_each() -> void:
	_known = ["s1", "s2", "s3", "s4"]


## ===== 验收点 1：进度条主视觉放大 + 预计结账 Wx 常显 =====
func test_task_slot_card_visual() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var bar_h := float(table["ui_progress_visual"])
	assert_true(bar_h >= 10.0 and bar_h <= 14.0, "进度条主视觉高 10-14（D.2 窗）")
	assert_eq(TaskSlotCard.PROGRESS_BAR_H, bar_h, "进度条高镜像=ui_progress_visual（防双源漂移）")
	var board := _make_board()
	board.start_paper(_make_paper(3, 1), 0)
	var card := TaskSlotCard.new()
	add_child_autofree(card)
	await get_tree().process_frame
	card.refresh(board.get_slot_view(0))
	# 进度条主视觉放大：高 12px +水平拉伸（横贯卡底）+只读非交互
	assert_eq(card.get_progress_bar_height(), bar_h, "进度条高=12px（主视觉放大）")
	assert_true(card.is_progress_full_width(), "进度条水平拉伸=横贯卡底")
	assert_true(card.get_progress_value() >= 0.0, "进度值可读（只读可视化）")
	# 预计结账 Wx 常显（运行中；与文本键盘面同源）
	assert_eq(
		card.get_eta_text(),
		TextService.format("time_est_settle", {"周数": "3"}),
		"预计结账 Wx 常显（3 周工期=W3）",
	)
	assert_true(card.get_eta_text().contains("W"), "预计结账句含 W 记号")
	assert_eq(card.get_state(), CoreEnums.ProjectState.IN_PROGRESS, "运行中状态=IN_PROGRESS")
	# 空槽=置灰空态句（A.5 空态可见可辨；防"—"假数据）
	var empty_card := TaskSlotCard.new()
	add_child_autofree(empty_card)
	await get_tree().process_frame
	empty_card.refresh(board.get_slot_view(1))
	assert_eq(empty_card.get_state(), CoreEnums.ProjectState.EMPTY, "空槽状态=EMPTY")
	assert_eq(empty_card.get_state_text(), TextService.text("ui_task_slot_empty"), "空槽显空态句")
	assert_eq(empty_card.get_eta_text(), "", "空槽不显预计结账（无假数据）")
	assert_eq(empty_card.get_type_chip_text(), "", "空槽不显类型 chip")
	assert_almost_eq(
		empty_card.modulate.a,
		float(table["ui_slot_empty_dim"]),
		0.001,
		"空槽置灰强度=表 token",
	)


## ===== 验收点 2：三类项目类型色+图标区分 =====
func test_task_slot_type_visual() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var colors: Dictionary = table["ui_type_colors"]
	var icons: Dictionary = table["ui_type_icons"]
	# 类型→key 映射与 L2 单源一致（防 L3 镜像漂移）
	for project_type: int in [
		CoreEnums.ProjectType.PAPER,
		CoreEnums.ProjectType.MODEL,
		CoreEnums.ProjectType.COMPUTE,
	]:
		assert_eq(
			DashboardPresenter.TYPE_KEY[project_type],
			Project.type_to_key(project_type),
			"投影 type_key=L2 同源（%s）" % str(project_type),
		)
	var board := _make_board()
	board.start_paper(_make_paper(2, 1), 0)
	board.start_training(_make_model(2, 2), 1)
	board.start_compute(_make_compute(2, 1), 2)
	assert_eq(board.get_slot_view(0)["type"], CoreEnums.ProjectType.PAPER, "槽0=论文")
	assert_eq(board.get_slot_view(1)["type"], CoreEnums.ProjectType.MODEL, "槽1=训练")
	assert_eq(board.get_slot_view(2)["type"], CoreEnums.ProjectType.COMPUTE, "槽2=算力")
	# 三卡逐张：类型色+图标+类型句（双通道，色盲友好）
	var card_colors: Array[Color] = []
	for i: int in 3:
		var view: Dictionary = board.get_slot_view(i)
		var type_key: String = Project.type_to_key(int(view["type"]))
		var card := TaskSlotCard.new()
		add_child_autofree(card)
		await get_tree().process_frame
		card.refresh(view)
		var expected_color := Color(str(colors[type_key]))
		_assert_color_close(card.get_type_color(), expected_color, "槽%d 类型色=表 token" % i)
		assert_eq(card.get_type_icon_text(), str(icons[type_key]), "槽%d 类型图标字=表 token" % i)
		assert_true(
			card.get_type_chip_text().contains(str(icons[type_key])),
			"槽%d chip 含图标字（双通道）" % i,
		)
		assert_true(
			card.get_type_chip_text().contains(
				str(DashboardPresenter.slot_card_view(view)["type_label"])
			),
			"槽%d chip 含类型句（双通道）" % i,
		)
		card_colors.append(card.get_type_color())
	# 三类类型色互异（区分可读：论文/训练/算力视觉可分）
	assert_ne(card_colors[0], card_colors[1], "论文≠训练类型色")
	assert_ne(card_colors[1], card_colors[2], "训练≠算力类型色")
	assert_ne(card_colors[0], card_colors[2], "论文≠算力类型色")


## ===== 验收点 3：完成顶入动画 0.5s + 0.5s 内卡刷新 =====
func test_task_slot_refresh() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_eq(WorkspaceView.REFRESH_DUR, float(table["ui_slot_refresh_dur"]), "刷新预算镜像=表值")
	assert_eq(
		TaskSlotCard.FINISH_ANIM_DUR,
		float(table["ui_slot_finish_anim_dur"]),
		"完成动画时长镜像=表值",
	)
	var board := _make_board()
	board.start_training(_make_model(2, 1), 0)  # 2 周工期训练
	var workspace := WorkspaceView.new()
	add_child_autofree(workspace)
	await get_tree().process_frame
	workspace.bind(board.get_task_view, board, "task_board_changed")
	var card: TaskSlotCard = workspace.get_slot_card(0)
	assert_eq(card.get_state(), CoreEnums.ProjectState.IN_PROGRESS, "入槽后=IN_PROGRESS")
	assert_eq(card.get_anim_state(), "pop", "入槽触发弹入动画（0.5s）")
	# 周结推进×2 → 完成：信号驱动同帧刷新（≪0.5s 预算）+完成顶入动画
	board.week_tick()
	await get_tree().process_frame
	assert_eq(card.get_state(), CoreEnums.ProjectState.IN_PROGRESS, "第1周仍在跑（信号刷新）")
	board.week_tick()
	# 信号同步派发：week_tick 返回时刷新已完成（无需等待帧）
	assert_eq(card.get_state(), CoreEnums.ProjectState.FINISHED_PENDING, "完成后=完成待结算（同帧刷新）")
	assert_eq(card.get_state_text(), TextService.text("ui_task_finished"), "完成态句")
	assert_eq(card.get_anim_state(), "finish", "完成触发顶入动画")
	assert_eq(card.get_anim_duration(), 0.5, "顶入动画时长 0.5s（表 token）")
	assert_almost_eq(card.get_progress_value(), 1.0, 0.001, "完成=进度 100%（冻结）")


## ===== 补充：presenter 纯适配（零业务计算，headless 可单测） =====
func test_presenter_slot_card_fields() -> void:
	var board := _make_board()
	board.start_paper(_make_paper(3, 1), 0)
	# 双人协作：research×eval=相邻组合 ×1.08（staff.json 相邻表边）
	board.assign_staff("s1", 0)
	board.assign_staff("s2", 0)
	var fields: Dictionary = DashboardPresenter.slot_card_view(board.get_slot_view(0))
	assert_eq(fields["type_key"], "paper", "论文 type_key=paper")
	assert_eq(fields["type_label"], TextService.text("ui_type_paper"), "类型句=论文")
	assert_eq(fields["title_text"], TextService.text(TITLE_KEY_PAPER), "标题句=真实键解析")
	assert_eq(fields["eta_text"], "预计结账：W3", "预计结账 Wx 插值（<周数> 注入）")
	assert_eq(fields["collab_badge"], "×1.08", "协作角标 ×1.08（相邻组合表值）")
	assert_eq(fields["seat_text"], "2/2", "上桌位 2/2（2 人上桌/上限2）")
	assert_almost_eq(float(fields["progress"]), 0.0, 0.001, "初始进度 0")
	# 单人=无角标（同岗/单人 ×1.0 基准不显，task_board 同源语义）
	var lone: Dictionary = DashboardPresenter.slot_card_view(board.get_slot_view(1))
	assert_eq(lone["collab_badge"], "", "空槽无协作角标")


func _assert_color_close(actual: Color, expected: Color, msg: String) -> void:
	assert_almost_eq(actual.r, expected.r, 0.001, "%s（r）" % msg)
	assert_almost_eq(actual.g, expected.g, 0.001, "%s（g）" % msg)
	assert_almost_eq(actual.b, expected.b, 0.001, "%s（b）" % msg)


func _make_board() -> TaskBoard:
	var board := TaskBoard.new()
	# 装配注入与 test_task_board 同款（谓词方向：Roster 只出谓词不写状态）
	board.is_staff_known = func(staff_id: String) -> bool: return _known.has(staff_id)
	board.is_staff_assignable = func(staff_id: String) -> bool: return staff_id != "s6"
	board.get_staff_role_key = func(staff_id: String) -> String:
		match staff_id:
			"s1":
				return "research"
			"s2":
				return "eval"
			_:
				return "data"
	board.staff_table = DataLoader.load_json(STAFF_PATH)
	return board


func _make_paper(duration_weeks: int, card_hours_per_week: int) -> PaperProject:
	return PaperProject.new(TITLE_KEY_PAPER, duration_weeks, card_hours_per_week, 2)


func _make_model(duration_weeks: int, seat_limit: int) -> ModelProject:
	return ModelProject.new(TITLE_KEY_MODEL, TITLE_KEY_MODEL, duration_weeks, 2, seat_limit)


func _make_compute(duration_weeks: int, card_hours_per_week: int) -> ComputeStub:
	return ComputeStub.new(TITLE_KEY_COMPUTE, duration_weeks, card_hours_per_week, 2)
