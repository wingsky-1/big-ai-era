extends GutTest
## #139 ChipYard 档位测试（验收点 2/3/4 逐字用例名）：
## - test_tier_table_consistency：档位 T0-T2 画像与 chips.json 一致（
##   T1 12 万/T2 40 万，供给 8/16/32）——读表断言，真源=chips-spec D.2；
## - test_tier_quality_monotonic：品质分跨档单调（G13：算力权重 0.50；
##   护栏=算力维严格递增 + 品质分跨档不降）；
## - test_tier_and_budget_validation：训练启动档位+卡时双条件拒绝各显原因
##   （档位侧=ChipYard.get_tier_eligibility；卡时侧=Resources.consume
##   拒绝 missing；#140 训练启动把两因拼装——本单分别断言两因单一源）。
## 表加载：ChipYard._init 读 res://src/data/chips.json（真表）。

const TIER_T0: String = "t0"
const TIER_T1: String = "t1"
const TIER_T2: String = "t2"

var _yard: ChipYard


func before_each() -> void:
	_yard = ChipYard.new()
	autofree(_yard)


func test_tier_table_consistency() -> void:
	# 验收点 3：档位 T0-T2 画像与 chips.json 一致（T1 12 万/T2 40 万，供给 16/32）
	var table := DataLoader.load_json("res://src/data/chips.json")
	var tiers: Dictionary = table["chip_tiers"]
	# T0：供给 8 零购买费；T1：供给 16、价 12 万；T2：供给 32、价 40 万
	assert_eq(int((tiers[TIER_T0] as Dictionary)["supply"]), 8, "T0 供给 8（表）")
	assert_eq(int((tiers[TIER_T0] as Dictionary)["price"]), 0, "T0 零购买费（表）")
	assert_eq(int((tiers[TIER_T1] as Dictionary)["supply"]), 16, "T1 供给 16（表）")
	assert_eq(int((tiers[TIER_T1] as Dictionary)["price"]), 120000, "T1 价 12 万（表）")
	assert_eq(int((tiers[TIER_T2] as Dictionary)["supply"]), 32, "T2 供给 32（表）")
	assert_eq(int((tiers[TIER_T2] as Dictionary)["price"]), 400000, "T2 价 40 万（表）")
	# 类读表一致（ChipYard 查询=表真源，不另存副本）
	assert_eq(_yard.get_supply(TIER_T0), 8, "T0 供给 8")
	assert_eq(_yard.get_supply(TIER_T1), 16, "T1 供给 16")
	assert_eq(_yard.get_supply(TIER_T2), 32, "T2 供给 32")
	assert_eq(_yard.get_price(TIER_T1), 120000, "T1 价 12 万")
	assert_eq(_yard.get_price(TIER_T2), 400000, "T2 价 40 万")
	# T3/T4 数据表占位（P1）：表行存在、供给量级 64/128、解锁面=树节点占位
	assert_true(tiers.has("t3") and tiers.has("t4"), "T3/T4 表行占位在")
	assert_eq(_yard.get_supply("t3"), 64, "T3 供给 64（占位行）")
	assert_eq(_yard.get_supply("t4"), 128, "T4 供给 128（占位行）")
	assert_false(
		_yard.get_unlock_node("t3").is_empty() and _yard.get_unlock_node("t4").is_empty(),
		"T3/T4 解锁节点占位 id 非空（树批补行）",
	)


func test_tier_quality_monotonic() -> void:
	# 验收点 4：品质分跨档单调（G13：算力权重 0.50；防 T4<T2 升档降级灾难）
	var table := DataLoader.load_json("res://src/data/chips.json")
	var weights: Dictionary = table["chip_ndim_weight"]
	assert_eq(
		float(weights.get("compute", 0.0)),
		0.5,
		"算力权重=0.50（G13 冻结，护栏跨档单调）",
	)
	var tiers: Dictionary = table["chip_tiers"]
	var order: Array = tiers["_order"]
	var prev_score := -1.0
	var prev_compute := -1
	var prev_index := 0
	for i: int in order.size():
		var tier_key := str(order[i])
		var row: Dictionary = tiers[tier_key]
		var ndim: Dictionary = row["ndim"]
		var compute := int(ndim["compute"])
		var score := _yard.get_quality_score(tier_key)
		# 算力维跨档严格递增（高档算力猛）
		if i > 0:
			assert_true(
				compute > prev_compute,
				"算力维跨档严格递增（%s %d > %s %d）" % [tier_key, compute, str(order[i - 1]), prev_compute],
			)
			# 品质分跨档单调不降（G13 护栏：算力权重 ≥0.50 保单调）
			assert_true(
				score >= prev_score,
				"品质分跨档单调不降（%s %.1f >= %s %.1f）" % [tier_key, score, str(order[i - 1]), prev_score],
			)
		prev_score = score
		prev_compute = compute
		prev_index = i
	# 刻意 trade-off 非单调：能效维/成本维不随档位单调升（低档能效高）
	var eff_t0 := int((tiers[TIER_T0] as Dictionary)["ndim"]["eff"])
	var eff_t2 := int((tiers[TIER_T2] as Dictionary)["ndim"]["eff"])
	assert_true(eff_t0 > eff_t2, "能效刻意 trade-off（T0 85 > T2 65，低档能效高）")
	var cost_t1 := int((tiers[TIER_T1] as Dictionary)["ndim"]["cost"])
	var cost_t2 := int((tiers[TIER_T2] as Dictionary)["ndim"]["cost"])
	assert_true(cost_t1 > cost_t2, "成本维随档位降（高档贵但性价比维降低=口径）")


