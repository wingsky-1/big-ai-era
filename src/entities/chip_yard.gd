class_name ChipYard
extends RefCounted
## L2 芯片档位（#139）：档位 T0–T4 表查询/画像/品质分/升档购买/门槛校验。
## 架构落位（architecture-100 §③ 芯片行）：ChipYard（档位）+ CardHoursBudget
## （周预算账本**并入 Resources**——#135 已预留"周内已用计数+预算读表入口"，
## 本单由 Resources 落账本命令，档位供给经注入 provider 查询本类）。
## 职责边界：
## - 状态唯一持有：**当前档位键**（owned_tier，稳定字符串 t0..t4，入档
##   products.chips.owned_tier，快照顶层已含）；档位表/维集/权重全读
##   chips.json（#139 新建表，键名真源 chips-spec D.1/D.2 + numerics-master
##   §1.1）；代码零硬编码数值/零维名散落；
## - 品质分=Σ(维×权)（读 chip_ndim_weight；G13 冻结 0.50/0.15/0.15/0.20），
##   跨档单调护栏（算力维跨档严格递增+算力权重 ≥0.50）由 GUT 断言
##   （test_tier_quality_monotonic）；画像刻意 trade-off 非单调（G13/蓝图
##   开放问题 4：低档能效高/高档算力猛费电）；
## - 购买=升下一档一次性开支（t0→t1→t2 直接可购；T3/T4 表行完整占位但
##   unlock_node=树解锁节点占位 id，未点亮=locked——本单不接树谓词，默认
##   锁，升档链停在 t2，兑现"T0-T2 实数据"边界）；购买成功 owned_tier 前进
##   并返回新供给（Resources 经 provider 即刻读新值，无需同步）；
## - 门槛校验（验收点 2 档位侧）：get_tier_eligibility(required_tier) 比较
##   档位序（_order 表驱动），不足=原因单一源（卡时侧=Resources.consume
##   拒绝 missing，#140 训练启动把两因接成双条件校验）；
## - "约 Y 周够"估算（chips-spec D.2 账本公式 Y=升级下一档所需周数估算）：
##   estimate_weeks_to_upgrade(weekly_surplus)=价差÷周净能力，能力 ≤0 或
##   已最高档=保底 1（不承诺 0 周）。装配方把经济侧周净能力传入（本类
##   不自持经济引用防环）。
## - 出售折价/运维/购买开支=economy.json 真源（#135/#136 已表驱动接线；
##   Relief 出售现值=装配方按 get_price×eco_sell_back_rate 接线注入，
##   本类不发明第二本账）。
## 硬约束：RefCounted 零 Node；headless 可单测；双向引用零。
## 行数预算 ≤400（architecture §8）。

## chips.json 表键（键名真源=chips-spec D.1/D.2；代码零硬编码数值）
const TABLE_PATH: String = "res://src/data/chips.json"
const KEY_TIERS: String = "chip_tiers"
const KEY_ORDER: String = "_order"
const KEY_TIER_NDIM: String = "ndim"
const KEY_TIER_SUPPLY: String = "supply"
const KEY_TIER_PRICE: String = "price"
const KEY_TIER_UNLOCK: String = "unlock_node"
const KEY_NDIM_SET: String = "chip_ndim_set"
const KEY_NDIM_WEIGHT: String = "chip_ndim_weight"

## 档位字符串（开放字符串用于存档 chips.owned_tier；此处为常量非 enum——
## 档位表=dict-of-rows 稳定字符串承载，E2 加档=表加行零代码改动）
const TIER_T0: String = "t0"
const TIER_T1: String = "t1"
const TIER_T2: String = "t2"
const TIER_T3: String = "t3"
const TIER_T4: String = "t4"
## 初始档（学校机房；T0 零购买费）
const TIER_START: String = TIER_T0

