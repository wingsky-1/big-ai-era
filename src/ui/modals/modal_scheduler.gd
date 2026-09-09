class_name ModalScheduler
extends RefCounted
## L3 z2/z3 弹层调度（#151；ui-ux A.2「z2 决策卡先于周报（同帧按信号到达序
## 串行）」+ A.3 OP-UX-03）。弹层请求按类型优先级排队：
## 决策卡(DECISION) > 周报(REPORT) > 解锁弹卡(UNLOCK) > toast(TOAST)——
## 同帧 decision_pending 与 week_settled 并发到达时决策卡先出（决策卡阻塞世界，
## 周报在其处理完后才弹；解锁/toast 为轻量尾随）。
## 纯逻辑 RefCounted（headless 可单测）；只排"呈现序"，渲染由装配方消费
## pop_next() 结果 open 对应 PanelId；零业务计算（ADR-0016）。

enum ModalKind {
	DECISION,  # z2 决策卡（事件/危机/融资/价格战/挖人）
	REPORT,  # z2 周报自动弹（显著周）
	UNLOCK,  # z2 解锁弹卡（轻量自动收，≤3s）
	TOAST,  # z3 toast（同屏 ≤3）
}

## 呈现优先级（秩小=先出；决策先于周报=ui-ux A.2 硬序）
const KIND_PRIORITY: Dictionary = {
	ModalKind.DECISION: 0,
	ModalKind.REPORT: 1,
	ModalKind.UNLOCK: 2,
	ModalKind.TOAST: 3,
}

var _queue: Array[Dictionary] = []


## 入队（同帧信号到达序：先 push 先出同秩——FIFO 稳定）。
func push(kind: ModalKind, payload: Dictionary = {}) -> void:
	var rank := int(KIND_PRIORITY.get(kind, 99))
	var entry := {"kind": kind, "rank": rank, "payload": payload}
	var inserted := false
	for i: int in _queue.size():
		if rank < int(_queue[i]["rank"]):
			_queue.insert(i, entry)
			inserted = true
			break
	if not inserted:
		_queue.append(entry)


## 出队下一个呈现请求（按优先级；同秩=到达序 FIFO）。空=null 哨兵。
func pop_next() -> Variant:
	if _queue.is_empty():
		return null
	return _queue.pop_front()


func peek_next() -> Variant:
	if _queue.is_empty():
		return null
	return _queue[0]


func size() -> int:
	return _queue.size()


func is_empty() -> bool:
	return _queue.is_empty()
