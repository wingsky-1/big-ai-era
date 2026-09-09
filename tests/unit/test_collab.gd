extends GutTest
## #132 协作组合系数 unit 测试（DoD 用例名逐字落盘 + 细化断言）。
## 被测对象=src/entities/collab.gd（协作系数计算器：双人岗位组合→同岗/相邻/
## 互补；岗位相邻表真源读 staff.json staff_collab_adjacent_table）+ 协作数值
## 应用侧 project.gd 当量推进（周耗缩短体感数据面）。
## 真源：staff-spec.md D.2（staff_collab_same/adjacent/complement=×1.0/×1.08/
## ×1.18 G4 冻结值；互补>相邻>同岗 严格序）+ numerics-master §五（岗位矩阵/
## 相邻表全连通/对角互补）+ staff-spec A.5（"两人一起做快 1 天"体感可见）。

const STAFF_TABLE_PATH: String = "res://src/data/staff.json"


## 读取 staff.json 整表（协作系数/相邻表真源）
func _load_staff_table() -> Dictionary:
	var table := DataLoader.load_json(STAFF_TABLE_PATH)
	assert_false(table.is_empty(), "staff.json 可加载（%s）" % STAFF_TABLE_PATH)
	return table


func test_collab_order_strict() -> void:
	# DoD：协作组合严格序 互补>相邻>同岗 且同岗=1.0；
	# 数值 ×1.0/×1.08/×1.18（表驱动：断言表值与组合分类映射严格单调）
	var table := _load_staff_table()
	var same := float(table["staff_collab_same"])
	var adjacent := float(table["staff_collab_adjacent"])
	var complement := float(table["staff_collab_complement"])
	assert_eq(same, 1.0, "同岗=1.0 基准（staff-spec D.2 恒 1.0）")
	assert_true(
		same < adjacent and adjacent < complement,
		"严格序 同岗(%.3f) < 相邻(%.3f) < 互补(%.3f)（表值序=严格序真源）" % [same, adjacent, complement],
	)
	assert_almost_eq(adjacent, 1.08, 0.0001, "相邻=×1.08（G4 冻结值）")
	assert_almost_eq(complement, 1.18, 0.0001, "互补=×1.18（G4 冻结值）")
	# 分类-数值映射一致性（表结构→分类→表系数闭环，禁代码另写数值）
	var pairs := {
		CollabFactor.KIND_SAME: same,
		CollabFactor.KIND_ADJACENT: adjacent,
		CollabFactor.KIND_COMPLEMENT: complement,
	}
	assert_eq(pairs.size(), 3, "三种组合分类齐备")
	# 相邻表结构自检（numerics-master §五：四岗行齐/对称/无自环/全连通）
	var errors: Array = CollabFactor.validate_adjacent_table(table)
	assert_eq(errors, [], "岗位相邻表结构合法（%s）" % str(errors))
	# 全连通断言：任意两岗必属 same/adjacent/complement 之一且系数严格单调——
	# 遍历全部 4×4 岗位对（含对称与同岗），分类不得出现 none/缺档
	var roles: Array[String] = ["research", "eval", "data", "engineering"]
	var seen_factor: Dictionary = {}
	for role_a: String in roles:
		for role_b: String in roles:
			var result := CollabFactor.pair_factor(role_a, role_b, table)
			assert_true(bool(result["known"]), "岗位对 %s×%s 计算已知（表驱动）" % [role_a, role_b])
			var kind := str(result["kind"])
			var factor := float(result["factor"])
			assert_true(kind in pairs, "岗位对 %s×%s 分类 ∈ 三档（%s）" % [role_a, role_b, kind])
			assert_almost_eq(factor, pairs[kind], 0.0001, "分类-数值同源（%s=%s）" % [kind, str(factor)])
			seen_factor[kind] = factor
	# 三档全可达（表连通性）：四岗两两组合必须能触达 same/adjacent/complement
	assert_eq(seen_factor.keys().size(), 3, "四岗两两组合三档全可达（相邻表全连通）")
	# 具体真源对照：研究×工程=互补（numerics-master §五 对角相异组示例）
	var comp_pair := CollabFactor.pair_factor("research", "engineering", table)
	assert_eq(str(comp_pair["kind"]), CollabFactor.KIND_COMPLEMENT, "研究×工程=互补（对角相异组真源）")
	assert_almost_eq(float(comp_pair["factor"]), complement, 0.0001, "互补系数 ×1.18")
	# 相邻直连示例：研究×评测=相邻（相邻表行直连）
	var adj_pair := CollabFactor.pair_factor("research", "eval", table)
	assert_eq(str(adj_pair["kind"]), CollabFactor.KIND_ADJACENT, "研究×评测=相邻（相邻表直连）")
	assert_almost_eq(float(adj_pair["factor"]), adjacent, 0.0001, "相邻系数 ×1.08")
	# 同岗示例：数据×数据=同岗 1.0
	var same_pair := CollabFactor.pair_factor("data", "data", table)
	assert_eq(str(same_pair["kind"]), CollabFactor.KIND_SAME, "数据×数据=同岗")
	assert_almost_eq(float(same_pair["factor"]), same, 0.0001, "同岗系数 ×1.0")


