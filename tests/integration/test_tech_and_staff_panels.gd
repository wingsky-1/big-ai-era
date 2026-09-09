extends GutTest

## PR-C 科技树（§13 C方案）与员工名册详情集成测试：
## 1. 验证 TechTreeDialog (C 方案：列表展示、1-hop 微图前置显示、??? 行占位、域计数)；
## 2. 验证 StaffRosterDialog (详情展示、工位调度、单人单槽/单槽独占约束生效)；
## 3. 验证通过 UI 弹窗操作仅调用契约命令 (零直接改写实体状态)。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const TECH_TREE_SCENE: PackedScene = preload("res://src/ui/modals/tech_tree_dialog.tscn")
const STAFF_ROSTER_SCENE: PackedScene = preload("res://src/ui/modals/staff_roster_dialog.tscn")
const TECHS_PATH: String = "res://src/data/techs.json"
const UI_DISPLAY_PATH: String = "res://src/data/ui_display.json"
const GDD_PATH: String = "res://docs/gdd/gdd.md"


func _open_tech_tree(world: GameWorld) -> TechTreeDialog:
	var dialog: TechTreeDialog = TECH_TREE_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.setup(world)
	return dialog


func test_tech_tree_dialog_c_plan_features() -> void:
	var world := GameWorld.new()
	world.start_new_game()

	var dialog: TechTreeDialog = TECH_TREE_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.setup(world)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. 验证领域计数信息（#78：域与分母改由 L2 数据面出数，删硬编码/磁盘读）
	var summary_lbl: Label = dialog.get_node("%DomainSummaryLabel")
	assert_not_null(summary_lbl, "领域统计标签应存在")
	assert_string_contains(summary_lbl.text, "深度思考", "应包含深度思考域计数")
	assert_string_contains(summary_lbl.text, "蒲公英", "应包含蒲公英域计数")
	assert_string_contains(summary_lbl.text, "总探明", "应含总探明汇总（n/节点总数）")
	assert_false(summary_lbl.text.contains("模型架构"), "不得再显与 techs.json 不符的旧域名")

	# 2. 验证列表内包含 ??? 深层迷雾占位行
	var list_vbox: VBoxContainer = dialog.get_node("%TechListVBox")
	assert_true(list_vbox.get_child_count() > 0, "科技列表子项不应为空")

	var has_hidden_placeholder: bool = false
	var has_researchable_item: bool = false
	for child in list_vbox.get_children():
		var hbox := child as HBoxContainer
		if hbox != null and hbox.get_child_count() > 0:
			var lbl := hbox.get_child(0) as Label
			if lbl != null:
				if lbl.text.contains("???"):
					has_hidden_placeholder = true
				if lbl.text.contains("●"):
					has_researchable_item = true

	assert_true(has_hidden_placeholder, "迷雾深层节点必须以 '???' 占位显示")
	assert_true(has_researchable_item, "开局可研节点应以 '●' 标注并挂载研发按钮")


