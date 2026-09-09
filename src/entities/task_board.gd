class_name TaskBoard
extends RefCounted
## L2 统一任务槽容器（#131 + #132 指派完整流）：恒 4 槽 × Project 抽象基类。
## 硬约束（任务书/architecture-100 §4.1/ADR-0018/§4.4/§8/§5.2）：
## - RefCounted、零 Node/SceneTree 依赖（headless 可单测）；
## - **槽恒 4**：架构 §4.1"槽配置=固定 4，常量入 core/enums 或 ui.json"→ 本批
##   无新数据表（issue 实施提示"本批无新表"），真源=本常量（L0 枚举面，禁散落
##   硬编码；若未来入 ui.json 数据键需先有真源键，当前无键=按 issue 裁决常量化）；
## - 槽位 slot[0..3]：各持 0..1 Project + 0..N 上桌员工 id 列表（**字符串 id 数组，
##   不持对象引用**——防引用环、天然可序列化；weakref 语义=引用序列化 id 由
##   World 读档重建，架构 §9.1/ADR-0018）；双向一致性=每员工至多一槽；
## - 命令面：start_paper/start_training/start_compute/cancel_project/assign_staff/
##   unassign_staff（P0 直接入空槽=IN_PROGRESS；槽满即拒；Q 深队列 P2 才入枚举）；
## - 拒绝原因单一源：每条拒绝路径恰返回一枚举码（CoreEnums.SlotRejectReason），
##   禁字符串散落/拼接多因；文案键 *_disabled_reason 由 L3 按码拼 #124 键面；
##   校验序=固定（命中即返）；非契约/越界入口=防御性拒绝不抛错；
## - 指派写点=本容器槽成员 id 列表（架构 §4.1 唯一写点）；Staff/Roster **不写**
##   "在岗项目"字段，只出谓词——本类经构造注入两个谓词（is_staff_known/
##   is_staff_assignable，装配方把 Roster.is_assignable + 过滤串起来注入；
##   #130 同款"装配方注入"方向，本类不自持 Roster 引用防环）；
##   上桌人数上限校验来自 Project 声明（get_seat_limit），本类不发明上限；
## - #132 完整指派流：指派/撤派成功即按槽成员岗位组合重算协作系数
##   （CollabFactor 表驱动；岗位键经注入 get_staff_role_key 查询，staff.json 整表
##   经注入 staff_table 提供——本类不自读文件不自持 Staff 引用，防环同谓词），
##   写入 Project.set_collab_factor（多人>2=最弱配对保守下限，真源 #140/#141）；
##   0.5s 刷新语义=task_board_changed 信号发射 + 槽视图随查随新（#131 已有信号，
##   本批指派载荷不变；L3 消费信号重查 get_task_view，见架构 §5.2）；
## - week_tick 驱动各槽项目推进（架构 §5.3 phase 2；完成→FINISHED_PENDING，
##   槽不自动释放——结算/释放归 Settlement #135，本批不发明接口）；
## - 信号（架构 §5.2）：task_board_changed（槽态变）真实发射点+消费点（测试）；
##   project_finished 载荷需 kind_view（Settlement 路由产物），#135 随结算管线
##   一并发射，本批不提前发射（防零载荷死信号，§5.2 纪律）；
## - 数据面 get_task_view() 只读深拷贝（L3 只画）；每槽"预计结账 Wx/进度/周耗/
##   上桌者/上限/原因"全部出自本 view（槽卡呈现同源，禁双写）；#132 起槽视图
##   含协作系数/协作分类/上桌者角色键（协作角标数据面同源）；
## - 数值零硬编码：唯一数值=槽数 4（架构真源固定，见上）；协作系数值零代码
##   硬编码（读注入的 staff.json，见 CollabFactor）。
## 行数预算：≤500（architecture §8 严控）；超限拆子状态类（当前未超）。

signal task_board_changed(change: Dictionary)

