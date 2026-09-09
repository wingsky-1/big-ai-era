class_name Resources
extends RefCounted
## L2 三资源存量（#135）+ 卡时周预算账本（#139）。
## 契约（architecture §3 落位：Resources=现金/影响力/卡时三资源存量；
## architecture §③ 芯片行"CardHoursBudget 可并入 Resources"）：
## - **一切现金变更经 Ledger 过账**（唯一过账口，ADR-0015）；本类只做
##   存量应用+余额查询，不发明账目（每笔 change 先 record 后应用）；
## - **卡时周预算（#139 账本落位本类）**：周供给=注入 provider 查询
##   ChipYard 档位供给（装配方注入 ChipYard.get_supply(owned_tier)，
##   本类不自持 ChipYard 引用防环）；周预算纪律=消耗>供给拒绝+提示
##   （chips-spec A.2/OP-CHP-02/03，missing=还差量）、周结重置=供给
##   （剩余不清零不累积，Settlement phase 1 调 reset_weekly_card_hours）；
##   消费量整数；本单无真实消费方（#140 训练入槽接线），GUT 直驱；
## - 卡时预算供给查表入口（#139 前=provider 缺省 0 无消费方）。
## - 供给台账（influence_total：#135 只做存量，台账对账属 economy D.3
##   后续批——本类留 influence 存量，台账计数 #135 Settlement 路由论文时
##   以 ledger 行数推导，不建第二本账）。
## RefCounted 零 Node；headless 可单测。

## 周供给 provider（#139 注入 ChipYard 档位供给查询；缺省=0=无供给无消费）。
## 公有可注入（同 TaskBoard 谓词注入方向）；装配方接
## func(): return chip_yard.get_supply(chip_yard.get_owned_tier())。
var weekly_supply_provider: Callable = func() -> int: return 0

var _cash: int = 0
var _influence: int = 0
## 周内已用卡时（预算账本口径：周供给-剩余=已用；#135 存量语义保留）
var _card_hours_used: int = 0
var _card_hours_remaining: int = 0
## 周内是否已发生超分配拒绝（提示层持久；周结重置清零）
var _overdraw_hinted_this_week: bool = false


func _init(startup_cash: int = 0, startup_influence: int = 0) -> void:
	_cash = startup_cash
	_influence = startup_influence
	_card_hours_remaining = 0


## 现金余额
func get_cash() -> int:
	return _cash


func get_influence() -> int:
	return _influence


func get_card_hours_used() -> int:
	return _card_hours_used


## 本周卡时剩余（预算账本口径；周供给=provider 查询档位供给）
func get_card_hours_remaining() -> int:
	return _card_hours_remaining


## 本周卡时供给（经 provider 查档位供给；provider 缺省=0）
func get_card_hours_supply() -> int:
	return weekly_supply_provider.call()


## 周内是否已发生超分配拒绝（提示层持久；周结重置清零）
func has_overdraw_hint() -> bool:
	return _overdraw_hinted_this_week


## 应用一笔已过账的变更（Ledger.record 后调用；正=增负=减）。
## 负债语义：支出可超余额致 cash 转负（防贷款套现：负债计入终局结算，
## economy-spec C.3）；破产判定在 Settlement 层（收入结算后+救济可用性），
## 本类不拒绝负余额——"还能撑 X 周"为 0 即警示（eco_solvency_weeks）。
func apply_change(amount: int) -> void:
	_cash += amount


## 卡时消费（#139 预算账本命令；超分配拒绝+提示，不静默卡死）。
## 返回 {ok, remaining, used, missing, hinted}：
## - ok=false 且 hinted=true：消耗 > 供给-已用（missing=还差量）；
##   周结重置后可重试（新周预算=供给）；
## - hours<1=防御性拒绝（不置超分配提示）。
## 本单无真实消费方（#140 训练入槽接线：TaskBoard 校验该命令返回值）。
func consume_card_hours(hours: int) -> Dictionary:
	if hours < 1:
		return {"ok": false, "reason": "非法消费量（%d）" % hours}
	var supply := get_card_hours_supply()
	if _card_hours_used + hours > supply:
		_overdraw_hinted_this_week = true
		return {
			"ok": false,
			"missing": _card_hours_used + hours - supply,
			"remaining": supply - _card_hours_used,
			"used": _card_hours_used,
			"hinted": true,
		}
	_card_hours_used += hours
	_card_hours_remaining = supply - _card_hours_used
	return {
		"ok": true,
		"remaining": _card_hours_remaining,
		"used": _card_hours_used,
		"hinted": false,
	}


## 周结卡时重置（Settlement phase 1 调）：剩余=档位供给（不清零不累积——
## 预算语义：每周可用=供给，用剩作废不滚存）；超分配提示位同步清零
## （新周自动可重试，chips-spec OP-CHP-03"下周预算重置后自动可重试"）。
func reset_weekly_card_hours() -> void:
	_card_hours_used = 0
	_card_hours_remaining = get_card_hours_supply()
	_overdraw_hinted_this_week = false


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