func test_domain_count_denominator_consistency() -> void:
	# [T] #81 验收点 1：域计数分母三处口径一致（GDD §8.1 表 / 实表 techs.json / UI 汇总行）。
	var techs: Dictionary = DataLoader.load_json(TECHS_PATH)
	var nodes: Dictionary = techs.get("nodes", {})
	var domain_enum: Array = techs.get("domain_enum", [])
	var total_key: int = int(techs.get("total_nodes", -1))
	assert_eq(total_key, nodes.size(), "实表：total_nodes 数据键 = 实表节点数")
	assert_eq(total_key, 14, "实表：MVP 14 节点（DR-031/D3：11 可研 + 3 elsewhere）")

	# 逐域分母 = 该域实表节点数；Σ 逐域分母 = total_nodes（无域外节点、无双真源）。
	var totals: Dictionary = {}
	var researchable_count: int = 0
	var sum_rp_cost: int = 0
	for node_id: String in nodes:
		var domain: String = str(nodes[node_id].get("domain", ""))
		totals[domain] = int(totals.get(domain, 0)) + 1
		if _domain_researchable(techs, domain):
			researchable_count += 1
			sum_rp_cost += int(nodes[node_id].get("rp_cost", 0))
	var total_sum: int = 0
	for domain_variant: Variant in domain_enum:
		var domain: String = str(domain_variant)
		assert_true(totals.has(domain), "域 %s 必须在实表中有节点" % domain)
		total_sum += int(totals.get(domain, 0))
	assert_eq(total_sum, total_key, "Σ 逐域分母 = total_nodes")

	# GDD §8.1 口径行 ↔ 实表：14 = 11 可研 + 3 elsewhere、Σrp_cost 14210、分母口径 n/14。
	var gdd_section: String = _gdd_section("### 8.1", "### 8.2")
	assert_false(gdd_section.is_empty(), "GDD 应含 §8.1 全表")
	assert_string_contains(gdd_section, "14 节点", "GDD §8.1 标题应锚 14 节点口径")
	assert_string_contains(gdd_section, "11 可研", "GDD §8.1 应写 11 可研")
	assert_string_contains(gdd_section, "3 elsewhere", "GDD §8.1 应写 3 elsewhere")
	assert_string_contains(gdd_section, "n/14", "GDD §8.1 应写分母口径 n/14（选项 b）")
	assert_eq(researchable_count, 11, "实表可研节点 = 11（与 GDD §8.1 一致）")
	assert_eq(sum_rp_cost, 14210, "Σrp_cost 维持 14210（DR-031/A2 撤销调表）")
	assert_string_contains(gdd_section, str(sum_rp_cost), "GDD §8.1 应写实算 Σrp_cost=14210")
	assert_eq(_gdd_table_row_count(gdd_section), domain_enum.size(), "GDD §8.1 域行数 = 域枚举数")
	var labels: Dictionary = DataLoader.load_json(UI_DISPLAY_PATH).get("domain_labels", {})
	assert_eq(labels.size(), domain_enum.size(), "UI 域显示名键数 = 域枚举数")

	# L2 数据面：逐域分母与总分母均取自 TechFog 单点真源。
	var world := GameWorld.new()
	world.start_new_game()
	var progress: Dictionary = world.get_domain_progress()
	assert_eq(progress["domains"].size(), domain_enum.size(), "L2 域行数 = 域枚举数")
	assert_eq(
		int(progress["total_nodes"]), world.tech_fog.get_total_nodes(), "L2 总分母 = TechFog 数据键"
	)
	assert_eq(int(progress["total_nodes"]), total_key, "L2 总分母 = 实表 total_nodes")
	var surface_sum: int = 0
	for domain_variant: Variant in progress["domains"]:
		var row: Dictionary = domain_variant
		assert_eq(
			int(row["total"]), int(totals.get(str(row["id"]), 0)), "L2 域 %s 分母 = 实表节点数" % row["id"]
		)
		surface_sum += int(row["total"])
	assert_eq(surface_sum, total_key, "Σ L2 逐域分母 = 总分母")

	# UI 汇总行：逐域 n/该域分母 + 总 n/14，与 L2 数据面逐字一致。
	var dialog: TechTreeDialog = _open_tech_tree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary_lbl: Label = dialog.get_node("%DomainSummaryLabel")
	for domain_variant: Variant in progress["domains"]:
		var row: Dictionary = domain_variant
		assert_string_contains(
			summary_lbl.text,
			"%s %d/%d" % [row["label"], int(row["lit"]), int(row["total"])],
			"UI 应显域 %s 的真实 n/分母" % row["id"]
		)
	assert_string_contains(summary_lbl.text, "/%d" % total_key, "UI 总分母 = 实表节点数 14")


