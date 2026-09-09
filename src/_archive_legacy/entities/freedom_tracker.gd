class_name FreedomTracker
extends RefCounted

## 自由期三线追踪器（L2 RefCounted，issue #82 / DR-031 + 纪要 §十二 / 需求 §11 RF-01…RF-04）：
## - **RF-01 三线计数器**：霸榜周数（SOTA 保霸周 +1）/ 树已探明 n / 影响力存量；
##   后两者读现成真源（TechFog 域计数 / Economy 影响力），**不新增计数器**；
## - **RF-02 两阶段可见**：W25 起常显（弱展示，长线目标线）→ 首达饱和阈值分
##   （`benchmarks.json` `saturation.score_threshold`）升主权重 + 弹横幅（不硬编码 W54）；
## - **RF-03 终局触发**：走满 `clock.json` 的 `run_weeks` 当周产出终局段（Q-R3：自动弹、
##   玩家可继续自由期、与破产 Game Over 卡两套并存）；
## - **RF-04 后半不空转**：逐周产出三线变化清单（变化来源见 `changed_lines`）。
##
## 存档：计数器入 `flags{}` 开放容器（加键零迁移，红线 4）；树 n / 影响力不落盘（读现成）。

## 三线可见阶段（单调不回退：HIDDEN → WEAK → PRIMARY；枚举值隐式 0/1/2，勿写显式字面量——
## #71 数值门禁 `test_no_hardcoded_numbers_outside_data` 只白名单 0/1/-1）。
enum Stage {
	HIDDEN,  ## W25 前：三线不显
	WEAK,  ## W25 起：资源栏副行弱展示
	PRIMARY,  ## 首达饱和阈值：升工作区主权重 + 弹横幅
}

const STAGE_HIDDEN: String = "hidden"
const STAGE_WEAK: String = "weak"
const STAGE_PRIMARY: String = "primary"

## flags 开放容器键（全部带 `freedom_` 前缀，旧档缺键由 restore 兜底为 0/false）。
const FLAG_KING_WEEKS: String = "freedom_king_weeks"
const FLAG_SOTA_TIMES: String = "freedom_sota_times"
const FLAG_FINALE_SHOWN: String = "freedom_finale_shown"
const FLAG_LOWEST_MONEY: String = "freedom_lowest_money"
const FLAG_LOWEST_MONEY_WEEK: String = "freedom_lowest_money_week"
const FLAG_LAST_RESEARCH_WEEK: String = "freedom_last_research_week"
const FLAG_LAST_RESEARCH_ID: String = "freedom_last_research_id"
const FLAG_COSTLIEST_TRAINING_COST: String = "freedom_costliest_training_cost"
const FLAG_COSTLIEST_TRAINING_ID: String = "freedom_costliest_training_id"

## 三线变化来源标识（RF-04：封顶后 ≥3 次变化由测试统计，非 UI 文案）。
const LINE_KING_WEEKS: String = "king_weeks"
const LINE_TREE: String = "tree_n"
const LINE_INFLUENCE: String = "influence"

var king_weeks: int = 0
var sota_times: int = 0
var lowest_money: int = 0
var lowest_money_week: int = 0
var last_research_week: int = 0
var last_research_id: String = ""
var costliest_training_cost: int = 0
var costliest_training_id: String = ""

var _stage: Stage = Stage.HIDDEN
var _finale_shown: bool = false
var _display_week: int = 0
var _score_threshold: float = 0.0
var _run_weeks: int = 0
var _prev_tree_n: int = -1
var _prev_influence: int = -1


## 注入呈现/节奏参数（全部来自 L4 数据表；缺键即保持 0 = 三线不显、终局不触发）。
func setup(cfg: Dictionary) -> void:
	_display_week = int(cfg.get("display_week", 0))
	_score_threshold = float(cfg.get("score_threshold", 0.0))
	_run_weeks = int(cfg.get("run_weeks", 0))


## 新开局归零（含派生缓存；不入档字段一并清空）。
func reset() -> void:
	king_weeks = 0
	sota_times = 0
	lowest_money = 0
	lowest_money_week = 0
	last_research_week = 0
	last_research_id = ""
	costliest_training_cost = 0
	costliest_training_id = ""
	_stage = Stage.HIDDEN
	_finale_shown = false
	_prev_tree_n = -1
	_prev_influence = -1


## SOTA 次数 +1（玩家出分破纪录当周，由 GameWorld 出分判定驱动）。
func record_sota() -> void:
	sota_times += 1


## 关键决策回溯①：最晚的一次点树（成功启动研究时调用）。
func record_research(week_no: int, tech_id: String) -> void:
	last_research_week = week_no
	last_research_id = tech_id


