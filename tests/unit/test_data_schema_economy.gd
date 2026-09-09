extends GutTest
## #135 economy.json schema 断言（#128 data_schema 框架挂载）。

const ECONOMY_PATH: String = "res://src/data/economy.json"

const ECONOMY_SCHEMA: Dictionary = {
	"eco_startup_cash": {"type": "int"},
	"eco_salary_total_week": {"type": "int"},
	"eco_ops_cost_week_t0": {"type": "int"},
	"eco_ops_cost_week_t1": {"type": "int"},
	"eco_ops_cost_week_t2": {"type": "int"},
	"eco_ops_cost_week_t3": {"type": "int"},
	"eco_ops_cost_week_t4": {"type": "int"},
	"eco_warning_ratio": {"type": "float"},
	"eco_solvency_weeks_cap": {"type": "int"},
	"eco_salary_income_ratio_guard": {"type": "float"},
	"eco_loan_cap": {"type": "int"},
	"eco_loan_grace": {"type": "int"},
	"eco_loan_terms": {"type": "int"},
	"eco_loan_apr": {"type": "float"},
	"eco_loan_early_payoff_discount": {"type": "float"},
	"eco_sell_back_rate": {"type": "float"},
	"eco_job_total_limit": {"type": "int"},
	"eco_job_cooldown": {"type": "int"},
	"eco_job_decay": {"type": "float"},
	"eco_job_reward": {"type": "int"},
	"eco_market_influence_cost": {"type": "int"},
	"eco_penalty_outclassed": {"type": "float"},
	"eco_penalty_decay": {"type": "float"},
	"eco_stage_labor_weeks": {"type": "int"},
	"eco_stage_product_weeks": {"type": "int"},
	"eco_stage_total_weeks": {"type": "int"},
	"eco_stage_salary_mult": {"type": "dict"},
	"eco_stage_income_ratio_guard": {"type": "dict"},
}

const ECONOMY_NUMERIC_KEYS: Array[String] = [
	"eco_startup_cash",
	"eco_salary_total_week",
	"eco_warning_ratio",
	"eco_loan_cap",
	"eco_loan_grace",
	"eco_loan_terms",
	"eco_loan_apr",
	"eco_sell_back_rate",
	"eco_job_total_limit",
	"eco_job_cooldown",
	"eco_job_decay",
	"eco_job_reward",
	"eco_market_influence_cost",
	"eco_penalty_outclassed",
	"eco_penalty_decay",
	"eco_stage_labor_weeks",
	"eco_stage_product_weeks",
]


func test_economy_schema_valid() -> void:
	var table := DataLoader.load_json(ECONOMY_PATH)
	assert_false(table.is_empty(), "economy.json 可加载")
	var result := DataSchema.validate_table(table, ECONOMY_SCHEMA)
	assert_true(result.ok, "economy.json schema 校验全过: %s" % str(result.errors))


func test_economy_inline_bounds_present() -> void:
	var table := DataLoader.load_json(ECONOMY_PATH)
	var result := DataSchema.validate_inline_bounds(table, ECONOMY_NUMERIC_KEYS)
	assert_true(result.ok, "economy.json 数值键全带内嵌护栏: %s" % str(result.errors))


func test_economy_stage_weeks_consistent() -> void:
	# 阶段周数与单局总周一致（劳务+产品+资本=156；labor<product<total）
	var table := DataLoader.load_json(ECONOMY_PATH)
	var labor := int(table["eco_stage_labor_weeks"])
	var product := int(table["eco_stage_product_weeks"])
	var total := int(table["eco_stage_total_weeks"])
	assert_true(labor < product and product < total, "阶段周数递增")
	assert_eq(total, 156, "单局 156 周（time-spec 同源）")
	assert_eq(product - labor, 60, "产品期 60 周（41-100）")