## 槽总数（唯一"4"真源；issue 实施提示：槽配置=固定 4，常量入 core/enums——
## 集中在本类 L0 面常量，散落硬编码禁止；若未来改表驱动需先建真源键）
const TASK_SLOT_COUNT: int = 4
const INVALID_SLOT_INDEX: int = -1
## 空槽 type 哨兵（ProjectType 枚举范围外 -1：view/载荷的 type 在有项目时=真实
## enum、空槽时=-1，防空槽误按论文着色/入档混淆；state=EMPTY 才是空权威）
const EMPTY_SLOT_TYPE: int = -1

## 员工存在性谓词（注入；默认=不存在即拒——装配方未注入时防御性全拒，
## 防"假装配全员可派"掩盖集成缺口）。签名与 Roster.is_assignable 对齐：
## 只出谓词不写状态；未知 id 一律 false。
var is_staff_known: Callable = func(_staff_id: String) -> bool: return false
## 员工可派性谓词（注入；默认=全拒，同上防御方向；#132 前默认装配=Roster 谓词）
var is_staff_assignable: Callable = func(_staff_id: String) -> bool: return false
## 员工岗位键查询（注入；#132 协作系数按槽成员岗位组合计算用。装配方把
## Staff.role_to_key(roster.get_staff(id).get_role()) 串起来注入；本类不自持
## Staff/Roster 引用防环（同谓词方向）。未知 id/未装配=空串→CollabFactor 防御
## 回退 known=false 档。返回=岗位表内稳定字符串（research/eval/data/engineering）
var get_staff_role_key: Callable = func(_staff_id: String) -> String: return ""
## staff.json 整表（注入；#132 协作系数表驱动真源。装配方经 DataLoader 读表注入；
## 本类不自读文件（单测可注入假表/真表）。空=防御回退同岗 1.0 档不抛错）
var staff_table: Dictionary = {}

## 训练启动资源校验谓词（#140 注入；**默认=宽松通过**——与员工谓词默认全拒
## 相反：员工写点安全须缺省拒，资源校验无装配=无资源语义（测试桩/无 World），
## 缺省放行不误伤 #131 容器测试。装配方注入真实判定：
## - tier_met(tier_required: String) -> bool：档位门槛谓词（接 ChipYard
##   .get_tier_eligibility(...).ok；空门槛恒过）
## - budget_met(card_hours_per_week: int) -> bool：本周卡时谓词（接
##   Resources 剩余 ≥ 周耗）
var tier_met: Callable = func(_tier_required: String) -> bool: return true
var budget_met: Callable = func(_card_hours_per_week: int) -> bool: return true
## 周结预算扣减钩子（#140 注入；Settlement phase1 重置后调本类
## consume_weekly_budget() 时对在跑项目逐项扣本周周耗。装配方接
## Resources.consume_card_hours(周耗).ok；返回扣减成功与否汇总。
var consume_card_hours: Callable = func(_hours: int) -> bool: return true

var _slot_projects: Array = []
var _slot_staff_ids: Array = []
var _slot_states: Array = []


func _init() -> void:
	# 恒 4 槽（槽数=常量非数据，架构真源见类头注释；禁散落"4"字面量）
	for _i: int in TASK_SLOT_COUNT:
		_slot_projects.append(null)
		_slot_staff_ids.append([])
		_slot_states.append(CoreEnums.ProjectState.EMPTY)


## ---------- 命令面：入槽（论文/训练/算力三类同走统一入槽，互斥占槽） ----------


## 论文项目入槽（start_paper；#133 起由选题池装配方构造 PaperProject 传入）。
func start_paper(project: PaperProject, prefer_slot: int = INVALID_SLOT_INDEX) -> Dictionary:
	return _start_project(project, prefer_slot)


