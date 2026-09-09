extends GutTest
## #133 papers.json schema 断言（#128 data_schema 框架挂载）：
## 键名/类型/必需键/护栏跟键 + 结构自检（权重和=1/选题池完整性）。

const PAPERS_PATH: String = "res://src/data/papers.json"

const PAPERS_SCHEMA: Dictionary = {
	"paper_ndim_set": {"type": "array"},
	"paper_ndim_weight": {"type": "dict"},
	"paper_quality_drivers": {"type": "dict"},
	"paper_accept_threshold": {"type": "int"},
	"paper_accept_max_per_game": {"type": "int"},
	"paper_ablation_bonus": {"type": "int"},
	"paper_exp_card_hours": {"type": "dict"},
	"paper_duration_weeks": {"type": "dict"},
	"paper_rp_primary": {"type": "int"},
	"paper_rp_secondary": {"type": "int"},
	"paper_rp_multi_min": {"type": "float"},
	"paper_rp_multi_max": {"type": "float"},
	"paper_income_cash": {"type": "dict"},
	"paper_influence": {"type": "dict"},
	"paper_domains": {"type": "array"},
	"paper_topics": {"type": "dict"},
}

const PAPER_NUMERIC_KEYS: Array[String] = [
	"paper_accept_threshold",
	"paper_accept_max_per_game",
	"paper_ablation_bonus",
	"paper_rp_primary",
	"paper_rp_secondary",
	"paper_rp_multi_min",
	"paper_rp_multi_max",
]


func test_papers_schema_valid() -> void:
	var table := DataLoader.load_json(PAPERS_PATH)
	assert_false(table.is_empty(), "papers.json 可加载")
	var result := DataSchema.validate_table(table, PAPERS_SCHEMA)
	assert_true(result.ok, "papers.json schema 校验全过: %s" % str(result.errors))


func test_papers_inline_bounds_present() -> void:
	var table := DataLoader.load_json(PAPERS_PATH)
	var result := DataSchema.validate_inline_bounds(table, PAPER_NUMERIC_KEYS)
	assert_true(result.ok, "papers.json 数值键全带内嵌护栏: %s" % str(result.errors))


func test_papers_ndim_weight_sum_one() -> void:
	var table := DataLoader.load_json(PAPERS_PATH)
	var weights: Dictionary = table["paper_ndim_weight"]
	assert_true(NDims.weights_sum_to_one(weights), "论文 n 维权重和=1")


func test_papers_topics_structural_integrity() -> void:
	var table := DataLoader.load_json(PAPERS_PATH)
	var topics: Dictionary = table["paper_topics"]
	var domains: Array = table["paper_domains"]
	for domain: Variant in domains:
		var domain_key := str(domain)
		assert_true(topics.has(domain_key), "五域每域有选题: %s" % domain_key)
		var list: Array = topics[domain_key]
		assert_false(list.is_empty(), "域 %s 选题非空" % domain_key)
		for topic: Variant in list:
			assert_true(topic is Dictionary, "选题为对象")
			var t: Dictionary = topic
			assert_false(str(t.get("id", "")).is_empty(), "选题有 id")
			assert_false(str(t.get("title_key", "")).is_empty(), "选题有 title_key")
			assert_true(str(t.get("type", "")) in ["repro", "research", "contract"], "选题型合法")
			assert_true(int(t.get("duration_weeks", 0)) >= 2, "选题工期 ≥2 周")
