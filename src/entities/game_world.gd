# gdlint:ignore = max-public-methods
## 门面/资源服务类：方法即契约面与只读数据面，数量随功能增长，故豁免该上限。
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
	"upgrade_compute",
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
const BENCHMARKS_PATH: String = "res://src/data/benchmarks.json"
const BENCHMARK_KEY: String = "bench_gkp"
const MODEL_BASES_PATH: String = "res://src/data/model_bases.json"
const TASKS_PATH: String = "res://src/data/tasks.json"
const ECONOMY_PATH: String = "res://src/data/economy.json"
const RIVALS_PATH: String = "res://src/data/rivals.json"
const TECHS_PATH: String = "res://src/data/techs.json"
const UI_DISPLAY_PATH: String = "res://src/data/ui_display.json"
## 预告口径：任务剩余周数 <= 该值即判定"下一周结完成"（settle_week 每周期减 1）。
const FORECAST_SETTLE_WEEKS: int = 1
## 十进制底数（分数文本精度换算用）。
const DECIMAL_BASE: float = 10.0  # num-ok: 十进制底数（数学常数，非游戏数值）

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
var _last_emitted_progress: Dictionary = {}
## 只读数据面缓存（ADR-0016：L3 零业务计算/L3 禁读 L4，派生数据一律 L2 出）。
var _economy_cfg: Dictionary = {}
var _tasks_cfg: Dictionary = {}
var _techs_cfg: Dictionary = {}
var _rivals_cfg: Dictionary = {}
var _ui_display: Dictionary = {}
var _score_params: Dictionary = {}
## 出分与榜单（分级显示 / 命名仪式判定的数据源）。
var _scored_once: bool = false
var _player_best_score: float = 0.0
var _last_ledger: Dictionary = {}
var _rival_warn_level: String = RivalTrack.WARN_NONE
var _rival_warn_weeks_left: int = 0


## 组装子系统（GameClock/Economy/StaffRoster/TaskQueue/TechTree/Stages 强持有+参数注入；不回指）。
func _init() -> void:
	_load_data_caches()
	clock = GameClock.new()
	clock.setup(DataLoader.load_json("res://src/data/clock.json"), self)
	clock.week_boundary_reached.connect(_on_week_boundary)
	clock.tick_advanced.connect(_on_clock_tick)
	economy = Economy.new()
	economy.setup(_economy_cfg)
	economy.warned.connect(
		func(amount: int) -> void:
			toast_queued.emit({"text_key": "sys_save_hint", "warned": amount})
	)
	roster = StaffRoster.new()
	task_queue = TaskQueue.new()
	task_queue.setup(_tasks_cfg)
	tech_fog = TechFog.new()
	tech_tree = TechTree.new()
	stages = Stages.new()
	training = TrainingProject.new()
	sota_board = SotaBoard.new()
	rng_stream = RngStream.new()
	rival_track = RivalTrack.new()
	rival_track.rival_warned.connect(_on_rival_warned)
	event_engine = EventEngine.new()
	tech_fog.setup(_techs_cfg)
	tech_tree.setup(_techs_cfg, tech_fog)
	stages.setup(DataLoader.load_json("res://src/data/stages.json"))
	training.setup(DataLoader.load_json(MODEL_BASES_PATH), _score_params)
	event_engine.setup(DataLoader.load_json("res://src/data/events.json"))


## 只读数据面配置缓存（L2 读 L4 唯一入口；L3 一律经数据面取数，ADR-0016）。
func _load_data_caches() -> void:
	_economy_cfg = DataLoader.load_json(ECONOMY_PATH)
	_tasks_cfg = DataLoader.load_json(TASKS_PATH)
	_techs_cfg = DataLoader.load_json(TECHS_PATH)
	_rivals_cfg = DataLoader.load_json(RIVALS_PATH)
	_ui_display = DataLoader.load_json(UI_DISPLAY_PATH)
	_score_params = _load_score_params()


