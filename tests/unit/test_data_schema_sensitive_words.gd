extends GutTest
## #143 sensitive_words.json 三层词表 schema 断言（#128 data_schema 框架挂载）：
## 键名/类型 + 结构自检（max_len/白名单开关/blocklist 数组/homophone 数组 +
## 表存在性护栏——NameFilter 防御放行语义的前提=表可加载）。
## 真源=onboarding-spec.md C.5（name_filter_whitelist/blocklist/homophone_map）
## + architecture-100 §9.1（sensitive_words.json=三层配置表全局共用）。
## 词表内容=内容席维护示例级（[P] 正式词库留真人扩表）；本文件只断言结构。

const SENSITIVE_PATH: String = "res://src/data/sensitive_words.json"

const SENSITIVE_SCHEMA: Dictionary = {
	"name_filter_max_len": {"type": "number"},
	"name_filter_whitelist": {"type": "dict"},
	"name_filter_blocklist": {"type": "array"},
	"name_filter_homophone_map": {"type": "array"},
}


func test_sensitive_schema_valid() -> void:
	var table := DataLoader.load_json(SENSITIVE_PATH)
	assert_false(table.is_empty(), "sensitive_words.json 可加载")
	var result := DataSchema.validate_table(table, SENSITIVE_SCHEMA)
	assert_true(result.ok, "sensitive_words.json schema 校验全过: %s" % str(result.errors))


func test_sensitive_key_spelling_matches_source() -> void:
	# 键名拼写自检（#128 机制）；真源=onboarding C.5 三层 + max_len
	var table := DataLoader.load_json(SENSITIVE_PATH)
	var expected: Array[String] = [
		"name_filter_max_len",
		"name_filter_whitelist",
		"name_filter_blocklist",
		"name_filter_homophone_map",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "sensitive_words.json 键名拼写与真源一致: %s" % str(result.errors))


func test_sensitive_structure_guardrails() -> void:
	# 结构护栏：max_len ∈[1,20]；白名单含四类别键；词表/近音表非空可遍历
	var table := DataLoader.load_json(SENSITIVE_PATH)
	var max_len := int(table["name_filter_max_len"])
	assert_true(max_len >= 1 and max_len <= 20, "max_len ∈[1,20]（命名 ≤12 字占位）")
	var wl: Dictionary = table["name_filter_whitelist"]
	for key: String in ["cjk", "latin", "digit", "space", "extra"]:
		assert_true(wl.has(key), "白名单含类别键 %s" % key)
	var blocklist: Array = table["name_filter_blocklist"]
	assert_true(blocklist.size() >= 1, "blocklist 非空（侮辱/政治敏感/广告示例）")
	var homophone: Array = table["name_filter_homophone_map"]
	assert_true(homophone.size() >= 1, "homophone_map 非空（防真人近音示例）")
	for item: Variant in blocklist:
		assert_true(str(item).length() >= 1, "词表项非空")
	for item: Variant in homophone:
		assert_true(str(item).length() >= 1, "近音表项非空")
