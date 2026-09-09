class_name PaperArchive
extends RefCounted
## L2 论文谱系档案（#134）：单向"我引用了谁"（cites 数组入档，P2 双向预留）。
## 与 projects/ 分离（architecture §2.2 要点 2）：项目=进行时，档案=完成物资产；
## 同一产物完成 = 项目结算 → 档案入册两个动作，互不耦合（入册动作 #135
## Settlement 路由调用；本类只做容器+查询）。
## 入档字段=architecture §9.1 products.papers 行（id/title_key/domain/ndim/
## influence/cites/status——存档 schema 同构，快照唯一映射点 SnapshotCodec 读）。
## P1 单向（decisions G11）：cites=我引用了谁（引用方向字段=数组结构入档）；
## P2 双向=加"被引"索引/查询（E7：结构已预留，不加代码）。
## RefCounted 零 Node；headless 可单测。

signal paper_archived(entry: Dictionary)

## 论文状态稳定字符串（存档兼容；P0 全 published，#140 后批可扩展 submitted）
const STATUS_PUBLISHED: String = "published"

var _entries: Array[Dictionary] = []
var _next_id: int = 1


## 论文完成入谱（#135 Settlement 按型路由调本方法；字段=§9.1 papers 行同构）。
## 参数：title_key（texts 键）/domain/ndim（4 维值数组，按 paper_ndim_set 序）/
## score（加权合成分）/influence/cites（我引用了谁 id 数组，可为空）。
## 返回：入谱条目（含分配的 paper_id）。
func add_paper(
	title_key: String,
	domain: String,
	ndim: Array,
	score: float,
	influence: int,
	cites: Array = [],
) -> Dictionary:
	if title_key.is_empty() or domain.is_empty():
		push_error("PaperArchive.add_paper: title_key/domain 不可空")
		return {}
	var entry := {
		"id": "p%d" % _next_id,
		"title_key": title_key,
		"domain": domain,
		"ndim": ndim.duplicate(),
		"score": score,
		"influence": influence,
		"cites": cites.duplicate(),
		"status": STATUS_PUBLISHED,
	}
	_next_id += 1
	_entries.append(entry)
	paper_archived.emit(entry.duplicate())
	return entry.duplicate()


## 全部档案（深拷贝数组；L3 列表渲染走本方法，禁直取内部）
func get_all_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate())
	return result


## 空库判定（空态文案 paper_archive_empty 由 L3 消费）
func is_empty() -> bool:
	return _entries.is_empty()


func count() -> int:
	return _entries.size()


## 按 id 取条目（不存在返回空 dict）
func get_entry_by_id(paper_id: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if str(entry.get("id", "")) == paper_id:
			return entry.duplicate()
	return {}


## cites 数组（我引用了谁；单向 P1。不存在/空=独立工作无引用）
func get_cites(paper_id: String) -> Array:
	var entry := get_entry_by_id(paper_id)
	if entry.is_empty():
		return []
	var cites: Variant = entry.get("cites", [])
	if cites is Array:
		return (cites as Array).duplicate()
	return []


## 存档导出（§9.1 products.papers 行同构；SnapshotCodec #126 序列化读本方法）
func to_save_data() -> Array[Dictionary]:
	return get_all_entries()


## 读档重建（#126 SnapshotCodec 解码后经 World 装配调本方法；入档字段=§9.1）
func restore_from_save(saved_entries: Array) -> void:
	_entries.clear()
	_next_id = 1
	for item: Variant in saved_entries:
		if item is not Dictionary:
			continue
		var entry := (item as Dictionary).duplicate()
		_entries.append(entry)
	# 恢复后 next_id 接续（防新论文 id 撞已恢复条目）
	for entry: Dictionary in _entries:
		var id_str := str(entry.get("id", ""))
		if id_str.begins_with("p"):
			var num := id_str.substr(1).to_int()
			if num >= _next_id:
				_next_id = num + 1
