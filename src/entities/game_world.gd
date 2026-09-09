class_name GameWorld
extends RefCounted
## L2 世界唯一状态持有者（批7.1 #188 从 3 行占位落为门面）。
## 职责（架构评审修订：门面/工厂/相位三职责拆分）：
## - **装配**：WorldFactory.assemble(seed) 注入全部系统（零玩法逻辑）；
## - **命令面**（L3/测试驱动）：开局/接单/排训练/指派/研究/命名/变速/暂停/存档；
## - **周结驱动**：GameClock.tick → week_settled → Settlement phase0-6 +
##   WeeklyPipeline phase7-10（ADR-0015 硬序，单点消费防双结）；
## - **数据面**（L3 只读）：get_dashboard_view() 聚合四主区；
## - **存档**：12 域（SnapshotCodec.DOMAIN_KEYS）编解码唯一映射点，经 SaveSystem。
## 纪律：L3 禁直取本类内部系统对象（ADR-0016：view 字典下发）；RefCounted
## 零 Node；数值零硬编码（节拍锚读 onboarding.json，其余全表驱动）。

const ONBOARDING_PATH: String = "res://src/data/onboarding.json"
const FIRST_NODE_ID: String = "align_rlhf_align"

## 开局周锚（GameClock._week 初值；语义锚常量，与 GoalCard.START_WEEK 同源）
const START_WEEK: int = 1

var _parts: Dictionary = {}
var _machine: TutorialMachine = null
var _card: GoalCard = null
var _pipeline: WeeklyPipeline = null
var _settlement: Settlement = null
var _started: bool = false


func _init(seed: int = 0) -> void:
	_parts = WorldFactory.assemble(seed)
	_machine = TutorialMachine.new()
	_card = GoalCard.new(_machine)
	_bind_machine_predicates()
	_build_pipeline()


## ---------- 命令面（契约命令；全部无 Node 依赖） ----------


## 新局开局（教学节拍 W1：首任务入槽 + 首节点研究启动 + 目标卡就位）。
## seed=开局种子（同种子=同局可复现，#125）。
func start_new_game(seed: int = 0) -> Dictionary:
	_parts = WorldFactory.assemble(seed)
	_machine = TutorialMachine.new()
	_card = GoalCard.new(_machine)
	_bind_machine_predicates()
	_build_pipeline()
	var board: TaskBoard = _parts["board"]
	# W1 接单：align 域首题入槽（教学第一课=复现，papers.json 表驱动）
	var pool := PaperPool.new()
	var topics := pool.get_topics_in_domain("align")
	if topics.is_empty():
		return {"ok": false, "reason": "no_first_topic"}
	board.start_paper(PaperProject.from_topic(topics[0]))
	# W1 点树（OP-ONB-04 教学兜底翻雾两档到 visible + 研究启动）
	var tree: TechTree = _parts["tree"]
	tree.advance_fog(FIRST_NODE_ID)
	tree.advance_fog(FIRST_NODE_ID)
	tree.start_research(FIRST_NODE_ID)
	_started = true
	_machine.advance_check(START_WEEK)
	return {"ok": true}


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


## 失焦谓词注入（L3/main 在 OS 失焦时切换；time_focus_loss_pause 阈值内）
func set_focus_predicate(predicate: Callable) -> void:
	(_parts["clock"] as GameClock).focus_predicate = predicate


## z2 阻塞门控（L3 ModalScheduler 接线：决策/命名未决期间世界停+变速置灰）
func set_z2_blocked(blocked: bool) -> void:
	(_parts["clock"] as GameClock).set_z2_blocked(blocked)
	if _settlement != null:
		_settlement.z2_blocked = func() -> bool: return blocked


## 手动存档（L3 暂停菜单消费）：12 域编解码经 SaveSystem 原子写。
func manual_save() -> bool:
	var save: Dictionary = SnapshotCodec.encode(get_save_state(), SnapshotCodec.SAVE_KIND_MANUAL)
	return SaveSystem.save_game(save)


## ---------- 周结驱动（唯一推进口；L3 _process 喂墙钟） ----------


## 墙钟 tick（L3 _process 每帧调用）：GameClock 满 1 周 → week_settled →
## Settlement phase0-6 + WeeklyPipeline phase7-10（单点消费，防双结）。
func tick(delta_seconds: float) -> void:
	if not _started:
		return
	(_parts["clock"] as GameClock).tick(delta_seconds)