## 竞对逼近预警缓存（rival_track 判定单点，L2 只做只读转述）。
func _on_rival_warned(level: String, _action_id: String, weeks_left: int) -> void:
	_rival_warn_level = level
	_rival_warn_weeks_left = weeks_left


## 出分参数装载（benchmarks.json → ScoreMath.normalize_params；L0 不读盘，由 L2 注入）
func _load_score_params() -> Dictionary:
	var benchmarks := DataLoader.load_json(BENCHMARKS_PATH)
	var row: Dictionary = benchmarks.get(BENCHMARK_KEY, {})
	if row.is_empty():
		push_error("GameWorld: %s 缺 '%s' 行" % [BENCHMARKS_PATH, BENCHMARK_KEY])
		return {}
	return ScoreMath.normalize_params(row)


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


## ============ 只读数据面（ADR-0016：L3 零业务计算，派生/统计/预测一律在此出数）============


## 下周净流入预告（RU-02 / DR-031 D1⑥；不进命令面，随快照/周报载荷分发）。
## 逐项 = 下一周结 ledger 同口径：已入账待结算项（economy 周账，ADR-0015 账期契约）
## + 下周周结确定项（占槽任务结算收入 + 固定工资）。随机项（事件/竞对）不过账 money。
func get_income_forecast() -> Dictionary:
	var ledger: Dictionary = economy.get_week_ledger()
	var wage: int = _wage_per_week()
	var task_income: int = 0
	var task_rp: int = 0
	var active: Dictionary = task_queue.get_active_task()
	if not active.is_empty():
		var weeks_left: int = int(active.get("weeks_left", 0))
		if weeks_left <= FORECAST_SETTLE_WEEKS:
			var task_cfg: Dictionary = _tasks_cfg.get(str(active.get("task_id", "")), {})
			task_income = int(task_cfg.get("income", 0))
			task_rp = int(task_cfg.get("rp_output", 0))
	var booked_income: int = int(ledger.get("income", 0))
	var booked_expense: int = int(ledger.get("expense", 0))
	var income: int = booked_income + task_income
	var expense: int = booked_expense + wage
	return {
		"available": not _ui_display.is_empty(),
		"income": income,
		"expense": expense,
		"net": income - expense,
		"influence_delta": int(ledger.get("influence_delta", 0)) + task_rp,
		"wage": wage,
		"task_income": task_income,
		"display": _forecast_display_cfg(),
		"lines":
		[
			{"id": "wage", "amount": -wage},
			{"id": "opex", "amount": -booked_expense},
			{"id": "task", "amount": booked_income + task_income},
		],
	}


## 预告文案键（L3 禁读 L4：文案随数据面下发，L3 只拼接排版）。
func _forecast_display_cfg() -> Dictionary:
	var cfg: Dictionary = _ui_display.get("forecast", {})
	return {
		"row_label": str(cfg.get("row_label", "")),
		"expanded_label": str(cfg.get("expanded_label", "")),
		"unavailable_text": str(cfg.get("unavailable_text", "")),
		"approx_prefix": str(cfg.get("approx_prefix", "")),
		"line_separator": str(cfg.get("line_separator", "")),
		"net_separator": str(cfg.get("net_separator", "")),
		"net_label": str(cfg.get("net_label", "")),
		"line_labels": (cfg.get("line_labels", {}) as Dictionary).duplicate(true),
	}


## 员工三口径只读视图（ADR-0016；v0.1.3 反馈① total/assigned/idle）。
func get_staff_view() -> Dictionary:
	var rows: Array = roster.to_snapshot()
	var assigned_count: int = 0
	for row: Dictionary in rows:
		if str(row.get("assigned", "")) != "":
			assigned_count += 1
	return {
		"rows": rows,
		"total": rows.size(),
		"assigned": assigned_count,
		"idle": rows.size() - assigned_count,
	}