## 训练项目入槽（start_training；#140 起由基座装配方构造 ModelProject 传入）。
## #140 六因校验收口：入槽前先过资源双因（档位门槛 + 本周卡时），再走统一
## 入槽（槽满因在 _start_project 内）。models-spec 六因=槽满(ALL_SLOTS_FULL)/
## 档位不足(TIER_REQUIRED_NOT_MET)/卡时不足(CARD_HOURS_INSUFFICIENT)/
## 无研究员/上桌超限(指派阶段 SEAT_LIMIT_REACHED)/资金(购买档位阶段)——
## 命令层判两资源因 + 槽满，其余因归各阶段单一原因源。校验序固定：档位先、
## 卡时次、槽满最后（命中即返单因不拼接）。谓词默认宽松=无装配不误伤测试。
func start_training(project: ModelProject, prefer_slot: int = INVALID_SLOT_INDEX) -> Dictionary:
	if project == null or not project.is_running():
		return {"ok": false, "reason": CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT}
	var tier := project.get_tier_required()
	if not tier.is_empty() and not tier_met.call(tier):
		return {
			"ok": false,
			"reason": CoreEnums.SlotRejectReason.TIER_REQUIRED_NOT_MET,
			"tier_required": tier,
		}
	var hours := project.get_card_hours_per_week()
	if hours > 0 and not budget_met.call(hours):
		return {
			"ok": false,
			"reason": CoreEnums.SlotRejectReason.CARD_HOURS_INSUFFICIENT,
			"card_hours_per_week": hours,
		}
	return _start_project(project, prefer_slot)


## 算力项目入槽（start_compute，P2 占位——命令签名按架构 §4.1 命令面齐备；
## 本批无 ComputeProject 类，仅测试内 ComputeStub 经 _start_project 占槽）。
func start_compute(project: Project, prefer_slot: int = INVALID_SLOT_INDEX) -> Dictionary:
	return _start_project(project, prefer_slot)


## 统一入槽实现（三类命令共用=槽位互斥语义单点，防"三类队列分治"漂移）。
## 槽选择：prefer_slot 为提示性首选（该槽空才入）；否则自动取首空槽；
## 无空槽=槽满拒绝。任何路径都禁止覆写已占槽（防事故）。
func _start_project(project: Project, prefer_slot: int) -> Dictionary:
	if project == null or not project.is_running():
		return {"ok": false, "reason": CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT}
	var target: int = INVALID_SLOT_INDEX
	if prefer_slot >= 0 and prefer_slot < TASK_SLOT_COUNT and is_slot_empty(prefer_slot):
		target = prefer_slot
	if target == INVALID_SLOT_INDEX:
		target = _first_empty_slot()
	if target == INVALID_SLOT_INDEX:
		return {"ok": false, "reason": CoreEnums.SlotRejectReason.ALL_SLOTS_FULL}
	var change := {"kind": "started", "slot_index": target, "type": project.get_type()}
	_slot_projects[target] = project
	_slot_states[target] = CoreEnums.ProjectState.IN_PROGRESS
	_slot_staff_ids[target] = []
	_emit_changed(change)
	return {"ok": true, "slot_index": target, "reason": CoreEnums.SlotRejectReason.NONE}


## ---------- 命令面：指派（唯一写点=本容器槽成员 id 列表；防双真源） ----------


## 指派员工上桌到指定槽项目（架构 §4.1 指派命令落点；#132 完整流：
## 写入成功后按槽成员组合重算协作系数——组合角标/周耗加速的数据面同源）。
## 校验序=固定（_validate_assign 链）：槽/项目在位 → 员工存在 → 未在别槽 →
## 未在本槽 → 可派性 → 上桌上限。单因语义：命中即返，禁多因拼接。
## 0.5s 刷新语义=task_board_changed 信号发射（载荷含新协作 factor/kind，
## L3 收信号重查 get_task_view 即可 0.5s 内翻新卡与角标，架构 §5.2）。
func assign_staff(staff_id: String, slot_index: int) -> CoreEnums.SlotRejectReason:
	var slot: int = _resolve_target_slot(slot_index)
	var rejection := _validate_assign(slot, staff_id)
	if rejection != CoreEnums.SlotRejectReason.NONE:
		return rejection
	var project := get_project(slot)
	_slot_staff_ids[slot].append(staff_id)
	var factor: float = _refresh_slot_collab(slot)
	var change := {
		"kind": "assigned",
		"slot_index": slot,
		"type": project.get_type(),
		"staff_id": staff_id,
		"collab_factor": factor,
		"collab_kind": _slot_collab_kind(slot),
	}
	_emit_changed(change)
	return CoreEnums.SlotRejectReason.NONE


