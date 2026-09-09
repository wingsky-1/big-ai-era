class_name SnapshotCodec
extends RefCounted
## L2 快照/存档唯一映射点（#126 新建：ADR-0016 承诺 + architecture-100 §9.2 落点）。
## 职责边界：
## - 任何世界态进出存档/快照字典只准走本类（唯一映射点：档/快照/呈现三方口径同源）；
## - 世界态与档字典共享 §9.1 顶层形状（业务域清单见 DOMAIN_KEYS），
##   本类做深拷贝 + 信封（schema_version/save_kind）盖章/剥离，防别名与外部篡改；
## - 版本迁移纪律在 SaveMigrator（L1），磁盘 IO 在 SaveSystem（L1）；
##   本类不读写文件、不判断版本轨道（L2 只依赖 L0/L1）。
## 纯静态 RefCounted，headless 可单测。

## 信封键：版本由 SaveMigrator.CURRENT_VERSION 唯一真源盖章
const VERSION_KEY: String = "schema_version"
const KIND_KEY: String = "save_kind"

## save_kind 封闭值集（存档内稳定字符串，跨版本兼容；禁开放拼写）
const SAVE_KIND_AUTO: String = "auto"
const SAVE_KIND_MANUAL: String = "manual"
const SAVE_KINDS: Array[String] = [SAVE_KIND_AUTO, SAVE_KIND_MANUAL]

## 档/快照业务域清单（architecture-100 §9.1 顶层示意键；键名=实施排期首表冻结）。
## 未来实现批在此表增量挂载新域（数组/开放容器加键=非破坏性，零迁移）。
const DOMAIN_KEYS: Array[String] = [
	"meta",
	"game",
	"resources",
	"staff",
	"task_board",
	"tree",
	"rivals",
	"products",
	"economy",
	"flags",
	"events",
	"reports",
]


## 世界态 → 存档字典（唯一写方向）：深拷贝 + 信封盖章。
## save_kind 必须是 SAVE_KINDS 之一（防 stringly-typed 落盘脏档）；非法返回空字典。
static func encode(world_state: Dictionary, save_kind: String) -> Dictionary:
	if save_kind not in SAVE_KINDS:
		push_error("SnapshotCodec: 非法 save_kind '%s'（仅 auto/manual）" % save_kind)
		return {}
	var out := world_state.duplicate(true)
	out[VERSION_KEY] = SaveMigrator.CURRENT_VERSION
	out[KIND_KEY] = save_kind
	return out


## 世界态 → 只读快照（呈现/比对）：深拷贝隔离，不盖信封（快照无版本语义）。
static func snapshot(world_state: Dictionary) -> Dictionary:
	return world_state.duplicate(true)


## 存档字典 → 世界态（唯一读方向）：剥信封 + 深拷贝。
## 版本校验（缺失按 v1/只升不降/禁跳步/未来拒绝）在 SaveMigrator，
## 由 SaveSystem.load_game 读档链先执行；本层做形状剥离 + save_kind 合法校验
## （防跨版本脏档混入世界态）。
static func decode(save: Dictionary) -> Dictionary:
	var kind: Variant = save.get(KIND_KEY, SAVE_KIND_AUTO)
	if str(kind) not in SAVE_KINDS:
		push_error("SnapshotCodec: 存档 save_kind 非法（%s），已拒绝解码" % str(kind))
		return {}
	var out := save.duplicate(true)
	out.erase(VERSION_KEY)
	out.erase(KIND_KEY)
	return out
