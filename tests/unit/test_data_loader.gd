extends GutTest

## DataLoader 单元测试：真实 res:// 数据表加载与错误分支。
##
## GUT 9.7 错误追踪机制说明：错误分支会触发业务代码的 push_error /
## 引擎报错，必须用 assert_push_error / assert_engine_error 显式消费，
## 否则任何未被处理的错误都会导致测试失败（Unexpected Errors）。

const ITEMS_PATH: String = "res://src/data/items.json"


func test_load_items_table_succeeds() -> void:
	var items := DataLoader.load_json(ITEMS_PATH)
	assert_eq(items.size(), 2, "示例数据表应包含 2 个条目")
	assert_true(items.has("potion_small"), "应包含 potion_small 条目")
	assert_eq(int(items.get("potion_small", {}).get("heal", 0)), 30, "药水治疗量应为 30")
	assert_push_error_count(0, "正常路径不应产生任何错误")


func test_missing_file_returns_empty_dict() -> void:
	var result := DataLoader.load_json("res://tests/fixtures/no_such_file.json")
	assert_true(result.is_empty(), "缺失文件应返回空字典而非崩溃")
	assert_push_error("文件不存在", "缺失文件应有明确错误提示")


func test_broken_json_returns_empty_dict() -> void:
	var result := DataLoader.load_json("res://tests/fixtures/bad.json")
	assert_true(result.is_empty(), "损坏 JSON 应返回空字典而非崩溃")
	assert_engine_error("Parse JSON failed", "引擎层应报 JSON 解析失败")
	assert_push_error("顶层不是 JSON 对象", "业务层应拒绝非法数据")


func test_non_object_json_returns_empty_dict() -> void:
	var result := DataLoader.load_json("res://tests/fixtures/not_object.json")
	assert_true(result.is_empty(), "顶层数组 JSON 应返回空字典而非崩溃")
	assert_push_error("顶层不是 JSON 对象", "业务层应拒绝非对象 JSON")


func test_utf8_content_preserved() -> void:
	var items := DataLoader.load_json(ITEMS_PATH)
	var small: Dictionary = items.get("potion_small", {})
	# 注意：assert_string_contains 第三参是 match_case 而非消息，勿传中文消息
	assert_string_contains(str(small.get("name", "")), "药水")