func test_collab_assign_rules() -> void:
	# DoD：双人上桌触发协作角标；重复派同一人/满员拒绝（协作角标=槽视图
	# collab_kind/collab_factor 数据面同源；重复/满员拒绝走既有枚举单因）。
	# 双人上桌触发组合角标：表驱动分类+系数经 TaskBoard 指派写入槽视图
	var table := _load_staff_table()
	var board := _make_board(table)
	var model := ModelProject.new("base_demo", "base_demo", 3, 2, 2)
	board.start_training(model, 0)
	# 单人：无协作角标（factor=1.0 / kind=none）
	assert_eq(board.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "s1 上桌成功")
	var view_single: Dictionary = board.get_slot_view(0)
	assert_eq(float(view_single["collab_factor"]), 1.0, "单人不触发协作（factor=1.0）")
	assert_eq(view_single["collab_kind"], CollabFactor.KIND_NONE, "单人无协作角标")
	# 双人（研究×工程=互补 ×1.18）：协作角标浮现（组合语义 staff-spec A.1）
	assert_eq(board.assign_staff("s4", 0), CoreEnums.SlotRejectReason.NONE, "s4（工程）上桌成功")
	var view_pair: Dictionary = board.get_slot_view(0)
	assert_eq(view_pair["assigned_count"], 2, "双人上桌")
	assert_eq(view_pair["collab_kind"], CollabFactor.KIND_COMPLEMENT, "双人触发协作角标（互补）")
	assert_almost_eq(float(view_pair["collab_factor"]), 1.18, 0.0001, "协作系数=互补 ×1.18")
	assert_eq(view_pair["assigned_roles"], {"s1": "research", "s4": "engineering"}, "槽视图含上桌者角色键")
	assert_eq(board.get_project(0).get_collab_factor(), 1.18, "协作系数写入 Project 接口位（单一写点）")
	# 重复派同一人（同一项目不可派同一人，staff-spec A.1 异常边界）
	assert_eq(
		board.assign_staff("s1", 0),
		CoreEnums.SlotRejectReason.STAFF_ALREADY_ASSIGNED,
		"重复派同一人=STAFF_ALREADY_ASSIGNED（既有枚举单因，禁新字符串）",
	)
	# 满员拒绝：seat_limit=2 坐满后第三人（s2）被拒（上桌上限=Project 声明值）
	assert_eq(
		board.assign_staff("s2", 0),
		CoreEnums.SlotRejectReason.SEAT_LIMIT_REACHED,
		"满员拒绝=SEAT_LIMIT_REACHED（上限来自 Project 声明，本批 ≤4）",
	)
	assert_eq(board.get_slot_view(0)["assigned_count"], 2, "满员拒绝后仍 2 人（成员不被破坏）")
	# 撤派回单人：协作角标消失（factor 回落 1.0/kind none）
	assert_eq(board.unassign_staff("s4", 0), CoreEnums.SlotRejectReason.NONE, "撤派 s4 成功")
	var view_back: Dictionary = board.get_slot_view(0)
	assert_eq(float(view_back["collab_factor"]), 1.0, "撤派后协作系数回落 1.0")
	assert_eq(view_back["collab_kind"], CollabFactor.KIND_NONE, "撤派后协作角标消失")


