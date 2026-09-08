class_name DataLoader
extends RefCounted

## JSON 配置表加载器：数值/配置一律外置 JSON（Git 冲突友好），禁止硬编码进代码。
## 纯静态、无状态，可无头单测。


## 严格取键（ADR-0013 零默认值纪律）：缺失即 push_error 并返回 null。
## 调用方必须显式处理 null（熔断/降级），禁止 `dict.get(key, <字面量>)` 兜底
## ——代码默认值与数据表并存 = 双真源，改表不生效。
static func require_key(config: Dictionary, key: String, source: String) -> Variant:
	if not config.has(key):
		push_error("DataLoader: 缺键 '%s'（真源 %s）" % [key, source])
		return null
	return config[key]


## 从 res:// 或绝对路径加载 JSON 对象；失败时返回空字典（不抛异常）。
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
