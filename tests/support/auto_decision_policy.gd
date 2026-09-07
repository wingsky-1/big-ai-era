class_name AutoDecisionPolicy
extends RefCounted

## 测试注入用自动决策策略（GW3）：总是选第一个选项（idx=0）。
## simulate_weeks(policy=self) 时同帧应答决策卡，不阻塞模拟。


func pick(_card: Dictionary, options: Array) -> int:
	return 0 if not options.is_empty() else -1
