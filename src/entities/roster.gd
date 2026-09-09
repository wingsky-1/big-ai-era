class_name Roster
extends RefCounted
## L2 员工名册（#130）：初始 4 人装配自 staff.json；is_idle()/is_assignable() 谓词。
## 硬约束（任务书/架构 H2/H9/§3/§4.1/E1）：
## - RefCounted、零 Node/SceneTree 依赖（headless 可单测）；
## - **不写"在岗项目"字段**（架构 §4.1 防双真源：指派写点在 TaskBoard，#131/#132 做）；
##   本类只出谓词+属性读；"空闲"判定=装配方注入的可指派过滤器（默认真=无 TaskBoard
##   时全员可派；TaskBoard 落位后注入"不在任何槽成员"判定，弱回调无环引用）；
## - 初始装配=遍历 staff.json staff_initial_roster._order 全行（E1 表驱动预留：
##   4→8→12 扩展=表加行+扩编批激活新行，本类装配循环零改、不写死 4）；
## - 周粒度状态掷点=本类唯一命令入口（roll_weekly_states，外部周结/Settlement #135
##   驱动）：每员工每周恒 1 个 rng.staff 样本，掷点即 emit staff_state_rolled
##   （架构 §5.2 信号；载荷={staff_id,state,state_key,modifier*,…}，range_hint 由
##   L3 按文案键 staff_state_output_hint + 数值带拼出，文案与数值同源防两张皮）；
## - 数据面 get_roster_view()/get_staff_view() 深拷贝；get_staff() 只供 L2 内部装配
##   （TaskBoard/World）拿对象引用，L3 一律走 view（ADR-0016 数据面契约）。

signal staff_state_rolled(payload: Dictionary)

const STAFF_TABLE_PATH: String = "res://src/data/staff.json"
const KEY_INITIAL_ROSTER: String = "staff_initial_roster"
const KEY_ORDER: String = "_order"
const KEY_START_COUNT: String = "staff_start_count"

## 装配方注入的可指派过滤器（无参 Callable 之外带 staff_id 参数；返回 false=不可派）。
## 默认=全员可派（无 TaskBoard 阶段真实语义：开局无任何指派发生）。
var assignable_filter: Callable = func(_staff_id: String) -> bool: return true

var _staff_table: Dictionary = {}
var _staff_by_id: Dictionary = {}
var _order: Array[String] = []
var _rng: RngStream = null


func _init(staff_table: Dictionary = {}, rng_stream: RngStream = null) -> void:
	_staff_table = staff_table
	if _staff_table.is_empty():
		_staff_table = DataLoader.load_json(STAFF_TABLE_PATH)
		if _staff_table.is_empty():
			push_error("Roster: staff.json 加载失败（真源 %s）" % STAFF_TABLE_PATH)
			return
	_rng = rng_stream
	# RNG 流必须注入（状态带掷点=登记域消费，自建流会破坏同种子确定性；#125 纪律）
	if _rng == null:
		push_error("Roster: 必须注入 RngStream（装配方经 DataLoader+setup 提供）")
		return
	_assemble()


## ---------- 命令面（契约命令） ----------


## 周粒度全册掷点（架构 §5.3 phase 7d 员工状态带掷点的名册落点；Settlement #135
## 在周结 phase 7d 调用本方法）。每员工消费恰 1 个 rng.staff 样本（周粒度掷一次），
## 周内稳定（周结间不重掷——本方法只在周结被调用）；返回各员工掷点载荷数组。
func roll_weekly_states() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for staff_id: String in _order:
		var staff: Staff = _staff_by_id[staff_id]
		var new_state: CoreEnums.StaffState = staff.roll_state_week()
		var payload := {
			"staff_id": staff_id,
			"state": new_state,
			"state_key": Staff.state_to_key(new_state),
			"modifier": staff.get_output_modifier(),
			"modifier_min": staff.get_state_band_min(),
			"modifier_max": staff.get_state_band_max(),
		}
		staff_state_rolled.emit(payload)
		results.append(payload)
	return results


## ---------- 谓词（Roster 只出谓词，不写"在岗项目"字段；架构 §3/§4.1） ----------


## 员工是否空闲可派（存在 && 装配方注入的可指派过滤器通过；TaskBoard 落位前
## 全员 true=开局无指派真实语义）。未知 id 一律 false。
func is_idle(staff_id: String) -> bool:
	if not _staff_by_id.has(staff_id):
		return false
	return assignable_filter.call(staff_id)


func is_assignable(staff_id: String) -> bool:
	return is_idle(staff_id)


## 当前可指派员工 id 列表（过滤序=名册 _order，供未来指派入口遍历）
func get_assignable_ids() -> Array[String]:
	var result: Array[String] = []
	for staff_id: String in _order:
		if is_assignable(staff_id):
			result.append(staff_id)
	return result


## ---------- 数据面（只读、深拷贝；L3 经此拿数） ----------


func get_roster_view() -> Dictionary:
	var staff_views: Array = []
	for staff_id: String in _order:
		staff_views.append(_staff_by_id[staff_id].get_staff_view())
	return {
		"staff_count": staff_views.size(),
		"staff": staff_views,
	}


## 单个员工视图（L3 员工卡/详情页数据源；未知 id 返回空 dict）
func get_staff_view(staff_id: String) -> Dictionary:
	if not _staff_by_id.has(staff_id):
		return {}
	return _staff_by_id[staff_id].get_staff_view()


## 员工对象访问（仅供 L2 内部——TaskBoard/World/Settlement 装配与读属性；
## L3 禁拿对象，一律走 get_staff_view 深拷贝，ADR-0016）。未知 id 返回 null。
func get_staff(staff_id: String) -> Staff:
	var staff: Variant = _staff_by_id.get(staff_id)
	return staff as Staff if staff is Staff else null


func get_staff_count() -> int:
	return _order.size()


func get_staff_ids() -> Array[String]:
	return _order.duplicate()


## 初始人数目标（staff.json staff_start_count 键；E1 表驱动：扩编=表加行+改目标）
func get_initial_count_target() -> int:
	return int(_staff_table.get(KEY_START_COUNT, 0))


## ---------- 私有 ----------


func _assemble() -> void:
	var roster_def: Variant = _staff_table.get(KEY_INITIAL_ROSTER)
	if roster_def is not Dictionary:
		push_error("Roster: staff.json 缺初始名册块 '%s'" % KEY_INITIAL_ROSTER)
		return
	var order: Variant = (roster_def as Dictionary).get(KEY_ORDER)
	if order is not Array or (order as Array).is_empty():
		push_error("Roster: staff_initial_roster._order 缺失或为空（表驱动装配序）")
		return
	_staff_by_id.clear()
	_order.clear()
	for staff_id: Variant in order:
		if staff_id is not String:
			continue
		var entry: Variant = (roster_def as Dictionary).get(staff_id)
		if entry is not Dictionary:
			push_error("Roster: 初始名册缺员工行 '%s'" % str(staff_id))
			continue
		var definition := {
			"id": staff_id,
			"name": str((entry as Dictionary).get("name", "")),
			"role": str((entry as Dictionary).get("role", "")),
			"attrs": (entry as Dictionary).get("attrs", {}),
			"observation_pool_index": (entry as Dictionary).get("observation_pool_index", 0),
		}
		var staff := Staff.new(definition, _staff_table, _rng)
		_staff_by_id[staff_id] = staff
		_order.append(staff_id)