## 域进度只读视图（{lit,total} 按域；ADR-0016 决策②：L3 禁读 L4 表）。
## 分母真源单点 = TechFog.get_domain_totals()（实表节点数），此处不得另行统计。
func get_domain_progress() -> Dictionary:
	var counts: Dictionary = tech_fog.get_domain_counts()
	var totals: Dictionary = tech_fog.get_domain_totals()
	var labels: Dictionary = _ui_display.get("domain_labels", {})
	var summary_cfg: Dictionary = _ui_display.get("domain_summary", {})
	var domains: Array[Dictionary] = []
	var lit_total: int = 0
	for domain_variant: Variant in _techs_cfg.get("domain_enum", []):
		var domain: String = str(domain_variant)
		var lit: int = int(counts.get(domain, 0))
		lit_total += lit
		(
			domains
			. append(
				{
					"id": domain,
					"label": str(labels.get(domain, domain)),
					"lit": lit,
					"total": int(totals.get(domain, 0)),
					"mainline": _domain_flag(domain, "counts_mainline", true),
					"researchable": _domain_flag(domain, "researchable", true),
				}
			)
		)
	return {
		"domains": domains,
		"lit_total": lit_total,
		"total_nodes": tech_fog.get_total_nodes(),
		"summary":
		{
			"label": str(summary_cfg.get("label", "")),
			"label_separator": str(summary_cfg.get("label_separator", "")),
			"total_label": str(summary_cfg.get("total_label", "")),
			"separator": str(summary_cfg.get("separator", "")),
			"unresearchable_note": str(summary_cfg.get("unresearchable_note", "")),
		},
	}


## 科技节点列表只读视图（L3 渲染所需元数据；替代 L3 直读 techs.json）。
func get_tech_list_view() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var nodes: Dictionary = _techs_cfg.get("nodes", {})
	for tech_id: String in nodes:
		var node: Dictionary = nodes[tech_id]
		(
			rows
			. append(
				{
					"id": tech_id,
					"name": str(node.get("name", tech_id)),
					"cost": int(node.get("cost", 0)),
					"rp_cost": int(node.get("rp_cost", 0)),
					"parents": node.get("parents", []),
					"domain": str(node.get("domain", "")),
					"state": tech_fog.get_state(tech_id),
				}
			)
		)
	return rows


## 竞对/榜单只读视图（ADR-0016：名称/差距/进度/预警等级 + 玩家分数分级显示）。
func get_rival_view() -> Dictionary:
	var timeline: Array = _rivals_cfg.get("timeline", [])
	var cursor: int = rival_track.get_cursor()
	var progress: float = 0.0
	if not timeline.is_empty():
		progress = float(cursor) / float(timeline.size())
	return {
		"rival_name": str(_rivals_cfg.get("name", "")),
		"rival_best": rival_best,
		"player_model": model_name,
		"player_score": _player_best_score,
		"score_display": get_score_display(_player_best_score),
		"gap": rival_best - _player_best_score,
		"rival_progress": progress,
		"rival_cursor": cursor,
		"rival_total": timeline.size(),
		"warn_level": _rival_warn_level,
		"warn_weeks_left": _rival_warn_weeks_left,
		"has_scored": _scored_once,
	}


## 分数分级显示（RU-01：低于阈值主台只显档位标签，真值由周报保留）。
func get_score_display(score: float) -> Dictionary:
	var tiers: Array = _ui_display.get("score_tiers", [])
	var display_cfg: Dictionary = _ui_display.get("score_display", {})
	var separator: String = str(display_cfg.get("tier_separator", ""))
	var unavailable_text: String = str(display_cfg.get("unavailable_text", ""))
	if tiers.is_empty():
		# 阈值键缺失 = 退化为"显示真值"（V1-19 口径），不静默隐藏真值
		push_error("GameWorld.get_score_display: %s 缺 score_tiers" % UI_DISPLAY_PATH)
		return {
			"tier_id": "",
			"label": "",
			"reveal_truth": true,
			"score": score,
			"score_text": _format_score(score),
			"separator": separator,
			"unavailable_text": unavailable_text,
		}
	var chosen: Dictionary = {}
	for tier_variant: Variant in tiers:
		var tier: Dictionary = tier_variant
		if score >= float(tier.get("min_score", 0.0)):
			chosen = tier
	return {
		"tier_id": str(chosen.get("id", "")),
		"label": str(chosen.get("label", "")),
		"reveal_truth": bool(chosen.get("reveal_truth", false)),
		"score": score,
		"score_text": _format_score(score),
		"separator": separator,
		"unavailable_text": unavailable_text,
	}


