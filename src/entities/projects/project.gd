class_name Project
extends RefCounted
## L2 任务槽项目抽象基类（#131）：论文/训练/算力三类共用的统一接口面。
## 硬约束（任务书/architecture-100 §4.1/ADR-0018/§8）：
## - RefCounted、零 Node/SceneTree 依赖（headless 可单测）；abstract 语义：
##   直接 new Project=构造失败（push_error + 状态置 INVALID），子类才可实例化；
## - 数据：project_type（enum，禁字符串）/标题键（texts.json 键引用，值不落本层）/
##   工期（周定值）/进度（周内刻级，周结推进）/剩余周/周耗卡时/上桌上限/
##   状态（IN_PROGRESS→FINISHED_PENDING）；协作系数=接口位（#132 由 TaskBoard
##   按槽成员组合计算后注入写入，本层不发明算法）；
## - 统一钩子：week_tick()（由 TaskBoard 周结驱动，逐槽调用）→ 子类覆写
##   _on_week_tick（训练=推进 checkpoint；论文=推进；算力 P2=推进）+ 子类声明的
##   _on_finished() → 产出结算声明对象（本批子类=最小构造桩，声明体不落——真源
##   architecture-100 §4.3/ADR-0020：#135 Settlement 按型路由唯一过账）；
## - 工期/周耗为构造注入参数（论文表 #133/训练表 #140 尚未建，本批子类构造传入，
##   注释注明后续批替换为表驱动读取；上桌上限同样构造传入，不读不存在的表）；
## - 数值禁硬编码（本类零数值常量，工期/周耗/上限全部构造注入）；
## - 数据面 get_project_view() 只读深拷贝；进度=周内刻级单调不倒退、完成即冻结。
## #132 协作加速语义：周推进=工作量当量（float）驱动——week_tick 每 tick 扣
##   collab_factor 当量工作量；同岗 1.0 时与原整周语义逐位一致（factor=1.0 ⇔
##   每周恰 1 单位）。多人协作（互补 ×1.18/相邻 ×1.08）→ 周内工作量 >1 → 剩余周
##   数可见缩短（"两人一起做快 1 天"体感，staff-spec A.5）。显示剩余周=当量
##   ceil 派生（get_weeks_remaining 语义="保守承诺剩余周"；week_tick 完成判定=
##   当量 ≤0 冻结完成，见 _tick_work_units）。系数写入方=TaskBoard（按槽成员
##   组合经 CollabFactor 表驱动计算后调 set_collab_factor；本类不发明算法）。
## 双向引用纪律：本类不反向持有 TaskBoard/员工对象，上桌员工=字符串 id 列表由
## TaskBoard 持有（本类不存），无 weakref 需求（引用单向无环）。

const MIN_DURATION_WEEKS: int = 1

## 状态值=enum（硬约束 3）；构造入口校验用，非持久字段
var _status_valid: bool = false
var _project_type: CoreEnums.ProjectType = CoreEnums.ProjectType.PAPER
var _title_key: String = ""
var _duration_weeks: int = 0
var _card_hours_per_week: int = 0
var _seat_limit: int = 0
var _progress: float = 0.0
var _weeks_remaining: int = 0
## 剩余工作量当量（float；#132 协作加速载体：collab_factor>1 → 每周扣 >1 当量 →
## 实际剩余周 < 表定剩余周）。非持久字段，由 _initialize 按工期复位。
var _work_units_remaining: float = 0.0
var _collab_factor: float = 1.0
var _state: CoreEnums.ProjectState = CoreEnums.ProjectState.IN_PROGRESS
var _on_table_staff_ids: Array[String] = []


func _init() -> void:
	# 抽象基类禁直接实例化：子类 _init 末尾须调 _initialize()（伪 abstract 语义）。
	# 直接 new Project → push_error，Error Tracker 立即使调用方测试失败（防线）。
	push_error("Project: 抽象基类不可直接实例化（子类经 _initialize() 初始化）")
	_status_valid = false


## 子类 _init 末尾统一初始化入口（本方法=唯一合法落值路径；参数=构造注入
## 数据：工期/周耗/上限等。论文表 #133/训练表 #140 建后改为各子类读表，
## 本方法形状不变——仅调用方从"测试传参"变为"子类读表传参"）。
func _initialize(
	project_type: CoreEnums.ProjectType,
	title_key: String,
	duration_weeks: int,
	card_hours_per_week: int,
	seat_limit: int,
) -> void:
	_project_type = project_type
	_title_key = title_key
	_duration_weeks = duration_weeks
	_card_hours_per_week = card_hours_per_week
	_seat_limit = seat_limit
	_weeks_remaining = duration_weeks
	_work_units_remaining = float(duration_weeks)
	_progress = 0.0
	_collab_factor = 1.0
	_state = CoreEnums.ProjectState.IN_PROGRESS
	_status_valid = true
	if _duration_weeks < MIN_DURATION_WEEKS or _seat_limit < 1:
		push_error("Project: 非法工期/上桌上限（duration=%d seat_limit=%d）" % [_duration_weeks, _seat_limit])
		_status_valid = false


## ---------- 统一推进钩子（TaskBoard 周结驱动；final 语义=生命周期唯一推进口） ----------


