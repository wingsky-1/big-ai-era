extends GutTest

## DataLoader 单元测试：真实 res:// 数据表加载与错误分支。
##
## GUT 9.7 错误追踪机制说明：错误分支会触发业务代码的 push_error /
## 引擎报错，必须用 assert_push_error / assert_engine_error 显式消费，
## 否则任何未被处理的错误都会导致测试失败（Unexpected Errors）。

const TEXTS_PATH: String = "res://src/data/texts.json"


func test_load_texts_table_succeeds() -> void:
	var texts := DataLoader.load_json(TEXTS_PATH)
	assert_eq(texts.size(), 43, "文本起步集应包含 43 个键（批 1a 三键）")
	assert_true(texts.has("opening_line_intro"), "应包含 opening_line_intro 条目")
	var intro: Dictionary = texts.get("opening_line_intro", {})
	assert_eq(int(intro.get("max_len", 0)), 60, "开场白 max_len 应为 60")
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
	var texts := DataLoader.load_json(TEXTS_PATH)
	var intro: Dictionary = texts.get("opening_line_intro", {})
	# 注意：assert_string_contains 第三参是 match_case 而非消息，勿传中文消息
	assert_string_contains(str(intro.get("text", "")), "实验室")