## 购买拒绝原因（中文随 reason 返回；码=单一源不散落）
const REASON_ALREADY_TOP: String = "已达最高档"
const REASON_NOT_ENOUGH_CASH: String = "现金不足"
const REASON_UNLOCK_LOCKED: String = "档位未解锁"
const REASON_UNKNOWN_TIER: String = "未知档位"

var _table: Dictionary = {}
var _owned_tier: String = TIER_START


func _init() -> void:
	_table = DataLoader.load_json(TABLE_PATH)


## ---------- 档位/画像查询（读表只读） ----------


## 当前持有档位键（初始 t0）
func get_owned_tier() -> String:
	return _owned_tier


## 档位行（深拷贝防外部改表；未知档返回空）
func get_tier(tier_key: String) -> Dictionary:
	var tiers: Dictionary = _table.get(KEY_TIERS, {})
	var row: Variant = tiers.get(tier_key)
	if row is not Dictionary:
		return {}
	return (row as Dictionary).duplicate(true)


## 全档位键序（_order 表驱动；t0..t4）
func get_tier_order() -> Array[String]:
	var tiers: Dictionary = _table.get(KEY_TIERS, {})
	var order: Variant = tiers.get(KEY_ORDER, [])
	var result: Array[String] = []
	for key: Variant in order as Array:
		result.append(str(key))
	return result


## 档位在序中的索引（-1=未知档）
func get_tier_index(tier_key: String) -> int:
	return get_tier_order().find(tier_key)


## 档位周供给（卡时；表驱动。供给真源=档位行 supply，Resources 预算账本
## 经装配注入本查询）
func get_supply(tier_key: String) -> int:
	return int(get_tier(tier_key).get(KEY_TIER_SUPPLY, 0))


## 档位购买价（一次性开支；T0=0）
func get_price(tier_key: String) -> int:
	return int(get_tier(tier_key).get(KEY_TIER_PRICE, 0))


## 档位解锁节点 id（T0/T1/T2=空串=初始可购；T3/T4=树解锁节点占位 id）
func get_unlock_node(tier_key: String) -> String:
	return str(get_tier(tier_key).get(KEY_TIER_UNLOCK, ""))


## 档位名文案键（texts.json chip_tier_t*；L3 经 TextService 取句）
func get_name_key(tier_key: String) -> String:
	return str(get_tier(tier_key).get("name_key", ""))


## 档位 n 维画像（4 维；键=chip_ndim_set 真源；读表零维名硬编码）
func get_ndim_profile(tier_key: String) -> Dictionary:
	var row := get_tier(tier_key)
	var ndim: Variant = row.get(KEY_TIER_NDIM)
	if ndim is not Dictionary:
		return {}
	return (ndim as Dictionary).duplicate(true)


## 档位品质分（Σ(维×权)；读 chip_ndim_weight，0–100）。
## 合成=NDims.weighted_sum 单一公式真源（architecture §4.2/ADR-0019：
## 三产物同构共用 n_dims，不在此重写 Σ——#133 注释"芯片 #139 建表复用"）。
## G13 护栏：跨档单调由表 + GUT 断言（算力维严格递增 + 算力权重 ≥0.50）。
func get_quality_score(tier_key: String) -> float:
	var ndim := get_ndim_profile(tier_key)
	if ndim.is_empty():
		return 0.0
	var weights: Dictionary = _table.get(KEY_NDIM_WEIGHT, {})
	return NDims.weighted_sum(ndim, weights)


## n 维维名集合（chip_ndim_set；表驱动断言用）
func get_ndim_set() -> Array[String]:
	var set_v: Variant = _table.get(KEY_NDIM_SET, [])
	var result: Array[String] = []
	for dim: Variant in set_v as Array:
		result.append(str(dim))
	return result


## 下一个更高档位键（_order 表驱动；已最高档返回 ""）
func get_next_tier(tier_key: String) -> String:
	var order := get_tier_order()
	var idx := order.find(tier_key)
	if idx < 0 or idx >= order.size() - 1:
		return ""
	return order[idx + 1]


