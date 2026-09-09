class_name Relief
extends RefCounted
## L2 救济三件套（#136 最小）：贷款（宽限/分期/减息）+ 设备出售（折价）+
## 接私活（限次递减）。范围：economy-spec A.1 OP-ECO-02 + D.2 键名表。
## - 贷款：宽限期>0 内零还款；分期数表驱动；提前还清减息 50%；未还清不可再借；
##   一切资金过 Ledger（唯一过账口，#135 继承）。
## - 出售：折价率表驱动（≤65% 护栏）；T0 不可售（初始档无残值）；
##   可售设备查询=注入谓词（#139 chips 落位接真实持有档位）。
## - 私活：全局限次+冷却 6 周+收入递减 ×0.8/次（economy-spec：摆烂会死）。
## - 救济可用性（Settlement phase 5 破产判定的 relief_available 真源）：
##   有任一救济可用=未破产（可再借=贷款已清且未超限借次？否——救济可用性=
##   现金可补（贷款未借满 OR 私活余次>0 OR 有可售设备）。本类出
##   get_relief_available() 谓词，Settlement 装配接线。
## RefCounted 零 Node；数值全读 economy.json（代码零硬编码）。

const ECONOMY_PATH: String = "res://src/data/economy.json"

## 可售设备查询谓词（注入；#139 chips 前默认无可售=t0 不可售语义）
var sellable_assets: Callable = func() -> Array[String]: return []

## 资产价值查询谓词注入（#139 chips 表建后由装配方提供真实价格）
var asset_value: Callable = func(_tier_key: String) -> int: return 0

var _ledger: Ledger = null
var _table: Dictionary = {}

## 贷款状态
var _loan_active: bool = false
var _loan_principal: int = 0
var _loan_grace_left: int = 0
var _loan_periods_left: int = 0
var _loan_weeks_since_take: int = 0
## 私活状态
var _jobs_done: int = 0
var _job_cooldown_left: int = 0


func _init(ledger: Ledger) -> void:
	_ledger = ledger
	_table = DataLoader.load_json(ECONOMY_PATH)


## ---------- 贷款 ----------


## 贷款护栏（economy-spec D.2）：
## - 额度上限 eco_loan_cap（≤现金警告线×3 且 ≤净资产×0.5——#135 表内护栏值）
## - 宽限期>0（eco_loan_grace 2 周内零还款）
## - 分期 eco_loan_terms（每期还款 ≤ 周收入中位 ×0.3——本批按注入周收入校验）
## - 年化 eco_loan_apr（提前还清减息 50%）
## - 未还清不可再借（防循环套）
func take_loan(weekly_income: int = 0) -> Dictionary:
	if _loan_active:
		return {"ok": false, "reason": "loan_pending"}
	var cap := int(_table.get("eco_loan_cap", 0))
	var terms := int(_table.get("eco_loan_terms", 8))
	var grace := int(_table.get("eco_loan_grace", 2))
	# 还款护栏：每期 ≤ 周收入中位 ×0.3（收入不足=额度受限）
	var apr := float(_table.get("eco_loan_apr", 0.08))
	var max_by_income := 0
	if weekly_income > 0:
		max_by_income = int(float(weekly_income) * 0.3 * float(terms))
	if max_by_income > 0 and cap > max_by_income:
		cap = max_by_income
	if cap <= 0:
		return {"ok": false, "reason": "no_capacity"}
	_loan_active = true
	_loan_principal = cap
	_loan_grace_left = grace
	_loan_periods_left = terms
	_loan_weeks_since_take = 0
	# 到账过账（贷款=收入类；负债绑定=principal 记负资产口径由破产结算用）
	if _ledger != null:
		_ledger.record(Ledger.Category.INCOME_LOAN, cap, "loan_take")
	return {
		"ok": true,
		"amount": cap,
		"grace": grace,
		"terms": terms,
		"apr": apr,
	}


## 周结推进（Settlement phase 3 后调用）：宽限结束开始分期还款。
## 返回本周围绕贷款的行（{} = 无还款）。
func week_tick(_weekly_income: int = 0) -> Dictionary:
	if not _loan_active:
		return {}
	_loan_weeks_since_take += 1
	if _loan_grace_left > 0:
		_loan_grace_left -= 1
		return {}
	# 分期还款（每期=本金/期数；余额不足=还剩余额清零）
	var per_period := int(ceilf(float(_loan_principal) / float(_loan_periods_left)))
	var pay := mini(per_period, _loan_principal)
	_loan_principal -= pay
	_loan_periods_left -= 1
	if _ledger != null:
		_ledger.record(Ledger.Category.EXPENSE_LOAN, -pay, "loan_repay")
	if _loan_periods_left <= 0 or _loan_principal <= 0:
		_loan_active = false
		_loan_principal = 0
	return {"repay": pay, "paid_off": not _loan_active}


