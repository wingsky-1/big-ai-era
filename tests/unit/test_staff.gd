extends GutTest
## #130 staff 员工个体 unit 测试（staff-spec 验收点落地）：
## - test_staff_start_roster：初始 4 人属性/岗位与 staff.json 一致，两强两中
## - test_staff_state_week_granularity_and_pity：状态带周粒度/周内稳定/期望≈1.00±0.02/pity
## - test_observation_line_static_seed：观察句静态种子（同种子同员工同句不轮转）
## - test_staff_role_matrix：岗位矩阵表驱动（data 系数 1.25 非全矩阵唯一最高）
## 辅助：同种子双实例可复现（随机登记域纪律，rng.staff 消费可数）。

const STAFF_TABLE_PATH: String = "res://src/data/staff.json"
## 全局种子（装配用；任何正 int 均可，断言两侧用同一种子）
const TEST_SEED: int = 20260130

## staff.json 顶层键（供单测读表；与 test_data_schema_staff 同源）
const ATTR_KEYS: Array[String] = ["theory", "engineering", "data", "communication"]


func _load_staff_table() -> Dictionary:
	var table := DataLoader.load_json(STAFF_TABLE_PATH)
	assert_false(table.is_empty(), "staff.json 可加载（%s）" % STAFF_TABLE_PATH)
	return table


## 读表构造名册（注入真实 RngStream；同种子可复现）
func _make_roster(seed: int = TEST_SEED) -> Roster:
	var rng := RngStream.new()
	rng.setup(seed)
	return Roster.new(_load_staff_table(), rng)


## 由表初始名册行直接读期望定义（防测试与实现互相抄错：同一 JSON 真源）
func _expected_definition(staff_id: String) -> Dictionary:
	var table := _load_staff_table()
	var roster_def: Dictionary = table["staff_initial_roster"]
	return roster_def[staff_id]


## ===== DoD 用例 1：初始 4 人属性/岗位与 staff.json 一致，两强两中 =====
func test_staff_start_roster() -> void:
	var roster := _make_roster()
	assert_eq(roster.get_staff_count(), 4, "初始名册 4 人（staff_start_count=4）")
	assert_eq(roster.get_staff_ids(), ["s1", "s2", "s3", "s4"], "名册序=表 _order")
	# 逐人与表逐字段一致（属性/岗位/观察句绑定）
	for staff_id: String in roster.get_staff_ids():
		var expected: Dictionary = _expected_definition(staff_id)
		var view := roster.get_staff_view(staff_id)
		assert_eq(str(view["name"]), str(expected["name"]), "%s 姓名与表一致" % staff_id)
		var expected_role_key := str(expected["role"])
		assert_eq(
			str(view["role_key"]),
			expected_role_key,
			"%s 岗位与表一致（%s）" % [staff_id, expected_role_key],
		)
		assert_eq(
			int(view["observation_id"]),
			int(expected["observation_pool_index"]),
			"%s 观察句绑定与表一致" % staff_id,
		)
		var attrs: Dictionary = view["attrs"]
		for attr_key: String in ATTR_KEYS:
			assert_almost_eq(
				float(attrs[attr_key]),
				float((expected["attrs"] as Dictionary)[attr_key]),
				0.001,
				"%s 属性 %s 与表一致" % [staff_id, attr_key],
			)
	# 两强两中（staff-spec D.2 staff_attr_base 护栏行："初始 4 人两强两中（教学公平）"）：
	# 强=主属性 ≥60（强档，稀有度上沿）；中=主属性 40–59 且全维 ∈[40,60) 基础带。
	# 两强：s1(理论 56)… 以主属性排序取前 2 判强、后 2 判中——先按全维 40–60 带
	# 卡两强两中判据：主属性=岗位对应 attr_coef 最高的维（表驱动读矩阵，不硬编码）。
	var table := _load_staff_table()
	var roles: Dictionary = table["staff_roles"]
	var strongest: Array[String] = []
	var mid: Array[String] = []
	for staff_id: String in roster.get_staff_ids():
		var view := roster.get_staff_view(staff_id)
		var role_key := str(view["role_key"])
		var coefs: Dictionary = roles[role_key]["attr_coef"]
		# 主属性=岗位系数最高的维（data 1.25 / 其余 1.2 最高列）
		var main_dim := ""
		var best_coef := -1.0
		for attr_key: String in ATTR_KEYS:
			var coef := float(coefs[attr_key])
			if coef > best_coef:
				best_coef = coef
				main_dim = attr_key
		var main_value := float(view["attrs"][main_dim])
		if main_value >= 60.0:
			strongest.append(staff_id)
		else:
			mid.append(staff_id)
		assert_true(
			main_value >= 40.0,
			"%s 主属性 %s=%d 须 ≥40（属性带下限，防开局残废）" % [staff_id, main_dim, int(main_value)],
		)
	assert_eq(strongest.size(), 2, "两强：主属性 ≥60 恰 2 人（%s）" % str(strongest))
	assert_eq(mid.size(), 2, "两中：主属性 <60 恰 2 人（%s）" % str(mid))


