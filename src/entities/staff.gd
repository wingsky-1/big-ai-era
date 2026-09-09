class_name Staff
extends RefCounted
## L2 员工个体（#130）：id/姓名/岗位/4 维基础属性/状态带（周粒度）/观察句 id/在职年限。
## 硬约束（任务书/架构 H2/H3/H6/H9）：
## - RefCounted、零 Node/SceneTree 依赖（"无窗口服务器可跑"判据，headless 可单测）；
## - 数值零硬编码：构造时注入 staff.json 整表（装配方读表传入），只读表键；
## - 岗位=CoreEnums.StaffRole、状态带=CoreEnums.StaffState（enum 禁字符串）；
##   enum→表内稳定字符串的映射（同源派生）只在本类内一处（role_to_key/state_to_key）；
## - 状态带周粒度：每员工每周恒消费 1 个 rng.staff 样本（周结外部调用 roll_state_week）；
##   周内不重掷（周内稳定）；同一样本既定态又定带内产出乘数位置（累计权重轮盘 +
##   带内余量定位，randomness-spec OP-RND-05 "带内加权"：乘数条件均匀分布于状态带）；
##   pity=连摸 rnd_staff_pity 周必转（读 rng.json + 本表权重，见 _draw_week）；
##   本类不自持 RNG 流：rng_stream 由外部（Roster/周结装配方）注入，掷点=注入流消费
##   staff 域（架构 §5.3 phase 7d：员工状态带掷点 rng.staff 由周结驱动）；
## - 观察句=静态种子：构造时从 staff.json staff_observation_pool 按池序确定性取
##   1 句绑定（initial_roster.observation_pool_index），持 observation_id 永不轮转
##   （staff-spec C.4：同种子同员工同句）；文本值在 texts.json，本类只持 id；
## - 双向引用纪律：本类不反向持有名册/父对象，无 weakref 需求（引用单向）。
## 数据面 get_staff_view() 只读深拷贝；命令面只掷状态，无副作用外漏。

## 表路径常量（构造注入整表；缺表由 DataSchema 单测守护 test_data_schema_staff）
const STAFF_TABLE_PATH: String = "res://src/data/staff.json"
const RNG_TABLE_PATH: String = "res://src/data/rng.json"

## staff.json 表键（D.2 真源拼写）
const KEY_START_COUNT: String = "staff_start_count"
const KEY_ATTR_BASE_MIN: String = "staff_attr_base_min"
const KEY_ATTR_BASE_MAX: String = "staff_attr_base_max"
const KEY_ATTR_GROWTH: String = "staff_attr_growth_per_project"
const KEY_STATE_WEIGHTS: String = "staff_state_weights"
const KEY_STATE_MODIFIER: String = "staff_state_modifier"
const KEY_OBSERVATION_POOL: String = "staff_observation_pool"
const KEY_ROLES: String = "staff_roles"
const KEY_INITIAL_ROSTER: String = "staff_initial_roster"

## rng.json 状态带参数键（randomness-spec D.2 拼写；rng_stream.get_param 读取）
const RNG_KEY_PITY: String = "rnd_staff_pity"

## staff_state_weights/staff_state_modifier 子键（三态表内稳定字符串，与文案键对应）
const STATE_KEY_FOCUS: String = "focus"
const STATE_KEY_SLACKING: String = "slacking"
const STATE_KEY_INSPIRED: String = "inspired"

## staff_roles 岗位表内稳定字符串（G3 直接 4 岗；与 CoreEnums.StaffRole 同源派生）
const ROLE_KEY_RESEARCH: String = "research"
const ROLE_KEY_EVAL: String = "eval"
const ROLE_KEY_DATA: String = "data"
const ROLE_KEY_ENGINEERING: String = "engineering"

## 属性四维稳定键（numerics-master §1.3 员工属性映射真源；与矩阵 attr_coef 同键）
const ATTR_KEYS: Array[String] = ["theory", "engineering", "data", "communication"]

