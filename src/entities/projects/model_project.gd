class_name ModelProject
extends Project
## L2 模型训练项目子类（#140 完整版）：表驱动基座（models.json）+ 上桌上限
## 随基座 + 卡时周耗 + checkpoint 50% 确定性事件。
## 历史：#131 最小桩（构造注入工期/周耗/上限）；#140 新增 from_base() 工厂
## （读 models.json 基座行构造），旧构造保留（#131 测试/装配兼容）。
## 范围（任务书改动面）：
## - 基座行→工期/卡时/上桌上限/档位要求/域/画像全读表（models-spec D.2）；
## - checkpoint 50% 确定性墙钟事件（零掷骰零数值掉落，models-spec
##   OP-MDL-02/model_ckpt_progress）：训练周推进跨过 50% → 置位
##   checkpoint_hit 并 emit checkpoint_reached（L3 叙事卡消费；事件确定性=
##   表驱动位置 + 无 RNG 依赖）；
## - 训练时长=周定值不随随机波动（rng 红线：随机零接入时长）；
## - 上桌上限随基座（迷你 1→大基座 4，models.json on_table_cap）；
## - 出分/命名/模型库/SOTA=#141/#142（本单不落：训练完成=FINISHED_PENDING，
##   结算声明由 #135/#141 接）。
## #131/#132 硬约束：RefCounted 零 Node；数值禁硬编码（全读表）。

signal checkpoint_reached(payload: Dictionary)

const MODELS_PATH: String = "res://src/data/models.json"
const KEY_CKPT_PROGRESS: String = "model_ckpt_progress"

## 表缓存（静态；万次模拟/周推进避免重复 IO——DataLoader 无缓存，训练
## 周推进每 tick 读 ckpt 位置会拖慢；静态缓存=进程内单次加载）
static var _models_table: Dictionary = {}

var _base_id: String = ""
var _base_name_key: String = ""
var _domain: String = ""
## 基座档位要求键（t0..t4 或空=教学无门槛；#139 ChipYard.get_tier_eligibility 判定）
var _tier_required: String = ""
var _ndim_profile: Dictionary = {}
var _checkpoint_hit: bool = false


## 兼容构造（#131 形状：显式注入工期/周耗/上限；测试与旧装配用。
## 新装配优先 from_base 表驱动；本构造 base 元数据为空=无门槛训练桩）。
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


## #140 工厂：从基座行数据构造（ModelPool 出基座后调用；数据源 models.json）。
## 基座行→工期/卡时/上限/档位要求/域/画像全表驱动（代码零硬编码）。
## base_row 可为整表行或 {id:...}（缺字段回退默认防御）；duration/卡时等
## 从行内读——行由 ModelPool/调用方从 models.json 取（本类不重复读文件）。
static func from_base(base_row: Dictionary) -> ModelProject:
	var project := (
		ModelProject
		. new(
			str(base_row.get("id", "")),
			str(base_row.get("name_key", "")),
			int(base_row.get("duration_weeks", 0)),
			int(base_row.get("card_hours_week", 0)),
			int(base_row.get("on_table_cap", 1)),
		)
	)
	project._domain = str(base_row.get("domain", ""))
	project._tier_required = str(base_row.get("tier_required", ""))
	var profile: Variant = base_row.get("ndim_profile", {})
	if profile is Dictionary:
		project._ndim_profile = profile
	if project._base_id.is_empty():
		push_error("ModelProject.from_base: 基座行缺 id")
	return project


## 训练推进（周内刻级；checkpoint 判定点：跨过 50% 确定性置位+发信号）
func _on_week_tick() -> void:
	var prev := _progress
	_progress = _progress_from_weeks_remaining()
	if not _checkpoint_hit and prev < _ckpt_progress() and _progress >= _ckpt_progress():
		_checkpoint_hit = true
		checkpoint_reached.emit(
			{"base_id": _base_id, "progress": _progress, "checkpoint": _ckpt_progress()}
		)


func get_base_id() -> String:
	return _base_id


func get_base_name_key() -> String:
	return _base_name_key


func get_domain() -> String:
	return _domain


## 基座档位要求键（空=教学无门槛）
func get_tier_required() -> String:
	return _tier_required


func get_ndim_profile() -> Dictionary:
	return _ndim_profile.duplicate()


## checkpoint 是否已触发（视图/L3 预告用；确定性事件只一次）
func is_checkpoint_hit() -> bool:
	return _checkpoint_hit


## 模型数据面扩展（基类 view + 模型元数据/checkpoint 标；L3 经 TaskBoard 聚合）
func get_model_view() -> Dictionary:
	var view := get_project_view()
	view["base_id"] = _base_id
	view["domain"] = _domain
	view["tier_required"] = _tier_required
	view["checkpoint_hit"] = _checkpoint_hit
	view["checkpoint_progress"] = _ckpt_progress()
	return view


## ---------- 私有 ----------


## checkpoint 位置（表驱动 model_ckpt_progress=0.5=50%；零硬编码；
## 静态缓存防周推进每 tick 读文件）
func _ckpt_progress() -> float:
	if _models_table.is_empty():
		_models_table = DataLoader.load_json(MODELS_PATH)
	return float(_models_table.get(KEY_CKPT_PROGRESS, 0.5))


## 剩余周→进度（周内单调推进；完成冻结由基类 week_tick 收口）。
## 语义：本 tick 已扣 1 周后，_weeks_remaining∈[1,duration]；已推进周数=
## duration - remaining（完成周=remaining 0 由基类置 progress=1 冻结）。
func _progress_from_weeks_remaining() -> float:
	return 1.0 - float(_weeks_remaining) / float(_duration_weeks)