## ===== DoD 用例 2：状态带周粒度/周内稳定/期望≈1.00±0.02/pity 生效 =====
func test_staff_state_week_granularity_and_pity() -> void:
	var roster := _make_roster()
	var staff_ids: Array[String] = roster.get_staff_ids()
	# 周粒度掷一次：每员工每周恰消费 1 个 rng.staff 样本（计数器差=人数）
	var rng_probe := RngStream.new()
	rng_probe.setup(TEST_SEED)
	# Roster 内部 _rng 已消费；此处用独立流按同一装配序复算：装配不消费 rng（观察句
	# 表驱动绑定零随机），首周掷点前 staff 域计数=0，掷一周后=4（每员工 1 样本）
	var roster_b := Roster.new(_load_staff_table(), rng_probe)
	var counter_before := rng_probe.get_counter("staff")
	assert_eq(counter_before, 0, "装配/构造零随机消费（观察句=表驱动静态绑定）")
	var week_payloads: Array = roster_b.roll_weekly_states()
	assert_eq(week_payloads.size(), 4, "每周掷点恰 4 个员工载荷")
	assert_eq(rng_probe.get_counter("staff"), 4, "周粒度掷一次：一周恰消费 4 个 staff 样本")
	# 周内稳定：掷点后不重掷——同周内重复查询状态/乘数不变
	var week_2_views: Array[Dictionary] = []
	for staff_id: String in staff_ids:
		var view: Dictionary = roster.get_staff_view(staff_id)
		var view2: Dictionary = roster.get_staff_view(staff_id)
		assert_eq(int(view["state"]), int(view2["state"]), "%s 周内状态稳定" % staff_id)
		assert_almost_eq(
			float(view["modifier"]),
			float(view2["modifier"]),
			0.0001,
			"%s 周内乘数稳定" % staff_id,
		)
		week_2_views.append(view)
	# 期望乘数 ≈1.00±0.02（rnd_staff_exp 护栏带 [0.98,1.02]）：单员工 20000 周长程模拟
	var long_rng := RngStream.new()
	long_rng.setup(TEST_SEED + 1)
	var long_roster := Roster.new(_load_staff_table(), long_rng)
	var staff: Staff = long_roster.get_staff("s3")
	var sum_mod := 0.0
	var weeks := 20000
	for i: int in weeks:
		staff.roll_state_week()
		sum_mod += staff.get_output_modifier()
	var mean_mod := sum_mod / float(weeks)
	assert_true(
		absf(mean_mod - 1.0) < 0.02,
		"状态带长程期望乘数 ≈1.00±0.02（实测 %.5f，n=%d）" % [mean_mod, weeks],
	)
	# pity 生效：连摸 ≤ pity_max-1（连 3 必转；摸鱼计数不越 pity 线）
	var rng_table: Dictionary = DataLoader.load_json("res://src/data/rng.json")
	var pity_max := int(rng_table["rnd_staff_pity"])
	assert_true(pity_max >= 2 and pity_max <= 3, "摸鱼保底 2–3 周（表值 %d）" % pity_max)
	var pity_rng := RngStream.new()
	pity_rng.setup(TEST_SEED + 2)
	var pity_roster := Roster.new(_load_staff_table(), pity_rng)
	var pity_staff: Staff = pity_roster.get_staff("s2")
	var max_streak := 0
	for i: int in 30000:
		pity_staff.roll_state_week()
		max_streak = maxi(max_streak, pity_staff.get_slack_streak())
	assert_true(
		max_streak < pity_max,
		"摸鱼保底生效：连击峰值 %d < pity_max %d（连 3 必转）" % [max_streak, pity_max],
	)
	# 保底周强制转出：摸鱼连续 2 周后第 3 周必不摸鱼（slacking 权重清零）
	var forced_rng := RngStream.new()
	forced_rng.setup(TEST_SEED + 3)
	var forced_roster := Roster.new(_load_staff_table(), forced_rng)
	var forced_staff: Staff = forced_roster.get_staff("s4")
	var forced_ok := false
	for i: int in 40000:
		forced_staff.roll_state_week()
		if forced_staff.get_slack_streak() == pity_max - 1:
			# 已连摸 pity-1 周：下周必转出（不摸鱼）
			forced_staff.roll_state_week()
			assert_ne(
				forced_staff.get_state(),
				CoreEnums.StaffState.SLACKING,
				"保底周强制不摸鱼（连 %d 必转）" % pity_max,
			)
			forced_ok = true
			break
	assert_true(forced_ok, "40000 周内必然出现连摸 %d 周触发保底场景" % (pity_max - 1))