## 命名仪式视图（X7：出分且未命名 → L3 推 NAMING_DIALOG）。
func get_naming_view() -> Dictionary:
	return {
		"has_scored": _scored_once,
		"pending": _scored_once and model_name.is_empty(),
		"model_name": model_name,
	}


## 最近一次周结账目（预告=实际对账用；只读，非契约命令）。
func get_last_ledger() -> Dictionary:
	return _last_ledger.duplicate(true)


## 每周固定工资（economy.json 真源 × 在册人数；与 Economy.accrue_fixed_expense 同口径）。
func _wage_per_week() -> int:
	var wage_variant: Variant = DataLoader.require_key(_economy_cfg, "wage_per_staff", ECONOMY_PATH)
	if wage_variant == null:
		return 0
	return int(wage_variant) * staff.size()


## 域标志（techs.json domain_flags.<flag>；未标注域取 default_value）。
func _domain_flag(domain: String, flag: String, default_value: bool) -> bool:
	var flags: Dictionary = _techs_cfg.get("domain_flags", {})
	var row: Variant = flags.get(domain)
	if row is Dictionary:
		return bool((row as Dictionary).get(flag, default_value))
	return default_value


## 分数文本（精度取 benchmarks.json score_precision；缺失退化为原值文本）。
func _format_score(score: float) -> String:
	var precision_variant: Variant = _score_params.get("score_precision")
	if precision_variant == null or float(precision_variant) <= 0.0:
		return str(score)
	var digits: int = int(round(log(1.0 / float(precision_variant)) / log(DECIMAL_BASE)))
	return ("%." + str(digits) + "f") % score


## ============ 命令面（11）============


## 建档（B1/GW8）：seed 定格开局态（灵犀 Chat 已发布+三研究员+W0 态）。
func start_new_game(seed: int = 0) -> void:
	rng_seed = seed
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
	_scored_once = false
	_player_best_score = 0.0
	_last_ledger = {}
	_rival_warn_level = RivalTrack.WARN_NONE
	_rival_warn_weeks_left = 0
	economy.setup(_economy_cfg)
	var opening := DataLoader.load_json("res://src/data/opening.json")
	var compute: Dictionary = opening.get("compute", {})
	economy.init_resources(
		int(opening.get("money", 0)),
		int(opening.get("influence", 0)),
		int(compute.get("tier", 1)),
		float(compute.get("hours_remaining", 0.0))
	)
	economy.recharge_weekly()  # 开局即满周预算（Q-R2/P6）
	rival_best = float(opening.get("rival_best", rival_best))
	var staff_table := DataLoader.load_json("res://src/data/staff.json")
	roster.setup(staff_table, opening)
	staff = roster.get_all_staff()
	task_queue.setup(_tasks_cfg)
	tech_fog.setup(_techs_cfg)
	tech_tree.setup(_techs_cfg, tech_fog)
	stages.setup(DataLoader.load_json("res://src/data/stages.json"))
	training.setup(DataLoader.load_json(MODEL_BASES_PATH), _score_params)
	sota_board.setup(opening, DataLoader.load_json(BENCHMARKS_PATH))
	sota_best = sota_board.get_best_score()
	rival_best = sota_board.get_rival_best()
	rival_track.setup(_rivals_cfg, rng_stream)
	event_engine.setup(DataLoader.load_json("res://src/data/events.json"))
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
		"training_headcount": roster.get_slot_count(StaffRoster.SLOT_TRAINING),
	}
	var res := training.start_training(base_id, context)
	if res.get("ok", false):
		_emit_resources()


