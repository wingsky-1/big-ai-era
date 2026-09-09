class_name Economy
extends RefCounted
## L2 经济规则（#135 切片）：周工资/阶段判定/破产谓词/还能撑 X 周。
## 范围裁明：工资按在册 4 人周总额读表（economy.json eco_salary_total_week
## 劳务期基准；阶段乘子 eco_stage_salary_mult 后续批接扩编）；运维按档位读表
## （#139 chips 批接真实持有档位，本批=按注入档位查表）；救济三件套（贷款/
## 出售/私活）= #136；部署/市场/授权 = 后续批（economy P1）。
## 破产判定（economy-spec C.3/230 行）：cash<0 且无可用救济——本类出
## 谓词输入（solvency/救济可用性由注入查询，#136 前默认"无救济"即
## cash<0 即破产信号；#136 落位后接真实救济可用判定）。
## 三阶段（eco_stage_unlock_week：劳务 0-40/产品 41-100/资本 101-156）=周数
## 表驱动（阶段=行为解锁非硬周：本批按周数推荐值做阶段标签，#135 DoD 验收
## 4 断言表一致；行为解锁联动后续批）。
## RefCounted 零 Node；数值全读 economy.json（代码零硬编码）。

enum Stage {
	LABOR,
	PRODUCT,
	CAPITAL,
}

const ECONOMY_PATH: String = "res://src/data/economy.json"

## 阶段稳定字符串（存档/数据面；单向映射）
const STAGE_TO_KEY: Dictionary = {
	Stage.LABOR: "labor",
	Stage.PRODUCT: "product",
	Stage.CAPITAL: "capital",
}

var _table: Dictionary = {}


func _init() -> void:
	_table = DataLoader.load_json(ECONOMY_PATH)


## 开局现金（开局装配读表）
func get_startup_cash() -> int:
	return int(_table.get("eco_startup_cash", 0))


## 周工资（阶段基准×阶段乘子；在册 4 人基准——扩编 8/12 后批接 staff 批）
func get_weekly_salary(stage: Stage) -> int:
	var base := int(_table.get("eco_salary_total_week", 0))
	var mult := float(_table.get("eco_stage_salary_mult", {}).get(STAGE_TO_KEY[stage], 1.0))
	return int(roundf(float(base) * mult))


## 周运维（按注入档位键 t0-t4 查表；#139 前无持有档位=0）
func get_weekly_ops_cost(tier_key: String = "t0") -> int:
	var key := "eco_ops_cost_week_%s" % tier_key
	return int(_table.get(key, 0))


## 阶段判定（周数表驱动：劳务 1-40/产品 41-100/资本 101-156）
func get_stage(week: int) -> Stage:
	var labor_end := int(_table.get("eco_stage_labor_weeks", 40))
	var product_end := int(_table.get("eco_stage_product_weeks", 100))
	if week <= labor_end:
		return Stage.LABOR
	if week <= product_end:
		return Stage.PRODUCT
	return Stage.CAPITAL


static func stage_to_key(stage: Stage) -> String:
	return str(STAGE_TO_KEY.get(stage, "labor"))


## 还能撑 X 周（eco_solvency_weeks 公式：cash ÷ 周净流出，上限 99；
## 净流入为正 → 返回 99 表示"盈余中"——由调用方区分显示）
func get_solvency_weeks(cash: int, weekly_net_outflow: int) -> int:
	var cap := int(_table.get("eco_solvency_weeks_cap", 99))
	if weekly_net_outflow <= 0:
		return cap
	return mini(int(cash / weekly_net_outflow), cap)


## 警告线（现金阈值=月支出×ratio；月=4 周）
func get_warning_line(weekly_expense: int) -> int:
	var ratio := float(_table.get("eco_warning_ratio", 0.3))
	return int(roundf(float(weekly_expense * 4) * ratio))


## 工资护栏（工资 ≤ 周收入中位 ×0.6 表驱动断言值；Settlement 过账前校验）
func is_salary_guarded(stage: Stage, weekly_income: int) -> bool:
	var guard := float(_table.get("eco_stage_income_ratio_guard", {}).get(STAGE_TO_KEY[stage], 0.6))
	return float(get_weekly_salary(stage)) <= float(maxi(weekly_income, 0)) * guard
