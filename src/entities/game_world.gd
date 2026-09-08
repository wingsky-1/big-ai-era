class_name GameWorld
extends RefCounted

## 唯一门面（L2，v1.1 §B 单向数据流契约）：收命令/发信号/组装子系统。
## 强持有子系统（单向树，子系统不回指）；快照与存档字典经 SnapshotCodec
## 唯一映射；周结管线 v2.1 步序在此定型，子系统逐 PR 填充（本 PR：骨架 +
## start_new_game/get_ui_snapshot/set_paused/request_save/simulate_weeks +
## GW3 决策策略同帧应答钩子）。
## 命令 11 / 信号 11（DR-026），测试按 CONTRACT_COMMANDS/CONTRACT_SIGNALS 对账。

signal resources_changed(money: int, compute_hours: float, influence: int)
signal week_settled(report: Dictionary)
signal decision_pending(card: Dictionary)
signal sota_updated(entry: Dictionary)
signal fog_changed(revealed_ids: PackedStringArray)
signal task_state_changed(task_id: String, state: String)
signal stage_advanced(stage_id: int)
signal model_named(model_name: String)
signal game_over(summary: Dictionary)
signal toast_queued(payload: Dictionary)
signal progress_ticked(progress: Dictionary)

## 契约对账清单（v1.1 §B；加命令/信号须同步此处+测试）
const CONTRACT_COMMANDS: PackedStringArray = [
	"start_new_game",
	"get_ui_snapshot",
	"assign_staff",
	"unassign_staff",
	"enqueue_task",
	"start_research",
	"start_training",
	"choose_decision",
	"submit_model_name",
	"set_paused",
	"request_save",
]
const CONTRACT_SIGNALS: PackedStringArray = [
	"resources_changed",
	"week_settled",
	"decision_pending",
	"sota_updated",
	"fog_changed",
	"task_state_changed",
	"stage_advanced",
	"model_named",
	"game_over",
	"toast_queued",
	"progress_ticked",
]
const SCHEMA_VERSION: int = 1
const DECISION_POLICY_META: StringName = &"decision_policy"

var week: int = 0  # 权威周数（游戏状态口径；clock.week 仅触发器内部计数，一致性由测试锁定）
var research_eff: int = 0
var tech_bonus: float = 0.0
var user_paused: bool = false
var game_over_flag: bool = false
var model_name: String = ""
var staff: Dictionary = {}
var rng_seed: int = 0
var sota_best: float = 0.0
var rival_best: float = 0.0
var cum_income: int = 0
var tutorial_step: int = 0
var tutorial_done: bool = false

var clock: GameClock
var economy: Economy
var roster: StaffRoster
var task_queue: TaskQueue
var tech_fog: TechFog
var tech_tree: TechTree
var stages: Stages
var training: TrainingProject
var sota_board: SotaBoard
var rng_stream: RngStream
var rival_track: RivalTrack
var event_engine: EventEngine
var pending_decision: Dictionary = {}

var _named_ids: Dictionary = {}
var _named_cursor: int = 0
var _last_signal_report: Dictionary = {}
var _income_roll_seed: int = 0
var _last_emitted_progress: Dictionary = {}


## 组装子系统（GameClock/Economy/StaffRoster/TaskQueue/TechTree/Stages 强持有+参数注入；不回指）。
func _init() -> void:
	clock = GameClock.new()
	clock.setup(DataLoader.load_json("res://src/data/clock.json"), self)
	clock.week_boundary_reached.connect(_on_week_boundary)
	clock.tick_advanced.connect(_on_clock_tick)
	economy = Economy.new()
	economy.setup(DataLoader.load_json("res://src/data/economy.json"))
	economy.warned.connect(
		func(amount: int) -> void:
			toast_queued.emit({"text_key": "sys_save_hint", "warned": amount})
	)
	roster = StaffRoster.new()
	task_queue = TaskQueue.new()
	task_queue.setup(DataLoader.load_json("res://src/data/tasks.json"))
	tech_fog = TechFog.new()
	tech_tree = TechTree.new()
	stages = Stages.new()
	training = TrainingProject.new()
	sota_board = SotaBoard.new()
	rng_stream = RngStream.new()
	rival_track = RivalTrack.new()
	event_engine = EventEngine.new()
	var techs_cfg := DataLoader.load_json("res://src/data/techs.json")
	tech_fog.setup(techs_cfg)
	tech_tree.setup(techs_cfg, tech_fog)
	stages.setup(DataLoader.load_json("res://src/data/stages.json"))
	training.setup(DataLoader.load_json("res://src/data/model_bases.json"))
	event_engine.setup(DataLoader.load_json("res://src/data/events.json"))


