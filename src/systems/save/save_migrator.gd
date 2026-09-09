class_name SaveMigrator
extends RefCounted
## L1 存档迁移链（#126）：schema_version=1 起步，版本缺失按 v1、
## 只升不降、禁跳步、未来版本拒绝加载（ADR-0003/ADR-0021/architecture-100 §9.3）。
## 纯字典操作、纯静态、零 Node 依赖，headless 可单测；文件 IO 一律在 SaveSystem。

## 当前代码支持的 schema 版本（破坏性变更时 +1 并新增迁移分支+单测）
const CURRENT_VERSION: int = 1

## 顶层键名（架构 §9.1：save_kind/meta/game 等业务键由后续实现批冻结；
## v1 起步只保证 schema 版本纪律与壳结构，不预判业务键形状）
const VERSION_KEY: String = "schema_version"


## 迁移链执行：把任意历史版本存档字典逐级升到 CURRENT_VERSION。
## 规则（ADR-0003）：版本缺失=按 v1；只升不降；禁跳步（逐级 match 升）；
## 当前版本透传；高于当前版本=拒绝（返回空字典，防旧版本游戏覆盖新存档）。
static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var version: int = int(data.get(VERSION_KEY, CURRENT_VERSION))
	if version > CURRENT_VERSION:
		push_error(
			(
				"SaveMigrator: 存档 schema_version(%d) 高于当前支持版本(%d)，拒绝加载（未来版本保护）"
				% [version, CURRENT_VERSION]
			)
		)
		return {}
	if version < CURRENT_VERSION:
		push_error(
			(
				"SaveMigrator: 存档 schema_version(%d) 低于当前支持版本(%d)，拒绝加载（v1 起步旧档弃迁）"
				% [version, CURRENT_VERSION]
			)
		)
		return {}
	data[VERSION_KEY] = CURRENT_VERSION
	return data