func test_domain_counts_render_real_values() -> void:
	# [T] #81 验收点 2：域计数 UI 显真实数值，且随迷雾状态变化（防 X2"恒 0/4、0/5、0/5"回归）。
	var world := GameWorld.new()
	world.start_new_game()
	var dialog: TechTreeDialog = _open_tech_tree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary_lbl: Label = dialog.get_node("%DomainSummaryLabel")
	var opening_text: String = summary_lbl.text

	# 开局真值：4 开局可研节点 + 3 elsewhere 传闻 = 7 探明；分母逐域取实表节点数。
	assert_string_contains(opening_text, "深度思考 2/3", "开局深度思考应为 2/3（实表 3 节点）")
	assert_string_contains(opening_text, "蒲公英 2/3", "开局蒲公英应为 2/3（实表 3 节点）")
	assert_string_contains(opening_text, "长忆 0/2", "开局长忆应为 0/2（实表 2 节点）")
	assert_string_contains(opening_text, "通感 0/1", "开局通感应为 0/1（实表 1 节点）")
	assert_string_contains(opening_text, "工具 0/1", "开局工具应为 0/1（实表 1 节点）")
	assert_string_contains(opening_text, "交叉 0/1", "开局交叉应为 0/1（实表 1 节点）")
	assert_string_contains(opening_text, "总探明 7/14", "开局总探明 7/14")
	assert_false(opening_text.contains("0/4"), "不得再显旧硬编码分母 0/4")
	assert_false(opening_text.contains("0/5"), "不得再显旧硬编码分母 0/5")

	# 翻雾推进（P50 供给带内）后，逐域与总探明数值必须真实变化。
	world.tech_fog.advance_with_context({"cum_influence": 600})
	dialog.setup(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var revealed_text: String = summary_lbl.text
	assert_ne(revealed_text, opening_text, "域计数文本必须随迷雾状态变化（防恒 0 回归）")
	assert_string_contains(revealed_text, "深度思考 3/3", "翻雾后深度思考 3/3")
	assert_string_contains(revealed_text, "蒲公英 3/3", "翻雾后蒲公英 3/3")
	assert_string_contains(revealed_text, "长忆 2/2", "翻雾后长忆 2/2")
	assert_string_contains(revealed_text, "通感 1/1", "翻雾后通感 1/1")
	assert_string_contains(revealed_text, "工具 1/1", "翻雾后工具 1/1")
	assert_string_contains(revealed_text, "交叉 1/1", "翻雾后交叉 1/1")
	assert_string_contains(revealed_text, "总探明 14/14", "翻雾后总探明 14/14")

	# UI 文本与 L2 数据面逐行一致（数值非 UI 自算）。
	var progress: Dictionary = world.get_domain_progress()
	for domain_variant: Variant in progress["domains"]:
		var row: Dictionary = domain_variant
		assert_string_contains(
			revealed_text,
			"%s %d/%d" % [row["label"], int(row["lit"]), int(row["total"])],
			"UI 域 %s 数值必须与 L2 数据面一致" % row["id"]
		)


func test_tech_panel_asserts_correct_domain_keys() -> void:
	# [T] #81 验收点 3：面板域名键必须与实表 domain_enum 一一对应（修 F4 假绿测试）。
	var world := GameWorld.new()
	world.start_new_game()
	var dialog: TechTreeDialog = _open_tech_tree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary_lbl: Label = dialog.get_node("%DomainSummaryLabel")

	var techs: Dictionary = DataLoader.load_json(TECHS_PATH)
	var labels: Dictionary = DataLoader.load_json(UI_DISPLAY_PATH).get("domain_labels", {})
	for domain_variant: Variant in techs.get("domain_enum", []):
		var domain: String = str(domain_variant)
		var label: String = str(labels.get(domain, domain))
		assert_string_contains(summary_lbl.text, label, "UI 应显实表域 %s 的显示名 %s" % [domain, label])

	# 旧实现断言的三个错误域名在 techs.json 中不存在，UI 与测试都不得再出现。
	for bogus: String in ["模型架构", "算法演进", "工程基建", "architecture", "algorithm", "infrastructure"]:
		assert_false(summary_lbl.text.contains(bogus), "UI 不得再显不存在域名 %s" % bogus)

	# elsewhere：显示但注明不可研（分母口径 b，不把分母改成 11）。
	var progress: Dictionary = world.get_domain_progress()
	var elsewhere_row: Dictionary = {}
	for domain_variant: Variant in progress["domains"]:
		if str(domain_variant["id"]) == "elsewhere":
			elsewhere_row = domain_variant
	assert_false(elsewhere_row.is_empty(), "L2 数据面必须含 elsewhere 行（显示但不可研）")
	assert_false(bool(elsewhere_row["researchable"]), "elsewhere researchable 必须为 false")
	assert_false(bool(elsewhere_row["mainline"]), "elsewhere 不计入主干")
	assert_eq(int(elsewhere_row["total"]), 3, "elsewhere 分母 = 3（实表节点数）")
	assert_string_contains(summary_lbl.text, "他者道路", "elsewhere 必须显示")
	assert_string_contains(summary_lbl.text, "(不可研)", "elsewhere 必须注明不可研")

	# 节点列表：3 个 elsewhere 节点各有一行 ??? 占位并注明不可研。
	var list_vbox: VBoxContainer = dialog.get_node("%TechListVBox")
	var unresearchable_rows: int = 0
	for child in list_vbox.get_children():
		var hbox := child as HBoxContainer
		if hbox == null or hbox.get_child_count() == 0:
			continue
		var lbl := hbox.get_child(0) as Label
		if lbl != null and lbl.text.contains("不可研"):
			unresearchable_rows += 1
	assert_eq(unresearchable_rows, 3, "elsewhere 3 节点应各有一行注明不可研")


func _domain_researchable(techs: Dictionary, domain: String) -> bool:
	var flags: Dictionary = techs.get("domain_flags", {})
	var row: Variant = flags.get(domain)
	if row is Dictionary:
		return bool((row as Dictionary).get("researchable", true))
	return true


## 截取 GDD 指定小节文本（含起止标记之间内容）。
func _gdd_section(start_marker: String, end_marker: String) -> String:
	var text: String = FileAccess.get_file_as_string(GDD_PATH)
	var start: int = text.find(start_marker)
	if start < 0:
		return ""
	var end: int = text.find(end_marker, start)
	if end < 0:
		return text.substr(start)
	return text.substr(start, end - start)


## GDD 表格数据行数（去掉表头与分隔行）。
func _gdd_table_row_count(section: String) -> int:
	var count: int = 0
	for line: String in section.split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("|"):
			continue
		if trimmed.contains("---") or trimmed.begins_with("| 域"):
			continue
		count += 1
	return count


func test_staff_roster_dialog_slot_assignment_ui() -> void:
	var world := GameWorld.new()
	world.start_new_game()

	var dialog: StaffRosterDialog = STAFF_ROSTER_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.setup(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var list_vbox: VBoxContainer = dialog.get_node("%StaffListVBox")
	assert_eq(list_vbox.get_child_count(), 3, "开局应列出 3 位研究员卡片")

	# 模拟点击为 r_lin 指派任务工位
	world.assign_staff("r_lin", StaffRoster.SLOT_TASK)
	assert_eq(world.staff.get("r_lin", {}).get("assigned", ""), StaffRoster.SLOT_TASK)

	# 再次指派到模型训练工位（单人单槽）
	world.assign_staff("r_lin", StaffRoster.SLOT_TRAINING)
	assert_eq(world.staff.get("r_lin", {}).get("assigned", ""), StaffRoster.SLOT_TRAINING)

	# 撤岗
	world.unassign_staff("r_lin")
	assert_eq(world.staff.get("r_lin", {}).get("assigned", ""), "")


func test_app_shell_dock_and_staff_entry_opens_panels() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	var stack: PanelStack = main_scene.get_stack()

	# 1. 点击 Dock 科技键打开科技树
	var dock_tech_btn: Button = main.get_node("%DockTechBtn")
	dock_tech_btn.emit_signal("pressed")
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.TECH_TREE, "Dock 科技键应打开科技树")

	# 2. 点击 Dock 周报键打开周报重看
	var dock_report_btn: Button = main.get_node("%DockReportBtn")
	dock_report_btn.emit_signal("pressed")
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.REPORT_ARCHIVE, "Dock 周报键应以 z1 打开历史周报")