## 组装口（GameLoopDriver 经此取时钟；非契约命令）。
func get_clock() -> GameClock:
	return clock


## 资源只读委托（资源状态内聚 Economy，M3 唯一过账口无分叉状态）。
func get_money() -> int:
	return economy.get_money()


func get_influence() -> int:
	return economy.get_influence()


func get_compute() -> Dictionary:
	return economy.get_compute()


## ============ 命令面（11）============


## 建档（B1/GW8）：seed 定格开局态（灵犀 Chat 已发布+三研究员+W0 态）。
func start_new_game(seed: int = 0) -> void:
	rng_seed = seed
	_income_roll_seed = seed + 1  # 收入脉冲随机源种子（PR7 换 rng_stream）
	rng_stream.setup(seed)
	week = 0
	cum_income = 0
	tutorial_step = 0
	tutorial_done = false
	research_eff = 0
	tech_bonus = 0.0
	user_paused = false
	game_over_flag = false
	model_name = ""
	pending_decision = {}
	_named_ids = {}
	_named_cursor = 0
	sota_best = 0.0
	staff = {}
	economy.setup(DataLoader.load_json("res://src/data/economy.json"))
	var opening := DataLoader.load_json("res://src/data/opening.json")
	var compute: Dictionary = opening.get("compute", {})
	economy.init_resources(
		int(opening.get("money", 0)),
		int(opening.get("influence", 0)),
		int(compute.get("tier", 1)),
		float(compute.get("hours_remaining", 0.0))
	)
	rival_best = float(opening.get("rival_best", rival_best))
	var staff_table := DataLoader.load_json("res://src/data/staff.json")
	roster.setup(staff_table, opening)
	staff = roster.get_all_staff()
	task_queue.setup(DataLoader.load_json("res://src/data/tasks.json"))
	var techs_cfg := DataLoader.load_json("res://src/data/techs.json")
	tech_fog.setup(techs_cfg)
	tech_tree.setup(techs_cfg, tech_fog)
	stages.setup(DataLoader.load_json("res://src/data/stages.json"))
	training.setup(DataLoader.load_json("res://src/data/model_bases.json"))
	sota_board.setup(opening, DataLoader.load_json("res://src/data/benchmarks.json"))
	sota_best = sota_board.get_best_score()
	rival_best = sota_board.get_rival_best()
	rival_track.setup(DataLoader.load_json("res://src/data/rivals.json"), rng_stream)
	event_engine.setup(DataLoader.load_json("res://src/data/events.json"))
	_income_roll_seed = rng_seed
	_named_ids.clear()
	_last_signal_report = {}
	_recalculate_research_eff()
	_recalculate_tech_bonus()
	_sync_card_block()
	_emit_resources()
	# W0 假头条：灵犀 Chat 已发布（竞对榜基线，非玩家纪录）
	sota_updated.emit(
		{"model": str(opening.get("rival_model_name", "")), "score": rival_best, "rival": true}
	)


## 资源信号统一出口（唯一广播点；载荷取自 Economy 单一真源）。
func _emit_resources() -> void:
	var compute_state := economy.get_compute()
	resources_changed.emit(
		economy.get_money(), float(compute_state["hours_remaining"]), economy.get_influence()
	)


## 全量 UI 快照（B1）：reload/读档/回菜单重进的初始渲染唯一来源。
func get_ui_snapshot() -> Dictionary:
	return SnapshotCodec.ui_snapshot(self)


func assign_staff(staff_id: String, slot_id: String) -> void:
	if roster.assign_staff(staff_id, slot_id):
		staff = roster.get_all_staff()
		_recalculate_research_eff()
		# 指派影响研发力与员工统计口径，广播资源信号驱动 UI 刷新（v0.1.3 反馈①）
		_emit_resources()


