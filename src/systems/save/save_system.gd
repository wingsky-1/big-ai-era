extends Node

## 存档服务（autoload 单例）：只负责持久化 IO 与升轨调度，
## 迁移逻辑全部在 [class SaveMigrator]（纯静态、可单测）。
##
## 架构红线：autoload 脚本禁止声明 class_name——类名会与 autoload
## 单例名冲突导致解析失败（Godot 4 明确报 "hides an autoload singleton"）。
## 全局通过 autoload 名 `SaveSystem` 访问。
##
## 使用方式：`SaveSystem.save_game(data)` / `SaveSystem.load_game()`。

const SAVE_PATH: String = "user://savegame.json"


## 保存游戏数据；自动补写当前 schema_version，成功返回 true。
func save_game(data: Dictionary) -> bool:
	var stamped := data.duplicate(true)
	stamped["schema_version"] = SaveMigrator.CURRENT_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: 无法写入存档 %s（错误码 %d）" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(stamped, "\t"))
	# 写入落盘校验：磁盘满等静默失败会导致丢档，必须显式检查
	if file.get_error() != OK:
		push_error("SaveSystem: 存档写入未完成（错误码 %d），拒绝虚报成功" % file.get_error())
		return false
	return true


## 读取并升轨存档；无存档、文件损坏或 schema 过新时返回空字典。
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: 无法读取存档 %s（错误码 %d）" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("SaveSystem: 存档内容不是合法 JSON 对象，已拒绝加载")
		return {}
	var migrated := SaveMigrator.migrate(parsed)
	if migrated.is_empty():
		push_error("SaveSystem: 存档 schema 无法迁移，已拒绝加载（保留磁盘原档）")
		return {}
	return migrated