## 提前还清（减息 50%：未还本金×[1-减息比例]？不——减息=剩余应付利息减免；
## 最小实现：提前还清=还剩余本金×50% 折扣（eco_loan_early_payoff_discount））
func pay_off_early() -> Dictionary:
	if not _loan_active:
		return {"ok": false, "reason": "no_loan"}
	var discount := float(_table.get("eco_loan_early_payoff_discount", 0.5))
	var payoff := int(roundf(float(_loan_principal) * (1.0 - discount)))
	if _ledger != null:
		_ledger.record(Ledger.Category.EXPENSE_LOAN, -payoff, "loan_payoff")
	_loan_active = false
	_loan_principal = 0
	_loan_periods_left = 0
	return {"ok": true, "paid": payoff}


## ---------- 设备出售 ----------


## 出售持有设备（折价率表驱动；T0 不可售——注入查询不含 t0）。
## tier_key 须在 sellable_assets() 返回列表内（#139 chips 接真实持有）。
func sell_asset(tier_key: String) -> Dictionary:
	var assets := sellable_assets.call() as Array
	if tier_key not in assets:
		return {"ok": false, "reason": "not_sellable"}
	var rate := float(_table.get("eco_sell_back_rate", 0.6))
	# 出售金额=该档位购买价×折价率——#139 chips 表建前用注入价格查询
	# （本批最小：sellable_assets 返回 [tier_key, price] 元组扩展？不——
	# 简化：价格查询谓词注入 asset_value(tier)->int；无注入=按 t1 基准占位 0）
	var value := int(asset_value.call(tier_key))
	if value <= 0:
		return {"ok": false, "reason": "no_value"}
	var proceeds := int(roundf(float(value) * rate))
	if _ledger != null:
		_ledger.record(Ledger.Category.INCOME_OTHER, proceeds, "sell_%s" % tier_key)
	return {"ok": true, "proceeds": proceeds}


## ---------- 私活 ----------


## 接私活（全局限次 eco_job_total_limit + 冷却 + 收入递减 ×0.8/次）
func take_job() -> Dictionary:
	var total_limit := int(_table.get("eco_job_total_limit", 3))
	var reward := int(_table.get("eco_job_reward", 0))
	var decay := float(_table.get("eco_job_decay", 0.8))
	if _jobs_done >= total_limit:
		return {"ok": false, "reason": "job_limit_reached"}
	if _job_cooldown_left > 0:
		return {"ok": false, "reason": "job_cooldown"}
	# 收入递减：第 n 次 = reward × decay^(n-1)
	var income := int(roundf(float(reward) * pow(decay, float(_jobs_done))))
	_jobs_done += 1
	_job_cooldown_left = int(_table.get("eco_job_cooldown", 6))
	if _ledger != null:
		_ledger.record(Ledger.Category.INCOME_JOB, income, "job_%d" % _jobs_done)
	return {"ok": true, "income": income, "jobs_done": _jobs_done}


## 周结推进冷却（Settlement 周结调；与贷款 week_tick 同入口）
func tick_cooldowns() -> void:
	if _job_cooldown_left > 0:
		_job_cooldown_left -= 1


## ---------- 救济可用性（Settlement phase 5 接线） ----------


## 有任一救济可用=不破产：贷款可再借（未 active）OR 私活余次>0 且非冷却 OR
## 有可售设备。冷却中私活不算可用（防"每周 1 私活"无限续命——G8 摆烂会死）。
func get_relief_available() -> bool:
	var total_limit := int(_table.get("eco_job_total_limit", 3))
	if not _loan_active:
		return true
	if _jobs_done < total_limit and _job_cooldown_left <= 0:
		return true
	if not (sellable_assets.call() as Array).is_empty():
		return true
	return false


## ---------- 数据面（只读） ----------


func is_loan_active() -> bool:
	return _loan_active


func get_loan_principal() -> int:
	return _loan_principal


func get_loan_grace_left() -> int:
	return _loan_grace_left


func get_jobs_done() -> int:
	return _jobs_done


func get_job_cooldown_left() -> int:
	return _job_cooldown_left


func get_loan_state_view() -> Dictionary:
	return {
		"active": _loan_active,
		"principal": _loan_principal,
		"grace_left": _loan_grace_left,
		"periods_left": _loan_periods_left,
		"weeks_since_take": _loan_weeks_since_take,
	}


func get_job_state_view() -> Dictionary:
	return {
		"done": _jobs_done,
		"cooldown_left": _job_cooldown_left,
		"limit": int(_table.get("eco_job_total_limit", 3)),
	}
