class_name TutorialMachine
extends RefCounted
## L2 六步目标卡引导状态机（#152；onboarding-spec A.1 OP-ONB-01~06/B.2 +
## architecture-100 §2.1 onboarding/tutorial_machine.gd）。
## 引导纪律（architecture §2.1 onboarding 行硬约束）：
## - **引导只读世界状态+发指令，绝不直接改玩法状态**：六步达成判定全部经
##   构造注入谓词（装配方从 TaskBoard/TreeResearch/ModelLibrary/RivalPack
##   数据面串接；默认恒假=未装配时引导静默等待，不发明玩法事实）；
## - 发指令=step_advanced / chain_completed / onboarding_error 三信号
##   （L3 消费翻新目标卡/点亮进度点/兜底 toast）；本类零玩法系统引用
##   （单向无环，无需 weakref）；
## - 错误态=跳过不阻塞（A.3）：谓词故障/表配置损坏 → onboarding_error 上报 +
##   该步不产生阻塞效应（扫描继续，后续步照常点亮），世界照走；
## - 步数/节拍锚点读 onboarding.json（数值零硬编码）；步 id=enum 封闭集合
##   （stringly-typed 防线），文案键=onb_goal_N 规则派生（texts-keys 同源）。
## 存档：flags 开放容器设计（numerics §八），get_save_view/restore_from_save
##   纯值字典；SnapshotCodec 接线归 World 装配批。
## RefCounted 零 Node；headless 可单测。

signal step_advanced(payload: Dictionary)
signal chain_completed(payload: Dictionary)
signal onboarding_error(payload: Dictionary)

## 六步（issue 标题链：接单→点树→攒影响力→排训练→出分→命名→首对手；
## 出分+命名=一格——命名完成谓词由装配方串接 ModelLibrary 计数）
enum Step { FIRST_TASK, FIRST_TREE, INFLUENCE, FIRST_TRAIN, FIRST_SCORE, FIRST_RIVAL }

const ONBOARDING_PATH: String = "res://src/data/onboarding.json"
const KEY_GOAL_CARD_STEPS: String = "onb_goal_card_steps"

## 步 id 稳定串（存档 flags/L3 锚点用；索引与 Step 枚举严格对齐，单一真源）
const STEP_IDS: Array[String] = [
	"first_task",
	"first_tree",
	"influence",
	"first_train",
	"first_score",
	"first_rival",
]

## 文案键派生规则（texts.json onb_goal_1..6 已落 22 键；存在性断言在 schema 测试）
const GOAL_KEY_FMT: String = "onb_goal_%d"
const GOAL_DETAIL_KEY_FMT: String = "onb_goal_%d_detail"

## 六步达成谓词注入（装配方串接世界只读数据面；默认恒假=引导静默等待）
var is_task_started: Callable = func() -> bool: return false
var is_tree_lit: Callable = func() -> bool: return false
var is_influence_stocked: Callable = func() -> bool: return false
var is_train_started: Callable = func() -> bool: return false
var is_score_named: Callable = func() -> bool: return false
var is_rival_arrived: Callable = func() -> bool: return false

var _completed: Array[bool] = []
var _config_ok: bool = false
var _error_count: int = 0
var _chain_emitted: bool = false


func _init(table: Dictionary = {}) -> void:
	if table.is_empty():
		table = DataLoader.load_json(ONBOARDING_PATH)
	var count := int(table.get(KEY_GOAL_CARD_STEPS, STEP_IDS.size()))
	# 表损坏自检（A.3 错误态）：步数≤0 或与谓词数不符 → 引导整体禁用（不阻塞
	# 世界，不抛错；错误面走 onboarding_error 由装配决定上报）——同时防
	# 谓词数组越界（步数>谓词数时 _predicates()[i] 会崩）
	if count <= 0 or count != STEP_IDS.size():
		_report_error("config_invalid", -1)
		return
	for _i: int in count:
		_completed.append(false)
	_config_ok = true


## ---------- 推进（装配方在周结/世界状态变更后驱动；幂等可重入） ----------