func unassign_staff(staff_id: String) -> void:
	if roster.unassign_staff(staff_id):
		staff = roster.get_all_staff()
		_recalculate_research_eff()
		_emit_resources()


func enqueue_task(task_id: String) -> void:
	var context := {
		"money": get_money(),
		"lit_techs": [],
	}
	var check := task_queue.can_enqueue(task_id, context)
	if not check.get("ok", false):
		return
	var tasks_config: Dictionary = DataLoader.load_json("res://src/data/tasks.json")
	var task_cfg: Dictionary = tasks_config.get(task_id, {})
	var cost := int(task_cfg.get("cost", 0))
	if cost > 0:
		if not economy.apply_delta("money", -cost, "task_cost"):
			return
		_emit_resources()
	if task_queue.enqueue(task_id, context):
		var active := task_queue.get_active_task()
		if not active.is_empty() and active.get("task_id", "") == task_id:
			task_state_changed.emit(task_id, "active")
		else:
			task_state_changed.emit(task_id, "enqueued")


func start_research(tech_id: String) -> void:
	var context := {
		"influence": get_influence(),
		"money": get_money(),
		"economy": economy,
	}
	var res := tech_tree.start_research(tech_id, context)
	if res.get("ok", false):
		_recalculate_tech_bonus()
		_emit_resources()


func start_training(base_id: String) -> void:
	var context := {
		"research_eff": research_eff,
		"compute_tier": economy.get_compute()["tier"],
		"money": get_money(),
		"economy": economy,
	}
	var res := training.start_training(base_id, context)
	if res.get("ok", false):
		_emit_resources()


func choose_decision(pending_id: String, option_idx: int) -> void:
	if not pending_decision.is_empty() and pending_decision.get("id", "") == pending_id:
		if event_engine.choose_decision_option(option_idx, self):
			set_pending_decision({})
			_emit_resources()


## 命名（PR6 接入长度/敏感词校验+名池轮转+转义防二次解析）。
func submit_model_name(raw: String) -> void:
	if game_over_flag:
		return

	var candidate := raw.strip_edges()
	var final_name := candidate

	# 若玩家输入为空或跳过命名，从默认名池确定性轮转
	if candidate.is_empty():
		final_name = TextService.default_name(_named_cursor)
		_named_cursor += 1
	else:
		# 单大括号转义防二次注入：把 { 替换为 {{，把 } 替换为 }}
		var escaped := candidate.replace("{", "{{").replace("}", "}}")
		# 校验长度（<= 20）与敏感词
		var stripped_brackets := candidate.replace("{", "").replace("}", "")
		if not TextService.is_name_allowed(stripped_brackets, 20):
			# 敏感词或不合法拒绝
			toast_queued.emit({"text_key": "naming_sensitive_reject"})
			return
		final_name = escaped

	model_name = final_name
	_named_ids[final_name] = true
	model_named.emit(final_name)


## 暂停键（Q4 防御第一半：blocked 期间解除请求被拒；GameClock 持第二半）。
func set_paused(on: bool) -> void:
	if not on and not pending_decision.is_empty():
		return  # 带卡期间 UI 解除暂停无效（DR-022① 卡优先）
	clock.set_user_paused(on)
	user_paused = clock.user_paused


## 生成 Game Over 总结字典（周数/最高分/SOTA 纪录/破产原因）
func get_game_over_summary() -> Dictionary:
	return {
		"week": week,
		"best_score": sota_best,
		"rival_best": rival_best,
		"model_name": model_name,
		"cum_income": cum_income,
		"reason": "bankruptcy",
	}


## 手动/退出/切后台存档触发（PR8 三保险时机；经 SaveSystem 唯一写入口）。
func request_save(reason: String = "manual") -> bool:
	var payload := SnapshotCodec.to_save(self)
	payload["save_reason"] = reason
	return SaveSystem.save_game(payload)