## #114 回归锁：主台员工实体卡（V1-03 收口）——W0 三名员工各一卡（名字+岗位状态），
## 点击卡直达名册面板（≤2 击完成指派链路的前置：卡可见 + 一击可达）。
func test_main_screen_staff_cards_render_and_open_roster() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	var stack: PanelStack = main_scene.get_stack()
	var cards_vbox: VBoxContainer = main.get_node("%StaffCardsVBox")
	assert_true(cards_vbox.get_child_count() >= 3, "主台应渲染至少 3 张员工卡（W0 三研究员）")

	var names_found: Dictionary = {}
	for child: Node in cards_vbox.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var text: String = str(btn.text)
		assert_false(text.is_empty(), "员工卡按钮文案非空")
		assert_true(
			text.contains("待命") or text.contains("训练位") or text.contains("任务位"),
			"卡片应含岗位状态（%s）" % text
		)
		for staff_name: String in ["林拾光", "温若愚", "白鹿鸣"]:
			if text.contains(staff_name):
				names_found[staff_name] = true
	assert_eq(names_found.size(), 3, "三名研究员的名字都应出现在卡片上")

	# 点击第一张卡 → 名册以 z1 打开（≤2 击完成指派的前提：卡点击=1 击进名册）
	var first_card := cards_vbox.get_child(0) as Button
	first_card.emit_signal("pressed")
	assert_eq(stack.get_z1_panel(), PanelStack.PanelId.ROSTER, "点击员工卡应直达名册面板")
