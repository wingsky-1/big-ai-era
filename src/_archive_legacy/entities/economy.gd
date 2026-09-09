# gdlint:ignore = max-public-methods
## 门面/资源服务类：方法即契约面与只读数据面，数量随功能增长，故豁免该上限。
class_name Economy
extends RefCounted

## 经济系统（L2，DR-006 / DR-021 M3）：
## - apply_delta 是全游戏唯一资源过账口：任何 money/influence/compute 余量
##   变化必须经此（资源状态内聚本类，World 只读委托）。
## - 双来源收入（v0.1.0）：课题脉冲（大额低频）+复现小额（小额高频）；
##   financing/api 收支行 schema 占位（enabled:false，v0.2 接管）。
## - 职责分离：r 曲线管压迫（支出端乘子）、stage_depr 管收入衰减（复现系数
##   +课题间隔），两参独立，扰动互不影响。
## - 警告线/破产线双线判定；-200k 破产判负（Game Over 短路接线在 PR8）。
## 纯 RefCounted 可无头单测；数值全在 src/data/economy.json（红线 3）。

signal warned(amount: int)
signal compute_upgraded(new_tier: int, new_capacity: int)

enum { WARNED_NONE, WARNED_SOFT, WARNED_BANKRUPT }

const ECONOMY_PATH: String = "res://src/data/economy.json"

var money: int = 0
var influence: int = 0
var compute_tier: int = 1
var compute_hours_remaining: float = 0.0

var _config: Dictionary = {}
var _tiers: Dictionary = {}
var _reproduce_factor: float = 1.0
var _grant_interval_add_weeks: int = 0
var _stage_depr_r: float = 1.0
var _week_revenue: int = 0
var _week_expense: int = 0
var _week_influence: int = 0
## 累计获得影响力（只增不减；翻雾供给源单一真源，RK-04 / DR-031 §2.9）。
var _cum_influence: int = 0