## 初始观察句 id（绑定池序，随员工固定；仅装配私有，外部经 observation_id 读取）
var _id: String = ""
var _name: String = ""
var _role: CoreEnums.StaffRole = CoreEnums.StaffRole.RESEARCH
var _attrs: Dictionary = {}
var _observation_id: int = -1
var _career_weeks: int = 0
var _state: CoreEnums.StaffState = CoreEnums.StaffState.FOCUS
var _state_weeks_in: int = 0
var _slack_streak: int = 0
var _current_modifier: float = 1.0
var _staff_table: Dictionary = {}
var _rng: RngStream = null
var _state_weights: Dictionary = {}
var _state_modifier: Dictionary = {}
var _pity_max: int = 3


func _init(definition: Dictionary, staff_table: Dictionary, rng_stream: RngStream) -> void:
	_staff_table = staff_table
	_rng = rng_stream
	if definition.is_empty() or _staff_table.is_empty() or _rng == null:
		push_error("Staff: 构造参数不完整（缺员工定义/表/流）")
		return
	_extract_role(definition)
	_id = str(definition.get("id", ""))
	_name = str(definition.get("name", ""))
	_extract_attrs(definition)
	# 观察句静态种子绑定：池序确定性取 1 句，永不轮转（staff-spec C.4）
	var pool: Array = _staff_table.get(KEY_OBSERVATION_POOL, [])
	_observation_id = int(definition.get("observation_pool_index", 0))
	if pool.is_empty() or _observation_id < 0 or _observation_id >= pool.size():
		push_error("Staff: 观察句池为空或绑定越界（id=%s）" % _id)
		_observation_id = -1
		return
	# 状态带参数（rng.json pity + staff.json 三态权重/带）
	_pity_max = _rng.get_int_param(RNG_KEY_PITY)
	_state_weights = _staff_table.get(KEY_STATE_WEIGHTS, {})
	_state_modifier = _staff_table.get(KEY_STATE_MODIFIER, {})
	# 首个状态不带随机：全部员工从 FOCUS（专注）起步（开局稳定，教学友好），
	# 起步乘数=专注带下限 1.0（周 1 未消费任何随机样本，状态带从首个周结开始掷）
	_state = CoreEnums.StaffState.FOCUS
	_state_weeks_in = 1
	_slack_streak = 0
	_current_modifier = _state_band_min(_state)


## ---------- 命令面（契约命令；掷点=周粒度一次，由周结装配方外部驱动） ----------


## 周粒度状态带掷点（架构 §5.3 phase 7d 落点）。每员工每周恒消费 1 个
## rng.staff 样本（同种子同局可复现）：同一样本既掷状态（累计权重轮盘）又
## 定带内产出乘数位置（randomness-spec OP-RND-05 "带内加权"，周内稳定）；
## pity=slacking 连击达 rnd_staff_pity 必转。在职年限随每次周结掷点推进。
func roll_state_week() -> CoreEnums.StaffState:
	if _rng == null:
		push_error("Staff: RNG 流未注入，无法掷点")
		return _state
	# 恰 1 个 staff 域样本：域消费点可数（ADR-0008，消费点 grep 可数）
	var roll: float = _rng.randf_domain("staff")
	var draw := _draw_week(roll, _slack_streak, _pity_max, _state_weights)
	var new_state: CoreEnums.StaffState = draw["state"]
	if new_state == _state:
		_state_weeks_in += 1
	else:
		_state_weeks_in = 1
	if new_state == CoreEnums.StaffState.SLACKING:
		_slack_streak += 1
	else:
		_slack_streak = 0
	_state = new_state
	# 带内余量定位：t∈[0,1) 映射到该态乘数带 [min,max]（条件分布=带内均匀，
	# 摸鱼能出 0.90–1.00 全带、灵感能出 0.92–1.08 全带——状态→产出带可读）
	_current_modifier = _band_value(_state_band(_state), float(draw["t"]))
	_career_weeks += 1
	return _state


## ---------- 谓词（供 Roster/指派侧读；不写"在岗项目"字段，架构 §4.1） ----------


## 当前是否空闲（未在岗项目；本单 Roster 无在岗写点，恒 idle——指派写点在
## TaskBoard #131/#132；谓词形状=架构 §3 Roster 只出谓词，id 交给外部反查）。
func is_idle() -> bool:
	return true


