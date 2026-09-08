class_name TestRngStream
extends GutTest

## PR7 (issue #13) RNG 三域分域流专项测试
## 验证全部 3 个 [T] 验收点：
## 1. 同 seed 确定性断言（分域序列一致、互不串扰）
## 2. 新增随机域零迁移断言（开放 dict 加键）
## 3. 全局 RNG 消费点 grep=3 断言（rival_jitter / inspiration / event_roll）
##
## #92 追加 1 个 [T]：同域连续抽样去相关（防 `hash(String)` 直取低位退化）。


func test_acceptance_point_1_domain_isolation_and_determinism() -> void:
	# [T] 验收点 1：同 seed 确定性断言（分域序列一致、互不串扰）
	var stream_a := RngStream.new(42)
	var stream_b := RngStream.new(42)

	# 1.1 同 seed 下各域序列完全一致
	var a_rival_1: float = stream_a.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
	var b_rival_1: float = stream_b.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
	assert_eq(a_rival_1, b_rival_1, "同 seed 相同域首次随机数必须严格一致")

	var a_insp_1: float = stream_a.randf_domain(RngStream.DOMAIN_INSPIRATION)
	var b_insp_1: float = stream_b.randf_domain(RngStream.DOMAIN_INSPIRATION)
	assert_eq(a_insp_1, b_insp_1, "灵感域随机数完全一致")

	# 1.2 域隔离互不串扰：让 stream_a 在 event 域连续抽样 100 次
	for i in 100:
		stream_a.randf_domain(RngStream.DOMAIN_EVENT_ROLL)

	# 验证 stream_a 的 rival 域后续抽样与未经 event 污染的 stream_b 完全一致！
	var a_rival_2: float = stream_a.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
	var b_rival_2: float = stream_b.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
	assert_eq(a_rival_2, b_rival_2, "其他域大量抽样绝不影响目标域确定性序列（零串扰）")


func test_acceptance_point_2_zero_migration_open_dict() -> void:
	# [T] 验收点 2：新增随机域零迁移断言（开放 dict 加键）
	var stream := RngStream.new(100)
	stream.randf_domain(RngStream.DOMAIN_RIVAL_JITTER)
	stream.randf_domain(RngStream.DOMAIN_INSPIRATION)

	var saved_dict := stream.to_save()
	assert_eq(saved_dict["root_seed"], 100)
	assert_eq(saved_dict[RngStream.DOMAIN_RIVAL_JITTER], 1)
	assert_eq(saved_dict[RngStream.DOMAIN_INSPIRATION], 1)

	# 模拟未来版本新增 "recruit" 域（DR-029 A-6 加键零迁移）
	saved_dict["recruit"] = 5

	var fresh_stream := RngStream.new()
	fresh_stream.restore(saved_dict)

	assert_eq(fresh_stream.get_counter("recruit"), 5, "新域计数器正确恢复")
	assert_eq(fresh_stream.get_counter(RngStream.DOMAIN_EVENT_ROLL), 0, "未包含域缺省为 0")


func test_acceptance_point_3_grep_three_consumption_points() -> void:
	# [T] 验收点 3：全局 RNG 消费域常量数量恰为 3
	assert_eq(RngStream.REGISTERED_DOMAINS.size(), 3, "MVP 官方登记消费域恰 3 处")
	assert_true(RngStream.REGISTERED_DOMAINS.has("rival_jitter"))
	assert_true(RngStream.REGISTERED_DOMAINS.has("inspiration"))
	assert_true(RngStream.REGISTERED_DOMAINS.has("event_roll"))


func test_domain_samples_are_decorrelated() -> void:
	# [T] #92：同域连续抽样去相关（防 `hash(String)` 直取低位的退化回归）
	var stream := RngStream.new(42)
	var samples: Array[float] = []
	for i: int in range(64):
		samples.append(stream.randf_domain(RngStream.DOMAIN_EVENT_ROLL))
	var min_gap: float = 1.0
	for i: int in range(1, samples.size()):
		min_gap = minf(min_gap, absf(samples[i] - samples[i - 1]))
	assert_gt(min_gap, 1e-6, "同域相邻抽样必须去相关（最小间隔 %.9f）" % min_gap)
	var buckets: Dictionary = {}
	for v: float in samples:
		buckets[int(v * 10.0)] = true
	assert_gte(buckets.size(), 4, "同域连续抽样应覆盖多个十分位（实测 %d 个）" % buckets.size())
	# 单局命中率落在二项带内：p=0.35、n=1000 → 期望 350，容差 ±80（旧实现恒 0 或 1000）
	var hit_stream := RngStream.new(20260908)
	var hits: int = 0
	for i: int in range(1000):
		if hit_stream.hit_domain(RngStream.DOMAIN_EVENT_ROLL, 0.35):
			hits += 1
	assert_between(hits, 270, 430, "同 seed 1000 次 hit(0.35) 应落在二项带内（实测 %d）" % hits)
