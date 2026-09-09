extends GutTest
## #130 staff.json 数据表断言（#128 schema 框架挂载）：
## 键名拼写真源=staff-spec.md D.1/D.2 + C.4（精确拼写，缺/多余键都报）；
## 初始 4 人/岗位矩阵/状态带/观察句绑定结构断言；护栏跟键走（D6）。

const STAFF_PATH: String = "res://src/data/staff.json"

## staff.json 顶层键（spec D.2 数值键 + D.1 结构块；_ 前缀元数据键豁免比对）
const SOURCE_KEYS: Array[String] = [
	"staff_start_count",
	"staff_attr_base_min",
	"staff_attr_base_max",
	"staff_attr_growth_per_project",
	"staff_state_weights",
	"staff_state_modifier",
	"staff_observation_pool",
	"staff_roles",
	"staff_ndim_map",
	"staff_initial_roster",
	"staff_collab_same",
	"staff_collab_adjacent",
	"staff_collab_complement",
	"staff_collab_adjacent_table",
]
## 数值键（须全带内嵌护栏 _bounds 声明）
const NUMERIC_KEYS: Array[String] = [
	"staff_start_count",
	"staff_attr_base_min",
	"staff_attr_base_max",
	"staff_attr_growth_per_project",
	"staff_collab_same",
	"staff_collab_adjacent",
	"staff_collab_complement",
]

const STAFF_SCHEMA: Dictionary = {
	"staff_start_count": {"type": "int"},
	"staff_attr_base_min": {"type": "int"},
	"staff_attr_base_max": {"type": "int"},
	"staff_attr_growth_per_project": {"type": "float"},
	"staff_state_weights": {"type": "dict"},
	"staff_state_modifier": {"type": "dict"},
	"staff_observation_pool": {"type": "array"},
	"staff_roles": {"type": "dict"},
	"staff_ndim_map": {"type": "dict"},
	"staff_initial_roster": {"type": "dict"},
	"staff_collab_same": {"type": "float"},
	"staff_collab_adjacent": {"type": "float"},
	"staff_collab_complement": {"type": "float"},
	"staff_collab_adjacent_table": {"type": "dict"},
}

## 岗位矩阵真源键（numerics-master §五：research/eval/data/engineering 四岗）
const ROLE_KEYS: Array[String] = ["research", "eval", "data", "engineering"]
## 属性四维真源键（numerics-master §1.3 员工属性→产物维映射表）
const ATTR_KEYS: Array[String] = ["theory", "engineering", "data", "communication"]
## 三态键（staff-spec D.2 staff_state_weights/modifier 行；A.3 专注/摸鱼/灵感）
const STATE_KEYS: Array[String] = ["focus", "slacking", "inspired"]


func test_staff_table_loads_and_validates() -> void:
	var table := DataLoader.load_json(STAFF_PATH)
	assert_false(table.is_empty(), "staff.json 可加载")
	var result := DataSchema.validate_table(table, STAFF_SCHEMA)
	assert_true(result.ok, "staff.json schema 校验全过: %s" % str(result.errors))


func test_staff_numeric_keys_inline_bounds_present() -> void:
	var table := DataLoader.load_json(STAFF_PATH)
	var result := DataSchema.validate_inline_bounds(table, NUMERIC_KEYS)
	assert_true(result.ok, "staff.json 数值键全部带内嵌护栏: %s" % str(result.errors))


func test_staff_key_spelling_matches_source() -> void:
	var table := DataLoader.load_json(STAFF_PATH)
	var result := DataSchema.validate_key_spelling(table, SOURCE_KEYS)
	assert_true(
		result.ok,
		"staff.json 键名拼写与 staff-spec D.1/D.2 一致: %s" % str(result.errors),
	)


func test_staff_state_weights_structure() -> void:
	# 三态权重键精确存在（A.3 三态；权重和=1 且每态>0）
	var table := DataLoader.load_json(STAFF_PATH)
	var weights: Dictionary = table["staff_state_weights"]
	assert_eq(weights.keys().size(), STATE_KEYS.size(), "状态权重恰三态")
	var total := 0.0
	for state_key: String in STATE_KEYS:
		assert_true(
			weights.has(state_key),
			"staff_state_weights 缺三态键 %s" % state_key,
		)
		var value := float(weights[state_key])
		assert_true(value > 0.0, "状态权重必须 >0（%s=%.3f）" % [state_key, value])
		total += value
	assert_almost_eq(total, 1.0, 0.0001, "三态权重和=1（%.3f）" % total)
	# 分布带护栏（staff-spec D.2 建议行：0.60/0.25/0.15 ∈ 0.55–0.65/0.20–0.30/0.10–0.20）
	assert_true(
		float(weights["focus"]) >= 0.55 and float(weights["focus"]) <= 0.65,
		"专注权重 ∈[0.55,0.65]（表值 %.3f）" % float(weights["focus"]),
	)
	assert_true(
		float(weights["slacking"]) >= 0.20 and float(weights["slacking"]) <= 0.30,
		"摸鱼权重 ∈[0.20,0.30]（表值 %.3f）" % float(weights["slacking"]),
	)
	assert_true(
		float(weights["inspired"]) >= 0.10 and float(weights["inspired"]) <= 0.20,
		"灵感权重 ∈[0.10,0.20]（表值 %.3f）" % float(weights["inspired"]),
	)