## 撤派（把员工移出槽成员；校验对象=在桌员工）。撤派后重算协作系数
## （回单人=1.0；多人剩 2 人=按剩余两人组合）——角标随撤派即时消失。
func unassign_staff(staff_id: String, slot_index: int) -> CoreEnums.SlotRejectReason:
	var slot: int = _resolve_target_slot(slot_index)
	if slot == INVALID_SLOT_INDEX:
		return CoreEnums.SlotRejectReason.SLOT_OUT_OF_RANGE
	if not is_running(slot):
		return CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT
	if not _staff_ids(slot).has(staff_id):
		return CoreEnums.SlotRejectReason.UNASSIGN_NOT_ON_TABLE
	_slot_staff_ids[slot].erase(staff_id)
	_refresh_slot_collab(slot)
	var change := {
		"kind": "unassigned",
		"slot_index": slot,
		"type": _slot_type(slot),
		"staff_id": staff_id,
	}
	_emit_changed(change)
	return CoreEnums.SlotRejectReason.NONE


## ---------- 命令面：取消（项目未完成才能撤台；完成=结算对象，归 #135） ----------


func cancel_project(slot_index: int) -> CoreEnums.SlotRejectReason:
	var slot: int = _resolve_target_slot(slot_index)
	if slot == INVALID_SLOT_INDEX:
		return CoreEnums.SlotRejectReason.SLOT_OUT_OF_RANGE
	if not is_running(slot):
		return CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT
	_slot_projects[slot] = null
	_slot_staff_ids[slot] = []
	_slot_states[slot] = CoreEnums.ProjectState.EMPTY
	_emit_changed({"kind": "cancelled", "slot_index": slot})
	return CoreEnums.SlotRejectReason.NONE


## 周结预算扣减（#140；Settlement phase1 卡时重置后调用）：对全部在跑
## **训练型**项目逐项扣本周周耗（consume_card_hours 注入谓词，装配方接
## Resources.consume_card_hours；扣减失败=预算异常返回 false——供得上护栏
## 下不应发生，防御语义）。论文型周耗扣减归 #141 出分批接线（chips-spec
## 账本"Σ训练+Σ论文实验"，本单只落训练侧）。
func consume_weekly_budget() -> bool:
	var ok := true
	for slot: int in TASK_SLOT_COUNT:
		if not is_running(slot):
			continue
		var project := get_project(slot)
		if project == null or project.get_type() != CoreEnums.ProjectType.MODEL:
			continue
		var hours := project.get_card_hours_per_week()
		if hours > 0 and not consume_card_hours.call(hours):
			ok = false
	return ok


## ---------- 周结推进（架构 §5.3 phase 2 槽推进落点；Settlement #135 调用） ----------


## 逐槽推进在跑项目；返回完成载荷（FINISHED_PENDING）列表（槽不释放：
## 释放/结算路由归 #135；本批不发明接口）。变更后发 task_board_changed。
func week_tick() -> Array[Dictionary]:
	var finished: Array[Dictionary] = []
	for slot: int in TASK_SLOT_COUNT:
		if not is_running(slot):
			continue
		var project := get_project(slot)
		if project == null:
			continue
		var change: Dictionary = {
			"kind": "progressed", "slot_index": slot, "type": project.get_type()
		}
		if project.week_tick():
			if project.is_finished_pending():
				change["kind"] = "finished_pending"
				_slot_states[slot] = CoreEnums.ProjectState.FINISHED_PENDING
				finished.append(
					{"slot_index": slot, "type": project.get_type(), "project": project}
				)
		_emit_changed(change)
	return finished


## ---------- 数据面（只读深拷贝；L3 只画） ----------


