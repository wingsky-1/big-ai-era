extends GutTest

## #104 PR-B（P0 玩家入口·训练侧）训练板专项测试：
## 1. test_training_rows_match_bases_json    —— 行 = 基座数，名称/工期/成本取自数据表（L3 零硬编码）
## 2. test_blocked_reason_single_source      —— 可启动性/原因与 TrainingProject.can_start_training 单点一致
## 3. test_meta_excludes_min_staff           —— 不展示 min_staff（DR-031/P5 本版不启用，防假需求）
## 4. test_start_training_charges_once       —— 启动扣一次成本；重复启动被拒（already_training）
## 5. test_workspace_training_visible        —— 启动后工作区显示训练名/进度（P0-5 修复）

const BASES_PATH: String = "res://src/data/model_bases.json"
const SEED: int = 104
const FIRST_BASE: String = "base_pushi_1b"


func test_training_rows_match_bases_json() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var view: Dictionary = world.get_training_view()
	var bases_cfg: Dictionary = DataLoader.load_json(BASES_PATH)
	assert_eq((view["rows"] as Array).size(), bases_cfg.size(), "训练板行数 = model_bases.json 基座数")
	for row_variant: Variant in view["rows"]:
		var row: Dictionary = row_variant
		var cfg: Dictionary = bases_cfg[str(row["base_id"])]
		assert_eq(str(row["name"]), str(cfg["name"]), "基座名取自 model_bases.json")
		assert_true(str(row["meta_text"]).contains(str(int(cfg["train_weeks"]))), "元信息应含工期")
		assert_true(str(row["meta_text"]).contains(str(int(cfg["max_staff"]))), "元信息应含上桌上限")
		assert_false(str(row["state_text"]).is_empty(), "每行必须有状态/原因文案")
	assert_false(str(view["start_label"]).is_empty(), "启动按钮文案由 L2 出数")
	assert_false(str(view["entry_label"]).is_empty(), "入口按钮文案由 L2 出数")


func test_blocked_reason_single_source() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	# 无在岗研究员 → 研发力 0 → 全部基座不可启动
	var view: Dictionary = world.get_training_view()
	for row_variant: Variant in view["rows"]:
		var row: Dictionary = row_variant
		assert_false(bool(row["available"]), "无研发力时基座不可启动")
		assert_eq(str(row["reason"]), "zero_research_eff", "无研发力原因应可辨识（%s）" % str(row["base_id"]))
		assert_false(str(row["state_text"]).is_empty(), "不可启动必须给出原因文案")
	# 指派 1 人上桌 → 低档基座可启动；算力档不足的高档基座仍拒
	var staff_ids: Array = world.staff.keys()
	assert_gt(staff_ids.size(), 0, "开局应有研究员")
	world.assign_staff(str(staff_ids[0]), StaffRoster.SLOT_TRAINING)
	var context: Dictionary = world._training_context()
	for row_variant: Variant in world.get_training_view()["rows"]:
		var row: Dictionary = row_variant
		var check: Dictionary = world.training.can_start_training(str(row["base_id"]), context)
		assert_eq(
			bool(row["available"]),
			bool(check["ok"]),
			"%s 可启动性必须与 can_start_training 一致" % str(row["base_id"])
		)
		assert_eq(
			str(row["reason"]),
			str(check["reason"]),
			"%s 原因必须与 can_start_training 一致（单点真源）" % str(row["base_id"])
		)


func test_meta_excludes_min_staff() -> void:
	# min_staff 是零消费死键（DR-031/P5 本版不启用）→ 不得出现在玩家可见文案里。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var view: Dictionary = world.get_training_view()
	for row_variant: Variant in view["rows"]:
		var row: Dictionary = row_variant
		assert_false(
			str(row["meta_text"]).contains("min_staff"), "元信息不得暴露内部键名（%s）" % str(row["base_id"])
		)
	var template: Dictionary = DataLoader.load_json("res://src/data/ui_display.json")["training"]
	assert_false(
		str(template.get("meta_template", "")).contains("min_staff"),
		"文案模板不得含 min_staff 占位符（死键不进玩家视野）"
	)


func test_start_training_charges_once() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var staff_ids: Array = world.staff.keys()
	world.assign_staff(str(staff_ids[0]), StaffRoster.SLOT_TRAINING)
	var cost: int = int(DataLoader.load_json(BASES_PATH)[FIRST_BASE]["cost"])
	var money_before: int = world.get_money()
	assert_true(world.start_training(FIRST_BASE), "首次启动训练应成功")
	assert_eq(money_before - world.get_money(), cost, "启动应扣一次成本")
	assert_true(world.training.is_training(), "应进入训练态")
	assert_false(world.start_training(FIRST_BASE), "重复启动应被拒（返回 false）")
	assert_eq(world.get_money(), money_before - cost, "重复启动不得再扣款")
	var view: Dictionary = world.get_training_view()
	var active_row: Dictionary = _row_of(view, FIRST_BASE)
	assert_true(bool(active_row["active"]), "进行中基座行应标记 active")


