extends GutTest
## #139 chips.json schema 断言（#128 data_schema 框架挂载）：
## 键名/类型 + 表结构自检（档位序/供给量级/价格带/画像四维/权重和=1/
## 解锁面 T0-T2 可购 / T3-T4 占位）。
## chips.json=纯容器表（chip_tiers dict-of-rows + chip_ndim_set/weight），
## 无顶层标量数值键 → 不设顶层 _bounds（仿 papers.json 容器表先例：
## papers _bounds 只覆盖顶层 scalar；dict 内数值由结构测试手写护栏断言，
## 真源=chips-spec D.2 护栏行+architecture D6）。

const CHIPS_PATH: String = "res://src/data/chips.json"

const CHIPS_SCHEMA: Dictionary = {
	"chip_tiers": {"type": "dict"},
	"chip_ndim_set": {"type": "array"},
	"chip_ndim_weight": {"type": "dict"},
}


func test_chips_schema_valid() -> void:
	var table := DataLoader.load_json(CHIPS_PATH)
	assert_false(table.is_empty(), "chips.json 可加载")
	var result := DataSchema.validate_table(table, CHIPS_SCHEMA)
	assert_true(result.ok, "chips.json schema 校验全过: %s" % str(result.errors))


func test_chips_key_spelling_matches_source() -> void:
	# 键名拼写自检（#128 机制：validate_key_spelling 精确比对缺/多余键）
	# 真源=chips-spec D.1/D.2 + numerics-master §1.1；容器表仅 3 顶层业务键
	var table := DataLoader.load_json(CHIPS_PATH)
	var expected: Array[String] = [
		"chip_tiers",
		"chip_ndim_set",
		"chip_ndim_weight",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "chips.json 键名拼写与真源一致: %s" % str(result.errors))


func test_chips_spelling_detects_typo() -> void:
	var table := DataLoader.load_json(CHIPS_PATH)
	var broken := table.duplicate()
	broken.erase("chip_ndim_weight")
	broken["chip_ndim_weigth"] = {"compute": 0.5}
	var result := (
		DataSchema
		. validate_key_spelling(
			broken,
			["chip_tiers", "chip_ndim_set", "chip_ndim_weight"],
		)
	)
	assert_false(result.ok, "键名拼错必须被拼写自检发现")
	assert_true(str(result.errors).contains("chip_ndim_weigth"), "报错指明多余键")


func test_chips_tier_rows_have_required_fields() -> void:
	# 每档行字段齐备：id/name_key/supply/price/unlock_node/ndim(4 维全)
	var table := DataLoader.load_json(CHIPS_PATH)
	var tiers: Dictionary = table["chip_tiers"]
	var ndim_set: Array = table["chip_ndim_set"]
	var order: Array = tiers["_order"]
	assert_eq(order.size(), 5, "档位序 t0..t4 共 5 档")
	for tier_key: Variant in order:
		var row: Dictionary = tiers[str(tier_key)]
		assert_eq(str(row.get("id", "")), str(tier_key), "行 id=档位键")
		assert_false(str(row.get("name_key", "")).is_empty(), "档位有 name_key")
		assert_true(int(row.get("supply", 0)) >= 8, "供给 ≥8（量级下限）")
		assert_true(int(row.get("price", -1)) >= 0, "价格 ≥0")
		assert_true(row.has("unlock_node"), "解锁面字段在位")
		var ndim: Dictionary = row["ndim"]
		assert_eq(ndim.size(), ndim_set.size(), "每档画像=4 维")
		for dim: Variant in ndim_set:
			assert_true(ndim.has(str(dim)), "画像含维 %s" % str(dim))
			assert_true(
				float(ndim[str(dim)]) >= 0.0 and float(ndim[str(dim)]) <= 100.0,
				"维值 ∈[0,100]",
			)