func is_assignable() -> bool:
	return is_idle()


## ---------- 数据面（只读、深拷贝） ----------


func get_staff_view() -> Dictionary:
	return {
		"id": _id,
		"name": _name,
		"name_key": str(_name),
		"role": _role,
		"role_key": role_to_key(_role),
		"role_name_key": _role_name_key(),
		"attrs": _attrs.duplicate(true),
		"state": _state,
		"state_key": state_to_key(_state),
		"state_name_key": _state_name_key(_state),
		"state_weeks_in": _state_weeks_in,
		"modifier": _current_modifier,
		"modifier_min": _state_band_min(_state),
		"modifier_max": _state_band_max(_state),
		"observation_id": _observation_id,
		"observation_text_key": _observation_text_key(),
		"career_weeks": _career_weeks,
	}


func get_id() -> String:
	return _id


func get_name() -> String:
	return _name


func get_role() -> CoreEnums.StaffRole:
	return _role


## 岗位适配系数（表驱动读 staff_roles[role].attr_coef[dim]；无岗无维返回 0）
func role_coef_for(dim_key: String) -> float:
	var roles: Dictionary = _staff_table.get(KEY_ROLES, {})
	var role_key := role_to_key(_role)
	var role_def: Variant = roles.get(role_key)
	if role_def is Dictionary:
		var coefs: Variant = (role_def as Dictionary).get("attr_coef")
		if coefs is Dictionary:
			return float((coefs as Dictionary).get(dim_key, 0.0))
	return 0.0


func get_attr(dim_key: String) -> float:
	return float(_attrs.get(dim_key, 0.0))


func get_observation_id() -> int:
	return _observation_id


## 观察句文案键（texts.json 真源键；id 绑定永不轮转，L3 经 TextService 取句）
func get_observation_text_key() -> String:
	return _observation_text_key()


func get_state() -> CoreEnums.StaffState:
	return _state


func get_state_weeks_in() -> int:
	return _state_weeks_in


func get_slack_streak() -> int:
	return _slack_streak


func get_career_weeks() -> int:
	return _career_weeks


## 状态产出乘数（确定性：当前周状态带内定位值；防带内二次未登记随机，
## 同一样本既定态又定位——numerics-master §六 staff_state_modifier 带收口；
## ±10% 同量级护栏断言见 test_data_schema_staff）
func get_output_modifier() -> float:
	return _current_modifier


## 当前状态带区间（读表直接输出，供 L3/周报"出活 X–Y%"同源提示；未知态回退全带）
func get_state_band_min() -> float:
	return _state_band_min(_state)


func get_state_band_max() -> float:
	return _state_band_max(_state)


## 当前状态带内位置 t∈[0,1]（roll 定位；数据面供曲线/详情只读展示）
func get_state_band_position() -> float:
	var band := _state_band(_state)
	if band.is_empty():
		return 0.0
	var min_v := float(band.get("min", 1.0))
	var max_v := float(band.get("max", 1.0))
	if max_v <= min_v:
		return 0.0
	return clampf((_current_modifier - min_v) / (max_v - min_v), 0.0, 1.0)


## ---------- 私有 ----------


func _extract_role(definition: Dictionary) -> void:
	var role_key: Variant = definition.get("role")
	_role = (
		CoreEnums.StaffRole.DATA
		if role_key == ROLE_KEY_DATA
		else (
			CoreEnums.StaffRole.ENGINEERING
			if role_key == ROLE_KEY_ENGINEERING
			else (
				CoreEnums.StaffRole.EVAL
				if role_key == ROLE_KEY_EVAL
				else CoreEnums.StaffRole.RESEARCH
			)
		)
	)


func _extract_attrs(definition: Dictionary) -> void:
	var raw: Variant = definition.get("attrs")
	if raw is Dictionary:
		for key: String in ATTR_KEYS:
			_attrs[key] = float((raw as Dictionary).get(key, 0.0))