## 任务板视图：Array[槽 view]（每槽：type/标题键/进度/预计结账/周耗/上桌者/
## 上限/协作/状态/该槽当前唯一拒绝原因）。深拷贝，改外部结果不影响内部。
func get_task_view() -> Array:
	var views: Array = []
	for slot: int in TASK_SLOT_COUNT:
		views.append(_slot_view(slot))
	return views


func get_slot_view(slot_index: int) -> Dictionary:
	var slot: int = _resolve_target_slot(slot_index)
	if slot == INVALID_SLOT_INDEX:
		return {}
	return _slot_view(slot)


## ---------- 谓词/读值（L2 装配/周结/测试用；L3 一律走 view） ----------


## 槽当前状态（EMPTY=空；空槽 = state EMPTY（完成待结算槽≠空，仍占位））。
func get_slot_state(slot_index: int) -> CoreEnums.ProjectState:
	var slot: int = _resolve_target_slot(slot_index)
	if slot == INVALID_SLOT_INDEX:
		return CoreEnums.ProjectState.EMPTY
	return _slot_states[slot]


## 槽是否空（可入槽；仅 EMPTY 态=可入——FINISHED_PENDING 槽不可复用，
## 由 #135 消费释放后才回到 EMPTY）
func is_slot_empty(slot_index: int) -> bool:
	return get_slot_state(slot_index) == CoreEnums.ProjectState.EMPTY


## 项目是否运行中（在跑=可指派/取消；空/完成=否）
func is_running(slot_index: int) -> bool:
	if get_slot_state(slot_index) != CoreEnums.ProjectState.IN_PROGRESS:
		return false
	var project := get_project(slot_index)
	return project != null and project.is_running()


## 槽内项目对象（仅 L2 内部/测试访问；view 已含全部，L3 禁取对象，ADR-0016）
func get_project(slot_index: int) -> Project:
	var slot: int = _resolve_target_slot(slot_index)
	if slot == INVALID_SLOT_INDEX:
		return null
	var project: Variant = _slot_projects[slot]
	return project as Project if project is Project else null


## 槽成员 id 列表（深拷贝；只读面——写点只有 assign/unassign/cancel 命令）
func get_assigned_staff(slot_index: int) -> Array[String]:
	var slot: int = _resolve_target_slot(slot_index)
	if slot == INVALID_SLOT_INDEX:
		return []
	var members: Array[String] = []
	for staff_id: Variant in _slot_staff_ids[slot]:
		members.append(str(staff_id))
	return members


## 全部槽成员 id（聚合反查：员工卡"在岗"由 World 遍历本列表反查槽号，
## 杜绝 Roster 另存"在岗项目"双写漂移；架构 §4.1）
func get_all_assigned_staff() -> Array[String]:
	var all: Array[String] = []
	for slot: int in TASK_SLOT_COUNT:
		for staff_id: Variant in _slot_staff_ids[slot]:
			all.append(str(staff_id))
	return all


## 员工当前所在槽（不在任何槽=INVALID_SLOT_INDEX；每员工至多一槽由
## assign_staff 校验 + 本谓词反查共同守住双向一致性）
func get_slot_of_staff(staff_id: String) -> int:
	for slot: int in TASK_SLOT_COUNT:
		if _slot_staff_ids[slot].has(staff_id):
			return slot
	return INVALID_SLOT_INDEX


## 当前空槽数（L3 接单入口"可入槽数"提示）
func get_empty_slot_count() -> int:
	var count: int = 0
	for slot: int in TASK_SLOT_COUNT:
		if is_slot_empty(slot):
			count += 1
	return count


func get_slot_count() -> int:
	return TASK_SLOT_COUNT


## ---------- 私有 ----------


