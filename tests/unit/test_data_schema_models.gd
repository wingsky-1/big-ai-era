extends GutTest
## #140 models.json schema 断言（#128 data_schema 框架挂载）：
## 键名/类型 + 表结构自检（六基座行/工期定值/卡时≤供给护栏/上限 1-4/
## 画像 5 维/权重和=1/checkpoint 位置 0.5）。
## models.json=容器表（model_bases dict-of-rows + model_ndim_set/weight +
## model_ckpt_progress 顶层标量），无其他顶层标量 → 无顶层 _bounds
## （仿 chips.json 容器表先例；数值护栏由结构测试手写断言，真源=
## models-spec D.2 + chips-spec 供给护栏）。

const MODELS_PATH: String = "res://src/data/models.json"

const MODELS_SCHEMA: Dictionary = {
	"model_ndim_set": {"type": "array"},
	"model_ndim_weight": {"type": "dict"},
	"model_ckpt_progress": {"type": "float"},
	"model_bases": {"type": "dict"},
}


func test_models_schema_valid() -> void:
	var table := DataLoader.load_json(MODELS_PATH)
	assert_false(table.is_empty(), "models.json 可加载")
	var result := DataSchema.validate_table(table, MODELS_SCHEMA)
	assert_true(result.ok, "models.json schema 校验全过: %s" % str(result.errors))


func test_models_key_spelling_matches_source() -> void:
	# 键名拼写自检（#128 机制：缺/多余键都报）；真源=models-spec D.2
	var table := DataLoader.load_json(MODELS_PATH)
	var expected: Array[String] = [
		"model_ndim_set",
		"model_ndim_weight",
		"model_ckpt_progress",
		"model_bases",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "models.json 键名拼写与真源一致: %s" % str(result.errors))


func test_models_base_rows_required_fields() -> void:
	# 每基座行字段齐备：id/name_key/domain/tier_required/duration_weeks/
	# card_hours_week/on_table_cap/unlock_node/ndim_profile(5 维全)
	var table := DataLoader.load_json(MODELS_PATH)
	var bases: Dictionary = table["model_bases"]
	var ndim_set: Array = table["model_ndim_set"]
	var order: Array = bases["_order"]
	assert_eq(order.size(), 6, "P0 六基座（迷你+五域各一）")
	for base_id: Variant in order:
		var row: Dictionary = bases[str(base_id)]
		assert_eq(str(row.get("id", "")), str(base_id), "行 id=基座键")
		assert_false(str(row.get("name_key", "")).is_empty(), "基座有 name_key")
		assert_true(int(row.get("duration_weeks", 0)) >= 4, "训练工期 ≥4 周（定值）")
		assert_true(int(row.get("card_hours_week", 0)) >= 1, "周耗 ≥1")
		assert_true(int(row.get("on_table_cap", 0)) >= 1, "上桌上限 ≥1")
		assert_true(row.has("unlock_node"), "解锁面字段在位")
		var profile: Dictionary = row["ndim_profile"]
		assert_eq(profile.size(), ndim_set.size(), "画像=5 维")
		for dim: Variant in ndim_set:
			assert_true(profile.has(str(dim)), "画像含维 %s" % str(dim))
			assert_true(
				float(profile[str(dim)]) >= 0.0 and float(profile[str(dim)]) <= 100.0,
				"画像维值 ∈[0,100]",
			)


func test_models_duration_card_cap_guardrails() -> void:
	# D.2 护栏：训练时长定值（不随随机）；周耗 ≤ 该档供给（供得上但供得紧）；
	# 上桌上限随档位单调 1→4；P0 可训三基座=初始开放、占位三基座=树解锁
	var table := DataLoader.load_json(MODELS_PATH)
	var bases: Dictionary = table["model_bases"]
	# 卡时周耗 ≤ 对应档位供给（chips-spec chip_train_burn 护栏）
	var chips := DataLoader.load_json("res://src/data/chips.json")
	var chips_tiers: Dictionary = chips["chip_tiers"]
	for base_id: Variant in bases["_order"]:
		var row: Dictionary = bases[str(base_id)]
		var tier := str(row["tier_required"])
		if tier.is_empty():
			continue
		var supply := int((chips_tiers[tier] as Dictionary)["supply"])
		assert_true(
			int(row["card_hours_week"]) <= supply,
			"周耗≤档位供给（%s：%d≤%d，永远供得上）" % [str(base_id), int(row["card_hours_week"]), supply],
		)
	# P0 可训三基座 unlock 空；占位三基座 unlock_node 非空（树解锁占位）
	for open_id: String in ["mini", "lingxi_1", "qingyu_1"]:
		assert_eq(str((bases[open_id] as Dictionary)["unlock_node"]), "", "%s 初始可训" % open_id)
	for locked_id: String in ["changhe_1", "zhibi_1", "tonggan_1"]:
		assert_false(
			str((bases[locked_id] as Dictionary)["unlock_node"]).is_empty(),
			"%s 树解锁占位（#144 接线）" % locked_id,
		)
	# 上桌上限随档位单调：mini(1) < lingxi/qingyu(2) < changhe/zhibi(3) < tonggan(4)
	assert_eq(int((bases["mini"] as Dictionary)["on_table_cap"]), 1, "迷你上限 1")
	assert_eq(int((bases["lingxi_1"] as Dictionary)["on_table_cap"]), 2, "灵犀上限 2")
	assert_eq(int((bases["tonggan_1"] as Dictionary)["on_table_cap"]), 4, "通感上限 4")


func test_models_ndim_weight_sum_one() -> void:
	# numerics-master §1.1：模型权重 0.25/0.2/0.15/0.2/0.2，和=1
	var table := DataLoader.load_json(MODELS_PATH)
	var weights: Dictionary = table["model_ndim_weight"]
	assert_true(NDims.weights_sum_to_one(weights), "模型权重和=1")
	assert_eq(float(weights.get("reasoning", 0.0)), 0.25, "推理权重 0.25")


func test_models_ckpt_progress_is_50() -> void:
	# model_ckpt_progress=0.5（checkpoint 50% 确定性位置；零掷骰零掉落）
	var table := DataLoader.load_json(MODELS_PATH)
	assert_eq(float(table["model_ckpt_progress"]), 0.5, "checkpoint 位置=50%")
