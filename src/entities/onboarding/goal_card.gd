class_name GoalCard
extends RefCounted
## L2 目标卡出数器（#152；onboarding-spec A.1 OP-ONB-02/B.2 + ui-ux A.1
## 目标卡带 + architecture-100 §2.1 onboarding/goal_card.gd）。
## 职责边界：**只出数**（当前步 view + "约再跑 X 周"），绝不直接改玩法状态；
## 周提示口径=周结权威（expected_week 为负=预期已过但未达成→0），与
## onboarding.json 教学节拍锚点单源推导（本类不做日历对象，零时钟依赖——
## week 参数由装配/测试传入，与周结同源）。
## 阶段链 P1（自由期三线）=本类扩展点：current view 含 stage 字段
##（"onboarding"），P1 替换链数据源不改 L3 消费形状。
## RefCounted 零 Node；headless 可单测。

const ONBOARDING_PATH: String = "res://src/data/onboarding.json"
const KEY_TASK_DURATION: String = "onb_first_task_duration"
const KEY_NODE_DURATION: String = "onb_first_node_duration"
const KEY_TRAIN_DURATION: String = "onb_first_train_duration"
const KEY_RIVAL_WEEK: String = "onb_first_rival_week"
## 开局周锚（GameClock._week 初值 1= W1；时间语义锚常量，真源 GDD 2022 初开局）
const START_WEEK: int = 1
## 引导期阶段标记（P1 阶段链扩展位；稳定字符串，L3 只透传不解释）
const STAGE_ONBOARDING: String = "onboarding"

## 六步预期达成周（教学节拍单源推导表：W=开局周锚 1；语义=事件周标签）
## W_lit = 1 + node_duration（研究 W1 与首任务并行启动，numerics §〇 W3）
## W_score = 1 + task + 1 + train（W3 结算→W4 排训→W4+train 出分）
## W_rival = onb_first_rival_week（镜像键==rivals.json 深巷 timeline 首行周）
var _expected_weeks: Array[int] = []
var _goal_keys: Array[String] = []
var _detail_keys: Array[String] = []
var _machine: Object = null  # TutorialMachine（注入防环：本类不回写 machine）


func _init(machine: Object = null, table: Dictionary = {}) -> void:
	_machine = machine
	if table.is_empty():
		table = DataLoader.load_json(ONBOARDING_PATH)
	var task := maxi(1, int(table.get(KEY_TASK_DURATION, 2)))
	var node := maxi(1, int(table.get(KEY_NODE_DURATION, 2)))
	var train := maxi(1, int(table.get(KEY_TRAIN_DURATION, 4)))
	var rival := maxi(0, int(table.get(KEY_RIVAL_WEEK, 10)))
	# 教学节拍周语义（numerics §〇 唯一时钟，事件周标签=结果可见周）：
	# 接单=开局即刻（W1）；lit=开局周+研究周（研究 W1 与首任务并行启动）；
	# 影响力=首任务结算周（W1+task）；排训练=结算次周（W3 结算→W4 入槽）；
	# 出分=入槽周+训练周（4+train，train=4→W8 / spec 占位 5→W9 同锚）；
	# 首对手=镜像键（==rivals.json 深巷 timeline 首行周）。
	_expected_weeks = [
		START_WEEK,
		START_WEEK + node,
		START_WEEK + task,
		START_WEEK + task + 1,
		START_WEEK + task + 1 + train,
		rival,
	]
	if machine != null:
		var progress: Dictionary = machine.get_progress()
		for i: int in int(progress["total"]):
			_goal_keys.append(machine.goal_key(i))
			_detail_keys.append(machine.goal_detail_key(i))


## ---------- 数据面（只读；L3 只画） ----------


## 预期达成周表（只读副本；教学节拍断言/GUT 节拍测试同源出数点）
func get_expected_weeks() -> Array[int]:
	return _expected_weeks.duplicate()


## 当前目标卡视图（OP-ONB-02 ≤2 击说清"还差几周"的数据同源）：
## {stage, step_index, step_id, goal_key, detail_key, weeks_hint, all_done, config_ok}
## 全完成=goal_key 空串（L3 空态=卡面收起/常显完成态按 A.1）。
func get_goal_card_view(week: int) -> Dictionary:
	var machine := _machine_ref()
	if machine == null:
		return _empty_view("machine_missing")
	var progress: Dictionary = machine.get_progress()
	if not bool(progress["config_ok"]):
		return _empty_view("config_invalid")
	var total: int = progress["total"]
	var current: int = progress["current_step"]
	if current < 0:
		return {
			"stage": STAGE_ONBOARDING,
			"step_index": -1,
			"step_id": "",
			"goal_key": "",
			"detail_key": "",
			"weeks_hint": 0,
			"all_done": true,
			"config_ok": true,
		}
	if current >= total:
		return _empty_view("index_overflow")
	return {
		"stage": STAGE_ONBOARDING,
		"step_index": current,
		"step_id": machine.step_id(current),
		"goal_key": machine.goal_key(current),
		"detail_key": machine.goal_detail_key(current),
		"weeks_hint": _weeks_hint(current, week),
		"all_done": false,
		"config_ok": true,
	}


## 六点进度（B.2 guide_target_pending(N/6)：含新点亮步=completed 数组直出；
## 深拷贝防越权）。L3 进度点条只画此数组+completed_count。
func get_progress_view() -> Dictionary:
	var machine := _machine_ref()
	if machine == null:
		return {"completed": [], "completed_count": 0, "total": 0}
	return machine.get_progress()


## ---------- 私有 ----------


## "约再跑 X 周"（人话口径）：预期周 - 当前周，下限 0（预期已过未达成→"就这一
## 两天"→0）；全过=0。与周结同源=week 参数由装配传（周结回调驱动 view 重查）。
func _weeks_hint(step_index: int, week: int) -> int:
	if step_index < 0 or step_index >= _expected_weeks.size():
		return 0
	return maxi(0, _expected_weeks[step_index] - week)


## 弱引用取机（RefCounted 双向引用纪律：GoalCard→TutorialMachine 单向即无环，
## 本类不回写 machine；注入持 Object 引用+类型防线，World 批同生命周期无泄漏）
func _machine_ref() -> Object:
	if _machine == null or not is_instance_valid(_machine):
		return null
	return _machine


func _empty_view(reason: String) -> Dictionary:
	return {
		"stage": STAGE_ONBOARDING,
		"step_index": -1,
		"step_id": "",
		"goal_key": "",
		"detail_key": "",
		"weeks_hint": 0,
		"all_done": false,
		"config_ok": false,
		"error_reason": reason,
	}