func test_tier_and_budget_validation() -> void:
	# 验收点 2：训练启动档位+卡时双条件拒绝各显原因
	# 档位侧：教学迷你基座（required=""）恒过；T1 门槛在 T0 不足=拒绝显原因；
	# 卡时侧：Resources.consume 超供给=拒绝带 missing（#140 训练启动拼装双因）
	var eligible_free := _yard.get_tier_eligibility("")
	assert_true(eligible_free.ok, "无档位要求（迷你基座）恒过")
	var blocked_tier := _yard.get_tier_eligibility(TIER_T1)
	assert_false(blocked_tier.ok, "T1 门槛在 T0 拒绝")
	assert_false(str(blocked_tier.get("reason", "")).is_empty(), "档位不足拒绝带原因")
	assert_eq(str(blocked_tier.get("owned_tier", "")), TIER_T0, "拒绝载荷当前档=T0")
	assert_eq(str(blocked_tier.get("required_tier", "")), TIER_T1, "拒绝载荷要求档=T1")
	# 卡时侧：预算账本在 Resources（供给 provider 注入档位供给）
	var res := Resources.new(200000, 0)
	autofree(res)
	res.weekly_supply_provider = func() -> int: return _yard.get_supply(_yard.get_owned_tier())
	res.reset_weekly_card_hours()
	# 本周供给=T0=8：耗 8 过、再耗 1=超分配拒绝带 missing
	var ok_consume := res.consume_card_hours(8)
	assert_true(ok_consume.ok, "T0 供给 8：耗 8 通过")
	assert_eq(res.get_card_hours_remaining(), 0, "剩余 0")
	var over := res.consume_card_hours(1)
	assert_false(over.ok, "超分配拒绝")
	assert_eq(int(over.get("missing", 0)), 1, "拒绝带 missing=还差 1")
	assert_true(res.has_overdraw_hint(), "超分配提示位置位（提示层持久）")


func test_purchase_tier_chain_and_reasons() -> void:
	# 升档链 t0→t1→t2（T0-T2 实数据可购）；拒绝各显原因单一源
	# T0→T1：资金不足拒绝（missing）；足额通过
	var poor := _yard.purchase_next_tier(50000)
	assert_false(poor.ok, "现金不足拒绝升 T1")
	assert_eq(str(poor.get("reason", "")), ChipYard.REASON_NOT_ENOUGH_CASH, "原因=现金不足")
	assert_eq(_yard.get_owned_tier(), TIER_T0, "拒绝不改当前档")
	# 足额 12 万升 T1
	var bought1 := _yard.purchase_next_tier(120000)
	assert_true(bought1.ok, "足额升 T1")
	assert_eq(str(bought1.get("owned_tier", "")), TIER_T1, "当前档=T1")
	assert_eq(int(bought1.get("supply", 0)), 16, "新供给=16")
	# 已最高可购档（T2 之后=T3 树锁）——资金足但树未解锁=拒绝显原因
	var bought2 := _yard.purchase_next_tier(400000)
	assert_true(bought2.ok, "足额升 T2")
	assert_eq(_yard.get_owned_tier(), TIER_T2, "当前档=T2")
	var locked := _yard.purchase_next_tier(9999999)
	assert_false(locked.ok, "T3 树锁未解锁=拒绝")
	assert_eq(str(locked.get("reason", "")), ChipYard.REASON_UNLOCK_LOCKED, "原因=档位未解锁")
	# 解锁谓词注入后 T3 可购（表占位行完整=升档链数据齐）
	var unlock_ok := func(_node_id: String) -> bool: return true
	var bought3 := _yard.purchase_next_tier(1200000, unlock_ok)
	assert_true(bought3.ok, "树解锁后升 T3")
	assert_eq(_yard.get_owned_tier(), "t3", "当前档=T3")
	assert_eq(_yard.get_supply("t3"), 64, "T3 供给 64")


func test_overdraw_hint_weeks_estimate() -> void:
	# "约 Y 周够"估算（chips-spec D.2：Y=下一档价差÷周净能力；能力 ≤0=保底 1）
	# 当前 T0→T1 价差 12 万：周净 3 万 → 4 周；周净 0 → 1（不承诺 0 周）
	var weeks := _yard.estimate_weeks_to_upgrade(30000)
	assert_eq(weeks, 4, "T1 价 12 万÷周净 3 万=4 周够")
	assert_eq(_yard.estimate_weeks_to_upgrade(0), 1, "周净 0=保底 1 周（不承诺 0）")
	# 已最高可购档（升 T3 被树锁仍可估算 T3 价差；直接估最高档 t4→无下一档=1）
	assert_true(_yard.estimate_weeks_to_upgrade(100000) >= 1, "Y 估算恒 ≥1")
