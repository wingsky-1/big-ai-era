class_name ModelProject
extends Project
## L2 模型训练项目子类（#131 最小实现）：证明"同接口可多态"的最小落地。
## 本批范围（任务书改动面）：
## - 只做构造注入工期/周耗/上桌上限 + 统一推进钩子；基座 id/名称=构造注入
##   （models.json 未建，不读不存在的表；#140 建 models.json 后替换为表驱动：
##   基座表行→工期/卡时/上桌上限/checkpoint 周等全部从表读，构造签名届时收口）；
## - checkpoint 50% 墙钟事件（确定性零掷骰）= #140（models-spec OP-MDL-02）；
## - 训练时长周定值语义=构造注入 duration_weeks（models-spec"训练时长不随随机
##   波动"：定值由表给，随机波动零接入——本批构造函数即固定值参数）。
## #131 硬约束：RefCounted 零 Node；数值禁硬编码（全构造注入）。

var _base_id: String = ""
var _base_name_key: String = ""


func _init(
	base_id: String,
	base_name_key: String,
	duration_weeks: int,
	card_hours_per_week: int,
	seat_limit: int,
) -> void:
	_base_id = base_id
	_base_name_key = base_name_key
	_initialize(
		CoreEnums.ProjectType.MODEL,
		base_name_key,
		duration_weeks,
		card_hours_per_week,
		seat_limit,
	)


## 训练推进（周内刻级；训练=纯进度推进，checkpoint 墙钟事件 #140 落地）
func _on_week_tick() -> void:
	_progress = _progress_from_weeks_remaining()


func get_base_id() -> String:
	return _base_id


func get_base_name_key() -> String:
	return _base_name_key


## ---------- 私有 ----------


## 剩余周→进度（周内单调推进；完成冻结由基类 week_tick 收口）。
## 语义：本 tick 已扣 1 周后，_weeks_remaining∈[1,duration]；已推进周数=
## duration - remaining（完成周=remaining 0 由基类置 progress=1 冻结）。
func _progress_from_weeks_remaining() -> float:
	return 1.0 - float(_weeks_remaining) / float(_duration_weeks)
