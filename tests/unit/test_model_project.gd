extends GutTest
## #140 训练项目入槽测试（验收点 2/3/4 逐字用例名 + 六因启动矩阵收口）：
## - test_train_duration_deterministic：训练时长定值（万次模拟零波动——训练
##   时长=models.json 工期周定值，随机零接入；万次抽样等价=确定性无 RNG）；
## - test_checkpoint_deterministic_no_drop：checkpoint 50% 确定性事件零掷骰
##   零数值掉落（事件由表驱动位置触发一次，无 RNG 依赖）；
## - test_on_table_cap：上桌上限随基座（迷你 1→大基座 4）与 models.json 一致；
## - test_train_blocked_single_reason_source：训练启动六因拒绝各显单一原因源
##   （#131 容器版互补；本版=档位/卡时/槽满资源矩阵收口，models-spec 六因）。
## 真源：models-spec.md（A.1/OP-MDL-01/02/D.2）+ architecture-100 §4.1 +
## #139 预算账本（Resources）+ chips-spec OP-CHP-03。

const MODELS_PATH: String = "res://src/data/models.json"


func _base_rows() -> Dictionary:
	var table := DataLoader.load_json(MODELS_PATH)
	return table["model_bases"]


func _make_project_from_table(base_id: String) -> ModelProject:
	var rows := _base_rows()
	var row: Dictionary = rows[base_id]
	var project := ModelProject.from_base(row)
	autofree(project)
	return project


func test_train_duration_deterministic() -> void:
	# 验收点：训练时长定值——万次模拟零波动（确定性：时长=表工期周定值，
	# 无任何 RNG 掷点路径；万次抽样=构造同一基座工期恒等，等价零波动断言。
	# 断言聚合循环外（防数十万断言拖慢 GUT）：循环内累计偏离计数）
	var table := DataLoader.load_json(MODELS_PATH)
	var rows: Dictionary = table["model_bases"]
	var mismatch := 0
	var extra_tick := 0
	var total_runs := 0
	for base_id: Variant in rows["_order"]:
		var row: Dictionary = rows[str(base_id)]
		var expected := int(row["duration_weeks"])
		for _i: int in 10000:
			var project := ModelProject.from_base(row)
			total_runs += 1
			if project.get_duration_weeks() != expected:
				mismatch += 1
				continue
			for _w: int in expected:
				project.week_tick()
			if not project.is_finished_pending():
				mismatch += 1
				continue
			if project.week_tick():
				extra_tick += 1
	assert_eq(total_runs, 60000, "万次×6 基座模拟全部执行")
	assert_eq(mismatch, 0, "训练时长零波动（万次无一偏离表定工期）")
	assert_eq(extra_tick, 0, "完成后零多余推进（万次无一多推）")


func test_checkpoint_deterministic_no_drop() -> void:
	# 验收点：checkpoint 50% 确定性事件——零掷骰零数值掉落
	# （事件触发=进度跨过表驱动位置；全程无 RNG 调用；无数值字段被改）
	var project := _make_project_from_table("mini")  # mini 4 周 → 跨 50% 在推进 2 后
	var fired: Array = []
	watch_signals(project)
	project.checkpoint_reached.connect(func(payload: Dictionary) -> void: fired.append(payload))
	# 推进前：未触发
	assert_false(project.is_checkpoint_hit(), "初始未达 checkpoint")
	assert_eq(project.get_ndim_profile().size(), 5, "画像 5 维（数值无掉落）")
	var before_profile := project.get_ndim_profile().duplicate()
	# 第 1 周：progress 0.25 < 0.5 未触发
	project.week_tick()
	assert_false(project.is_checkpoint_hit(), "第 1 周（25%）未触发 checkpoint")
	# 第 2 周：progress 0.5 触发（确定性位置；一次性）
	project.week_tick()
	assert_true(project.is_checkpoint_hit(), "第 2 周（50%）触发 checkpoint")
	assert_eq(fired.size(), 1, "checkpoint 信号恰发一次")
	var payload: Dictionary = fired[0]
	assert_eq(str(payload.get("base_id", "")), "mini", "载荷含基座 id")
	# 继续推进到完成：不二次触发（确定性单次）
	for _w: int in 3:
		project.week_tick()
	assert_true(project.is_finished_pending(), "4 周后完成")
	assert_eq(fired.size(), 1, "checkpoint 全程只发一次（无重复掷点）")
	# 零数值掉落：推进不改任何画像数值字段
	assert_eq(project.get_ndim_profile(), before_profile, "画像数值零掉落")


