extends GutTest
## #133 论文项目测试：三型/域/表驱动构造 + 周推进 + 视图。
## DoD 用例名与 issue 逐字一致。

const PAPERS_PATH: String = "res://src/data/papers.json"

var _paper_table: Dictionary = {}


func before_each() -> void:
	_paper_table = DataLoader.load_json(PAPERS_PATH)


## 测试用最小合法题（表驱动构造样本；字段=真实 papers.json 行形状）
func _sample_topic(domain: String, type_key: String) -> Dictionary:
	var topics: Dictionary = _paper_table["paper_topics"]
	if topics.has(domain):
		var list: Array = topics[domain]
		if not list.is_empty():
			var t: Dictionary = list[0]
			if str(t.get("type", "")) == type_key:
				return t
	# 回退：手工最小题（测试不依赖具体行）
	return {
		"id": "test_%s" % domain,
		"title_key": "paper_topic_lora_align",
		"type": type_key,
		"domain": domain,
		"duration_weeks": 3,
		"rp_primary": true,
		"quality_hint": {"novelty": 0.5, "repro": 0.8},
	}


func test_paper_project_from_topic_table_driven() -> void:
	var topic := _sample_topic("align", "repro")
	var project := PaperProject.from_topic(topic)
	assert_not_null(project, "from_topic 可构造")
	assert_eq(project.get_topic_id(), str(topic.get("id", "")), "topic_id 正确")
	assert_eq(project.get_domain(), "align", "域=align")
	assert_eq(project.get_duration_weeks(), int(topic.get("duration_weeks", 0)), "工期表驱动")
	assert_eq(project.get_paper_kind(), PaperProject.PaperKind.REPRO, "型=repro")
	assert_true(project.is_running(), "构造后运行中")


func test_paper_kinds_three_types() -> void:
	# 三型语义（papers-spec A.1）：repro/research/contract 各有 type 键
	var kinds: Array[String] = ["repro", "research", "contract"]
	for k: String in kinds:
		var project := PaperProject.new("k_%s" % k, 3, 1, 1, _kind_from_key(k))
		assert_eq(
			PaperProject.kind_to_key(project.get_paper_kind()),
			k,
			"kind_to_key 往返=%s" % k,
		)


func test_paper_project_week_tick_advances() -> void:
	var topic := _sample_topic("align", "repro")
	var project := PaperProject.from_topic(topic)
	var duration := project.get_duration_weeks()
	for i: int in duration:
		assert_true(project.week_tick(), "第 %d 周可推进" % (i + 1))
	assert_true(project.is_finished_pending(), "工期到=完成待结算")
	assert_eq(project.get_weeks_remaining(), 0, "剩余周=0")


func test_paper_view_contains_metadata() -> void:
	var topic := _sample_topic("align", "repro")
	var project := PaperProject.from_topic(topic)
	var view: Dictionary = project.get_paper_view()
	assert_eq(view["domain"], "align", "视图含域")
	assert_eq(view["paper_kind_key"], "repro", "视图含型键")
	assert_true(view.has("topic_id"), "视图含 topic_id")
	assert_true(view.has("rp_primary"), "视图含 rp_primary")


func _kind_from_key(key: String) -> PaperProject.PaperKind:
	match key:
		"research":
			return PaperProject.PaperKind.RESEARCH
		"contract":
			return PaperProject.PaperKind.CONTRACT
	return PaperProject.PaperKind.REPRO