func test_collab_factor_table_driven_values() -> void:
	# 细化：数值零硬编码防线——代码不写 1.0/1.08/1.18 常量以外的数值真源：
	# 表改值（bounds 内合法）→ 分类映射自动跟随（表驱动回归面）
	var table := _load_staff_table()
	# 表复制改相邻系数（1.06 合法下限）→ pair_factor 输出跟随表值
	var tweaked := table.duplicate(true)
	tweaked["staff_collab_adjacent"] = 1.06
	var adj_result := CollabFactor.pair_factor("research", "eval", tweaked)
	assert_almost_eq(float(adj_result["factor"]), 1.06, 0.0001, "相邻系数跟随表值（表驱动）")
	assert_eq(str(adj_result["kind"]), CollabFactor.KIND_ADJACENT, "分类不受数值改动影响")
	# 对称性：pair_factor(a,b) == pair_factor(b,a)（无向组合）
	var forward := CollabFactor.pair_factor("engineering", "research", table)
	var backward := CollabFactor.pair_factor("research", "engineering", table)
	assert_eq(str(forward["kind"]), str(backward["kind"]), "岗位对对称（无向）")
	assert_almost_eq(float(forward["factor"]), float(backward["factor"]), 0.0001, "岗位对系数对称")
	# 防御：空表/未知岗位不抛错，回退 known=false 同岗 1.0 档
	var empty_table: Dictionary = {}
	var guarded := CollabFactor.pair_factor("research", "engineering", empty_table)
	assert_false(bool(guarded["known"]), "空表防御回退 known=false")
	assert_eq(float(guarded["factor"]), 1.0, "空表防御回退 1.0（不抛错）")
	assert_eq(str(guarded["kind"]), CollabFactor.KIND_SAME, "空表防御回退同岗档")


func test_project_collab_weeks_shrink_and_finish() -> void:
	# 细化：协作乘数应用（project.gd 当量推进）——双人互补上桌比单人早 1 周完成
	# （"两人一起做快 1 天"体感数据面；staff-spec A.5 [P]：组合角标+剩余周数缩短）。
	# 对照组设计：7 周工期模型，单/双人并行推进；互补 ×1.18 → 当量 7 周耗尽
	# 需 ceil(7/1.18)=6 周 < 单人 7 周（快 1 周，第 6 周结可见 剩1→剩0/完成）。
	var table := _load_staff_table()
	var solo := _make_board(table)
	solo.start_training(ModelProject.new("base_demo", "base_demo", 7, 2, 2), 0)
	assert_eq(solo.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "对照组 s1（研究）上桌")
	var pair := _make_board(table)
	pair.start_training(ModelProject.new("base_demo", "base_demo", 7, 2, 2), 0)
	assert_eq(pair.assign_staff("s1", 0), CoreEnums.SlotRejectReason.NONE, "协作组 s1 上桌")
	assert_eq(pair.assign_staff("s4", 0), CoreEnums.SlotRejectReason.NONE, "协作组 s4（工程）上桌")
	var pair_view: Dictionary = pair.get_slot_view(0)
	assert_eq(pair_view["collab_kind"], CollabFactor.KIND_COMPLEMENT, "协作角标=互补（双人触发）")
	assert_almost_eq(float(pair_view["collab_factor"]), 1.18, 0.0001, "协作系数=互补 ×1.18")
	assert_almost_eq(
		pair.get_project(0).get_collab_factor(),
		1.18,
		0.0001,
		"系数写入 Project 接口位（TaskBoard 唯一写方）",
	)
	# 第 1–5 周结：两板同推进 5 次，剩余周显示相同（保守 ceil 同源）。
	# week_tick()=TaskBoard 周结驱动（架构 §5.3 phase 2，返回完成载荷数组）
	for i: int in 5:
		solo.week_tick()
		pair.week_tick()
	assert_eq(int(solo.get_slot_view(0)["weeks_left"]), 2, "单人第 5 周结后剩 2 周")
	assert_eq(int(pair.get_slot_view(0)["weeks_left"]), 2, "双人第 5 周结后显示剩 2 周（保守承诺值）")
	# 第 6 周结：双人当量耗尽提前完成（剩 0 周），单人仍剩 1 周——快 1 天体感
	solo.week_tick()
	assert_eq(int(solo.get_slot_view(0)["weeks_left"]), 1, "单人第 6 周结后剩 1 周")
	pair.week_tick()
	assert_false(pair.is_running(0), "双人第 6 周结后完成（7 周工期 6 周干完=快 1 周）")
	assert_eq(
		pair.get_slot_state(0),
		CoreEnums.ProjectState.FINISHED_PENDING,
		"双人提前完成=FINISHED_PENDING",
	)
	assert_eq(int(pair.get_slot_view(0)["weeks_left"]), 0, "双人完成周剩余周数=0（缩短可见）")
	# 第 7 周结：单人才完成（对照组=无协作基准）
	solo.week_tick()
	assert_false(solo.is_running(0), "单人第 7 周结后完成（对照组耗时 7 周）")
	assert_eq(
		solo.get_slot_state(0),
		CoreEnums.ProjectState.FINISHED_PENDING,
		"单人完成=FINISHED_PENDING",
	)


