extends GutTest
## #137 tech_tree.json 迷雾批 schema 断言（#128 data_schema 框架挂载）：
## 键名真源=tech-tree-spec.md D.2 公式与参数表（tree_fog_*/tree_insight_* 本单落位）。
## ⚠️ 键名前缀分区（#137/#138 协作契约）：tech_tree.json 由 #138 同文件增量研究键
## （tree_research_*），本测试只对"本单前缀键集合"做精确拼写比对（tree_node_/
## tree_domain_/tree_fog_/tree_insight_/tree_reveal_ 前缀 ∈ 本单集合），
## tree_research_* 前缀（#138 域）豁免——两单并行合并不互红。

const TREE_PATH: String = "res://src/data/tech_tree.json"

## 本单键全集合（tech-tree-spec D.2 行 + 节点表结构块；#138 将在此表加 tree_research_*）
const OWN_KEYS: Array[String] = [
	"tree_node_total",
	"tree_domain_nodes",
	"tree_insight_pity_max",
	"tree_reveal_cross",
	"tree_fog_reveal_rate",
	"tree_domains",
	"tree_nodes",
	"tree_cross_nodes",
	"tree_rumor_nodes",
]

## 本单键的 schema 描述（类型；结构块逐层自检在结构测试做）
const TREE_SCHEMA: Dictionary = {
	"tree_node_total": {"type": "int"},
	"tree_domain_nodes": {"type": "int"},
	"tree_insight_pity_max": {"type": "int"},
	"tree_reveal_cross": {"type": "int"},
	"tree_fog_reveal_rate": {"type": "float"},
	"tree_domains": {"type": "dict"},
	"tree_nodes": {"type": "dict"},
	"tree_cross_nodes": {"type": "array"},
	"tree_rumor_nodes": {"type": "array"},
}

## 数值键（须全部带内嵌护栏声明 _bounds，D6 跟键走）
const OWN_NUMERIC_KEYS: Array[String] = [
	"tree_node_total",
	"tree_domain_nodes",
	"tree_insight_pity_max",
	"tree_reveal_cross",
	"tree_fog_reveal_rate",
]

## 本单键名前缀（拼写比对时按前缀分区：#138 tree_research_* 不在其中）
const OWN_PREFIXES: Array[String] = [
	"tree_node_",
	"tree_domain_",
	"tree_insight_",
	"tree_reveal_",
	"tree_fog_",
]

const DOMAIN_IDS: Array[String] = ["align", "distill", "memory", "tool", "multimodal"]


func test_tree_schema_valid() -> void:
	var table := DataLoader.load_json(TREE_PATH)
	assert_false(table.is_empty(), "tech_tree.json 可加载")
	var result := DataSchema.validate_table(table, TREE_SCHEMA)
	assert_true(result.ok, "tech_tree.json 本单键 schema 校验全过: %s" % str(result.errors))


func test_tree_inline_bounds_present() -> void:
	var table := DataLoader.load_json(TREE_PATH)
	var result := DataSchema.validate_inline_bounds(table, OWN_NUMERIC_KEYS)
	assert_true(result.ok, "tech_tree.json 数值键全带内嵌护栏: %s" % str(result.errors))


func test_tree_own_keys_spelling_partitioned() -> void:
	## 本单键拼写=精确存在；tree_research_*（#138 分区）豁免；其余未知键报错。
	var table := DataLoader.load_json(TREE_PATH)
	var errors: Array[String] = []
	for key: String in OWN_KEYS:
		if not table.has(key):
			errors.append("缺本单键 '%s'" % key)
	for key: Variant in table.keys():
		var key_str := str(key)
		if key_str.begins_with("_"):
			continue  # 元数据键（_comment/_bounds）
		if key_str.begins_with("tree_research_"):
			continue  # #138 分区键豁免（同文件增量，git 自动合并）
		if key_str in OWN_KEYS:
			continue
		errors.append("多余未知键 '%s'（非本单分区）" % key_str)
	assert_true(errors.is_empty(), "tech_tree.json 本单键拼写与 D.2 一致: %s" % str(errors))


func test_tree_14_nodes_structure() -> void:
	## tech-tree-spec A.1：14 节点=10 域节点（每域 2）+3 交叉+1 传闻占位
	var table := DataLoader.load_json(TREE_PATH)
	assert_eq(int(table["tree_node_total"]), 14, "tree_node_total=14")
	assert_eq(int(table["tree_domain_nodes"]), 2, "每域 2 节点")
	var nodes: Dictionary = table["tree_nodes"]
	assert_eq(nodes.size(), 5, "五域节点块")
	var total_domain_rows := 0
	for domain_id: String in DOMAIN_IDS:
		assert_true(nodes.has(domain_id), "域块存在: %s" % domain_id)
		var rows: Array = nodes[domain_id]
		assert_eq(rows.size(), 2, "每域 2 节点（%s）" % domain_id)
		total_domain_rows += rows.size()
	assert_eq(total_domain_rows, 10, "10 域节点")
	var cross: Array = table["tree_cross_nodes"]
	assert_eq(cross.size(), 3, "3 交叉节点")
	var rumor: Array = table["tree_rumor_nodes"]
	assert_eq(rumor.size(), 1, "1 传闻占位")
	assert_eq(total_domain_rows + cross.size() + rumor.size(), 14, "14 节点合计")


func test_tree_node_rows_have_fog_fields() -> void:
	## 节点行迷雾字段完整（#137 单只落迷雾/翻雾声明；研究成本/效果 #138 填）
	var table := DataLoader.load_json(TREE_PATH)
	var rows: Array = []
	for domain_id: String in DOMAIN_IDS:
		rows.append_array(table["tree_nodes"][domain_id])
	rows.append_array(table["tree_cross_nodes"])
	rows.append_array(table["tree_rumor_nodes"])
	var seen: Dictionary = {}
	for row_variant: Variant in rows:
		assert_true(row_variant is Dictionary, "节点行为对象")
		if row_variant is not Dictionary:
			continue
		var row: Dictionary = row_variant
		var node_id := str(row.get("id", ""))
		assert_false(node_id.is_empty(), "节点有 id")
		assert_false(seen.has(node_id), "节点 id 唯一: %s" % node_id)
		seen[node_id] = true
		assert_false(str(row.get("name_key", "")).is_empty(), "节点有 name_key（迷雾行文案键）")
		assert_true(row.has("reveal_paths"), "节点声明翻雾通路（三通路表驱动）")
		assert_true(row.has("cross_from"), "交叉节点含相邻域声明")
		assert_true(row.has("spill_eligible"), "节点含外溢资格声明（表驱动）")


func test_tree_cross_adjacent_domains_valid() -> void:
	## 交叉节点 cross_from ⊆ 五域（表驱动相邻域声明合法性）
	var table := DataLoader.load_json(TREE_PATH)
	for row_variant: Variant in table["tree_cross_nodes"]:
		if row_variant is not Dictionary:
			continue
		var row: Dictionary = row_variant
		var from: Array = row.get("cross_from", [])
		assert_true(from.size() >= 2, "交叉节点跨 ≥2 域（%s）" % str(row.get("id", "")))
		for item: Variant in from:
			assert_true(DOMAIN_IDS.has(str(item)), "相邻域 ∈ 五域: %s" % str(item))