## week_settled 消费（装配方=本类；GameClock 信号单点连接——Settlement 自身
## week_settled 信号不消费，防双结双广播）
func _on_week_settled(payload: Dictionary) -> void:
	var week := int(payload["week"])
	if _settlement == null:
		_build_pipeline()
	# phase0-6（收入/破产/账期）+ phase7-10（硬序，ADR-0015）
	_settlement.run_settle(week)
	_pipeline.run(week)
	# 引导机推进（只读世界状态）
	_machine.advance_check(week)


## ---------- 数据面（只读；L3 只画） ----------


## 四主区聚合（DashboardPresenter 消费；view 字典全部深拷贝防越权）
func get_dashboard_view() -> Dictionary:
	var board: TaskBoard = _parts["board"]
	var roster: Roster = _parts["roster"]
	var resources: Resources = _parts["resources"]
	var clock: GameClock = _parts["clock"]
	var pack: RivalPack = _parts["pack"]
	var ceremony: ModelCeremony = _parts["ceremony"]
	var tree: TechTree = _parts["tree"]
	var clock_view: Dictionary = clock.get_clock_view()
	return {
		"clock": clock_view,
		"tasks": board.get_task_view(),
		"staff": roster.get_roster_view(),
		"resources":
		{
			"cash": resources.get_cash(),
			"influence": resources.get_influence(),
			"card_hours_used": resources.get_card_hours_used(),
			"card_hours_remaining": resources.get_card_hours_remaining(),
			"card_hours_supply": resources.get_card_hours_supply(),
		},
		"rival_light": pack.get_highest_warn(int(clock_view["week"])),
		"goal_card": _card.get_goal_card_view(int(clock_view["week"])),
		"naming_pending": ceremony.has_pending(),
		"tree": tree.get_fog_view(),
	}


## 周报视图（L3 周报弹层消费；无周报=空 dict）
func get_report_view() -> Dictionary:
	var report: Object = _parts.get("weekly_report")
	if report == null:
		return {}
	return (report as WeeklyReport).get_report_view()


## 引导机访问器（测试/装配方读进度；L3 一律走 dashboard view）
func get_machine() -> TutorialMachine:
	return _machine


## 目标卡访问器（测试/装配方读节拍锚）
func get_goal_card() -> GoalCard:
	return _card


## 命名待决谓词（L3 命名框可见性；周结内 z2 门控同源）
func has_naming_pending() -> bool:
	return (_parts["ceremony"] as ModelCeremony).has_pending()


## ---------- 存档（12 域编解码唯一映射点；SnapshotCodec 承诺） ----------


## 世界态 → 存档字典（SnapshotCodec.encode 信封盖章后经 SaveSystem 落盘）。
## 域键=SnapshotCodec.DOMAIN_KEYS（12 域冻结集，不加域）。
func get_save_state() -> Dictionary:
	var clock: GameClock = _parts["clock"]
	var resources: Resources = _parts["resources"]
	var ledger: Ledger = _parts["ledger"]
	var board: TaskBoard = _parts["board"]
	var tree: TechTree = _parts["tree"]
	var roster: Roster = _parts["roster"]
	var pack: RivalPack = _parts["pack"]
	var archive: PaperArchive = _parts["archive"]
	var library: ModelLibrary = _parts["library"]
	var clock_view: Dictionary = clock.get_clock_view()
	return {
		"meta": {"saved_at_week": clock.get_week(), "created_at": "2026"},
		"game":
		{
			"seed": (_parts["rng"] as RngStream).get_root_seed(),
			"week": clock.get_week(),
			"quarter": int(clock_view["quarter"]),
			"year": int(clock_view["year"]),
			"speed": int(clock_view["speed_index"]),
			"rng": (_parts["rng"] as RngStream).to_save(),
		},
		"resources":
		{
			"cash": resources.get_cash(),
			"influence": resources.get_influence(),
			"card_hours_used": resources.get_card_hours_used(),
			"ledger": ledger.get_all_rows(),
		},
		"staff": roster.get_roster_view(),
		"task_board": board.get_task_view(),
		"tree": tree.get_fog_view(),
		"rivals": pack.get_save_view(),
		"products":
		{
			"papers": archive.get_all_entries(),
			"models": library.get_all_entries(),
		},
		"economy": {},
		"flags": _machine.get_save_view(),
		"events": {},
		"reports": {},
	}


