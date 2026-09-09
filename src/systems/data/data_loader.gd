class_name DataLoader
extends RefCounted
## L1 JSON 配置表加载器（#128）：读表 + schema 校验（形状/类型/必需键/护栏）。
## 数值/配置一律外置 JSON（AGENTS.md 红线 3），代码内只出现键名引用。
## 纯静态无状态，headless 可单测。


## 读 JSON 表文件；失败返回空字典并 push_error（错误分支由调用方/测试消费）。
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: 文件不存在: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: 无法打开 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("DataLoader: %s 顶层不是 JSON 对象" % path)
		return {}
	return parsed


## 读表 + schema 断言（#128 主入口）：结构/类型/必需键不过则报错返回空表。
## schema 描述格式见 DataSchema.validate_table()。
static func load_validated(path: String, schema: Dictionary) -> Dictionary:
	var table := load_json(path)
	if table.is_empty():
		return {}
	var result := DataSchema.validate_table(table, schema)
	if not result.ok:
		for error: String in result.errors:
			push_error("DataSchema[%s]: %s" % [path.get_file(), error])
		return {}
	return table