## 单样本周抽（核心机制）：累计权重轮盘 + 同一样本带内定位 t（条件均匀）。
## roll∈[0,1)：累计概率轴分段 [0,w_focus)/[w_focus,w_focus+w_slack)/…，t=落在
## 该态段内的相对位置（余量/段宽）——同一样本既掷状态又定带内位置，不新增随机。
## pity 保底=slacking 连续 pity_max 周（含当周）必转——slacking 权重清零强制不重复
## 摸鱼（staff-spec D.2 "连 3 必转" + randomness-spec OP-RND-05 "pity 内不重复摸鱼"）。
## 返回 {state, t}；权重缺失/和≤0 回退 FOCUS+t=0。
func _draw_week(roll: float, slack_streak: int, pity_max: int, weights: Dictionary) -> Dictionary:
	var w_focus := float(weights.get(STATE_KEY_FOCUS, 0.0))
	var w_slack := float(weights.get(STATE_KEY_SLACKING, 0.0))
	var w_inspired := float(weights.get(STATE_KEY_INSPIRED, 0.0))
	if slack_streak + 1 >= pity_max:
		w_slack = 0.0  # 保底周不重复摸鱼（slacking 池清零）
	var total := w_focus + w_slack + w_inspired
	if total <= 0.0:
		return {"state": CoreEnums.StaffState.FOCUS, "t": 0.0}
	var scaled := roll * total
	if scaled < w_focus:
		return {"state": CoreEnums.StaffState.FOCUS, "t": scaled / w_focus}
	scaled -= w_focus
	if scaled < w_slack:
		return {"state": CoreEnums.StaffState.SLACKING, "t": scaled / w_slack}
	scaled -= w_slack
	return {"state": CoreEnums.StaffState.INSPIRED, "t": scaled / w_inspired}


## 带内定位（t∈[0,1) → [min,max]）线性映射（条件均匀分布：状态→产出带可读）
func _band_value(band: Dictionary, t: float) -> float:
	if band.is_empty():
		return 1.0
	var min_v := float(band.get("min", 1.0))
	var max_v := float(band.get("max", 1.0))
	return min_v + clampf(t, 0.0, 1.0) * (max_v - min_v)


func _state_band_min(state: CoreEnums.StaffState) -> float:
	var band := _state_band(state)
	return float(band.get("min", 1.0)) if not band.is_empty() else 1.0


func _state_band_max(state: CoreEnums.StaffState) -> float:
	var band := _state_band(state)
	return float(band.get("max", 1.0)) if not band.is_empty() else 1.0


func _state_band(state: CoreEnums.StaffState) -> Dictionary:
	var entry: Variant = _state_modifier.get(state_to_key(state))
	return entry if entry is Dictionary else {}


func _observation_text_key() -> String:
	var pool: Array = _staff_table.get(KEY_OBSERVATION_POOL, [])
	if _observation_id >= 0 and _observation_id < pool.size():
		return str(pool[_observation_id])
	return ""


func _role_name_key() -> String:
	var roles: Dictionary = _staff_table.get(KEY_ROLES, {})
	var role_def: Variant = roles.get(role_to_key(_role))
	if role_def is Dictionary:
		return str((role_def as Dictionary).get("name_key", ""))
	return ""


func _state_name_key(state: CoreEnums.StaffState) -> String:
	match state:
		CoreEnums.StaffState.SLACKING:
			return "staff_state_slacking"
		CoreEnums.StaffState.INSPIRED:
			return "staff_state_inspired"
		_:
			return "staff_state_focus"


## 岗位/状态 enum→表内稳定字符串的单向集中映射（跨模块字典同源派生防线）
static func role_to_key(role: CoreEnums.StaffRole) -> String:
	match role:
		CoreEnums.StaffRole.EVAL:
			return ROLE_KEY_EVAL
		CoreEnums.StaffRole.DATA:
			return ROLE_KEY_DATA
		CoreEnums.StaffRole.ENGINEERING:
			return ROLE_KEY_ENGINEERING
		_:
			return ROLE_KEY_RESEARCH


static func state_to_key(state: CoreEnums.StaffState) -> String:
	match state:
		CoreEnums.StaffState.SLACKING:
			return STATE_KEY_SLACKING
		CoreEnums.StaffState.INSPIRED:
			return STATE_KEY_INSPIRED
		_:
			return STATE_KEY_FOCUS
