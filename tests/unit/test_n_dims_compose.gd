extends GutTest
## #141 n 维合成测试（验收点 1/2/3/4 逐字用例名收口）：
## - test_score_formula_and_sota_semantics：score 合成=加权和公开权重 ∈[0,100]
##   （sota 判定语义部分 #142 SotaBoard 收口；本单=score 合成域护栏）；
## - test_ndim_formula_all_products：n 维合成三产物同构（Σ(维×权) 与权重表
##   一致/权重和=1/维数数组化无写死——NdimProfiles 布局读表驱动）；
## - test_ndim_three_sources_weights：模型三源权重合法（staff 50%×tree 25%×
##   chip 25%，和=1 + 员工最大单项 ≥20% 护栏）；
## - test_model_ndim_weights_public：模型 5 维权重 0.25/0.20/0.15/0.20/0.20 公开。
## 真源：numerics-master §1.1/§1.2 + architecture-100 §4.2 + models-spec D.2。


func test_score_formula_and_sota_semantics() -> void:
	# score 合成=加权和公开权重 ∈[0,100]（模型 5 维）
	var model_layout := NdimProfiles.layout(NdimProfiles.PRODUCT_MODEL)
	assert_false(model_layout.is_empty(), "模型布局可解析")
	var weights: Dictionary = model_layout["weights"]
	# 全维满分 → 100；零分 → 0；单维满分 × 权
	var full := {
		"reasoning": 100.0, "knowledge": 100.0, "chat": 100.0, "speed": 100.0, "cost": 100.0
	}
	assert_almost_eq(NDims.weighted_sum(full, weights), 100.0, 0.001, "全维 100 → score=100")
	var zero := {"reasoning": 0.0, "knowledge": 0.0, "chat": 0.0, "speed": 0.0, "cost": 0.0}
	assert_almost_eq(NDims.weighted_sum(zero, weights), 0.0, 0.001, "全维 0 → score=0")
	var partial := {"reasoning": 100.0, "knowledge": 0.0, "chat": 0.0, "speed": 0.0, "cost": 0.0}
	assert_almost_eq(NDims.weighted_sum(partial, weights), 25.0, 0.001, "推理权重 0.25：单维 100 → 25")
	# compose 合成域 ∈[0,100]（随机组合不越界；saturate_clamp 收口）
	for i: int in 100:
		var sources := {
			"staff":
			{
				"reasoning": float(randi() % 101),
				"knowledge": float(randi() % 101),
				"chat": float(randi() % 101),
				"speed": float(randi() % 101),
				"cost": float(randi() % 101),
			},
			"tree":
			{
				"reasoning": float(randi() % 41),
				"knowledge": float(randi() % 41),
			},
			"chip":
			{
				"speed": float(randi() % 61),
				"cost": float(randi() % 61),
			},
		}
		var result := NDims.compose(model_layout["drivers"], sources, weights)
		assert_true(
			result.score >= 0.0 and result.score <= 100.0, "score∈[0,100]: %f" % result.score
		)
		assert_true(
			(
				NDims.saturate_clamp(result.score) >= 0.0
				and NDims.saturate_clamp(result.score) <= 100.0
			)
		)


func test_ndim_formula_all_products() -> void:
	# 三产物同构：每产物布局（dim_ids/weights）读表一致、权重和=1、维数数组化
	var product_rows := {
		NdimProfiles.PRODUCT_PAPER: {"dims": 4, "first_weight_sum": 1.0},
		NdimProfiles.PRODUCT_MODEL: {"dims": 5, "first_weight_sum": 1.0},
		NdimProfiles.PRODUCT_CHIP: {"dims": 4, "first_weight_sum": 1.0},
	}
	for product: String in NdimProfiles.all_products():
		var layout_data := NdimProfiles.layout(product)
		assert_false(layout_data.is_empty(), "布局可解析（%s）" % product)
		var dim_ids: Array = layout_data["dim_ids"]
		var weights: Dictionary = layout_data["weights"]
		assert_eq(
			dim_ids.size(),
			int(product_rows[product]["dims"]),
			"维数数组化与表一致（%s）" % product,
		)
		assert_true(NDims.weights_sum_to_one(weights), "权重和=1（%s）" % product)
		# 每维在权重表有对应（防 dim_ids 与 weights 漂移）
		for dim: Variant in dim_ids:
			assert_true(weights.has(str(dim)), "%s 维 %s 在权重表" % [product, str(dim)])


