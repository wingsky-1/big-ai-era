class_name PaperProject
extends Project
## L2 论文项目子类（#131 最小实现）：证明"同接口可多态"的最小落地。
## 本批范围（任务书改动面）：
## - 只做构造注入工期/周耗/上桌上限 + 统一推进钩子 + 三型论文（复现/研究/课题）
##   类型标签 enum 占位（papers-spec A.1）；
## - 论文三型选题池/报酬/RP/影响力/n 维合成= #133（papers.json 建表后表驱动）；
## - 标题键=构造注入（texts.json 键引用，标题池 #133 提供真实键值）。
## #131 硬约束：RefCounted 零 Node；工期/周耗数值禁硬编码（构造注入，不读
## 不存在的 papers.json；#133 替换为表驱动——构造签名不变，仅调用方改读表）。

enum PaperKind {
	REPRO,
	RESEARCH,
	CONTRACT,
}

var _paper_kind: PaperKind = PaperKind.REPRO


func _init(
	title_key: String,
	duration_weeks: int,
	card_hours_per_week: int,
	seat_limit: int = 1,
	kind: PaperKind = PaperKind.REPRO,
) -> void:
	_paper_kind = kind
	_initialize(
		CoreEnums.ProjectType.PAPER,
		title_key,
		duration_weeks,
		card_hours_per_week,
		seat_limit,
	)


## 论文推进（周内刻级；论文=纯进度推进，无 checkpoint/事件——papers-spec OP-PAP-02）
func _on_week_tick() -> void:
	_progress = _progress_from_weeks_remaining()


func get_paper_kind() -> PaperKind:
	return _paper_kind


## ---------- 私有 ----------


## 剩余周→进度（周内单调推进；完成冻结由基类 week_tick 收口）。
## 语义：本 tick 已扣 1 周后，_weeks_remaining∈[1,duration]；已推进周数=
## duration - remaining（完成周=remaining 0 由基类置 progress=1 冻结）。
func _progress_from_weeks_remaining() -> float:
	return 1.0 - float(_weeks_remaining) / float(_duration_weeks)