func test_on_table_cap() -> void:
	# 验收点：上桌上限随基座（迷你 1→大基座 4）与 models.json 一致
	var table := DataLoader.load_json(MODELS_PATH)
	var rows: Dictionary = table["model_bases"]
	var cap_by_id := {
		"mini": 1,
		"lingxi_1": 2,
		"qingyu_1": 2,
		"changhe_1": 3,
		"zhibi_1": 3,
		"tonggan_1": 4,
	}
	for base_id: Variant in rows["_order"]:
		var id_str := str(base_id)
		var row: Dictionary = rows[id_str]
		var project := ModelProject.from_base(row)
		# 项目声明的上桌上限=表行 on_table_cap（读表驱动）
		assert_eq(project.get_seat_limit(), int(row["on_table_cap"]), "上限随基座（%s）" % id_str)
		assert_eq(
			project.get_seat_limit(), int(cap_by_id[id_str]), "上限与 models.json 一致（%s）" % id_str
		)
	# 迷你无档位门槛（教学可训）；T1 起有档位要求
	var mini_row: Dictionary = rows["mini"]
	assert_eq(str(mini_row["tier_required"]), "", "迷你无档位门槛（教学）")
	var tonggan_row: Dictionary = rows["tonggan_1"]
	assert_eq(str(tonggan_row["tier_required"]), "t3", "通感档位门槛 t3")
	assert_eq(int(tonggan_row["on_table_cap"]), 4, "大基座上桌上限 4（随基座）")


func test_from_base_table_driven() -> void:
	# 表驱动工厂：工期/卡时/档位/域/画像全从基座行读（代码零硬编码）
	var project := _make_project_from_table("lingxi_1")
	assert_eq(project.get_base_id(), "lingxi_1", "基座 id")
	assert_eq(project.get_duration_weeks(), 6, "灵犀工期 6 周（表）")
	assert_eq(project.get_card_hours_per_week(), 3, "灵犀周耗 3 卡时（表）")
	assert_eq(project.get_tier_required(), "t1", "灵犀档位要求 t1")
	assert_eq(project.get_domain(), "align", "灵犀域=align（表）")
	assert_eq(project.get_title_key(), "model_base_lingxi_1", "名称键=表（title_key 承载）")


func test_train_blocked_single_reason_source() -> void:
	# 验收点 1（#140 收口版）：训练启动六因拒绝各显单一原因源
	# 矩阵：档位不足 / 卡时不足 / 槽满（#131 容器版已覆盖员工/上桌/满员）
	# ——每个拒绝路径恰返回一枚举码（单因不拼接，校验序固定）
	var board := TaskBoard.new()
	board.tier_met = func(_tier: String) -> bool: return false
	board.budget_met = func(_hours: int) -> bool: return false
	var project := _make_project_from_table("lingxi_1")
	# 档位不足（tier_met=false）：返回 TIER_REQUIRED_NOT_MET 单因（先于卡时）
	var tier_blocked: Dictionary = board.start_training(project)
	assert_false(tier_blocked.ok, "档位不足拒绝")
	assert_eq(
		tier_blocked["reason"],
		CoreEnums.SlotRejectReason.TIER_REQUIRED_NOT_MET,
		"档位不足=单一原因 TIER_REQUIRED_NOT_MET",
	)
	# 档位通过但卡时不足：CARD_HOURS_INSUFFICIENT 单因
	var board2 := TaskBoard.new()
	board2.tier_met = func(_tier: String) -> bool: return true
	board2.budget_met = func(_hours: int) -> bool: return false
	var project2 := _make_project_from_table("lingxi_1")
	var hours_blocked: Dictionary = board2.start_training(project2)
	assert_false(hours_blocked.ok, "卡时不足拒绝")
	assert_eq(
		hours_blocked["reason"],
		CoreEnums.SlotRejectReason.CARD_HOURS_INSUFFICIENT,
		"卡时不足=单一原因 CARD_HOURS_INSUFFICIENT",
	)
	# 双因都满足 → 入槽成功
	var board3 := TaskBoard.new()
	board3.tier_met = func(_tier: String) -> bool: return true
	board3.budget_met = func(_hours: int) -> bool: return true
	var ok_result: Dictionary = board3.start_training(_make_project_from_table("mini"))
	assert_true(ok_result.ok, "双资源因满足=入槽成功")
	# 槽满：四槽全占后第五训练被拒=ALL_SLOTS_FULL（容器因，单因）
	board3.start_training(_make_project_from_table("lingxi_1"))
	board3.start_training(_make_project_from_table("qingyu_1"))
	board3.start_training(_make_project_from_table("changhe_1"), 1)
	var full: Dictionary = board3.start_training(_make_project_from_table("tonggan_1"))
	assert_false(full.ok, "槽满拒绝")
	assert_eq(
		full["reason"],
		CoreEnums.SlotRejectReason.ALL_SLOTS_FULL,
		"槽满=单一原因 ALL_SLOTS_FULL",
	)


