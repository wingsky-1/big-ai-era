class_name PanelStack
extends RefCounted
## L3 弹窗栈逻辑（#145；ui-ux-spec A.2 PanelStack z0–z3 + architecture
## §2.1 panel_stack.gd + A8 逐批登记）。纯逻辑 RefCounted（headless 可单测）：
## 渲染层（Control 实例挂载/显隐）由装配方/后续面板批接——本类管"栈语义"。
## 职责：
## - **注册表**：PanelId 全量（ui-ux A.2 z1 已登记面板 + z2 弹层 + z3 通知），
##   每 PanelId 声明层级（z0/z1/z2/z3）→ 层级合法性（z0<z1<z2<z3）表驱动断言；
## - **Dock 三键冻结**：任务板/科技树/暂停=PanelId 常量三键（ui-ux A.2 注册
##   纪律：增键=变更控制标志位 DOCK_KEYS_FROZEN）；
## - **栈操作**：open(panel)（按层级规则：z2 阻塞=遮罩点击不关闭；z1=轻遮罩
##   可点外关闭）/close(panel)/back()（返回上一面板）/顶层查询；
## - z2 自动暂停语义：z2 阻塞面板在位=世界等待（settlement z2_blocked 谓词
##   装配读本栈 has_blocking_top）。
## 硬约束：L3 禁 import L2/L4（架构 §3）；零业务计算（ADR-0016）；本类只
## 依赖 L0（无 Node）。数值零硬编码（层级=数据声明）。

## PanelId 注册表（ui-ux-spec A.2 全量冻结；z1 面板实体逐批落地=enum 先注册
## 契约，面板场景/控件后批建——A8：空壳面板=死代码，故未落地面板不建实例）
enum PanelId {
	## z0 主台常显层（四主区/目标卡带/预警横幅/资源栏/Dock）——注册表含
	## z0 便于层级合法性全序断言（z0 不入栈操作）
	MAIN_STAGE,
	## z1 内容面板（轻遮罩可点外关闭）
	TASK_BOARD,
	TECH_TREE,
	STAFF_DETAIL,
	PAPER_ARCHIVE,
	MODEL_LIBRARY,
	CHIP_YARD,
	RELIEF_MARKET,
	RIVAL_CURVE,
	REPORT_ARCHIVE,
	PAUSE_MENU,
	TARGET_CARD,
	## z2 阻塞弹层（遮罩点击不关闭）
	DECISION_CARD,
	WEEKLY_REPORT,
	NAMING_DIALOG,
	## z3 通知层（toast；无遮罩同屏 ≤3——计数归 #149 批）
	TOAST,
}

## Dock 三键冻结（ui-ux A.2 注册纪律：任务板/科技树/暂停；增键=改 DOCK_KEYS
## + 变更控制流程，测试断言三键精确集合）
const DOCK_KEYS_FROZEN: bool = true
const DOCK_KEYS: Array[PanelId] = [PanelId.TASK_BOARD, PanelId.TECH_TREE, PanelId.PAUSE_MENU]

## 面板→层级映射（真源=ui-ux A.2 表；z0/z1/z2/z3 次序=层级合法性断言基准）
const PANEL_Z: Dictionary = {
	PanelId.MAIN_STAGE: 0,
	PanelId.TASK_BOARD: 1,
	PanelId.TECH_TREE: 1,
	PanelId.STAFF_DETAIL: 1,
	PanelId.PAPER_ARCHIVE: 1,
	PanelId.MODEL_LIBRARY: 1,
	PanelId.CHIP_YARD: 1,
	PanelId.RELIEF_MARKET: 1,
	PanelId.RIVAL_CURVE: 1,
	PanelId.REPORT_ARCHIVE: 1,
	PanelId.PAUSE_MENU: 1,
	PanelId.TARGET_CARD: 1,
	PanelId.DECISION_CARD: 2,
	PanelId.WEEKLY_REPORT: 2,
	PanelId.NAMING_DIALOG: 2,
	PanelId.TOAST: 3,
}

