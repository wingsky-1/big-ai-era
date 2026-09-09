class_name WorldCommands
extends RefCounted
## L2 世界命令委托层（批7.2 #189 拆分：GameWorld 公共方法超 20 上限 gdlint
## 门禁，命令面独立成类=门面/工厂/相位/命令四职责分离）。纯委托：命令
## 语义在各自 L2 系统（TaskBoard/TechTree/ModelCeremony），本类只做参数
## 形态适配（id→行→构造→调用），零玩法逻辑。

var _parts: Dictionary = {}


func _init(parts: Dictionary) -> void:
	_parts = parts


## 接单（L3 任务板消费）：选题 id → PaperProject.from_topic 入槽。
func accept_paper(topic_id: String) -> Dictionary:
	var pool := PaperPool.new()
	var topic := pool.get_topic_by_id(topic_id)
	if topic.is_empty():
		return {"ok": false, "reason": "unknown_topic"}
	return (_parts["board"] as TaskBoard).start_paper(PaperProject.from_topic(topic))


## 排训练（L3 训练页消费）：基座 id → ModelProject.from_base 入槽。
func start_training(base_id: String) -> Dictionary:
	var models_table := DataLoader.load_json("res://src/data/models.json")
	var bases: Dictionary = models_table["model_bases"]
	if not bases.has(base_id):
		return {"ok": false, "reason": "unknown_base"}
	return (_parts["board"] as TaskBoard).start_training(ModelProject.from_base(bases[base_id]))


## 指派上桌（L3 员工卡消费）；返回 SlotRejectReason（NONE=成功）。
func assign_staff(staff_id: String, slot_index: int) -> CoreEnums.SlotRejectReason:
	return (_parts["board"] as TaskBoard).assign_staff(staff_id, slot_index)


## 研究启动（L3 迷雾面板消费）；返回 TreeResearch/TechTree 结果字典。
func start_research(node_id: String) -> Dictionary:
	return (_parts["tree"] as TechTree).start_research(node_id)


## 命名确认（L3 命名框消费）；返回 {ok, reason, entry}。
func submit_name(name: String) -> Dictionary:
	return (_parts["ceremony"] as ModelCeremony).submit_name(name)


## 跳过命名（"交给命运"；首模型无跳过路径——返回 first_mandatory 拒绝）。
func skip_naming() -> Dictionary:
	return (_parts["ceremony"] as ModelCeremony).skip_naming()


## 变速（1x→2x→4x→1x；z2 阻塞拒绝）。返回新档位索引。
func cycle_speed() -> int:
	return (_parts["clock"] as GameClock).cycle_speed()


## 暂停/继续（永不禁用）。
func set_paused(paused: bool) -> void:
	(_parts["clock"] as GameClock).set_paused(paused)