func test_workspace_training_visible() -> void:
	# P0-5：启动训练后工作区必须显示训练名与进度（此前 main.gd 完全不渲染 training）。
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	var stack := PanelStack.new()
	var presenter := DashboardPresenter.new()
	presenter.setup(world, stack)
	assert_true(
		(presenter.get_workspace_view()["active_training"] as Dictionary).is_empty(), "开局无进行中训练"
	)
	var staff_ids: Array = world.staff.keys()
	world.assign_staff(str(staff_ids[0]), StaffRoster.SLOT_TRAINING)
	assert_true(world.start_training(FIRST_BASE), "启动训练应成功")
	var active: Dictionary = presenter.get_workspace_view()["active_training"]
	assert_false(active.is_empty(), "启动后工作区应有 active_training（P0-5）")
	var cfg: Dictionary = DataLoader.load_json(BASES_PATH)[FIRST_BASE]
	assert_eq(str(active["name"]), str(cfg["name"]), "训练名来自数据表")
	assert_eq(int(active["weeks_left"]), int(cfg["train_weeks"]), "剩余周数来自数据表")
	assert_almost_eq(float(active["progress"]), 0.0, 0.001, "刚启动进度为 0")
	world.settle_week()
	var after: Dictionary = presenter.get_workspace_view()["active_training"]
	assert_almost_eq(
		float(after["progress"]), 1.0 / float(int(cfg["train_weeks"])), 0.001, "周结后训练进度前进一周"
	)
	assert_true(
		str(after["progress_text"]).contains(str(int(cfg["train_weeks"]) - 1)), "剩余周数文案由 L2 出数"
	)


## #116 回归锁：训练冷启动死锁——全派任务时原因文案必须可行动（不误导），
## 面板必须携带研发力分布摘要；重指派 1 人上训练位后低档基座解锁。
func test_zero_eff_reason_actionable_and_eff_summary() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(SEED)
	# 全员派任务（"打工"态）→ 训练全禁，原因文案可行动
	var staff_ids: Array = world.staff.keys()
	assert_eq(staff_ids.size(), 3, "开局三研究员")
	for sid_variant: Variant in staff_ids:
		world.assign_staff(str(sid_variant), StaffRoster.SLOT_TASK)
	var view: Dictionary = world.get_training_view()
	assert_true(
		str(view["eff_summary"]).contains("训练位 0 人"), "摘要应显示训练位 0 人（%s）" % str(view["eff_summary"])
	)
	assert_true(
		str(view["eff_summary"]).contains("任务位 3 人"), "摘要应显示任务位 3 人（%s）" % str(view["eff_summary"])
	)
	for row_variant: Variant in view["rows"]:
		var row: Dictionary = row_variant
		assert_false(bool(row["available"]), "全派任务时基座不可启动（%s）" % str(row["base_id"]))
		assert_eq(str(row["reason"]), "zero_research_eff", "全派任务原因应为 zero_research_eff")
		assert_true(
			str(row["state_text"]).contains("指派模型训练"),
			"zero_research_eff 原因必须含可行动指引（%s）" % str(row["state_text"])
		)
		assert_false(
			str(row["state_text"]).contains("无在岗研究员（研发力为 0）"),
			"旧误导文案（无在岗研究员）必须移除（%s）" % str(row["state_text"])
		)
	# 重指派 1 人上训练位 → 摘要更新 + 低档基座解锁
	world.assign_staff(str(staff_ids[0]), StaffRoster.SLOT_TRAINING)
	var view2: Dictionary = world.get_training_view()
	assert_true(
		str(view2["eff_summary"]).contains("训练位 1 人"),
		"摘要应更新训练位 1 人（%s）" % str(view2["eff_summary"])
	)
	assert_true(
		str(view2["eff_summary"]).contains("任务位 2 人"),
		"摘要应更新任务位 2 人（%s）" % str(view2["eff_summary"])
	)
	assert_true(bool(_row_of(view2, FIRST_BASE)["available"]), "1 人上训练位后低档基座应可启动")


func _row_of(view: Dictionary, base_id: String) -> Dictionary:
	for row_variant: Variant in view.get("rows", []):
		var row: Dictionary = row_variant
		if str(row.get("base_id", "")) == base_id:
			return row
	return {}
