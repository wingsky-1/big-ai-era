class_name PaperPool
extends RefCounted
## L2 论文选题池（#133）：读 papers.json 选题表，按域分组；
## 域解锁谓词注入（tech_tree #137 接线前默认全解锁）；出题=按域列出可选题。
## 选题池随树扩展语义：树开哪些域 → 论文能选哪些方向（papers-spec A.1）；
## 域未解锁 → 该域选题不出现在池中（空态文案 paper_pool_empty_hint 属 L3）。
## RefCounted 零 Node；表驱动零硬编码（键名真源=papers-spec D.2）。

const PAPERS_PATH: String = "res://src/data/papers.json"

## 域解锁谓词（注入：tech_tree #137 落位后由装配方提供真解锁；默认全解锁）。
## 返回 true=该域可选题。禁止本类内写死域解锁逻辑（解锁权在树）。
var domain_unlocked: Callable = func(_domain: String) -> bool: return true

var _topics_by_domain: Dictionary = {}
var _all_topic_ids: Array[String] = []


func _init() -> void:
	_reload_topics()


## 重载选题表（测试/热更用；正常一次 _init 装载）
func _reload_topics() -> void:
	_topics_by_domain.clear()
	_all_topic_ids.clear()
	var table := DataLoader.load_json(PAPERS_PATH)
	var topics: Variant = table.get("paper_topics", {})
	if topics is not Dictionary:
		push_error("PaperPool: papers.json 缺 paper_topics 表")
		return
	for domain: String in topics.keys():
		var list: Variant = topics[domain]
		if list is not Array:
			continue
		var cleaned: Array[Dictionary] = []
		for item: Variant in list:
			if item is Dictionary:
				cleaned.append(item)
		_topics_by_domain[domain] = cleaned


## 注入域解锁谓词（#137 tech_tree 接线点；默认全解锁）
func set_domain_unlocked(predicate: Callable) -> void:
	if predicate.is_valid():
		domain_unlocked = predicate


## 某域是否可出题（解锁且该域有题）
func is_domain_available(domain: String) -> bool:
	return domain_unlocked.call(domain) and _topics_by_domain.has(domain)


## 全部可用域（已解锁且有题；顺序=表序）
func get_available_domains() -> Array[String]:
	var result: Array[String] = []
	for domain: String in _topics_by_domain.keys():
		if is_domain_available(domain):
			result.append(domain)
	return result


## 某域可选题列表（解锁才出；未解锁返回空）
func get_topics_in_domain(domain: String) -> Array[Dictionary]:
	if not is_domain_available(domain):
		return []
	var result: Array[Dictionary] = []
	for topic: Dictionary in _topics_by_domain[domain]:
		result.append(topic.duplicate())
	return result


## 全部可选题（跨域平铺；供对照表/测试）
func get_all_available_topics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for domain: String in get_available_domains():
		result.append_array(get_topics_in_domain(domain))
	return result


## 按题 id 取选题数据（任意域；找不到返回空 dict）
func get_topic_by_id(topic_id: String) -> Dictionary:
	for domain: String in _topics_by_domain.keys():
		for topic: Dictionary in _topics_by_domain[domain]:
			if str(topic.get("id", "")) == topic_id:
				return topic
	return {}


## 总题数（全表，含未解锁域；对照表"全量可查"用）
func get_total_topic_count() -> int:
	var count := 0
	for domain: String in _topics_by_domain.keys():
		count += (_topics_by_domain[domain] as Array).size()
	return count
