class_name L3Budget
extends RefCounted
## L3 全屏动画预算（#150；ui-ux B.4「L3 全屏：一局 ≤3 次」——两次晋升（4→8/8→12）
## +终局（IPO/破产结算页），恒 3 硬断言；ui_anim_l3_count 镜像常量）。
## 装配方（L3 仪式/终局面板）在申请全屏动画前调 request()，拒绝=超预算（截断/
## 降级）；单局计数不清零（跨周累计）。
## 纯逻辑 RefCounted（headless 可单测）；零业务计算。

## L3 全屏次数上限（=ui.json ui_anim_l3_count 3；镜像常量，GUT 断言镜像=表值）
const L3_CAP: int = 3

var _used: int = 0


## 申请一次 L3 全屏：预算内=计入并返回 true；超限=拒绝（硬断言护栏）。
func request() -> bool:
	if _used >= L3_CAP:
		return false
	_used += 1
	return true


func get_used() -> int:
	return _used


func get_cap() -> int:
	return L3_CAP
