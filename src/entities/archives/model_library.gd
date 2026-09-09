class_name ModelLibrary
extends RefCounted
## L2 模型库（#143；architecture-100 §2.2 archives/model_library.gd + §9.1
## products.models 行同构）。职责：
## - 模型收藏容器：出分模型入册（id/name/base_id/ndim/score/peak/week/
##   deployed 状态位——P2 部署/迭代字段按 §9.1 留键位不实现逻辑，E10）；
## - **峰值分数**唯一持有者：单模型历史最高分（=入册 score，P2 迭代提升时
##   才可能再高——本批模型一次出分即峰值；"峰值分数显示"读本容器）；
## - 命名写入点（ModelCeremony 命名确认后调 rename 更新名字，或跳过时以
##   默认名入册）；
## - 谱系=单模型家族（同 base_id 的 v2/v3 标 P2 预留：字段 iterations 入档，
##   值恒 0，E10 不预实现逻辑）。
## 与 SotaBoard 解耦：#142 拍板"榜语义独立于收藏"——本类只做收藏/峰值，
## 不做 SOTA 判定（玩家最高分判定=ModelCeremony 提交 SotaBoard）。
## RefCounted 零 Node；无反向引用；读档重建=快照纯值注入零环。

signal model_archived(entry: Dictionary)
signal model_renamed(payload: Dictionary)

## 模型状态稳定字符串（存档兼容；P0 全 archived，#145+ 部署批扩展）
const STATUS_ARCHIVED: String = "archived"

## 档案容量护栏（模型库不设上限——收藏=作品墙 P0 全收；防失控仅保留常量位）
const MAX_ENTRIES: int = 999

var _entries: Array[Dictionary] = []
var _next_id: int = 1


## 模型入册（出分仪式定名后调用；字段=§9.1 products.models 行同构）。
## 参数：name（定名结果）/base_id（基座 id）/ndim（5 维值数组，按
## model_ndim_set 序）/score（合成分，∈[0,100]）/week（出分周）。
## 返回：入册条目（含分配的 model_id）。
## ndim 长度=5 由表驱动断言（测试侧），本函数只透传数组化字段。
func add_model(
	name: String,
	base_id: String,
	ndim: Array,
	score: float,
	week: int = 0,
) -> Dictionary:
	if name.is_empty() or base_id.is_empty():
		push_error("ModelLibrary.add_model: name/base_id 不可空")
		return {}
	if _entries.size() >= MAX_ENTRIES:
		push_error("ModelLibrary.add_model: 档案满（%d）" % MAX_ENTRIES)
		return {}
	var entry := {
		"id": "m%d" % _next_id,
		"name": name,
		"base_id": base_id,
		"ndim": ndim.duplicate(),
		"score": score,
		"peak": score,  # 首次入册峰值=出分（P2 迭代才可能再高，E10 键位预留）
		"week": week,
		"deploy": null,  # P2 部署状态位（§9.1 键位；值 null=未部署，E10）
		"iterations": 0,  # P2 迭代版本号位（§9.1 键位；恒 0，E10）
		"status": STATUS_ARCHIVED,
	}
	_next_id += 1
	_entries.append(entry)
	model_archived.emit(entry.duplicate())
	return entry.duplicate()


## 改名（命名确认/跳过默认名后调用；name 已过 NameFilter 校验或取自名池——
## 本类不做过滤，过滤归 ModelCeremony 单一入口）
func rename_model(model_id: String, name: String) -> bool:
	if name.is_empty():
		push_error("ModelLibrary.rename_model: name 不可空")
		return false
	for i: int in _entries.size():
		if str(_entries[i].get("id", "")) == model_id:
			_entries[i]["name"] = name
			model_renamed.emit({"model_id": model_id, "name": name})
			return true
	return false


## ---------- 查询（只读深拷贝；L3/对账经本类，禁直取内部） ----------


## 单模型条目（无=空 dict）
func get_entry(model_id: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if str(entry.get("id", "")) == model_id:
			return entry.duplicate()
	return {}


## 全部模型（深拷贝数组；L3 模型库渲染/谱系走本方法）
func get_all_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate())
	return result


func count() -> int:
	return _entries.size()


## 玩家历史最高分（=任一模型 peak 的最大值；SotaBoard 判定的"当前纪录"是
## 榜状态（含竞对），本方法是收藏侧纯峰值口径——#142 解耦语义下二者独立，
## L3 模型库"历史最高"读本方法）
func get_highest_peak() -> float:
	var highest := 0.0
	for entry: Dictionary in _entries:
		highest = maxf(highest, float(entry.get("peak", 0.0)))
	return highest


## 读档重建（无环：快照纯值注入；装配方在 SaveSystem 读档后调）。
## 视图缺键=防御保留初值；_next_id 由最大 id 推导防重复分配。
## （#126 存档 schema 的 products.models 段装配在 GameWorld 批——本方法
## 供该批调用；测试覆盖 restore 纯值注入零环语义。）
func restore_from_snapshot(entries: Array) -> void:
	_entries.clear()
	_next_id = 1
	for item: Variant in entries:
		if item is not Dictionary:
			continue
		var entry: Dictionary = (item as Dictionary).duplicate(true)
		if str(entry.get("id", "")).is_empty():
			continue
		_entries.append(entry)
		var id_num := int(str(entry["id"]).trim_prefix("m"))
		_next_id = maxi(_next_id, id_num + 1)
