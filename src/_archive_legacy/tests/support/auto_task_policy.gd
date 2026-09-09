class_name AutoTaskPolicy
extends RefCounted

## 测试注入用自动接任务策略（C1 后经营收入唯一来源 = 占槽任务结算）。
## 每次周结前调用 fill()，保证任务槽始终有活；用于万周确定性/性能回归。
## 优先级按"周均净收益"排序（工资 6000/周 需被覆盖，否则会破产）：
## task_grant_pilot 33000/4 周 > task_reproduce_lingxi 12000/4 周 > 纸面复现 8000/3 周。

const PRIORITY: PackedStringArray = [
	"task_grant_pilot",
	"task_reproduce_lingxi",
	"task_reproduce_paper_0",
	"task_research_basic",
]


## 任务槽为空时按优先级接一单（受资金/解锁条件约束，全部失败则空转）
func fill(world: GameWorld) -> void:
	if world == null or not world.task_queue.get_active_task().is_empty():
		return
	for task_id: String in PRIORITY:
		world.enqueue_task(task_id)
		if not world.task_queue.get_active_task().is_empty():
			return