## 买卡只读视图（UI 按钮三态数据面；非契约命令）
func get_compute_upgrade_view() -> Dictionary:
	return economy.get_upgrade_view()


## 买卡契约命令（N9，命令面 11→12）：升档经 Economy.upgrade_compute 过账，
## 资源信号驱动 UI 刷新（compute_tier 经快照读取）。
func upgrade_compute(target_tier: int) -> bool:
	var ok: bool = economy.upgrade_compute(target_tier)
	if ok:
		_emit_resources()
	return ok


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
		if not TextService.is_name_allowed(stripped_brackets, TextService.name_max_chars()):
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
	# 读档路径不重抽 jitter（consume_rng=false）：否则 RNG 序列多消费 4 次后漂移（架构复审 D3）
	rival_track.setup(DataLoader.load_json("res://src/data/rivals.json"), rng_stream, false)
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
	economy.set_cum_influence(int(flags.get("cum_influence", 0)))  # 翻雾供给源（RK-04）
	# 呈现层读档还原（#78）：出分标记与玩家最高分（分级显示/命名仪式判定数据源）
	_scored_once = bool(flags.get("scored", false))
	_player_best_score = float(flags.get("player_best_score", 0.0))
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
	clock.advance(clock.tick_seconds * float(clock.ticks_per_week))


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

	# 步序 0: 预告快照（周结前口径）——周报对账尾注与 [T] 预告=实际 同源
	var forecast_before: Dictionary = get_income_forecast()

	# 步序 1: 卡时预算重置（ADR-0011）+ 经营收入结算（占槽任务，DR-031/C1）+ 固定支出
	economy.recharge_weekly()
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
	economy.accrue_fixed_expense(staff.size())
	var ledger := economy.get_week_ledger()
	_last_ledger = ledger.duplicate(true)  # 预告=实际对账锚（get_last_ledger）
	economy.emit_week_warning(ledger)

	# 步序 2: Game Over 短路判定（在全部经营收入结算之后；ADR-0015 / DR-021 B3）
	if economy.check_lines() == Economy.WARNED_BANKRUPT:
		game_over_flag = true
		var summary: Dictionary = get_game_over_summary()
		# 终局档落盘（三保险之一，经 SaveSystem 唯一写入口）
		request_save("game_over")
		game_over.emit(summary)
		# 短路：跳过出分/SOTA/竞对/迷雾/事件/阶段/周报，直接返回
		return

	# 账期翻页：步序 3 起的过账计入下一个未结算周（ADR-0015 账期契约）
	economy.reset_week_ledger()

	# 周结第 3 步：消费 delayed 效果队列（在出分前消费）
	event_engine.consume_delayed_effects(self)
	# 周结第 4 步出分与第 5 步 SOTA 判定（训练先占用本周卡时预算；不过账 money）
	if training.is_training():
		economy.apply_delta("compute", -training.get_weekly_hours(), "training_compute")
	var train_res := training.settle_week(research_eff, tech_bonus, economy.get_compute()["tier"])
	if train_res.get("completed", false):
		var score: float = float(train_res.get("score", 0.0))
		# 出分登记（分级显示/命名仪式判定的唯一来源；模型名沿用未命名占位）
		_scored_once = true
		_player_best_score = maxf(_player_best_score, score)
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
	# 周结第 7 步迷雾翻雾推进（RK-04：供给源 = 累计获得影响力，非当前余额）
	tech_fog.advance_with_context({"cum_influence": economy.get_cum_influence()})
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
		"rows": _build_report_rows(ledger, forecast_before),
		"line_state": economy.check_lines(),
	}
	_last_signal_report = report
	_emit_resources()
	week_settled.emit(report)
	# 步序 11: 周界自动存档（三保险之一）
	request_save("weekly_auto")