## 注入经济参数表（economy.json；每次 start_new_game 重建）。
func setup(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_tiers = {}
	for tier_row: Dictionary in _config.get("compute_tiers", []):
		_tiers[int(tier_row.get("tier", 0))] = {
			"price": int(tier_row.get("price", 0)),
			"capacity": int(tier_row.get("capacity", 0)),
			"weekly_supply": int(tier_row.get("weekly_supply", 0)),
		}
	var stage_depr: Dictionary = _config.get("stage_depr", {})
	_reproduce_factor = float(stage_depr.get("reproduce_factor", 1.0))
	_grant_interval_add_weeks = int(stage_depr.get("grant_interval_add_weeks", 0))
	_stage_depr_r = _reproduce_factor  # r 与 stage_depr 起点同值；扰动后各自独立
	_cum_influence = 0  # 新局/读档前先归零，读档值由 GameWorld 经 set_cum_influence 注入


## ============ 唯一过账口（M3）============


## 开局基线注入（start_new_game 专用；不入周账，避免污染收支行）。
func init_resources(money_value: int, influence_value: int, tier: int, hours: float) -> void:
	money = money_value
	influence = influence_value
	compute_tier = maxi(tier, 1)
	compute_hours_remaining = hours


## 资源变动的唯一入口；非法资源/算力超容量拒绝并返回 false。
func apply_delta(resource: String, amount: int, reason: String) -> bool:
	match resource:
		"money":
			money += amount
			if amount < 0:
				_week_expense += -amount
			else:
				_week_revenue += amount
		"influence":
			influence += amount
			_week_influence += amount
			if amount > 0:
				# 累计计数器只吃正向过账（点树消耗是负向，故"点树不拖慢翻雾"）；
				# 开局基线经 init_resources 注入，不计入累计（真源 opening.json）。
				_cum_influence += amount
		"compute":
			# amount=卡时余量调整（消费传负数）；拒绝超档位容量
			if compute_hours_remaining + amount < 0.0:
				return false
			if compute_hours_remaining + amount > float(get_compute_capacity()):
				return false
			compute_hours_remaining += amount
		_:
			push_error("Economy.apply_delta: 未知资源 '%s'（reason=%s）" % [resource, reason])
			return false
	return true


## ============ 只读视图（World 快照委托用）============


func get_money() -> int:
	return money


func get_influence() -> int:
	return influence


## 累计获得影响力（只增不减；翻雾供给源，GameWorld 经此出数并写入 flags）。
func get_cum_influence() -> int:
	return _cum_influence


## 读档还原累计计数器（存档 flags.cum_influence；负值归零防脏档）。
func set_cum_influence(value: int) -> void:
	_cum_influence = maxi(0, value)


func get_compute() -> Dictionary:
	return {"tier": compute_tier, "hours_remaining": compute_hours_remaining}


func get_compute_capacity() -> int:
	var tier: Dictionary = _tiers.get(compute_tier, {})
	return int(tier.get("capacity", 0))


## 本周卡时预算（ADR-0011：周预算而非卡池余量；档位数据键 weekly_supply）
func get_compute_supply() -> int:
	var tier: Dictionary = _tiers.get(compute_tier, {})
	return int(tier.get("weekly_supply", 0))


## 周结步序 1：卡时预算重置为本周供给（不累计、不递减）
func recharge_weekly() -> void:
	compute_hours_remaining = float(get_compute_supply())


func get_week_ledger() -> Dictionary:
	return {
		"income": _week_revenue,
		"expense": _week_expense,
		"net": _week_revenue - _week_expense,
		"influence_delta": _week_influence,
	}


## 双线判定：0=正常 1=警告线（提示） 2=破产线（判负）。
func check_lines() -> int:
	var warn_variant: Variant = DataLoader.require_key(_config, "warn_line", ECONOMY_PATH)
	var bankrupt_variant: Variant = DataLoader.require_key(_config, "bankruptcy_line", ECONOMY_PATH)
	if warn_variant == null or bankrupt_variant == null:
		return WARNED_NONE
	var warn_line := int(warn_variant)
	var bankruptcy_line := int(bankrupt_variant)
	if money <= bankruptcy_line:
		return WARNED_BANKRUPT
	if money <= warn_line:
		return WARNED_SOFT
	return WARNED_NONE


## ============ 周结管线（settle 步序 1 收支）============


## 周结固定支出（工资 × 在册人数 + 固定运维），经 apply_delta 过账。
## 经营收入改由"占槽任务结算"在 GameWorld 侧过账（DR-031/C1：脉冲源退役）。
func accrue_fixed_expense(headcount: int) -> void:
	var fixed: Dictionary = get_weekly_fixed_expense(headcount)
	var wage: int = int(fixed.get("wage", 0))
	var upkeep: int = int(fixed.get("upkeep", 0))
	if wage != 0:
		apply_delta("money", -wage, "wage")
	if upkeep != 0:
		apply_delta("money", -upkeep, "upkeep")


## 每周固定支出分解（工资 + 固定运维，真源 economy.json）；
## 周结扣款与"下周净流入预告"共用此口径（防两处漂移，DR-031/C3）。
func get_weekly_fixed_expense(headcount: int) -> Dictionary:
	var wage_variant: Variant = DataLoader.require_key(_config, "wage_per_staff", ECONOMY_PATH)
	var wage: int = int(wage_variant) * headcount if wage_variant != null else 0
	var upkeep_variant: Variant = DataLoader.require_key(_config, "upkeep_weekly", ECONOMY_PATH)
	var upkeep: int = int(upkeep_variant) if upkeep_variant != null else 0
	return {"wage": wage, "upkeep": upkeep, "total": wage + upkeep}


## 账期翻页（ADR-0015 账期契约）：周结步序 1–2 结束后重置周账，
## 此后发生的非周结过账（买卡/研究/入队/事件）计入**下一个未结算周**。
func reset_week_ledger() -> void:
	_week_revenue = 0
	_week_expense = 0
	_week_influence = 0


## 软警告广播（破产线短路由 GameWorld 步序 2 处理）
func emit_week_warning(ledger: Dictionary) -> void:
	if check_lines() == WARNED_SOFT:
		warned.emit(int(ledger.get("net", 0)))


## 买卡只读视图（UI 按钮三态：下一档价格 / 可否购买 / 原因）
func get_upgrade_view() -> Dictionary:
	var next_tier: int = compute_tier + 1
	var tier: Dictionary = _tiers.get(next_tier, {})
	if tier.is_empty():
		return {"available": false, "next_tier": 0, "price": 0, "reason": "max_tier"}
	var price := int(tier.get("price", 0))
	if money < price:
		return {
			"available": false,
			"next_tier": next_tier,
			"price": price,
			"reason": "insufficient_money",
		}
	return {"available": true, "next_tier": next_tier, "price": price, "reason": ""}


## 算力升档（买卡）：价格从资金扣（经 apply_delta），本周预算重置为新档供给。
## capacity 仅作 apply_delta("compute") 的上限校验（ADR-0011）。
func upgrade_compute(target_tier: int) -> bool:
	var tier: Dictionary = _tiers.get(target_tier, {})
	if tier.is_empty() or target_tier <= compute_tier:
		return false
	var price := int(tier.get("price", 0))
	if money < price or not apply_delta("money", -price, "compute_upgrade"):
		return false
	compute_tier = target_tier
	compute_hours_remaining = float(get_compute_supply())
	compute_upgraded.emit(target_tier, get_compute_capacity())
	return true


## ============ 内部 ============


## r 曲线与 stage_depr 独立扰动（EC4 职责分离测试锚点；数值校准归 PR10 前收口）。
func set_stage_depr(reproduce_factor: float, grant_interval_add_weeks: int) -> void:
	_reproduce_factor = reproduce_factor
	_grant_interval_add_weeks = grant_interval_add_weeks


func set_r_curve(r: float) -> void:
	_stage_depr_r = r


func get_stage_depr_params() -> Dictionary:
	return {
		"reproduce_factor": _reproduce_factor, "grant_interval_add_weeks": _grant_interval_add_weeks
	}


func get_r_curve() -> float:
	return _stage_depr_r


## 训练折价（卡时×单价）：返回本周训练成本，调用方过账。
func training_cost(hours: int) -> int:
	var unit_variant: Variant = DataLoader.require_key(
		_config, "training_cost_per_compute_hour", ECONOMY_PATH
	)
	if unit_variant == null:
		return 0
	return hours * int(unit_variant)
