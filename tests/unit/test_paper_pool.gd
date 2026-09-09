extends GutTest
## #133 论文选题池测试：域解锁谓词/随树扩展语义/对照表。
## DoD 用例名与 issue 逐字一致。

const PAPERS_PATH: String = "res://src/data/papers.json"


func test_topic_pool_expands_with_tree() -> void:
	var pool := PaperPool.new()
	autofree(pool)
	# 默认全解锁：五域全出题
	var domains_all := pool.get_available_domains()
	assert_eq(domains_all.size(), 5, "五域全解锁时全部可出题")
	assert_true(domains_all.has("align"), "含 align 域")
	assert_true(domains_all.has("multimodal"), "含 multimodal 域")
	# 域解锁谓词注入：锁掉 4 域只留 align → 只有 align 出题
	pool.set_domain_unlocked(func(domain: String) -> bool: return domain == "align")
	var domains_locked := pool.get_available_domains()
	assert_eq(domains_locked, ["align"], "未解锁域不出题（随树扩展语义）")
	assert_true(pool.get_topics_in_domain("distill").is_empty(), "distill 锁定→空列表")
	assert_false(pool.get_topics_in_domain("align").is_empty(), "align 解锁→有题")


func test_pool_topics_match_texts_keys() -> void:
	# 选题 title_key 与 texts.json 键一致（#124 已落；键缺失=文案断链）
	var pool := PaperPool.new()
	autofree(pool)
	var all_topics := pool.get_all_available_topics()
	assert_false(all_topics.is_empty(), "有可选题")
	for topic: Dictionary in all_topics:
		var title_key := str(topic.get("title_key", ""))
		assert_false(title_key.is_empty(), "选题必带 title_key")
		assert_true(TextService.text(title_key) != "", "title_key 在 texts.json 有文案: %s" % title_key)


func test_pool_rejects_unknown_domain() -> void:
	var pool := PaperPool.new()
	autofree(pool)
	assert_false(pool.is_domain_available("nonexistent_domain"), "未知域不可出题")
	assert_true(pool.get_topics_in_domain("nonexistent_domain").is_empty(), "未知域空列表")


func test_shared_task_slots_three_types() -> void:
	# DoD 验收 1（#131 已有同名基础断言；本侧=论文真实入槽路径增量）：
	# PaperProject 经 TaskBoard.start_paper 入槽，三类互斥占槽 ≤4
	var board := TaskBoard.new()
	autofree(board)
	var pool := PaperPool.new()
	autofree(pool)
	var topic := pool.get_topics_in_domain("align")[0]
	for i: int in 4:
		var paper := PaperProject.from_topic(topic)
		var result: Dictionary = board.start_paper(paper)
		assert_true(result.ok, "第 %d 篇论文入槽成功" % (i + 1))
	# 槽满（4/4）→ 第 5 篇拒绝且有原因
	var overflow := PaperProject.from_topic(topic)
	var reject: Dictionary = board.start_paper(overflow)
	assert_false(reject.ok, "满槽拒绝")
	assert_true(reject.has("reason"), "拒绝带原因码（单一原因源）")
