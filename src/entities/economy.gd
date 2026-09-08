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


## 注入经济参数表（economy.json；每次 start_new_game 重建）。
func setup(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_tiers = {}
	for tier_row: Dictionary in _config.get("compute_tiers", []):
		_tiers[int(tier_row.get("tier", 0))] = {
			"price": int(tier_row.get("price", 0)),
			"capacity": int(tier_row.get("capacity", 0)),
		}
	var stage_depr: Dictionary = _config.get("stage_depr", {})
	_reproduce_factor = float(stage_depr.get("reproduce_factor", 1.0))
	_grant_interval_add_weeks = int(stage_depr.get("grant_interval_add_weeks", 0))
	_stage_depr_r = _reproduce_factor  # r 与 stage_depr 起点同值；扰动后各自独立


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


func get_compute() -> Dictionary:
	return {"tier": compute_tier, "hours_remaining": compute_hours_remaining}


func get_compute_capacity() -> int:
	var tier: Dictionary = _tiers.get(compute_tier, {})
	return int(tier.get("capacity", 0))


func get_week_ledger() -> Dictionary:
	return {"income": _week_revenue, "expense": _week_expense, "net": _week_revenue - _week_expense}


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


## 周收支聚合：固定支出（工资×人数+ upkeep）+ 双来源脉冲收入期望占位，
## 全部经 apply_delta 过账。随机收入由注入的随机源提供（World 按 seed 播种；
## PR7 换 rng_stream 零重构）。返回周报收支行。
func accrue_week(headcount: int, random_source: Object) -> Dictionary:
	_week_revenue = 0
	_week_expense = 0
	var wage := int(_config.get("wage_per_staff", 0)) * headcount
	if wage != 0:
		apply_delta("money", -wage, "wage")
	if _source_enabled("reproduce"):
		var amount := _roll_income(random_source, _config.get("reproduce", {}))
		amount = int(round(amount * _reproduce_factor))
		if amount > 0:
			apply_delta("money", amount, "reproduce")
	if _source_enabled("grant"):
		var amount_grant := _roll_income(random_source, _config.get("grant", {}))
		if amount_grant > 0:
			apply_delta("money", amount_grant, "grant")
	var ledger := get_week_ledger()
	var line_state := check_lines()
	if line_state == WARNED_SOFT:
		warned.emit(ledger["net"])
	return ledger


## 算力升档（买卡）：价格从资金扣（经 apply_delta），余量补到新档容量。
func upgrade_compute(target_tier: int) -> bool:
	var tier: Dictionary = _tiers.get(target_tier, {})
	if tier.is_empty() or target_tier <= compute_tier:
		return false
	var price := int(tier.get("price", 0))
	if money < price or not apply_delta("money", -price, "compute_upgrade"):
		return false
	compute_tier = target_tier
	compute_hours_remaining = float(get_compute_capacity())
	compute_upgraded.emit(target_tier, get_compute_capacity())
	return true


## ============ 内部 ============


func _source_enabled(name_string: String) -> bool:
	var sources: Dictionary = _config.get("sources", {})
	var source: Dictionary = sources.get(name_string, {})
	return bool(source.get("enabled", false))


## 收入脉冲 roll：amount/duration 均匀抽样（占位随机源经 random_source.randi()）。
func _roll_income(random_source: Object, spec: Variant) -> int:
	if not (spec is Dictionary):
		return 0
	var spec_dict: Dictionary = spec
	var low := int(spec_dict.get("amount_min", 0))
	var high := int(spec_dict.get("amount_max", 0))
	if high <= low or random_source == null or not random_source.has_method("randi_in_range"):
		return 0
	return random_source.call("randi_in_range", low, high)


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