## 槽 view 组装（单一出数点；"预计结账 Wx/进度条/周耗/上桌/原因"同源）
func _slot_view(slot: int) -> Dictionary:
	var state: CoreEnums.ProjectState = _slot_states[slot]
	var project := get_project(slot)
	var base := {
		"slot_index": slot,
		"state": state,
		"type": _slot_type(slot),
		"title_key": "",
		"progress": 0.0,
		"weeks_left": 0,
		"eta_weeks": 0,
		"card_hours_per_week": 0,
		"seat_limit": 0,
		"assigned_staff": _slot_staff_ids[slot].duplicate(),
		"assigned_count": 0,
		"assigned_roles": {},
		"collab_kind": CollabFactor.KIND_NONE,
		"collab_factor": 1.0,
		"base_id": "",
		"checkpoint_hit": false,
		"checkpoint_progress": 0.0,
	}
	if project == null:
		return base
	base["type"] = project.get_type()
	base["title_key"] = project.get_title_key()
	base["progress"] = project.get_progress()
	base["weeks_left"] = project.get_weeks_remaining_display()
	base["eta_weeks"] = project.get_weeks_remaining_display()
	base["card_hours_per_week"] = project.get_card_hours_per_week()
	base["seat_limit"] = project.get_seat_limit()
	base["assigned_staff"] = _slot_staff_ids[slot].duplicate()
	base["assigned_count"] = _slot_staff_ids[slot].size()
	base["assigned_roles"] = _slot_assigned_roles(slot)
	base["collab_kind"] = _slot_collab_kind(slot)
	base["collab_factor"] = project.get_collab_factor()
	# 模型训练槽：基座元数据 + checkpoint 标（[P] 训练等待段"快好了"钩子
	# 数据面：50% 位置/是否已过——L3 训练卡预告同源）
	if project.get_type() == CoreEnums.ProjectType.MODEL and project is ModelProject:
		var model_view := (project as ModelProject).get_model_view()
		base["base_id"] = model_view.get("base_id", "")
		base["checkpoint_hit"] = bool(model_view.get("checkpoint_hit", false))
		base["checkpoint_progress"] = float(model_view.get("checkpoint_progress", 0.0))
	return base


## 首个空槽（无空槽返回 INVALID_SLOT_INDEX）
func _first_empty_slot() -> int:
	for slot: int in TASK_SLOT_COUNT:
		if is_slot_empty(slot):
			return slot
	return INVALID_SLOT_INDEX