## ---------- 夹具 ----------


## TaskBoard 夹具：4 员工全已知可派；岗位键=真实 staff.json staff_roles 同源
## 映射（研究 s1/评测 s2/数据 s3/工程 s4——初始名册岗位表真源）；注入 staff.json。
func _make_board(staff_table: Dictionary) -> TaskBoard:
	var board := TaskBoard.new()
	board.is_staff_known = func(staff_id: String) -> bool: return _role_of(staff_id) != ""
	board.is_staff_assignable = func(staff_id: String) -> bool: return _role_of(staff_id) != ""
	board.get_staff_role_key = func(staff_id: String) -> String: return _role_of(staff_id)
	board.staff_table = staff_table
	return board


## 员工→岗位映射（与 staff.json staff_initial_roster 同源；测试夹具行内直存）
func _role_of(staff_id: String) -> String:
	match staff_id:
		"s1":
			return "research"
		"s2":
			return "eval"
		"s3":
			return "data"
		_:
			return "engineering"


func test_ndim_staff_source_mapping() -> void:
	# DoD：员工属性→n 维映射表驱动（员工源 50% 语义=注释/接口预留，见 n_dims.gd
	# 类头注释+#141 布局表断言；本用例=属性×岗位适配表驱动映射的守恒/维可达/
	# 无代码维名断言）
	var table := _load_staff_table()
	assert_true(
		table.has("staff_ndim_map"),
		"staff.json 含员工→产物维映射表（numerics §1.3 真源键）",
	)
	var ndim_map: Dictionary = table["staff_ndim_map"]
	var attr_keys: Array[String] = ["theory", "engineering", "data", "communication"]
	assert_eq(ndim_map.keys().size(), attr_keys.size(), "映射表行=属性四维")
	var paper_dims: Array[String] = ["novelty", "rigor", "impact", "repro"]
	var model_dims: Array[String] = ["reasoning", "knowledge", "chat", "speed", "cost"]
	for attr_key: String in attr_keys:
		assert_true(ndim_map.has(attr_key), "映射表缺属性行 %s" % attr_key)
		var per_product: Dictionary = ndim_map[attr_key]
		assert_true(per_product.has("paper"), "属性 %s 含论文映射" % attr_key)
		assert_true(per_product.has("model"), "属性 %s 含模型映射" % attr_key)
		for dim: Variant in per_product["paper"] as Array:
			assert_true(paper_dims.has(str(dim)), "论文维 %s 须 ∈ architecture 冻结 4 维" % str(dim))
		for dim: Variant in per_product["model"] as Array:
			assert_true(model_dims.has(str(dim)), "模型维 %s 须 ∈ architecture 冻结 5 维" % str(dim))
	# 守恒断言：任意岗位均质员工（四维 100）总贡献=Σ_属性 属性值×系数×映射维数
	# （映射表把每属性拆到 n 个产物维，每维都加 属性×系数——总贡献=各维增益和，
	# 与表行数一致；防表改坏静默少算/多算）
	var attrs := _uniform_attrs()
	var role_keys: Array[String] = ["research", "eval", "data", "engineering"]
	for role_key: String in role_keys:
		var coefs: Dictionary = table["staff_roles"][role_key]["attr_coef"]
		for product_key: String in ["paper", "model"]:
			var expected_total := 0.0
			for attr_key: String in attr_keys:
				var dims: Array = ndim_map[attr_key][product_key]
				expected_total += 100.0 * float(coefs[attr_key]) * dims.size()
			var result := NDims.staff_contribution(attrs, role_key, product_key, table)
			assert_true(bool(result["known"]), "%s×%s 映射已知（表驱动）" % [role_key, product_key])
			assert_almost_eq(
				float(result["total"]),
				expected_total,
				0.0001,
				"守恒：%s 岗 %s 总贡献=Σ 属性×系数×维数（%.2f）" % [role_key, product_key, expected_total],
			)
			assert_false(result["contributions"].is_empty(), "%s×%s 贡献非空" % [role_key, product_key])
	# 真源数值对照（numerics §五矩阵 × §1.3 映射）：研究岗 100 理论 → 论文创新/影响 各 +120
	var research := (
		NDims
		. staff_contribution(
			{"theory": 100.0, "engineering": 0.0, "data": 0.0, "communication": 0.0},
			"research",
			"paper",
			table,
		)
	)
	var rc: Dictionary = research["contributions"]
	assert_almost_eq(float(rc.get("novelty", 0.0)), 120.0, 0.0001, "理论×研究岗1.2 → 论文创新 +120")
	assert_almost_eq(float(rc.get("impact", 0.0)), 120.0, 0.0001, "理论×1.2 → 论文影响 +120")
	assert_false(rc.has("repro"), "研究岗理论不映射论文复现维（映射表=唯一真源）")
	# 数据岗 data 系数 1.25（矩阵最高）→ 数据 100 映射论文严谨+复现 各 +125
	var data_staff := (
		NDims
		. staff_contribution(
			{"theory": 0.0, "engineering": 0.0, "data": 100.0, "communication": 0.0},
			"data",
			"paper",
			table,
		)
	)
	var dc: Dictionary = data_staff["contributions"]
	assert_almost_eq(float(dc.get("rigor", 0.0)), 125.0, 0.0001, "数据×数据岗1.25 → 严谨 +125")
	assert_almost_eq(float(dc.get("repro", 0.0)), 125.0, 0.0001, "数据×1.25 → 复现 +125")
	# 工程岗对模型：工程 100×1.2 → 速度/成本 各 +120
	var eng_staff := (
		NDims
		. staff_contribution(
			{"theory": 0.0, "engineering": 100.0, "data": 0.0, "communication": 0.0},
			"engineering",
			"model",
			table,
		)
	)
	var ec: Dictionary = eng_staff["contributions"]
	assert_almost_eq(float(ec.get("speed", 0.0)), 120.0, 0.0001, "工程×工程岗1.2 → 速度 +120")
	assert_almost_eq(float(ec.get("cost", 0.0)), 120.0, 0.0001, "工程×1.2 → 成本 +120")
	# 防御面：缺表/未知岗位/未知产物（芯片未冻结）/零属性 → 空贡献不抛错
	var guarded := NDims.staff_contribution({}, "research", "paper", table)
	assert_false(bool(guarded["known"]), "零属性员工=防御 known=false")
	var unknown_role := NDims.staff_contribution(attrs, "poet", "paper", table)
	assert_false(bool(unknown_role["known"]), "未知岗位=防御 known=false")
	var unknown_product := NDims.staff_contribution(attrs, "research", "chip", table)
	assert_false(bool(unknown_product["known"]), "未冻结产物（芯片）=防御 known=false")
	var no_table := NDims.staff_contribution(attrs, "research", "paper", {})
	assert_false(bool(no_table["known"]), "空表=防御 known=false")
	# role_coef 查询与 staff.json staff_roles.attr_coef 同源（详情页匹配度共用）
	assert_almost_eq(NDims.role_coef("data", "data", table), 1.25, 0.0001, "数据岗 data 系数 1.25")
	assert_almost_eq(NDims.role_coef("research", "theory", table), 1.2, 0.0001, "研究岗 theory 系数 1.2")
	assert_eq(NDims.role_coef("no_role", "theory", table), 0.0, "未知岗位系数=0")
	# 员工源 50% 语义文档侧断言：真源护栏文本未漂移（代码侧权重在 #141 布局表，
	# 本单零字面量——numerics §1.2 "员工来源为最大单项（50%）"）
	var numerics_text := FileAccess.get_file_as_string(
		"res://docs/blueprints/specs/numerics-master.md"
	)
	assert_true(
		numerics_text.contains("员工来源为最大单项（50%）"),
		"numerics-master §1.2 员工来源 50% 最大单项护栏仍在（合成批 #141 断言依据）",
	)


## 均质属性员工（四维同值 100：岗位适配 ×1.0 全属性时贡献总和可整除校验）
func _uniform_attrs() -> Dictionary:
	var attrs: Dictionary = {}
	for attr: String in ["theory", "engineering", "data", "communication"]:
		attrs[attr] = 100.0
	return attrs