func test_staff_state_modifier_structure() -> void:
	# 状态→产出带（D.2 staff_state_modifier 行：全局 ≤±10% 与任务波动同量级）
	var table := DataLoader.load_json(STAFF_PATH)
	var modifier: Dictionary = table["staff_state_modifier"]
	assert_eq(modifier.keys().size(), STATE_KEYS.size(), "状态乘数带恰三态")
	for state_key: String in STATE_KEYS:
		var band: Dictionary = modifier[state_key]
		assert_true(band.has("min") and band.has("max"), "带结构含 min/max（%s）" % state_key)
		var min_v := float(band["min"])
		var max_v := float(band["max"])
		assert_true(min_v < max_v, "带须 min<max（%s）" % state_key)
		assert_true(min_v >= 0.9, "带下限 ≥0.90（%s=%.3f）" % [state_key, min_v])
		assert_true(max_v <= 1.1, "带上限 ≤1.10（%s=%.3f）" % [state_key, max_v])


func test_staff_observation_pool_keys_exist_in_texts() -> void:
	# C.4 观察句 6 句：staff.json 只存 texts.json 文案键绑定（id 绑定；禁重复建键）
	var table := DataLoader.load_json(STAFF_PATH)
	var texts := DataLoader.load_json("res://src/data/texts.json")
	var pool: Array = table["staff_observation_pool"]
	assert_eq(pool.size(), 6, "观察句池=6 句（staff-spec C.4 示例池）")
	for i: int in pool.size():
		var key := str(pool[i])
		assert_true(
			texts.has(key),
			"观察句绑定键 %s 须已存在 texts.json（#124 已落盘，禁重复建键）" % key,
		)


func test_staff_role_matrix_structure() -> void:
	# 岗位矩阵表（numerics-master §五 精确系数；四岗 × 四维）
	var table := DataLoader.load_json(STAFF_PATH)
	var roles: Dictionary = table["staff_roles"]
	assert_eq(roles.keys().size(), ROLE_KEYS.size(), "岗位恰四类（G3 直接 4 岗）")
	for role_key: String in ROLE_KEYS:
		var role_def: Dictionary = roles[role_key]
		assert_true(
			role_def.has("name_key") and role_def.has("attr_coef"),
			"岗位定义含 name_key/attr_coef（%s）" % role_key,
		)
		assert_true(
			str(role_def["name_key"]).begins_with("staff_role_"),
			"岗位文案键前缀 staff_role_（%s）" % role_key,
		)
		var coefs: Dictionary = role_def["attr_coef"]
		assert_eq(coefs.keys().size(), ATTR_KEYS.size(), "岗位矩阵四维齐（%s）" % role_key)
		for attr_key: String in ATTR_KEYS:
			assert_true(coefs.has(attr_key), "岗位矩阵缺维 %s（%s）" % [attr_key, role_key])


func test_staff_initial_roster_structure() -> void:
	# 初始 4 人表（D.1 staff.json 初始员工表）：行=员工 id，含 name/role/attrs/
	# observation_pool_index；人数=staff_start_count（E1 表驱动）
	var table := DataLoader.load_json(STAFF_PATH)
	var start_count := int(table["staff_start_count"])
	assert_eq(start_count, 4, "staff_start_count 恒 4（制作人拍板，护栏 [4,4]）")
	var roster_def: Dictionary = table["staff_initial_roster"]
	var order: Array = roster_def["_order"]
	assert_eq(order.size(), start_count, "初始名册行数=staff_start_count")
	for staff_id: Variant in order:
		var entry: Dictionary = roster_def[staff_id]
		for field: String in ["name", "role", "attrs", "observation_pool_index"]:
			assert_true(
				entry.has(field),
				"初始员工 %s 缺字段 %s" % [str(staff_id), field],
			)
		assert_true(
			ROLE_KEYS.has(str(entry["role"])),
			"初始员工 %s 岗位 ∈ 四岗（%s）" % [str(staff_id), str(entry["role"])],
		)
		var attrs: Dictionary = entry["attrs"]
		for attr_key: String in ATTR_KEYS:
			assert_true(attrs.has(attr_key), "初始员工 %s 缺属性 %s" % [str(staff_id), attr_key])
		assert_true(
			(
				int(entry["observation_pool_index"]) >= 0
				and (
					int(entry["observation_pool_index"])
					< int(table["staff_observation_pool"].size())
				)
			),
			"初始员工 %s 观察句绑定 id 越界" % str(staff_id),
		)