## 存档字典 → 世界态（SaveMigrator 校验后由 L3 读档链调用；本层反写核心域）。
## 返回 {ok, errors}。
func restore_from_save(save: Dictionary) -> Dictionary:
	var state: Dictionary = SnapshotCodec.decode(save)
	if state.is_empty():
		return {"ok": false, "errors": ["decode_failed"]}
	# 反写引导 flags（开放容器字符串键；跨版本兼容优先）
	var flags: Variant = state.get("flags", {})
	if flags is Dictionary:
		_machine.restore_from_save(flags)
	# 反写竞对时间线消费指针（rival_pack save/restore 已有 API）
	var rivals: Variant = state.get("rivals", {})
	if rivals is Dictionary and not (rivals as Dictionary).is_empty():
		(_parts["pack"] as RivalPack).restore_from_save(rivals)
	# 反写产品库（模型/论文条目纯值注入；ndim 数组化兼容）
	var products: Variant = state.get("products", {})
	if products is Dictionary:
		_restore_products(products as Dictionary)
	_started = true
	return {"ok": true, "errors": []}


## ---------- 私有 ----------


func _bind_machine_predicates() -> void:
	var parts := _parts
	_machine.is_task_started = func() -> bool: return _task_started(parts)
	_machine.is_tree_lit = func() -> bool:
		return bool((parts["tree"] as TechTree).get_research().is_lit.call(FIRST_NODE_ID))
	_machine.is_influence_stocked = func() -> bool: return _influence_stocked(parts)
	_machine.is_train_started = func() -> bool: return _train_started(parts)
	_machine.is_score_named = func() -> bool: return (parts["library"] as ModelLibrary).count() >= 1
	_machine.is_rival_arrived = func() -> bool:
		return (
			int(
				(parts["pack"] as RivalPack).get_rival_view("deep_alley").get(
					"timeline_consumed", 0
				)
			)
			> 0
		)


func _build_pipeline() -> void:
	_settlement = (
		Settlement
		. new(
			_parts["ledger"],
			_parts["resources"],
			_parts["economy"],
			_parts["board"],
			_parts["archive"],
		)
	)
	_pipeline = WeeklyPipeline.new(
		_parts["board"], _parts["ceremony"], _parts["tree"], _parts["pack"], _parts["roster"]
	)
	# 周结内命名待决=z2 阻塞（跨周门控；ModalScheduler 消费 pending 呈现）
	_settlement.z2_blocked = func() -> bool:
		return (_parts["ceremony"] as ModelCeremony).has_pending()
	_pipeline.autosave = func(_week: int) -> void:
		var save: Dictionary = SnapshotCodec.encode(get_save_state(), SnapshotCodec.SAVE_KIND_AUTO)
		SaveSystem.save_game(save)
	# GameClock week_settled 单点连接（防双结：Settlement 自身 week_settled 不消费）
	var clock := _parts["clock"] as GameClock
	if not clock.week_settled.is_connected(_on_week_settled):
		clock.week_settled.connect(_on_week_settled)


func _task_started(parts: Dictionary) -> bool:
	var board := parts["board"] as TaskBoard
	for slot: int in board.get_slot_count():
		var project := board.get_project(slot)
		if project != null and project.get_type() == CoreEnums.ProjectType.PAPER:
			return true
	return (parts["archive"] as PaperArchive).count() > 0


func _influence_stocked(parts: Dictionary) -> bool:
	var papers_table := DataLoader.load_json("res://src/data/papers.json")
	var threshold := int((papers_table["paper_influence"] as Dictionary)["repro"])
	var total := 0
	for entry: Dictionary in (parts["archive"] as PaperArchive).get_all_entries():
		total += int(entry["influence"])
	return total >= threshold


func _train_started(parts: Dictionary) -> bool:
	var board := parts["board"] as TaskBoard
	for slot: int in board.get_slot_count():
		var project := board.get_project(slot)
		if project != null and project.get_type() == CoreEnums.ProjectType.MODEL:
			return true
	return false


func _restore_products(products: Dictionary) -> void:
	# 论文谱系（纯值注入：title_key/domain/ndim/score/influence）
	var papers: Variant = products.get("papers", [])
	if papers is Array:
		for entry: Variant in papers as Array:
			if entry is Dictionary:
				var e := entry as Dictionary
				(
					(_parts["archive"] as PaperArchive)
					. add_paper(
						str(e.get("title_key", "")),
						str(e.get("domain", "")),
						(e.get("ndim", []) as Array).duplicate(),
						float(e.get("score", 0.0)),
						int(e.get("influence", 0)),
					)
				)
	# 模型库（命名/基座/ndim/score/week 纯值注入）
	var models: Variant = products.get("models", [])
	if models is Array:
		for entry: Variant in models as Array:
			if entry is Dictionary:
				var e := entry as Dictionary
				(
					(_parts["library"] as ModelLibrary)
					. add_model(
						str(e.get("name", "")),
						str(e.get("base_id", "")),
						(e.get("ndim", []) as Array).duplicate(),
						float(e.get("score", 0.0)),
						int(e.get("week", 0)),
					)
				)
