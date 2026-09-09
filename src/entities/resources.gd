class_name Resources
extends RefCounted
## L2 三资源存量（#135）：cash/influence/card_hours_used。
## 契约（architecture §3 落位：Resources=现金/影响力/卡时三资源存量）：
## - **一切资源变更经 Ledger 过账**（唯一过账口，ADR-0015）；本类只做
##   存量应用+余额查询，不发明账目（每笔 change 先 record 后应用）；
## - 卡时周预算：#139 chips 批落位周供给与重置（phase 1），本类先持
##   周内已用计数与预算读表入口（#139 前预算=0 无消费方）；
## - 供给台账（influence_total：#135 只做存量，台账对账属 economy D.3
##   后续批——本类留 influence 存量，台账计数 #135 Settlement 路由论文时
##   以 ledger 行数推导，不建第二本账）。
## RefCounted 零 Node；headless 可单测。

var _cash: int = 0
var _influence: int = 0
var _card_hours_used: int = 0


func _init(startup_cash: int = 0, startup_influence: int = 0) -> void:
	_cash = startup_cash
	_influence = startup_influence


## 现金余额
func get_cash() -> int:
	return _cash


func get_influence() -> int:
	return _influence


func get_card_hours_used() -> int:
	return _card_hours_used


## 应用一笔已过账的变更（Ledger.record 后调用；正=增负=减）。
## 负债语义：支出可超余额致 cash 转负（防贷款套现：负债计入终局结算，
## economy-spec C.3）；破产判定在 Settlement 层（收入结算后+救济可用性），
## 本类不拒绝负余额——"还能撑 X 周"为 0 即警示（eco_solvency_weeks）。
func apply_change(amount: int) -> void:
	_cash += amount


## 卡时消费（#139 前禁消费：预算未落位时消费=越权，返回 false）
func consume_card_hours(hours: int) -> bool:
	if hours < 1:
		push_error("Resources.consume_card_hours: 消费量非法（hours=%d）" % hours)
		return false
	# #139 周预算落位前无消费方（训练/论文周耗卡时 #139/#140 接线）
	push_error("Resources.consume_card_hours: 卡时预算系统未落位（#139），拒绝消费")
	return false


## 周结卡时重置（phase 1；#139 落位真实重置逻辑，本批=清周内计数接口）
func reset_weekly_card_hours() -> void:
	_card_hours_used = 0


func spend_influence(amount: int) -> bool:
	if amount < 0:
		push_error("Resources.spend_influence: 消费量非法（amount=%d）" % amount)
		return false
	if _influence < amount:
		return false
	_influence -= amount
	return true


func gain_influence(amount: int) -> void:
	if amount < 0:
		push_error("Resources.gain_influence: 增益量非法（amount=%d）" % amount)
		return
	_influence += amount