## 从存档字典恢复世界（读档流程：load_game→restore→get_ui_snapshot 首渲染；
## 非 11 命令面，引擎装配层调用；业务字段随 PR 扩展）。
func restore(data: Dictionary) -> void:
	week = int(data.get("week", 0))
	cum_income = int(data.get("cum_income", 0))
	var tut_data: Dictionary = data.get("tutorial", {})
	tutorial_step = int(tut_data.get("step", 0))
	tutorial_done = bool(tut_data.get("done", false))
	economy.setup(DataLoader.load_json("res://src/data/economy.json"))
	var resources: Dictionary = data.get("resources", {})
	var compute: Dictionary = resources.get("compute", {})
	economy.init_resources(
		int(resources.get("money", 0)),
		int(resources.get("influence", 0)),
		int(compute.get("tier", 1)),
		float(compute.get("hours_remaining", 0.0))
	)
	var sota: Dictionary = data.get("sota", {})
	sota_board.restore(sota)
	sota_best = sota_board.get_best_score()
	rival_best = sota_board.get_rival_best()
	var rng_data: Dictionary = data.get("rng", {})
	rng_stream.restore(rng_data)
	var training_data: Dictionary = data.get("training", {})
	training.restore(training_data)
	var rivals_data: Dictionary = data.get("rivals", {})
	rival_track.setup(DataLoader.load_json("res://src/data/rivals.json"), rng_stream)
	rival_track.restore(rivals_data)
	var staff_data: Dictionary = data.get("staff", {})
	var opening := DataLoader.load_json("res://src/data/opening.json")
	var staff_table := DataLoader.load_json("res://src/data/staff.json")
	roster.setup(staff_table, opening)
	roster.restore(staff_data)
	staff = roster.get_all_staff()
	var tasks_data: Dictionary = data.get("tasks", {})
	task_queue.setup(DataLoader.load_json("res://src/data/tasks.json"))
	task_queue.restore(tasks_data)
	var techs_data: Dictionary = data.get("techs", {})
	tech_fog.setup(DataLoader.load_json("res://src/data/techs.json"))
	tech_fog.restore(techs_data)
	tech_tree.setup(DataLoader.load_json("res://src/data/techs.json"), tech_fog)
	tech_tree.restore(techs_data)
	var stages_data: Dictionary = data.get("stages", {})
	stages.setup(DataLoader.load_json("res://src/data/stages.json"))
	stages.restore(stages_data)
	var events_data: Dictionary = data.get("events", {})
	event_engine.setup(DataLoader.load_json("res://src/data/events.json"))
	event_engine.restore(events_data)
	var flags: Dictionary = data.get("flags", {})
	game_over_flag = bool(flags.get("game_over", false))
	_named_cursor = int(flags.get("name_cursor", 0))
	var names: Array = data.get("player_model_names", [])
	model_name = str(names.back()) if not names.is_empty() else ""
	_named_ids.clear()
	for name_entry: String in names:
		_named_ids[name_entry] = true
	pending_decision = {}
	if not event_engine.get_pending_card().is_empty():
		set_pending_decision(event_engine.get_pending_card())
	_last_signal_report = {}
	_recalculate_research_eff()
	_sync_card_block()


## ============ 模拟与测试入口 ============


## headless 推进 n 周（decision_policy 注入同帧应答，GW3），返回逐周报告。
## 带 pending 卡且策略应答 -1（或无策略）时停止模拟（防死循环）。
func simulate_weeks(n: int, policy: Object = null, _seed: int = 0) -> Array[Dictionary]:
	if policy != null:
		set_meta(DECISION_POLICY_META, policy)
	var reports: Array[Dictionary] = []
	for i in n:
		_resolve_pending_same_frame()
		if not pending_decision.is_empty():
			break  # 带卡不结周：无可用应答，模拟停在此周
		var before := week
		_advance_one_week()
		if week == before:
			break
		if not _last_signal_report.is_empty():
			reports.append(_last_signal_report.duplicate(true))
		if game_over_flag:
			break
	return reports


## ============ 内部：周结管线 v2.1 骨架（步序定型，子系统逐 PR 填充）============


func _advance_one_week() -> void:
	_sync_card_block()
	clock.advance(clock.tick_seconds * GameClock.TICKS_PER_WEEK)