## 面板是否已落地实例（A8 逐批登记：enum 注册≠实例存在；本表随面板批增量
## 置 true——未落地面板 open=防御拒绝，防死代码空壳）
const PANEL_IMPLEMENTED: Dictionary = {}

var _open_stack: Array[PanelId] = []
var _panels: Dictionary = {}  # PanelId → 面板数据（装配方挂渲染句柄；空=未实例）

## ---------- 注册表查询（只读） ----------


static func z_of(panel: PanelId) -> int:
	return int(PANEL_Z.get(panel, -1))


static func is_registered(panel: PanelId) -> bool:
	return PANEL_Z.has(panel)


## 全 z1 面板（注册表完整性断言基准；ui-ux A.2 z1 行）
static func all_z1_panels() -> Array[PanelId]:
	return [
		PanelId.TASK_BOARD,
		PanelId.TECH_TREE,
		PanelId.STAFF_DETAIL,
		PanelId.PAPER_ARCHIVE,
		PanelId.MODEL_LIBRARY,
		PanelId.CHIP_YARD,
		PanelId.RELIEF_MARKET,
		PanelId.RIVAL_CURVE,
		PanelId.REPORT_ARCHIVE,
		PanelId.PAUSE_MENU,
		PanelId.TARGET_CARD,
	]


## ---------- 栈操作（装配方/面板批调用） ----------


## 打开面板：层级入栈语义——同层互斥（新开同层=旧同层先关）；z2 阻塞置顶
## 后新 z1 不可开（阻塞世界等待）；返回 {ok, reason}。
func open(panel: PanelId) -> Dictionary:
	if not is_registered(panel):
		return {"ok": false, "reason": "unregistered"}
	if panel == PanelId.MAIN_STAGE or panel == PanelId.TOAST:
		return {"ok": false, "reason": "not_stackable"}
	# z2 阻塞在位：仅允许 z2/z3 操作（z1 被压——决策等待中世界停）
	if has_blocking_top() and z_of(panel) < 2:
		return {"ok": false, "reason": "blocked_by_z2"}
	var z := z_of(panel)
	# 同层互斥：移除已在栈的同层面板（z1 开新关旧；z2 同层也互斥）
	for i: int in range(_open_stack.size() - 1, -1, -1):
		if z_of(_open_stack[i]) == z:
			_open_stack.remove_at(i)
	_open_stack.append(panel)
	return {"ok": true, "reason": ""}


## 关闭指定面板（z1 轻遮罩点外关闭/z2 决策后关闭/返回键）。未开=防御 ok。
func close(panel: PanelId) -> bool:
	var idx := _open_stack.find(panel)
	if idx == -1:
		return false
	_open_stack.remove_at(idx)
	return true


## 返回上一面板（关闭顶层；z1 返回键 / z2 决策卡关闭语义）。无=空操作。
func back() -> bool:
	if _open_stack.is_empty():
		return false
	_open_stack.pop_back()
	return true


## ---------- 数据面（只读） ----------


func is_open(panel: PanelId) -> bool:
	return _open_stack.has(panel)


func top() -> PanelId:
	if _open_stack.is_empty():
		return PanelId.MAIN_STAGE
	return _open_stack.back()


func get_open_stack() -> Array[PanelId]:
	return _open_stack.duplicate()


## 是否有 z2 阻塞顶层（z2 自动暂停/settlement z2_blocked 谓词装配读）
func has_blocking_top() -> bool:
	if _open_stack.is_empty():
		return false
	return z_of(_open_stack.back()) >= 2


## 渲染面板数据挂载/取回（装配方存 Control 句柄等；本类不实例化）
func mount(panel: PanelId, data: Variant) -> void:
	_panels[panel] = data


func get_mounted(panel: PanelId) -> Variant:
	return _panels.get(panel, null)
