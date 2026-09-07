class_name TestRngStream
extends GutTest

## PR7 (issue #13) RNG 三域分域流专项测试
## 验证全部 3 个 [T] 验收点：
## 1. 同 seed 确定性断言（分域序列一致、互不串扰）
## 2. 新增随机域零迁移断言（开放 dict 加键）
## 3. 全局 RNG 消费点 grep=3 断言（rival_jitter / inspiration / event_roll）


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