## ---------- 门槛校验（验收点 2 档位侧） ----------


## 档位门槛校验：当前档位 ≥ 基座要求档位（档位序表驱动）。
## required_tier=""（教学迷你基座无档位要求）→ 恒过。
## 返回 {ok, reason, owned_tier, required_tier}；不足=REASON_UNKNOWN_TIER 之外
## 的明确原因（卡时侧=Resources.consume 拒绝 missing，双条件 #140 拼装）。
func get_tier_eligibility(required_tier: String) -> Dictionary:
	if required_tier.is_empty():
		return {
			"ok": true,
			"owned_tier": _owned_tier,
			"required_tier": required_tier,
		}
	var req_idx := get_tier_index(required_tier)
	var owned_idx := get_tier_index(_owned_tier)
	if req_idx < 0:
		return {"ok": false, "reason": REASON_UNKNOWN_TIER, "required_tier": required_tier}
	if owned_idx < req_idx:
		return {
			"ok": false,
			"reason": "档位不足（需 %s，当前 %s）" % [required_tier, _owned_tier],
			"owned_tier": _owned_tier,
			"required_tier": required_tier,
		}
	return {"ok": true, "owned_tier": _owned_tier, "required_tier": required_tier}


## "约 Y 周够"估算（拒绝提示的 Y；chips-spec D.2 账本公式：Y=升级下一档
## 所需周数估算=下一档价差÷周净能力）。weekly_surplus=装配方注入的经济侧
## 周净能力（读 ledger/现金能力）；≤0 或已最高档=保底 1（不承诺 0 周）。
func estimate_weeks_to_upgrade(weekly_surplus: int) -> int:
	var next := get_next_tier(_owned_tier)
	if next.is_empty():
		return 1
	var price := get_price(next)
	if weekly_surplus <= 0 or price <= 0:
		return 1
	return maxi(int(ceilf(float(price) / float(weekly_surplus))), 1)


## ---------- 档位购买（升档=一次性开支） ----------


## 升到下一档（预算检查）。cash_balance=当前现金（装配方注入查询），
## unlock_ok=树解锁谓词（注入；本单默认=仅 unlock_node 为空的档可购——
## T3/T4 解锁占位未点亮前 locked，升档链停在 t2）。
## 返回 {ok, owned_tier, tier_key, price, supply, reason}：
## 资金不足/未解锁/已最高档/未知档=拒绝各显原因（单一源）。
func purchase_next_tier(
	cash_balance: int, unlock_ok: Callable = func(_node_id: String) -> bool: return false
) -> Dictionary:
	var current := _owned_tier
	var next := get_next_tier(current)
	if next.is_empty():
		return {"ok": false, "reason": REASON_ALREADY_TOP, "owned_tier": current}
	var unlock_node := get_unlock_node(next)
	if not unlock_node.is_empty() and not unlock_ok.call(unlock_node):
		return {
			"ok": false,
			"reason": REASON_UNLOCK_LOCKED,
			"tier_key": next,
			"unlock_node": unlock_node,
			"owned_tier": current,
		}
	var price := get_price(next)
	if cash_balance < price:
		return {
			"ok": false,
			"reason": REASON_NOT_ENOUGH_CASH,
			"tier_key": next,
			"missing": price - cash_balance,
			"price": price,
			"owned_tier": current,
		}
	_owned_tier = next
	return {
		"ok": true,
		"owned_tier": next,
		"tier_key": next,
		"price": price,
		"supply": get_supply(next),
	}


## 资产现值（Relief 出售注入装配用：购买价×economy 折价率；rate 由装配方
## 从 economy.json eco_sell_back_rate 传入——本类不读第二本账防双源）。
func get_asset_value(tier_key: String, sell_back_rate: float = 0.6) -> int:
	var price := get_price(tier_key)
	return int(roundf(float(price) * sell_back_rate))
