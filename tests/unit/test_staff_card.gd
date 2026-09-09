extends GutTest
## #147 员工区实体卡验收 GUT（用例名=issue body 逐字）：
## - test_staff_card_refresh：名/状态色带+字样/在岗项目，指派 0.5s 刷新
## - test_staff_state_dual_channel：状态带色+文字双通道（色盲安全）
## - test_collab_badge_visible：协作角标在双人上桌时浮现
## - test_staff_area_responsive：竖屏横滑行卡≥48px / 横屏网格
## 被测=src/ui/staff_area/{staff_card,staff_area_view}.gd + dashboard_presenter
## 员工卡适配。数据面=真实 Roster+TaskBoard（L2 注入方向：L3 产品代码不引类，
## 测试侧把 view 源包成 Callable 注入 + 连接变更信号）。
## 真源=ui-ux B.2 ui_staff_card 行 / B.5 竖屏折叠 / staff-spec A.1 OP-STA-01/02 +
## ui.json（ui_staff_state_colors/ui_staff_grid_columns/ui_touch_min）。

const UI_PATH: String = "res://src/data/ui.json"
const STAFF_TABLE_PATH: String = "res://src/data/staff.json"
const TEST_SEED: int = 147147
const TITLE_KEY_PAPER: String = "paper_topic_mm_clip"

var _known: Array[String] = []


func before_each() -> void:
	_known = ["s1", "s2", "s3", "s4"]


## ===== 验收点 1：员工卡 + 指派 0.5s 刷新 =====
func test_staff_card_refresh() -> void:
	var table := DataLoader.load_json(UI_PATH)
	assert_eq(StaffAreaView.REFRESH_DUR, float(table["ui_slot_refresh_dur"]), "0.5s 刷新预算镜像=表值")
	var roster := _make_roster()
	var board := _make_board()
	board.start_paper(_make_paper(3, 1), 0)
	var area := StaffAreaView.new()
	add_child_autofree(area)
	await get_tree().process_frame
	area.bind(roster.get_roster_view, board.get_task_view, board, roster)
	# 初始：4 卡、名/岗位/状态字样在位、无在岗行
	assert_eq(area.get_card_count(), 4, "4 名员工=4 卡（E1 扩编预留）")
	var first: StaffCard = area.get_staff_card(0)
	assert_false(first.get_name_text().is_empty(), "名在位")
	assert_false(first.get_role_text().is_empty(), "岗位字样在位")
	assert_false(first.get_state_text().is_empty(), "状态字样在位")
	assert_eq(first.get_assigned_text(), "", "未指派=无在岗行")
	# 指派 s1 → task_board_changed 信号同步刷新（同帧 ≪0.5s 预算）
	assert_eq(board.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "指派成功")
	var s1: StaffCard = area.get_staff_card_by_id("s1")
	assert_true(s1.get_assigned_text().contains("在岗"), "指派后 0.5s 内翻新在岗行")
	assert_true(
		s1.get_assigned_text().contains(TextService.text(TITLE_KEY_PAPER)),
		"在岗=<项目名>（真实键解析）",
	)
	# 撤派 → 在岗行消失（信号刷新）
	assert_eq(board.unassign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "撤派成功")
	assert_eq(s1.get_assigned_text(), "", "撤派后在岗行消失（信号刷新）")


## ===== 验收点 2：状态带色+文字双通道（色盲安全） =====
func test_staff_state_dual_channel() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var state_colors: Dictionary = table["ui_staff_state_colors"]
	# 镜像=表值（防 L3 双源漂移）
	for state_key: String in ["focus", "slacking", "inspired"]:
		assert_true(state_colors.has(state_key), "token 表含状态键 %s" % state_key)
		assert_eq(
			StaffCard.STATE_COLOR[state_key],
			Color(str(state_colors[state_key])),
			"%s 色镜像=表值" % state_key,
		)
	var roster := _make_roster()
	var area := StaffAreaView.new()
	add_child_autofree(area)
	await get_tree().process_frame
	area.bind(roster.get_roster_view, Callable(), null, null)
	# 全员逐卡：色带色=表 token、状态字样非空（色+文字双通道）
	for i: int in area.get_card_count():
		var card: StaffCard = area.get_staff_card(i)
		var state_key: String = card.get_state_key()
		assert_true(state_colors.has(state_key), "第%d 卡状态键在 token 表内（%s）" % [i, state_key])
		assert_eq(
			card.get_state_color(), Color(str(state_colors[state_key])), "第%d 卡状态带色=表 token" % i
		)
		assert_false(card.get_state_text().is_empty(), "第%d 卡状态字样非空（文字双通道）" % i)
	# 产出区间提示=状态数值带同源（防文案数值两张皮）
	var staff_view: Dictionary = roster.get_staff_view("s1")
	var hint: String = area.get_staff_card_by_id("s1").get_output_hint_text()
	assert_false(hint.is_empty(), "产出区间提示在位")
	assert_true(
		hint.contains(str(round(float(staff_view["modifier_min"]) * 100.0))),
		"产出区间下限=modifier_min 数值带同源",
	)
	assert_true(
		hint.contains(str(round(float(staff_view["modifier_max"]) * 100.0))),
		"产出区间上限=modifier_max 数值带同源",
	)


