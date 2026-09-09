class_name RivalPack
extends RefCounted
## L2 竞对包容器（#144；architecture §2.1 rivals/rival_pack.gd + E6）：
## - P0 只装深巷 1 员；P2 多竞对=包内加员（灰梯 P1/北岭 P2）——**容器对员
##   数零假设**，禁止"单竞对特判"分支（E6：`if rival.name=="深巷"` 即违规）；
## - 周推进=遍历全员 advance_week（每竞对一份时间线消费指针/分数曲线/预警
##   谓词，E6 按"每竞对一份"设计）；
## - 汇聚信号：rival_action_fired（L3 决策卡/头条/周报行消费）、
##   rival_timeline_advance（黄/红灯周报行谓词数据面）。
## 装配：读 rivals.json rival_actors._order 表驱动实例化（加员=表加行）；
## jitter 注入按竞对统一接 RngStream.symmetric_domain("rival", ±rival_jitter)
## （rivals-spec D.2 ≤±2 不改判定）。
## 硬约束：RefCounted 零 Node；零单竞对特判；数值零硬编码。

signal rival_action_fired(payload: Dictionary)
signal rival_timeline_advance(payload: Dictionary)

const RIVALS_PATH: String = "res://src/data/rivals.json"
const KEY_ACTORS: String = "rival_actors"
const KEY_ORDER: String = "_order"
const KEY_JITTER: String = "rival_jitter"
const RNG_DOMAIN_RIVAL: String = "rival"

var _rivals: Array[Rival] = []
var _jitter_fn: Callable = func(_score: float) -> float: return _score


func _init() -> void:
	var table := DataLoader.load_json(RIVALS_PATH)
	var actors: Variant = table.get(KEY_ACTORS)
	if actors is not Dictionary:
		return
	var order: Variant = (actors as Dictionary).get(KEY_ORDER)
	if order is not Array:
		return
	for actor_key: Variant in order as Array:
		_rivals.append(Rival.new(str(actor_key)))
		_rivals.back().rival_action_fired.connect(
			func(payload: Dictionary) -> void: rival_action_fired.emit(payload.duplicate())
		)


## 装配注入 jitter（装配方接 RngStream；未注入=零扰动确定性路径）。
## jitter=±扰动幅度（rivals.json rival_jitter，默认 ±1.5 ≤±2 护栏）。
func setup_jitter(rng: RngStream = null) -> void:
	if rng == null:
		_jitter_fn = func(_score: float) -> float: return _score
		return
	var magnitude := rng.get_param(KEY_JITTER)
	_jitter_fn = func(score: float) -> float:
		return score + rng.symmetric_domain(RNG_DOMAIN_RIVAL, magnitude)
	for rival: Rival in _rivals:
		rival.rival_jitter_fn = _jitter_fn


## 周推进：遍历全员（P0 单员/未来多员同路径）；返回全部触发载荷。
## player_released=玩家本周发版（撞车判定输入；编排方从模型出分仪式收集）。
func advance_all(week: int, player_released: bool = false) -> Array[Dictionary]:
	var fired: Array[Dictionary] = []
	for rival: Rival in _rivals:
		var per_rival := rival.advance_week(week, player_released)
		for payload: Dictionary in per_rival:
			fired.append(payload)
		# 预警数据面（rival_timeline_advance 发射=黄/红灯周报行源）
		var warn: Dictionary = rival.warn_state(week)
		if int(warn["level"]) > 0:
			(
				rival_timeline_advance
				. emit(
					{
						"actor_key": rival.get_actor_key(),
						"weeks_left": int(warn["weeks_left"]),
						"warn_level": int(warn["level"]),
						"action": str(warn["action"]),
						"week": int(warn["week"]),
					}
				)
			)
	return fired


## ---------- 数据面（只读） ----------


## 全部竞对视图（数组化；L3 对决曲线/周报遍历用——零单竞对特判）
func get_all_views() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for rival: Rival in _rivals:
		views.append(rival.get_rival_view())
	return views


func count() -> int:
	return _rivals.size()


## 按 actor_key 取视图（无=空 dict）
func get_rival_view(actor_key: String) -> Dictionary:
	for rival: Rival in _rivals:
		if rival.get_actor_key() == actor_key:
			return rival.get_rival_view()
	return {}


## 全局最高预警（跨竞对取最紧；供周报黄/红行与轻量入口——数组遍历零特判）
func get_highest_warn(week: int) -> Dictionary:
	var highest: Dictionary = {"level": 0, "weeks_left": -1, "action": "", "actor_key": ""}
	for rival: Rival in _rivals:
		var warn: Dictionary = rival.warn_state(week)
		if int(warn["level"]) > int(highest["level"]):
			highest = {
				"level": int(warn["level"]),
				"weeks_left": int(warn["weeks_left"]),
				"action": str(warn["action"]),
				"actor_key": rival.get_actor_key(),
				"week": int(warn["week"]),
			}
	return highest


## ---------- 存档（architecture §9.1 rivals 段同构） ----------


func get_save_view() -> Dictionary:
	var out: Dictionary = {}
	for rival: Rival in _rivals:
		out[rival.get_actor_key()] = rival.get_save_view()
	return out


func restore_from_save(snapshot: Dictionary) -> void:
	for rival: Rival in _rivals:
		if snapshot.has(rival.get_actor_key()):
			rival.restore_from_save(snapshot[rival.get_actor_key()] as Dictionary)