## 最近一次周结报告（周报 UI 唯一数据源；非契约命令，只读）。
## 修复 RE-02 的 UI 侧断裂：此前 UI 传 get_resource_view()（无 rows 键）→ 恒显兜底文案。
func get_last_report() -> Dictionary:
	return _last_signal_report.duplicate(true)


## 周报文本行（TextService 单真源；L3 只渲染不拼装）。
## 尾部两行（出分后）：分数真值行（RU-01：主台可只显档位标签，周报恒留真值）
## 与预告对账尾注（Δ-06：把"预告=实际"搬到玩家眼前）。
func _build_report_rows(ledger: Dictionary, forecast_before: Dictionary = {}) -> Array[String]:
	var rows: Array[String] = []
	(
		rows
		. append(
			(
				TextService
				. format(
					"report_money_row",
					{
						"income": Formatter.format_money(int(ledger.get("income", 0))),
						"expense": Formatter.format_money(int(ledger.get("expense", 0))),
						"net": Formatter.format_delta(int(ledger.get("net", 0))),
					}
				)
			)
		)
	)
	(
		rows
		. append(
			(
				TextService
				. format(
					"report_reputation_row",
					{
						"influence": str(get_influence()),
						"influence_delta":
						Formatter.format_delta(int(ledger.get("influence_delta", 0))),
					}
				)
			)
		)
	)
	if _scored_once:
		rows.append(
			Formatter.format_stat_line(
				str(_ui_display.get("report_score_label", "")), _format_score(_player_best_score)
			)
		)
	var check_row: String = _build_forecast_check_row(forecast_before, ledger)
	if not check_row.is_empty():
		rows.append(check_row)
	return rows


## 预告对账尾注（文案键在 ui_display.json；不一致时同样如实标注，不美化）。
func _build_forecast_check_row(forecast_before: Dictionary, ledger: Dictionary) -> String:
	var cfg: Dictionary = _ui_display.get("forecast", {})
	var label: String = str(cfg.get("check_label", ""))
	var template: String = str(cfg.get("check_template", ""))
	if forecast_before.is_empty() or label.is_empty() or template.is_empty():
		return ""
	var approx: String = str(cfg.get("approx_prefix", ""))
	var predicted: int = int(forecast_before.get("net", 0))
	var actual: int = int(ledger.get("net", 0))
	var text: String = template
	text = text.replace("{predicted}", approx + Formatter.format_delta(predicted))
	text = text.replace("{actual}", Formatter.format_delta(actual))
	var mark: String = (
		str(cfg.get("check_matched_mark", ""))
		if predicted == actual
		else str(cfg.get("check_mismatch_mark", ""))
	)
	return Formatter.format_stat_line(label, "%s %s" % [text, mark])


## 收入脉冲确定性随机源已在批 1a 随脉冲源退役删除（DR-031/C1 + ADR-0008 决策 3：
## RNG 消费点回到 3 处，全部经 RngStream 域；`entities/` 内禁止新建 RandomNumberGenerator）。


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
		var week_progress: float = float(week_ticks) / float(clock.ticks_per_week)
		var total_weeks_done: float = float(duration - weeks_left) + week_progress
		var percent: float = clampf(total_weeks_done / float(maxi(duration, 1)), 0.0, 1.0)
		current_progress = {
			"task_id": task_id,
			"weeks_left": weeks_left,
			"progress_pct": int(percent * 100),  ## num-ok: 百分比换算（表现层系数）
		}
	if current_progress != _last_emitted_progress and not current_progress.is_empty():
		_last_emitted_progress = current_progress.duplicate()
		progress_ticked.emit(current_progress)


func _on_week_boundary(_new_week: int) -> void:
	pass  # 周结统一走 settle_week；保留接线点供刻级回调扩展


func _not_implemented_yet(command: String) -> void:
	push_warning("GameWorld: 命令 %s 将在后续 PR 接入" % command)
	toast_queued.emit({"text_key": "sys_save_hint", "command": command})