## 关键决策回溯②：最贵的训练（成功启动训练时调用，取成本更高者）。
func record_training(cost: int, base_id: String) -> void:
	if cost >= costliest_training_cost:
		costliest_training_cost = cost
		costliest_training_id = base_id


## 关键决策回溯③：最险的破产边缘（周结后记录资金低点）。
func record_money(week_no: int, money: int) -> void:
	if lowest_money_week == 0 or money < lowest_money:
		lowest_money = money
		lowest_money_week = week_no


## 周结三线结算（周结管线末步调用；纯逻辑，可单测）。
## ctx 键：week / player_best_score / player_is_champion / tree_n / tree_total / influence。
func settle_week(ctx: Dictionary) -> Dictionary:
	var week_no: int = int(ctx.get("week", 0))
	var tree_n: int = int(ctx.get("tree_n", 0))
	var influence: int = int(ctx.get("influence", 0))
	var king_delta: int = 0
	if bool(ctx.get("player_is_champion", false)):
		king_weeks += 1
		king_delta = 1
	var changed: Array[String] = []
	if king_delta > 0:
		changed.append(LINE_KING_WEEKS)
	if _prev_tree_n >= 0 and tree_n > _prev_tree_n:
		changed.append(LINE_TREE)
	if _prev_influence >= 0 and influence > _prev_influence:
		changed.append(LINE_INFLUENCE)
	_prev_tree_n = tree_n
	_prev_influence = influence
	var prev_stage: Stage = _stage
	_stage = _resolve_stage(week_no, float(ctx.get("player_best_score", 0.0)))
	return {
		"week": week_no,
		"stage": _stage,
		"stage_id": get_stage_id(),
		"king_weeks": king_weeks,
		"sota_times": sota_times,
		"tree_n": tree_n,
		"tree_total": int(ctx.get("tree_total", 0)),
		"influence": influence,
		"king_delta": king_delta,
		"changed_lines": changed,
		"banner": prev_stage != Stage.PRIMARY and _stage == Stage.PRIMARY,
		"finale_due": is_finale_due(week_no),
	}


func get_stage() -> Stage:
	return _stage


func get_stage_id() -> String:
	match _stage:
		Stage.PRIMARY:
			return STAGE_PRIMARY
		Stage.WEAK:
			return STAGE_WEAK
		_:
			return STAGE_HIDDEN


func get_display_week() -> int:
	return _display_week


func get_run_weeks() -> int:
	return _run_weeks


func is_finale_shown() -> bool:
	return _finale_shown


## 终局是否应触发（走满 run_weeks 且本局未弹过；Q-R3 自动弹一次，可继续自由期）。
func is_finale_due(week_no: int) -> bool:
	return _run_weeks > 0 and week_no >= _run_weeks and not _finale_shown


func mark_finale_shown() -> void:
	_finale_shown = true


func to_save() -> Dictionary:
	return {
		FLAG_KING_WEEKS: king_weeks,
		FLAG_SOTA_TIMES: sota_times,
		FLAG_FINALE_SHOWN: _finale_shown,
		FLAG_LOWEST_MONEY: lowest_money,
		FLAG_LOWEST_MONEY_WEEK: lowest_money_week,
		FLAG_LAST_RESEARCH_WEEK: last_research_week,
		FLAG_LAST_RESEARCH_ID: last_research_id,
		FLAG_COSTLIEST_TRAINING_COST: costliest_training_cost,
		FLAG_COSTLIEST_TRAINING_ID: costliest_training_id,
	}


## 读档还原（flags 开放容器缺键即兜底默认值 → 旧档零迁移）。
func restore(flags: Dictionary) -> void:
	king_weeks = int(flags.get(FLAG_KING_WEEKS, 0))
	sota_times = int(flags.get(FLAG_SOTA_TIMES, 0))
	_finale_shown = bool(flags.get(FLAG_FINALE_SHOWN, false))
	lowest_money = int(flags.get(FLAG_LOWEST_MONEY, 0))
	lowest_money_week = int(flags.get(FLAG_LOWEST_MONEY_WEEK, 0))
	last_research_week = int(flags.get(FLAG_LAST_RESEARCH_WEEK, 0))
	last_research_id = str(flags.get(FLAG_LAST_RESEARCH_ID, ""))
	costliest_training_cost = int(flags.get(FLAG_COSTLIEST_TRAINING_COST, 0))
	costliest_training_id = str(flags.get(FLAG_COSTLIEST_TRAINING_ID, ""))


## 阶段解析（单调：饱和阈值优先于 W25 时点；两者均为 L4 注入，代码零硬编码）。
func _resolve_stage(week_no: int, player_best_score: float) -> Stage:
	if _score_threshold > 0.0 and player_best_score >= _score_threshold:
		return Stage.PRIMARY
	if _display_week > 0 and week_no >= _display_week:
		return Stage.WEAK
	return Stage.HIDDEN