func test_ndim_three_sources_weights() -> void:
	# 模型三源权重合法（numerics §1.2：员工 50%×树 25%×芯片 25%）
	var model_layout := NdimProfiles.layout(NdimProfiles.PRODUCT_MODEL)
	var drivers: Dictionary = model_layout["drivers"]
	assert_almost_eq(float(drivers.get("staff", 0.0)), 0.5, 0.001, "员工源 50%")
	assert_almost_eq(float(drivers.get("tree", 0.0)), 0.25, 0.001, "树源 25%")
	assert_almost_eq(float(drivers.get("chip", 0.0)), 0.25, 0.001, "芯片源 25%")
	var check := NDims.validate_drivers(drivers)
	assert_true(check.ok, "三源权重合法（和=1+员工最大单项≥20%%）: %s" % str(check.errors))
	# 论文 drivers 同护栏合法（staff 0.5/tree 0.25/topic 0.25）
	var paper_drivers: Dictionary = NdimProfiles.layout(NdimProfiles.PRODUCT_PAPER)["drivers"]
	assert_true(NDims.validate_drivers(paper_drivers).ok, "论文三源权重合法")
	# 芯片无外部源（空 drivers=恒合法）
	var chip_drivers: Dictionary = NdimProfiles.layout(NdimProfiles.PRODUCT_CHIP)["drivers"]
	assert_true(NDims.validate_drivers(chip_drivers).ok, "芯片空 drivers=合法")
	# 防御：破坏性 drivers（和≠1/员工非最大）必须被护栏拦
	var broken := drivers.duplicate()
	broken["staff"] = 0.1
	assert_false(NDims.validate_drivers(broken).ok, "员工 <0.2 被护栏拦")
	var broken2 := drivers.duplicate()
	broken2["tree"] = 0.9
	assert_false(NDims.validate_drivers(broken2).ok, "员工非最大单项被拦")


func test_model_ndim_weights_public() -> void:
	# 模型 5 维权重公开：0.25/0.20/0.15/0.20/0.20（models-spec D.2 真源）
	var model_layout := NdimProfiles.layout(NdimProfiles.PRODUCT_MODEL)
	var weights: Dictionary = model_layout["weights"]
	assert_almost_eq(float(weights["reasoning"]), 0.25, 0.001, "推理 0.25")
	assert_almost_eq(float(weights["knowledge"]), 0.2, 0.001, "知识 0.20")
	assert_almost_eq(float(weights["chat"]), 0.15, 0.001, "对话 0.15")
	assert_almost_eq(float(weights["speed"]), 0.2, 0.001, "速度 0.20")
	assert_almost_eq(float(weights["cost"]), 0.2, 0.001, "成本 0.20")
	# 表真源一致（NdimProfiles 读表=唯一转换点）
	var table := DataLoader.load_json("res://src/data/models.json")
	var raw_weights: Dictionary = table["model_ndim_weight"]
	assert_eq(weights, raw_weights, "布局权重=表真源（无副本漂移）")


func test_compose_three_source_mix() -> void:
	# compose 三源混合语义：逐维 Σ(源值×源权重)，score=Σ(值×维权)
	var drivers := {"staff": 0.5, "tree": 0.25, "chip": 0.25}
	var sources := {
		"staff": {"reasoning": 80.0, "knowledge": 60.0},
		"tree": {"reasoning": 40.0},  # 树只强化推理维
		"chip": {"speed": 100.0, "cost": 50.0},
	}
	var weights := {"reasoning": 0.25, "knowledge": 0.2, "chat": 0.15, "speed": 0.2, "cost": 0.2}
	var result := NDims.compose(drivers, sources, weights)
	# reasoning = 80×0.5 + 40×0.25 + 0×0.25 = 50
	assert_almost_eq(float(result.values["reasoning"]), 50.0, 0.001, "推理维三源混合")
	# knowledge = 60×0.5 = 30（树/芯片无此维贡献）
	assert_almost_eq(float(result.values["knowledge"]), 30.0, 0.001, "知识维=员工源")
	# chat 维无任何源 → 0
	assert_almost_eq(float(result.values["chat"]), 0.0, 0.001, "对话维无源=0")
	# score = 50×0.25 + 30×0.2 + 0×0.15 + 25×0.2 + 12.5×0.2
	var expected := 50.0 * 0.25 + 30.0 * 0.2 + 0.0 * 0.15 + 25.0 * 0.2 + 12.5 * 0.2
	assert_almost_eq(result.score, expected, 0.001, "score=Σ(维×权)")