func test_weekly_budget_consumed_for_training() -> void:
	# #139+#140 接线：训练周耗从 Resources 周预算账本扣（周结重占）；
	# 启动校验 budget_met 接 Resources 剩余（周耗 > 剩余=拒）
	var res := Resources.new(200000, 0)
	autofree(res)
	# 装配：供给 provider=固定 8（T0）+ TaskBoard consume 接 Resources.consume
	res.weekly_supply_provider = func() -> int: return 8
	res.reset_weekly_card_hours()
	var board := TaskBoard.new()
	board.tier_met = func(_tier: String) -> bool: return true
	# budget_met=周剩余 ≥ 周耗（#140 装配方真实接法）
	board.budget_met = func(hours: int) -> bool: return res.get_card_hours_remaining() >= hours
	board.consume_card_hours = func(hours: int) -> bool: return res.consume_card_hours(hours).ok
	# 迷你周耗 1：入槽成功（budget_met 检查过=剩余 8 够；启动不预扣）
	var mini := _make_project_from_table("mini")
	var started: Dictionary = board.start_training(mini)
	assert_true(started.ok, "迷你周耗 1 入槽（预算 8 够）")
	assert_eq(res.get_card_hours_remaining(), 8, "启动不预扣（周结才扣周耗）")
	# 周结预算重占：Settlement phase1 reset 后 consume_weekly_budget 扣训练周耗
	assert_true(board.consume_weekly_budget(), "周结扣训练周耗成功")
	assert_eq(res.get_card_hours_remaining(), 7, "周结后剩余=8-1=7")
	# 启动校验联动：周结重置后再启动新训练，剩余不足=拒
	var lingxi := _make_project_from_table("lingxi_1")
	# 先手动耗 6（模拟他项目占）使剩余 1 < lingxi 周耗 3
	assert_true(res.consume_card_hours(3).ok, "耗 3 卡时")
	assert_true(res.consume_card_hours(3).ok, "再耗 3 卡时")
	var blocked: Dictionary = board.start_training(lingxi)
	assert_false(blocked.ok, "周剩余 1 < 灵犀周耗 3 → 启动拒")
	assert_eq(
		blocked["reason"],
		CoreEnums.SlotRejectReason.CARD_HOURS_INSUFFICIENT,
		"卡时不足=预算账本联动单一因",
	)


func test_slot_view_exposes_checkpoint_hook() -> void:
	# [P] 训练等待段"快好了"钩子数据面：槽视图带 checkpoint 标（位置+是否已过）
	var board := TaskBoard.new()
	board.tier_met = func(_tier: String) -> bool: return true
	board.budget_met = func(_hours: int) -> bool: return true
	var mini := _make_project_from_table("mini")
	board.start_training(mini, 0)
	var view0: Dictionary = board.get_slot_view(0)
	assert_eq(str(view0.get("base_id", "")), "mini", "槽视图含基座 id")
	assert_almost_eq(
		float(view0.get("checkpoint_progress", 0.0)), 0.5, 0.001, "槽视图含 checkpoint 位置 50%"
	)
	assert_false(bool(view0.get("checkpoint_hit", false)), "初始未过 checkpoint")
	# 推进到 50% 后视图翻转
	board.week_tick()
	board.week_tick()
	var view_after: Dictionary = board.get_slot_view(0)
	assert_true(bool(view_after.get("checkpoint_hit", false)), "过 50% 后视图 checkpoint_hit=true")