## 顺序扫描全部步：谓词真→点亮并发 step_advanced（载荷按索引升序，顺序性
## 由扫描序保证）；前步未达成不影响后步点亮=任一步跳过不阻塞。
## current_week 仅入载荷（L3 锚点/测试断言用），本类不自持时钟（零 Node 纪律）。
## 返回本次新点亮步索引数组（空数组=无推进）。
func advance_check(current_week: int) -> Array[int]:
	var advanced: Array[int] = []
	if not _config_ok:
		return advanced
	var predicates := _predicates()
	for i: int in _completed.size():
		if _completed[i]:
			continue
		if _safe_predicate(predicates, i):
			_completed[i] = true
			advanced.append(i)
			(
				step_advanced
				. emit(
					{
						"step_index": i,
						"step_id": step_id(i),
						"goal_key": goal_key(i),
						"week": current_week,
					}
				)
			)
	if not _chain_emitted and _completed.size() > 0 and not _completed.has(false):
		_chain_emitted = true
		chain_completed.emit({"week": current_week, "steps_total": _completed.size()})
	return advanced


## 错误态兜底命令（装配方/L3 显式跳过当前卡住步；A.3 "跳过不阻塞"的玩家侧入口）
func skip_current(current_week: int) -> bool:
	if not _config_ok:
		return false
	var i := _first_pending()
	if i < 0:
		return false
	_completed[i] = true
	_report_error("skipped", i)
	(
		step_advanced
		. emit(
			{
				"step_index": i,
				"step_id": step_id(i),
				"goal_key": goal_key(i),
				"week": current_week,
			}
		)
	)
	if not _chain_emitted and not _completed.has(false):
		_chain_emitted = true
		chain_completed.emit({"week": current_week, "steps_total": _completed.size()})
	return true


## ---------- 数据面（只读） ----------


func get_progress() -> Dictionary:
	return {
		"completed": _completed.duplicate(),
		"completed_count": _completed.count(true),
		"total": _completed.size(),
		"current_step": _first_pending(),
		"all_done": _config_ok and _completed.size() > 0 and not _completed.has(false),
		"config_ok": _config_ok,
		"error_count": _error_count,
	}


func is_config_ok() -> bool:
	return _config_ok


## 步 id/goal 键派生（L3 锚点与文案查表的单一出数点）
func step_id(index: int) -> String:
	if index < 0 or index >= STEP_IDS.size():
		return ""
	return STEP_IDS[index]


func goal_key(index: int) -> String:
	return GOAL_KEY_FMT % (index + 1)


func goal_detail_key(index: int) -> String:
	return GOAL_DETAIL_KEY_FMT % (index + 1)


## ---------- 存档（flags 开放容器：字符串键跨版本兼容优先） ----------


func get_save_view() -> Dictionary:
	return {
		"completed": _completed.duplicate(),
		"error_count": _error_count,
		"chain_emitted": _chain_emitted,
	}


func restore_from_save(snapshot: Dictionary) -> void:
	var saved: Variant = snapshot.get("completed", [])
	if saved is not Array or (saved as Array).size() != _completed.size():
		_report_error("restore_shape_mismatch", -1)
		return
	for i: int in _completed.size():
		_completed[i] = bool((saved as Array)[i])
	_error_count = int(snapshot.get("error_count", 0))
	_chain_emitted = bool(snapshot.get("chain_emitted", false))


## ---------- 私有 ----------


func _predicates() -> Array[Callable]:
	return [
		is_task_started,
		is_tree_lit,
		is_influence_stocked,
		is_train_started,
		is_score_named,
		is_rival_arrived,
	]


## 谓词安全调用：不可调用/返回非 bool=谓词故障→error 上报+本轮视为未达成
##（该步不阻塞后续步——扫描序天然跳步）。返回类型防线=ADR-0014 谓词单源。
func _safe_predicate(predicates: Array[Callable], index: int) -> bool:
	var predicate := predicates[index]
	if not predicate.is_valid():
		_report_error("predicate_invalid", index)
		return false
	var result: Variant = predicate.call()
	if result is not bool:
		_report_error("predicate_not_bool", index)
		return false
	return bool(result)


func _first_pending() -> int:
	for i: int in _completed.size():
		if not _completed[i]:
			return i
	return -1


func _report_error(reason: String, step_index: int) -> void:
	_error_count += 1
	onboarding_error.emit({"reason": reason, "step_index": step_index})