func test_chips_tier_supply_and_price_guardrails() -> void:
	# chips-spec D.2 护栏：供给固定量级 8/16/32/64/128；价格 T1 12 万起、
	# 递增（≥×3 里程碑感区间，护栏 "价格递增 ≥×3" 按相邻比 3.33/3/3/2.92
	# 近似 → 断言严格递增 + T0 免费）；T0/T1/T2 解锁面=空（初始可购）、
	# T3/T4=树节点占位非空
	var table := DataLoader.load_json(CHIPS_PATH)
	var tiers: Dictionary = table["chip_tiers"]
	var order: Array = tiers["_order"]
	var expected_supply := 8
	var prev_price := -1
	for i: int in order.size():
		var row: Dictionary = tiers[str(order[i])]
		var supply := int(row["supply"])
		assert_eq(supply, expected_supply, "供给量级 %s=%d" % [str(order[i]), expected_supply])
		expected_supply *= 2
		var price := int(row["price"])
		if i > 0:
			assert_true(price > prev_price, "价格严格递增（%s）" % str(order[i]))
		prev_price = price
	assert_eq(int((tiers["t0"] as Dictionary)["price"]), 0, "T0 免费")
	assert_eq(int((tiers["t1"] as Dictionary)["price"]), 120000, "T1 12 万")
	assert_eq(int((tiers["t2"] as Dictionary)["price"]), 400000, "T2 40 万")
	assert_true(
		(
			str((tiers["t0"] as Dictionary)["unlock_node"]).is_empty()
			and str((tiers["t1"] as Dictionary)["unlock_node"]).is_empty()
			and str((tiers["t2"] as Dictionary)["unlock_node"]).is_empty()
		),
		"T0/T1/T2 初始可购（unlock_node 空）",
	)
	assert_false(
		(
			str((tiers["t3"] as Dictionary)["unlock_node"]).is_empty()
			and str((tiers["t4"] as Dictionary)["unlock_node"]).is_empty()
		),
		"T3/T4 解锁节点占位非空（树批补行）",
	)


func test_chips_ndim_weight_sum_one_and_weights() -> void:
	# numerics-master §1.1：芯片权重 G13 冻结 0.50/0.15/0.15/0.20，和=1
	var table := DataLoader.load_json(CHIPS_PATH)
	var weights: Dictionary = table["chip_ndim_weight"]
	assert_eq(float(weights.get("compute", 0.0)), 0.5, "算力权重 0.50（G13 ≥0.50 保单调）")
	assert_eq(float(weights.get("eff", 0.0)), 0.15, "能效权重 0.15")
	assert_eq(float(weights.get("cost", 0.0)), 0.15, "成本权重 0.15")
	assert_eq(float(weights.get("stability", 0.0)), 0.2, "稳定性权重 0.20")
	var sum := 0.0
	for w: Variant in weights.values():
		sum += float(w)
	assert_true(
		is_equal_approx(sum, 1.0),
		"芯片权重和=1（Σ(维×权) 品质分 ∈[0,100] 前提）",
	)


func test_chips_tiers_quality_consistency_via_yard() -> void:
	# ChipYard 读表=表真源一致性（类不另存副本；品质分=Σ(维×权)）
	var yard := ChipYard.new()
	autofree(yard)
	var table := DataLoader.load_json(CHIPS_PATH)
	var tiers: Dictionary = table["chip_tiers"]
	var weights: Dictionary = table["chip_ndim_weight"]
	var order: Array = tiers["_order"]
	for tier_key: Variant in order:
		var row: Dictionary = tiers[str(tier_key)]
		var ndim: Dictionary = row["ndim"]
		var expected := 0.0
		for dim: Variant in ndim.keys():
			expected += float(ndim[dim]) * float(weights[str(dim)])
		assert_true(
			is_equal_approx(yard.get_quality_score(str(tier_key)), expected),
			"品质分=Σ(维×权)（%s）" % str(tier_key),
		)