## 槽号解析：越界返回 INVALID_SLOT_INDEX（防御拒绝，不抛错）
func _resolve_target_slot(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= TASK_SLOT_COUNT:
		return INVALID_SLOT_INDEX
	return slot_index


## 指派前置校验链（固定序命中即返单因——assign_staff 的 max-returns 收敛面；
## 返回 NONE=全部通过，可执行写入）
func _validate_assign(slot: int, staff_id: String) -> CoreEnums.SlotRejectReason:
	if slot == INVALID_SLOT_INDEX:
		return CoreEnums.SlotRejectReason.SLOT_OUT_OF_RANGE
	if not is_running(slot):
		return CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT
	if not is_staff_known.call(staff_id):
		return CoreEnums.SlotRejectReason.STAFF_UNKNOWN
	var reject: CoreEnums.SlotRejectReason = CoreEnums.SlotRejectReason.NONE
	for other_slot: int in TASK_SLOT_COUNT:
		if other_slot != slot and _staff_ids(other_slot).has(staff_id):
			reject = CoreEnums.SlotRejectReason.STAFF_ON_OTHER_SLOT
			break
	if reject == CoreEnums.SlotRejectReason.NONE and _staff_ids(slot).has(staff_id):
		reject = CoreEnums.SlotRejectReason.STAFF_ALREADY_ASSIGNED
	if reject == CoreEnums.SlotRejectReason.NONE and not is_staff_assignable.call(staff_id):
		reject = CoreEnums.SlotRejectReason.STAFF_NOT_ASSIGNABLE
	if reject == CoreEnums.SlotRejectReason.NONE:
		var project := get_project(slot)
		if project == null or _staff_ids(slot).size() >= project.get_seat_limit():
			reject = CoreEnums.SlotRejectReason.SEAT_LIMIT_REACHED
	return reject


func _staff_ids(slot: int) -> Array:
	return _slot_staff_ids[slot]


## 槽类型（空槽/未知=EMPTY_SLOT_TYPE=-1 哨兵，防空槽误按论文着色/入档混淆；
## 有项目=真实 enum；返回 int：-1 不在 ProjectType 值域内）
func _slot_type(slot: int) -> int:
	var project := get_project(slot)
	if project == null:
		return EMPTY_SLOT_TYPE
	return project.get_type()


## 槽上桌者岗位键表（{staff_id: role_key}；角标/组合计算同源；仅 L2 内部）
func _slot_assigned_roles(slot: int) -> Dictionary:
	var roles: Dictionary = {}
	for staff_id: Variant in _slot_staff_ids[slot]:
		roles[str(staff_id)] = get_staff_role_key.call(str(staff_id))
	return roles


## 槽协作状态单点计算（{factor: float, kind: String}）：0–1 人=1.0/none；
## 2 人=两人岗位组合（CollabFactor 表驱动）；≥3 人=取最弱配对保守下限
## （多人组合语义真源 #140/#141 收口前不发明叠乘，只保证角标可见且不超
## 单人最大组合）。未知角色/空表=防御回退 1.0（不抛错）。
func _slot_collab_state(slot: int) -> Dictionary:
	var members: Array = _slot_staff_ids[slot]
	if members.size() < 2:
		return {"factor": 1.0, "kind": CollabFactor.KIND_NONE}
	if members.size() == 2:
		var pair: Dictionary = (
			CollabFactor
			. pair_factor(
				get_staff_role_key.call(str(members[0])),
				get_staff_role_key.call(str(members[1])),
				staff_table,
			)
		)
		return {
			"factor": float(pair.get("factor", 1.0)),
			"kind": str(pair.get("kind", CollabFactor.KIND_SAME)),
		}
	# ≥3 人=最弱配对保守下限（多人语义 #140/#141 收口前不发明叠乘）；
	# 初值=首对结果再取 min/弱档（防"worst 从 1.0 起步吞掉真实对"）
	var worst_factor := 1.0
	var worst_kind := CollabFactor.KIND_SAME
	var first_pair := true
	for i: int in members.size():
		for j: int in range(i + 1, members.size()):
			var pair: Dictionary = (
				CollabFactor
				. pair_factor(
					get_staff_role_key.call(str(members[i])),
					get_staff_role_key.call(str(members[j])),
					staff_table,
				)
			)
			var factor := float(pair.get("factor", 1.0))
			var kind := str(pair.get("kind", CollabFactor.KIND_SAME))
			if first_pair:
				worst_factor = factor
				worst_kind = kind
				first_pair = false
			else:
				worst_factor = minf(worst_factor, factor)
				if _kind_rank(kind) < _kind_rank(worst_kind):
					worst_kind = kind
	return {"factor": worst_factor, "kind": worst_kind}


## 指派/撤派后重算并写入协作系数（Project.set_collab_factor 接口位写入方）；
## 返回写入值（载荷/调用方可直接取用）
func _refresh_slot_collab(slot: int) -> float:
	var project := get_project(slot)
	if project == null:
		return 1.0
	var factor := float(_slot_collab_state(slot).get("factor", 1.0))
	project.set_collab_factor(factor)
	return factor


## 槽协作分类（view/载荷呈现）：单人=none；双人起=真实组合分类（同岗=same，
## 效率 ×1.0 由详情页协同表呈现，staff-spec OP-STA-02；项目卡角标浮现条件=
## factor>1.0 由 L3 判定——同岗 ×1.0 是基准不显角标，D.2）
func _slot_collab_kind(slot: int) -> String:
	if _slot_staff_ids[slot].size() < 2:
		return CollabFactor.KIND_NONE
	return str(_slot_collab_state(slot).get("kind", CollabFactor.KIND_SAME))


## 分类档位秩（same=0 < adjacent=1 < complement=2；呈现代码与计算同源单调）
static func _kind_rank(kind: String) -> int:
	match kind:
		CollabFactor.KIND_ADJACENT:
			return 1
		CollabFactor.KIND_COMPLEMENT:
			return 2
		_:
			return 0


func _emit_changed(change: Dictionary) -> void:
	task_board_changed.emit(change)