## 周结推进一次（架构 §5.3 phase 2：for slot in TaskBoard: project.week_tick()）。
## final 语义：TaskBoard 依赖"推进/完成判定"确定性，子类不得覆写本方法，
## 只可覆写 _on_week_tick（每类各自的"推进"内幕）。
## #132 协作当量推进：先扣剩余周（_weeks_remaining -= 1）再按协作系数折算
## 当量（_tick_work_units：协作 >1.0 → 周内工作量 >1，扣到 0 即提前完成——
## "两人一起做快 1 天"），随后子类 _on_week_tick 读扣减后的剩余周/进度。
## 返回 false=不可推进（非法实例/已完成——已完成项目不再推进，等 #135 消费）。
func week_tick() -> bool:
	if not is_running():
		return false
	_weeks_remaining -= 1
	_tick_work_units()
	_on_week_tick()
	if _work_units_remaining <= 0.0:
		_weeks_remaining = 0
		_work_units_remaining = 0.0
		_progress = 1.0
		_state = CoreEnums.ProjectState.FINISHED_PENDING
	return true


## 子类覆写点：每类的推进内幕（论文=推进；训练=推进+checkpoint；算力 P2=推进）。
func _on_week_tick() -> void:
	push_error("Project: 子类未实现 _on_week_tick()")


## 产出结算声明（架构 §4.3/ADR-0020：项目完成不发资源，产出声明交给
## Settlement #135 按型路由唯一过账）。本批仅挂接口形状：
## 声明体（入谱/RP/出分/入账细则）随各子类真实落地批（#133/#140）实现——
## 本方法在子类完成状态可调用期由 TaskBoard 产出，未实现返回空 dict。
func produce_settlement_declaration() -> Dictionary:
	return {}


## ---------- 状态/谓词（只读） ----------


## 项目是否运行中（IN_PROGRESS）。is_running=false = 未初始化/已完成。
func is_running() -> bool:
	return _status_valid and _state == CoreEnums.ProjectState.IN_PROGRESS


func is_finished_pending() -> bool:
	return _status_valid and _state == CoreEnums.ProjectState.FINISHED_PENDING


## ---------- 数据面（只读、深拷贝；L3 经 TaskBoard.get_task_view 聚合，不直取） ----------


## 项目视图（TaskBoard 槽 view 的项目侧构成；枚举直出+键位同出：键位给
## L3/存档做稳定标识（槽 type 入档=稳定字符串，architecture §9.1）。
func get_project_view() -> Dictionary:
	return {
		"project_type": _project_type,
		"type_key": type_to_key(_project_type),
		"title_key": _title_key,
		"duration_weeks": _duration_weeks,
		"card_hours_per_week": _card_hours_per_week,
		"seat_limit": _seat_limit,
		"progress": _progress,
		"weeks_remaining": _weeks_remaining,
		"collab_factor": _collab_factor,
		"state": _state,
	}


## ---------- 类型/读值（L2 内部装配/推进用；视图已含全部，防散取） ----------


func get_type() -> CoreEnums.ProjectType:
	return _project_type


## 标题文案键（texts.json 键引用；L3 经 TextService 取句；空键=子类未提供标题）
func get_title_key() -> String:
	return _title_key


func get_duration_weeks() -> int:
	return _duration_weeks


func get_weeks_remaining() -> int:
	return _weeks_remaining


## 显示剩余周（视图"保守承诺"值；#132 起由当量 ceil 派生，见 _tick_work_units）
func get_weeks_remaining_display() -> int:
	return int(ceilf(maxf(_work_units_remaining, 0.0)))


func get_card_hours_per_week() -> int:
	return _card_hours_per_week


## 上桌上限（本槽项目声明；上桌人数校验/协作人数判定在 TaskBoard #131/#132）
func get_seat_limit() -> int:
	return _seat_limit


func get_progress() -> float:
	return _progress


## 协作系数接口位（#132 由 TaskBoard 按槽成员组合计算后调用写入；本层默认 1.0）
func set_collab_factor(factor: float) -> void:
	if not is_finite(factor) or factor < 0.0:
		push_error("Project: 协作系数非法（factor=%s，须有限且 ≥0）" % str(factor))
		return
	_collab_factor = factor


func get_collab_factor() -> float:
	return _collab_factor


## 预计结账周（数据面核心：当前进度下的到达周；在跑=按当前当量保守周乐观预判，
## 墙钟表现=Wx 常显同源。completed=view 的 weeks_left=0）
func get_eta_weeks() -> int:
	if not is_running():
		return 0
	return _weeks_remaining


## ---------- 私有 ----------


## 当量推进（#132 协作乘数应用点）：每 tick 扣 1 当量 × 协作系数。
## 协作系数=1.0（同岗/单人）→ 每 tick 恰扣 1.0，与整周推进语义逐位一致；
## 协作系数 >1.0 → 当量提前耗尽（可能中途越过 0），完成周冻结由 week_tick
## 收口。显示剩余周（视图 ceil 派生）与实际完成周解耦：factor>1 时显示
## 剩余周比 _weeks_remaining 少——"两人一起做快 1 天"的体感可见来源。
func _tick_work_units() -> void:
	_work_units_remaining -= maxf(_collab_factor, 0.0)


## enum→表内稳定字符串的唯一集中映射（单向；跨模块字典同源派生防线，
## architecture-100 §9.1：槽 type 入档=稳定字符串，代码侧 enum 映射单向）。
static func type_to_key(project_type: CoreEnums.ProjectType) -> String:
	match project_type:
		CoreEnums.ProjectType.MODEL:
			return "model"
		CoreEnums.ProjectType.COMPUTE:
			return "compute"
		_:
			return "paper"