func test_staff_guardrail_values_follow_spec() -> void:
	# 护栏跟键走：关键护栏与 spec D.2 断言列一致
	var table := DataLoader.load_json(STAFF_PATH)
	var bounds: Dictionary = table[DataSchema.BOUNDS_KEY]
	assert_almost_eq(float(bounds["staff_start_count"][0]), 4.0, 0.0001, "初始人数恒 4 护栏下限")
	assert_almost_eq(float(bounds["staff_start_count"][1]), 4.0, 0.0001, "初始人数恒 4 护栏上限")
	# 基础属性建议区间 40–70（按稀有度 35–75）；初始两强两中由 test_staff 行为断言
	assert_almost_eq(float(bounds["staff_attr_base_min"][0]), 35.0, 0.0001, "属性带下限护栏 ≥35")
	assert_almost_eq(float(bounds["staff_attr_base_max"][1]), 75.0, 0.0001, "属性带上限护栏 ≤75")


func test_staff_collab_keys_structure_and_guardrails() -> void:
	# #132 协作表结构（staff-spec D.2 三系数 G4 冻结值 + staff_collab_adjacent_table
	# 岗位相邻表 + staff_ndim_map 员工→产物维映射表（numerics §1.3））
	var table := DataLoader.load_json(STAFF_PATH)
	assert_almost_eq(float(table["staff_collab_same"]), 1.0, 0.0001, "同岗组合效率=1.0（恒基准）")
	var bounds: Dictionary = table[DataSchema.BOUNDS_KEY]
	assert_almost_eq(float(bounds["staff_collab_same"][0]), 1.0, 0.0001, "同岗护栏下限=1.0")
	assert_almost_eq(float(bounds["staff_collab_same"][1]), 1.0, 0.0001, "同岗护栏上限=1.0")
	var adjacent := float(table["staff_collab_adjacent"])
	var complement := float(table["staff_collab_complement"])
	# 表内数值序=严格序真源（护栏区间与 staff-spec D.2 建议行一致）
	assert_true(1.0 < adjacent and adjacent < complement, "表值序：同岗1.0<相邻<互补")
	assert_true(adjacent >= 1.06 and adjacent <= 1.10, "相邻系数 ∈[1.06,1.10]（表值 %.3f）" % adjacent)
	assert_true(
		complement >= 1.15 and complement <= 1.20, "互补系数 ∈[1.15,1.20]（表值 %.3f）" % complement
	)
	assert_almost_eq(float(bounds["staff_collab_adjacent"][0]), 1.06, 0.0001, "相邻护栏下限 1.06")
	assert_almost_eq(float(bounds["staff_collab_adjacent"][1]), 1.10, 0.0001, "相邻护栏上限 1.10")
	assert_almost_eq(float(bounds["staff_collab_complement"][0]), 1.15, 0.0001, "互补护栏下限 1.15")
	assert_almost_eq(float(bounds["staff_collab_complement"][1]), 1.20, 0.0001, "互补护栏上限 1.20")
	# 岗位相邻表：四岗行齐（键=staff_roles 同源）+ 对称 + 无自环（全连通由
	# CollabFactor.validate_adjacent_table + test_collab_order_strict 双断言）
	var adjacent_errors: Array = CollabFactor.validate_adjacent_table(table)
	assert_eq(adjacent_errors, [], "岗位相邻表结构合法（%s）" % str(adjacent_errors))
	# staff_ndim_map：属性四维行齐、每行含 paper/model、维名 ∈ architecture §4.2
	# 冻结 dim_ids（论文 4 维 novelty/rigor/impact/repro；模型 5 维
	# reasoning/knowledge/chat/speed/cost）——n_dims 测试面详细数值断言在
	# test_collab.gd::test_ndim_staff_source_mapping
	var ndim_map: Dictionary = table["staff_ndim_map"]
	var paper_dims: Array[String] = ["novelty", "rigor", "impact", "repro"]
	var model_dims: Array[String] = ["reasoning", "knowledge", "chat", "speed", "cost"]
	for attr_key: String in ATTR_KEYS:
		assert_true(ndim_map.has(attr_key), "staff_ndim_map 缺属性行 %s" % attr_key)
		var per_product: Dictionary = ndim_map[attr_key]
		assert_true(per_product.has("paper"), "staff_ndim_map 属性 %s 缺论文列" % attr_key)
		assert_true(per_product.has("model"), "staff_ndim_map 属性 %s 缺模型列" % attr_key)
		for dim: Variant in per_product["paper"] as Array:
			assert_true(paper_dims.has(str(dim)), "论文维 %s 非法（%s）" % [str(dim), attr_key])
		for dim: Variant in per_product["model"] as Array:
			assert_true(model_dims.has(str(dim)), "模型维 %s 非法（%s）" % [str(dim), attr_key])
