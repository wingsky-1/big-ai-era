class_name ClockMath
extends RefCounted

## 时间步进纯函数（L0 零依赖）：刻累积与周界判定，可无头单测。
## 公式形态在此写死（v1.1 §A），节拍数值（tick_seconds/ticks_per_week）由
## 调用方从 src/data/clock.json 传入——数值不硬编码（红线 3）。
## 约定：变速系数属 View（Q2，Driver 对 Δt 预乘），本类不感知速度。


## Δt 累积：返回新累积余量与本次跨过的整刻数。
## 暂停/停喂由上层保证（delta<=0 直接零步进），本函数只做数学。
static func accumulate(accumulator: float, delta_seconds: float, tick_seconds: float) -> Dictionary:
	if delta_seconds <= 0.0 or tick_seconds <= 0.0:
		return {"accumulator": accumulator, "ticks": 0}
	var total := accumulator + delta_seconds
	var ticks := int(floor(total / tick_seconds))
	return {"accumulator": total - ticks * tick_seconds, "ticks": ticks}


## 周界判定：本周内刻数在步进前后跨过了几个整周（一次长帧可跨多周）。
static func weeks_crossed(week_ticks_before: int, ticks_gained: int, ticks_per_week: int) -> int:
	if ticks_per_week <= 0 or ticks_gained <= 0:
		return 0
	return int((week_ticks_before + ticks_gained) / ticks_per_week)


## 本周内刻数推进后的余数（跨周后取模回落）。
static func week_ticks_after(week_ticks_before: int, ticks_gained: int, ticks_per_week: int) -> int:
	if ticks_per_week <= 0:
		return week_ticks_before
	return (week_ticks_before + maxi(ticks_gained, 0)) % ticks_per_week