## ===== 验收点 3：协作角标在双人上桌时浮现 =====
func test_collab_badge_visible() -> void:
	var roster := _make_roster()
	var board := _make_board()
	board.start_paper(_make_paper(3, 1), 0)  # seat=2
	board.assign_staff("s1", 0)
	var area := StaffAreaView.new()
	add_child_autofree(area)
	await get_tree().process_frame
	area.bind(roster.get_roster_view, board.get_task_view, board, roster)
	var s1: StaffCard = area.get_staff_card_by_id("s1")
	assert_eq(s1.get_collab_badge_text(), "", "单人上桌=无协作角标（×1.0 基准不显）")
	# research×eval=相邻组合 ×1.08（staff.json 相邻表边）→ 双人同槽两卡都显
	assert_eq(board.assign_staff("s2", 0), CoreEnums.SlotRejectReason.NONE, "s2 上桌成功")
	assert_eq(s1.get_collab_badge_text(), "×1.08", "双人上桌协作角标浮现（s1，相邻表值）")
	assert_eq(area.get_staff_card_by_id("s2").get_collab_badge_text(), "×1.08", "双人同槽两卡都显角标")
	assert_eq(area.get_staff_card_by_id("s3").get_collab_badge_text(), "", "未上桌员工无角标")


## ===== 验收点 4：竖屏横滑行卡≥48px / 横屏网格 =====
func test_staff_area_responsive() -> void:
	var table := DataLoader.load_json(UI_PATH)
	var grid_columns := int(table["ui_staff_grid_columns"])
	assert_true(grid_columns >= 2 and grid_columns <= 3, "横屏网格列数 2-3（B.5）")
	assert_eq(StaffAreaView.GRID_COLUMNS, grid_columns, "网格列数镜像=表值")
	assert_eq(
		StaffCard.MIN_CARD_SIZE,
		float(table["ui_touch_min"]),
		"卡高下限镜像=ui_touch_min（触屏纪律 48）",
	)
	var roster := _make_roster()
	var area := StaffAreaView.new()
	add_child_autofree(area)
	await get_tree().process_frame
	area.bind(roster.get_roster_view, Callable(), null, null)
	# 竖屏：横滑行单行 + 卡高 ≥48px（A.6 单行卡）
	area.apply_shape(LayoutPolicy.FOLD_HSCROLL)
	assert_eq(area.get_layout_shape(), LayoutPolicy.FOLD_HSCROLL, "竖屏=横滑行")
	for i: int in area.get_card_count():
		assert_true(
			area.get_staff_card(i).get_card_height() >= 48.0,
			"横滑行卡高 ≥48px（第%d 卡）" % i,
		)
	# 横屏：网格 + 列数=表值（2-3 列）
	area.apply_shape(LayoutPolicy.FOLD_NONE)
	assert_eq(area.get_layout_shape(), LayoutPolicy.FOLD_NONE, "横屏=网格")
	assert_eq(area.get_grid_columns(), grid_columns, "网格列数=表值（2-3 列）")


func _make_roster() -> Roster:
	var rng := RngStream.new()
	rng.setup(TEST_SEED)
	var roster := Roster.new(DataLoader.load_json(STAFF_TABLE_PATH), rng)
	roster.roll_weekly_states()  # 周粒度状态掷点（staff-spec：周结驱动）
	return roster


func _make_board() -> TaskBoard:
	var board := TaskBoard.new()
	# 装配注入与 test_task_board/test_task_slot_card 同款（谓词方向）
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
	board.staff_table = DataLoader.load_json(STAFF_TABLE_PATH)
	return board


func _make_paper(duration_weeks: int, card_hours_per_week: int) -> PaperProject:
	return PaperProject.new(TITLE_KEY_PAPER, duration_weeks, card_hours_per_week, 2)
