class_name SaveMigrator
extends RefCounted

## 存档升轨迁移链：把任意历史版本的存档字典逐级升到 CURRENT_VERSION。
## 纯字典操作、纯静态函数，可无头单测；文件 IO 一律在 [class SaveSystem]。
##
## 约定：
## - 存档顶层必须携带 schema_version（缺失视为 v1）。
## - 每个迁移步骤只做「上一版 -> 当前版」的最小变更，禁止跳步合并。
## - 遇到比当前更新 schema 的存档（来自更新的游戏版本）返回空字典，
##   由调用方拒绝写入，防止用旧版本逻辑覆盖新版本存档造成坏档。

const CURRENT_VERSION: int = 2


## 将原始存档字典迁移到 CURRENT_VERSION；无法迁移时返回空字典。
static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var version: int = int(data.get("schema_version", 1))
	if version > CURRENT_VERSION:
		push_error(
			"SaveMigrator: 存档 schema_version(%d) 高于当前支持版本(%d)，拒绝迁移以防坏档" % [version, CURRENT_VERSION]
		)
		return {}
	while version < CURRENT_VERSION:
		match version:
			1:
				# v1 -> v2 示例：字段重命名 hp -> health，并补默认值。
				data["health"] = float(data.get("hp", 100.0))
				data.erase("hp")
				version = 2
			_:
				# 未知的中间版本：中止迁移，防止死循环。
				push_error("SaveMigrator: 未知的中间 schema 版本: %d" % version)
				return {}
	data["schema_version"] = CURRENT_VERSION
	return data