## ===== DoD 用例 3：观察句静态种子（同种子同员工同句不轮转） =====
func test_observation_line_static_seed() -> void:
	# 静态种子绑定=构造即定，永不轮转：周掷点推进不改变观察句；同种子两局同句
	var roster_a := _make_roster(TEST_SEED)
	var roster_b := _make_roster(TEST_SEED)
	for staff_id: String in roster_a.get_staff_ids():
		var view_a: Dictionary = roster_a.get_staff_view(staff_id)
		var view_b: Dictionary = roster_b.get_staff_view(staff_id)
		assert_eq(
			int(view_a["observation_id"]),
			int(view_b["observation_id"]),
			"同种子同员工观察句 id 一致（%s）" % staff_id,
		)
		assert_eq(
			str(view_a["observation_text_key"]),
			str(view_b["observation_text_key"]),
			"同种子同员工观察句文案键一致（%s）" % staff_id,
		)
		# 同种子同员工同句：绑定确定且随周推进不轮转
		var sample: Staff = roster_a.get_staff(staff_id)
		var id_before: int = sample.get_observation_id()
		var key_before: String = sample.get_observation_text_key()
		for i: int in 520:
			sample.roll_state_week()
		assert_eq(
			sample.get_observation_id(),
			id_before,
			"%s 观察句 520 周后 id 不变（静态种子禁轮转）" % staff_id,
		)
		assert_eq(
			sample.get_observation_text_key(),
			key_before,
			"%s 观察句 520 周后文案键不变（静态种子禁轮转）" % staff_id,
		)
		# 文案键真源存在 texts.json（观察句=#124 落盘键，本单禁重复建键）
		assert_true(
			str(view_a["observation_text_key"]).begins_with("staff_observation_pool_"),
			"%s 观察句键名遵循池命名（%s）" % [staff_id, str(view_a["observation_text_key"])],
		)


## ===== DoD 用例 4：岗位矩阵表驱动（data 1.25 非全矩阵唯一最高） =====
func test_staff_role_matrix() -> void:
	var table := _load_staff_table()
	var roles: Dictionary = table["staff_roles"]
	var matrix: Dictionary = {}
	var data_attr := ""
	var data_coef := 0.0
	# 表驱动读全矩阵（数值真源=numerics-master §五，测试零硬编码系数）
	for role_key: String in roles.keys():
		var coefs: Dictionary = roles[role_key]["attr_coef"]
		matrix[role_key] = coefs
		for attr_key: String in ATTR_KEYS:
			var coef := float(coefs[attr_key])
			if role_key == "data" and attr_key == "data":
				data_attr = attr_key
				data_coef = coef
	assert_eq(data_attr, "data", "data 岗主属性=数据维")
	assert_almost_eq(data_coef, 1.25, 0.0001, "data 岗 data 系数=1.25（G4 修正）")
	# 唯一最高：data 系数 1.25 是全局唯一最大值（数值席修正：1.25 非全矩阵唯一最高）
	var max_coef := 0.0
	var max_count := 0
	for role_key: String in matrix.keys():
		for attr_key: String in ATTR_KEYS:
			var coef := float((matrix[role_key] as Dictionary)[attr_key])
			if coef > max_coef:
				max_coef = coef
				max_count = 1
			elif absf(coef - max_coef) < 0.0001:
				max_count += 1
	assert_almost_eq(max_coef, 1.25, 0.0001, "全局最高系数=1.25")
	assert_eq(max_count, 1, "1.25 为全矩阵唯一最高（防全员 data 岗恒优，G4）")
	# 表驱动可查：role_coef_for 从表读数与矩阵一致（代码走表、零硬编码）
	var roster := _make_roster()
	for staff_id: String in roster.get_staff_ids():
		var staff: Staff = roster.get_staff(staff_id)
		var role_key := Staff.role_to_key(staff.get_role())
		var coefs: Dictionary = roles[role_key]["attr_coef"]
		for attr_key: String in ATTR_KEYS:
			assert_almost_eq(
				staff.role_coef_for(attr_key),
				float(coefs[attr_key]),
				0.0001,
				"%s %s 系数走表（%s.%s）" % [staff_id, attr_key, role_key, attr_key],
			)