## GW3 同帧应答钩子：有 pending 卡且注入了策略 → 同帧选择，不跨帧不丢拍。
func _resolve_pending_same_frame() -> void:
	if pending_decision.is_empty() or not has_meta(DECISION_POLICY_META):
		return
	var policy: Object = get_meta(DECISION_POLICY_META)
	var options: Array = pending_decision.get("options", [])
	var idx: int = int(policy.pick(pending_decision, options))
	if idx >= 0:
		set_pending_decision({})  # 效果经 apply_delta 过账归 PR7；骨架仅消费卡


## 挂起决策卡登记（事件引擎 PR7 与装配层使用；同步带卡阻塞态，UI 不调用）。
func set_pending_decision(card: Dictionary) -> void:
	pending_decision = card.duplicate(true)
	if event_engine != null:
		event_engine._pending_card = card.duplicate(true)
	if not card.is_empty():
		user_paused = true
	_sync_card_block()


## 带卡不结周（M1/DR-022①）：pending 非空 → clock 第二暂停源置位。
func _sync_card_block() -> void:
	clock.set_blocked_by_card(not pending_decision.is_empty())


## GameClock 周界回调（DR-007 周结序）：
## 步序 1 收支（本 PR，全部经 economy.apply_delta 过账）→ PR8 Game Over 短路
## 接线；PR6 出分；PR7 竞对/迷雾/灵感/事件；PR5 阶段重评。
func settle_week() -> void:
	week += 1
	var roll := RandomNumberGenerator.new()
	roll.seed = hash(str(_income_roll_seed, ":", week))
	var headcount := staff.size()
	var ledger := economy.accrue_week(headcount, _DeterministicRoll.new(roll))
	# cum_income 经营性收入累计（课题+复现等经营性净收入，融资/IPO 不计）
	var weekly_income: int = int(ledger.get("income", 0))
	if weekly_income > 0:
		cum_income += weekly_income

	# 步序 2: Game Over 短路判定（写死在收支后，B3 / DR-021）
	if economy.check_lines() == Economy.WARNED_BANKRUPT:
		game_over_flag = true
		var summary: Dictionary = get_game_over_summary()
		# 终局档落盘（三保险之一，经 SaveSystem 唯一写入口）
		request_save("game_over")
		game_over.emit(summary)
		# 短路：跳过出分/SOTA/竞对/迷雾/事件/阶段/周报，直接返回
		return

	var task_settle := task_queue.settle_week()
	if task_settle.get("completed", false):
		var rp := int(task_settle.get("rp_output", 0))
		var income := int(task_settle.get("income", 0))
		if income > 0:
			economy.apply_delta("money", income, "task_reward")
			cum_income += income
		if rp > 0:
			economy.apply_delta("influence", rp, "task_rp")
		task_state_changed.emit(str(task_settle.get("task_id", "")), "completed")
		var next_active := task_queue.get_active_task()
		if not next_active.is_empty():
			task_state_changed.emit(str(next_active.get("task_id", "")), "active")
	# 周结第 3 步：消费 delayed 效果队列（在出分前消费）
	event_engine.consume_delayed_effects(self)
	# 周结第 4 步出分与第 5 步 SOTA 判定
	var train_res := training.settle_week(research_eff, tech_bonus, economy.get_compute()["tier"])
	if train_res.get("completed", false):
		var score: float = float(train_res.get("score", 0.0))
		var current_name := model_name if model_name != "" else "未命名"
		var broken := sota_board.submit_score(current_name, score)
		if broken:
			sota_best = sota_board.get_best_score()
			sota_updated.emit({"model": current_name, "score": sota_best, "rival": false})
	# 周结第 6 步竞对推进（8 动作剧本 + 论文外溢 + 发版播报）
	var rival_actions := rival_track.settle_week(week, tech_fog)
	for r_act: Dictionary in rival_actions:
		if str(r_act.get("type", "")) == "launch":
			var r_model: String = str(r_act.get("model", "深巷模型"))
			var r_score: float = float(r_act.get("score", 0.0))
			if sota_board.submit_score(r_model, r_score):
				sota_best = sota_board.get_best_score()
				rival_best = r_score
				sota_updated.emit({"model": r_model, "score": r_score, "rival": true})
	# 周结第 7 步迷雾翻雾推进
	tech_fog.advance(get_influence())
	# 周结第 8 步灵感触发与第 9 步事件抽取
	event_engine.evaluate_inspiration(rng_stream, tech_fog)
	var event_context := {
		"money": get_money(),
		"influence": get_influence(),
		"week": week,
	}
	var ev_res := event_engine.evaluate_events(week, rng_stream, event_context, self)
	if not event_engine.get_pending_card().is_empty():
		if has_meta(DECISION_POLICY_META):
			set_pending_decision(event_engine.get_pending_card())
		else:
			# 无 policy 注入时自动默认选项消费，保障全自动模拟不卡死
			event_engine.choose_decision_option(0, self)
			event_engine._pending_card.clear()
	# 周结第 10 步阶段软门重评
	var stage_context := {
		"crossover_count": tech_fog.get_crossover_progress(),
		"lit_techs": tech_fog.get_lit_techs(),
		"money": get_money(),
	}
	var stage_adv := stages.reevaluate(stage_context)
	if stage_adv.get("advanced", false):
		var mod: Dictionary = stage_adv.get("economy_mod", {})
		economy.set_stage_depr(
			float(mod.get("reproduce_factor", 1.0)), int(mod.get("grant_interval_add_weeks", 0))
		)
	var report := {
		"week": week,
		"money_row":
		{
			"income": Formatter.format_money(int(ledger["income"])),
			"expense": Formatter.format_money(int(ledger["expense"])),
			"net": Formatter.format_delta(int(ledger["net"])),
		},
		"line_state": economy.check_lines(),
	}
	_last_signal_report = report
	_emit_resources()
	week_settled.emit(report)
	# 步序 11: 周界自动存档（三保险之一）
	request_save("weekly_auto")


