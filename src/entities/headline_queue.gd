class_name HeadlineQueue
extends RefCounted
## L2 金框头条并发优先级队列（#150；ui-ux B.2 金框行 + B.4「L2 金框并发优先级
## （蓝图开放问题 2 收口）」：破纪录 > 被反超 > 顶会 > 大赏 > 首出分 > 融资 >
## 满树，同帧串行，各 ≤1.5s——时长预算 ui_anim_l2_dur 由 L3 消费，本类只出序）。
## 职责：
## - enqueue(kind[, payload])：按优先级秩排序入队（同帧多条目=串行出队语义）；
## - pop_next()：取当前最高优先级条目（FIFO 同秩；文档化"破纪录最优先"）；
## - 数据面 size()/is_empty()；秩表=Kind→rank 常量（B.4 顺序真源，测试断言）。
## 硬约束：RefCounted 零 Node（headless 可单测）；"优先级顺序"=本类唯一数值
## 面（秩=常量，B.4 顺序单一真源）；零业务计算（只排序不触及玩法数值）。

## 金框头条类型（B.4 优先级表；KIND_RANK 秩=出队序）
enum Kind {
	RECORD,  # 破纪录（最高优先：数字脉冲版式）
	OUTCLASSED,  # 被反超
	TOPCONF,  # 顶会接收
	QUARTER_AWARD,  # 季度 SOTA 大赏
	FIRST_SCORE,  # 首出分命名（署名仪式版式）
	FINANCING,  # 融资到账
	FULL_TREE,  # 满树（"已登顶"）
}

## 优先级秩（B.4 顺序真源：破纪录>被反超>顶会>大赏>首出分>融资>满树；秩小=先出）
const KIND_RANK: Dictionary = {
	Kind.RECORD: 0,
	Kind.OUTCLASSED: 1,
	Kind.TOPCONF: 2,
	Kind.QUARTER_AWARD: 3,
	Kind.FIRST_SCORE: 4,
	Kind.FINANCING: 5,
	Kind.FULL_TREE: 6,
}

var _queue: Array[Dictionary] = []


## 入队（载荷=展示用 view 字典，L3 金框消费；秩插入=同帧并发即按序串行）。
func enqueue(kind: Kind, payload: Dictionary = {}) -> void:
	var rank := int(KIND_RANK.get(kind, 99))
	var entry := {"kind": kind, "rank": rank, "payload": payload}
	var inserted := false
	for i: int in _queue.size():
		if rank < int(_queue[i]["rank"]):
			_queue.insert(i, entry)
			inserted = true
			break
	if not inserted:
		_queue.append(entry)


## 出队：最高优先级条目（同秩 FIFO；空队列=null 哨兵）。
func pop_next() -> Variant:
	if _queue.is_empty():
		return null
	return _queue.pop_front()


## 下一个条目但不移出（装配方预览）。
func peek_next() -> Variant:
	if _queue.is_empty():
		return null
	return _queue[0]


func size() -> int:
	return _queue.size()


func is_empty() -> bool:
	return _queue.is_empty()
