class_name PaperProject
extends Project
## L2 论文项目子类：#133 完整版。三型（复现/研究/课题）+ 域标签 + RP 权重 +
## 选题数据，表驱动（papers.json）。
## 历史：#131 最小桩（构造注入工期/周耗/上限）；#133 新增 from_topic() 工厂
## （读 papers.json 选题数据构造），旧构造保留（#131 测试/装配兼容）。
## 数值禁硬编码：工期/RP/报酬/影响力全读表；本类只持运行时状态。

enum PaperKind {
	REPRO,
	RESEARCH,
	CONTRACT,
}

## 论文类型稳定字符串映射（存档兼容；enum→字符串单向，禁散落字面量）
const KIND_TO_KEY: Dictionary = {
	PaperKind.REPRO: "repro",
	PaperKind.RESEARCH: "research",
	PaperKind.CONTRACT: "contract",
}

const PAPERS_PATH: String = "res://src/data/papers.json"

var _topic_id: String = ""
var _domain: String = ""
var _paper_kind: PaperKind = PaperKind.REPRO
var _rp_primary: bool = false
var _quality_hint: Dictionary = {}


## 兼容构造（#131 形状：title/duration/card_hours/seat_limit/kind 显式注入；
## 测试与旧装配用；新装配优先 from_topic 表驱动）。
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


## #133 工厂：从选题数据构造（PaperPool 出题后调用；数据源 papers.json）。
static func from_topic(topic_data: Dictionary) -> PaperProject:
	# 周耗卡时按型读表（paper_exp_card_hours；读表后才构造，避免改父类私有字段）
	var card_hours := 1
	var table := DataLoader.load_json(PAPERS_PATH)
	var exp_cfg: Variant = table.get("paper_exp_card_hours", {})
	var kind_key := str(topic_data.get("type", "repro"))
	if exp_cfg is Dictionary and exp_cfg.has(kind_key):
		card_hours = int(exp_cfg[kind_key])
	var project := (
		PaperProject
		. new(
			str(topic_data.get("title_key", "")),
			int(topic_data.get("duration_weeks", 0)),
			card_hours,
			1,
			_kind_from_key(kind_key),
		)
	)
	project._topic_id = str(topic_data.get("id", ""))
	project._domain = str(topic_data.get("domain", ""))
	project._rp_primary = bool(topic_data.get("rp_primary", false))
	var quality_hint: Variant = topic_data.get("quality_hint", {})
	if quality_hint is Dictionary:
		project._quality_hint = quality_hint
	if project._topic_id.is_empty() or project._domain.is_empty():
		push_error("PaperProject.from_topic: 选题数据缺 id/domain")
	return project


func _on_week_tick() -> void:
	_progress = _progress_from_weeks_remaining()


func get_topic_id() -> String:
	return _topic_id


func get_domain() -> String:
	return _domain


func get_paper_kind() -> PaperKind:
	return _paper_kind


func get_rp_primary() -> bool:
	return _rp_primary


func get_quality_hint() -> Dictionary:
	return _quality_hint.duplicate()


## 论文数据面扩展（基类 view + 论文元数据；L3 经 TaskBoard 聚合，不直取）
func get_paper_view() -> Dictionary:
	var view := get_project_view()
	view["topic_id"] = _topic_id
	view["domain"] = _domain
	view["paper_kind"] = _paper_kind
	view["paper_kind_key"] = kind_to_key(_paper_kind)
	view["rp_primary"] = _rp_primary
	return view


static func kind_to_key(kind: PaperKind) -> String:
	return str(KIND_TO_KEY.get(kind, "repro"))


static func _kind_from_key(key: String) -> PaperKind:
	for kind: PaperKind in [PaperKind.REPRO, PaperKind.RESEARCH, PaperKind.CONTRACT]:
		if str(KIND_TO_KEY.get(kind, "")) == key:
			return kind
	return PaperKind.REPRO


## ---------- 私有 ----------


func _progress_from_weeks_remaining() -> float:
	return 1.0 - float(_weeks_remaining) / float(_duration_weeks)