## 收入脉冲确定性随机源（PR7 前 MVP 占位：随机源接口与 rng_stream 对齐，
## World 按 seed+week 播种，同 seed 双跑哈希一致的确定性由此保证）。
class _DeterministicRoll:
	extends RefCounted

	var _rng: RandomNumberGenerator

	func _init(rng: RandomNumberGenerator) -> void:
		_rng = rng

	func randi_in_range(low: int, high: int) -> int:
		return _rng.randi_range(low, high)


func _recalculate_tech_bonus() -> void:
	if tech_tree != null:
		tech_bonus = tech_tree.get_tech_bonus()
	else:
		tech_bonus = 0.0


func _recalculate_research_eff() -> void:
	# DR-005R：research_eff=Σ 已分配研究力（求和版）。
	if roster != null:
		research_eff = roster.get_research_eff(StaffRoster.SLOT_TRAINING)
	else:
		research_eff = 0


func _on_clock_tick(week_ticks: int) -> void:
	# progress_ticked 刻级信号（M7）：值变才发，防高频无意义广播
	var active := task_queue.get_active_task()
	var current_progress: Dictionary = {}
	if not active.is_empty():
		var task_id := str(active.get("task_id", ""))
		var weeks_left := int(active.get("weeks_left", 0))
		var duration := int(active.get("duration_weeks", 1))
		var week_progress: float = float(week_ticks) / float(GameClock.TICKS_PER_WEEK)
		var total_weeks_done: float = float(duration - weeks_left) + week_progress
		var percent: float = clampf(total_weeks_done / float(maxi(duration, 1)), 0.0, 1.0)
		current_progress = {
			"task_id": task_id,
			"weeks_left": weeks_left,
			"progress_pct": int(percent * 100),
		}
	if current_progress != _last_emitted_progress and not current_progress.is_empty():
		_last_emitted_progress = current_progress.duplicate()
		progress_ticked.emit(current_progress)


func _on_week_boundary(_new_week: int) -> void:
	pass  # 周结统一走 settle_week；保留接线点供刻级回调扩展


func _not_implemented_yet(command: String) -> void:
	push_warning("GameWorld: 命令 %s 将在后续 PR 接入" % command)
	toast_queued.emit({"text_key": "sys_save_hint", "command": command})
