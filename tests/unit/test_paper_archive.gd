extends GutTest
## #134 论文谱系测试：入谱完整性/单向 cites/空态 + 存档往返。
## DoD 用例名与 issue 逐字一致。

var _archive: PaperArchive


func before_each() -> void:
	_archive = PaperArchive.new()
	autofree(_archive)


func test_paper_archive_integrity() -> void:
	# DoD 1：论文完成入谱——标题/域/影响力/质量分/4 维画像/cites 全字段
	var entry := (
		_archive
		. add_paper(
			"paper_topic_lora_align",
			"align",
			[71.0, 62.0, 55.0, 68.0],
			64.7,
			20,
			["rival_p1"],
		)
	)
	assert_false(entry.is_empty(), "入谱返回条目")
	assert_false(str(entry.get("id", "")).is_empty(), "条目有 id")
	assert_eq(entry["title_key"], "paper_topic_lora_align", "标题键入谱")
	assert_eq(entry["domain"], "align", "域入谱")
	assert_eq(entry["influence"], 20, "影响力入谱")
	assert_almost_eq(float(entry["score"]), 64.7, 0.001, "质量分入谱")
	var ndim: Array = entry["ndim"]
	assert_eq(ndim.size(), 4, "4 维画像入谱（数组化）")
	assert_eq(entry["cites"], ["rival_p1"], "cites 入谱")
	assert_eq(entry["status"], "published", "状态=published")
	# 信号发射（真实发射点纪律；GUT 需先 watch_signals）
	watch_signals(_archive)
	(
		_archive
		. add_paper(
			"paper_topic_distill_1",
			"distill",
			[80.0, 55.0, 60.0, 50.0],
			63.0,
			15,
		)
	)
	assert_signal_emitted(_archive, "paper_archived", "入谱发 paper_archived 信号")


func test_paper_archive_single_direction() -> void:
	# DoD 2：谱系单向 P1——cites=我引用了谁；P2 被引索引不预实现
	_archive.add_paper("paper_topic_lora_align", "align", [70.0, 60.0, 50.0, 65.0], 61.5, 10)
	_archive.add_paper(
		"paper_topic_distill_1", "distill", [80.0, 55.0, 60.0, 50.0], 63.0, 15, ["p1"]
	)
	# 第二篇 cites 第一篇（我引用了谁=方向从新到旧）
	assert_eq(_archive.get_cites("p2"), ["p1"], "p2 引用 p1（单向 cites）")
	assert_eq(_archive.get_cites("p1"), [], "p1 无引用（无被引索引=P2 不预实现）")
	# 无被引查询接口（P2 才加）：验证不存在的查询语义=仅 id 直取
	assert_true(_archive.get_entry_by_id("p1").has("cites"), "条目含 cites 字段（预留数组结构）")
	assert_true(_archive.get_entry_by_id("p2").has("cites"), "条目含 cites 字段")


func test_paper_archive_empty_state() -> void:
	# DoD 3：空库空态文案（数据面=is_empty 谓词；文案键 paper_archive_empty 由 L3 消费）
	assert_true(_archive.is_empty(), "初始空库")
	assert_eq(_archive.count(), 0, "计数=0")
	_archive.add_paper("paper_topic_mm_clip", "multimodal", [60.0, 70.0, 65.0, 55.0], 62.5, 12)
	assert_false(_archive.is_empty(), "入谱后非空")
	assert_eq(_archive.count(), 1, "计数=1")
	# 空态文案键存在（#124 已落；L3 空态渲染用）
	assert_true(TextService.text("paper_archive_empty") != "", "paper_archive_empty 文案在 texts.json")


func test_archive_duplicates_and_ids() -> void:
	# 多篇入谱 id 递增不重复；同标题两篇=独立条目（论文非唯一）
	var e1 := _archive.add_paper(
		"paper_topic_lora_align", "align", [70.0, 60.0, 50.0, 65.0], 61.5, 10
	)
	var e2 := _archive.add_paper(
		"paper_topic_lora_align", "align", [75.0, 55.0, 60.0, 60.0], 62.0, 10
	)
	assert_ne(e1["id"], e2["id"], "id 不重复")
	assert_eq(_archive.count(), 2, "两篇入谱")


func test_archive_save_restore_roundtrip() -> void:
	# 存档往返（§9.1 products.papers 行；#126 SnapshotCodec 装配读）
	_archive.add_paper("paper_topic_lora_align", "align", [70.0, 60.0, 50.0, 65.0], 61.5, 10)
	_archive.add_paper("paper_topic_tool_use", "tool", [80.0, 50.0, 55.0, 45.0], 60.0, 12, ["p1"])
	var saved := _archive.to_save_data()
	var restored := PaperArchive.new()
	restored.restore_from_save(saved)
	assert_eq(restored.count(), 2, "读档恢复 2 篇")
	var e1 := restored.get_entry_by_id("p1")
	assert_eq(e1["domain"], "align", "恢复条目字段完整")
	# 恢复后 id 接续：新论文不撞已恢复 id
	var e3 := restored.add_paper(
		"paper_topic_memory_ctx", "memory", [65.0, 60.0, 55.0, 60.0], 60.5, 10
	)
	assert_eq(e3["id"], "p3", "恢复后新论文 id 接续 p3")
