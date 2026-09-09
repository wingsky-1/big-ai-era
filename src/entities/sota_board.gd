class_name SotaBoard
extends RefCounted
## L2 SOTA 榜独立判定权威（#142；architecture A3 拍板"独立 SotaBoard——
## 榜语义独立于 ModelLibrary 收藏；rivals 守卫带读它天然解耦；读档重建无环"）。
## 职责：
## - **唯一判定权威**："严格大于=破纪录/平局归霸主"只在 L2 本类一处实现
##   （models-spec model_score_sota 硬语义；架构 §4.3）；
## - 榜状态：当前纪录分数 + 纪录持有者（player/rival/empty）+ 纪录保持
##   周数/上榜序列（破纪录次数）；submit_score 判定入榜（首分直接入榜；
##   严格大于=破纪录；等于/小于=不破——霸主保持）；
## - 守卫带查询：band_of(score) → L1-L4（rivals.json rival_guard_L1-L4
##   分数带；L4 上限=100 永不超玩家封顶，硬红线由表结构断言）；
## - 竞对分数=Rival 侧时间线输出（#144），本类只读入榜（submit_rival_score
##   供时间线批调用：竞对破玩家纪录=反超事件载荷——本单留接口不接 Rival）。
## 纯 RefCounted 零 Node；无反向引用（读档重建=静态 new + 状态注入，
## 零环）；数值零硬编码（守卫带读表，封顶 100=表断言非代码）。
## 行数预算 ≤200（architecture §8；S 单）。

signal sota_updated(payload: Dictionary)

## 守卫带层级（L1 起步 → L4 登顶；band_of 返回）
enum GuardBand {
	L1,
	L2,
	L3,
	L4,
}

const RIVALS_PATH: String = "res://src/data/rivals.json"

## 纪录持有者稳定键（数据面/存档/载荷；开放字符串，禁散落字面量）
const HOLDER_PLAYER: String = "player"
const HOLDER_RIVAL: String = "rival"
const HOLDER_EMPTY: String = "empty"

var _record_score: float = 0.0
var _record_holder: String = HOLDER_EMPTY
var _record_week: int = 0
var _break_count: int = 0
var _table: Dictionary = {}


func _init() -> void:
	_table = DataLoader.load_json(RIVALS_PATH)


## ---------- 判定命令（唯一判定权威） ----------


## 玩家出分提交判定：score > 当前纪录=破纪录入榜（严格大于）；=平局归霸主
## （不破）；< 不破。首个有效分（score>0）直接入榜=无前纪录。
## 返回 {ok, broke_record, record_score, record_holder, week, break_count}：
## broke_record=true=本次提交破纪录（含首分入榜）。
func submit_player_score(score: float, week: int = 0) -> Dictionary:
	if score < 0.0 or score > 100.0:
		push_error("SotaBoard.submit_player_score: score 非法（%.1f，须 ∈[0,100]）" % score)
		return {"ok": false}
	var prev_holder := _record_holder
	var broke := false
	if _record_holder == HOLDER_EMPTY or score > _record_score:
		broke = true
		_record_score = score
		_record_holder = HOLDER_PLAYER
		_record_week = week
		_break_count += 1
	elif prev_holder == HOLDER_RIVAL and score == _record_score:
		# 平局归霸主：竞对纪录未被玩家破（玩家平竞对=霸主保持竞对）
		broke = false
	# 玩家持平玩家纪录（自我平局）不动作
	var payload := {
		"ok": true,
		"broke_record": broke,
		"record_score": _record_score,
		"record_holder": _record_holder,
		"week": week,
		"break_count": _break_count,
		"submitted": score,
	}
	sota_updated.emit(payload.duplicate())
	return payload


## 竞对出分提交（#144 时间线批调用；本单留接口+单测判定）。
## 竞对严格大于玩家纪录=被反超事件（record_holder→rival）；
## 等于=平局归霸主（玩家霸主保持）。返回同上+outclassed 标记。
func submit_rival_score(score: float, week: int = 0) -> Dictionary:
	if score < 0.0 or score > 100.0:
		push_error("SotaBoard.submit_rival_score: score 非法（%.1f）" % score)
		return {"ok": false}
	var outclassed := false
	var broke := false
	if _record_holder == HOLDER_EMPTY or score > _record_score:
		outclassed = _record_holder == HOLDER_PLAYER
		broke = true
		_record_score = score
		_record_holder = HOLDER_RIVAL
		_record_week = week
		_break_count += 1
	var payload := {
		"ok": true,
		"outclassed": outclassed,
		"broke_record": broke,
		"record_score": _record_score,
		"record_holder": _record_holder,
		"week": week,
		"break_count": _break_count,
		"submitted": score,
	}
	sota_updated.emit(payload.duplicate())
	return payload


## ---------- 守卫带查询（读表只读） ----------


## 分数所在守卫带（rivals.json rival_guard_L1-L4 表驱动）。
## 带区间语义：[min, max)；L4 max=100 含 100（封顶不越——分 ∈[0,100]）。
func band_of(score: float) -> GuardBand:
	var bands: Array[GuardBand] = [GuardBand.L1, GuardBand.L2, GuardBand.L3, GuardBand.L4]
	for band: GuardBand in bands:
		var range_v: Variant = _table.get(_band_key(band))
		if range_v is Dictionary:
			var min_v := float((range_v as Dictionary).get("min", 0.0))
			var max_v := float((range_v as Dictionary).get("max", 100.0))
			if score >= min_v and (score < max_v or (band == GuardBand.L4 and score <= max_v)):
				return band
	# 防御：score<L1.min 或表缺失 → L1（最低带不误报）
	return GuardBand.L1


## 守卫带上限（band 不超玩家封顶 100 的读取口；#144 竞对曲线裁剪用）
func band_cap(band: GuardBand) -> float:
	var range_v: Variant = _table.get(_band_key(band))
	if range_v is Dictionary:
		return float((range_v as Dictionary).get("max", 100.0))
	return 100.0


## ---------- 数据面（只读） ----------


func get_record_score() -> float:
	return _record_score


func get_record_holder() -> String:
	return _record_holder


func get_record_week() -> int:
	return _record_week


func get_break_count() -> int:
	return _break_count


## 榜视图（L3/存档/对账；深拷贝）
func get_sota_view() -> Dictionary:
	return {
		"record_score": _record_score,
		"record_holder": _record_holder,
		"record_week": _record_week,
		"break_count": _break_count,
		"guard_band": band_of(_record_score) if _record_score > 0.0 else -1,
	}


## 读档重建（#142 无环重建路径：快照纯值注入，零对象引用；装配方在
## SaveSystem 读档后调）。视图缺键=防御保留初值。
func restore_from_view(snapshot: Dictionary) -> void:
	_record_score = float(snapshot.get("record_score", 0.0))
	_record_holder = str(snapshot.get("record_holder", HOLDER_EMPTY))
	_record_week = int(snapshot.get("record_week", 0))
	_break_count = int(snapshot.get("break_count", 0))


## ---------- 私有 ----------


func _band_key(band: GuardBand) -> String:
	match band:
		GuardBand.L1:
			return "rival_guard_L1"
		GuardBand.L2:
			return "rival_guard_L2"
		GuardBand.L3:
			return "rival_guard_L3"
		GuardBand.L4:
			return "rival_guard_L4"
	return "rival_guard_L1"
