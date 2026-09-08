class_name ScoreMath
extends RefCounted

## 出分与评测数学公式（L0 纯静态计算服务，DR-005 / DR-005R / DR-027③）：
## - Cobb-Douglas 求和聚合：
##   A = ability_scale · (1 + research_eff)^e_eff · (1 + tech_bonus)^e_tech · m(tier) · q
## - Sigmoid 标定映射：score = score_max / (1 + exp(-(A - theta) / k))
##
## 数值真源：src/data/benchmarks.json（ADR-0013：公式形态留代码，系数/指数/阈值全进表）。
## L0 零依赖：本类不读磁盘，参数由调用方经 `normalize_params()` 规范化后注入；
## 缺键即 push_error 并熔断返回 0（禁止代码默认值兜底——双真源会让改表不生效）。

const REQUIRED_KEYS: PackedStringArray = [
	"ability_scale",
	"ability_exponents",
	"compute_multipliers",
	"sigmoid_clamp_exponent",
	"score_max",
	"score_precision",
	"theta",
	"k",
]

## 阶段可覆盖的出分键白名单（RS-04 θ/k 参数通路，issue #79）：
## v1.0 仅 θ/k 允许按阶段覆盖，其余键（K/m/score_max…）一律沿用 benchmarks.json 基准。
const STAGE_OVERRIDE_KEYS: PackedStringArray = ["theta", "k"]


## JSON 行 → 规范化出分参数（compute_multipliers 的字符串键转 int；缺键返回空字典）。
static func normalize_params(benchmark_row: Dictionary) -> Dictionary:
	for key: String in REQUIRED_KEYS:
		if not benchmark_row.has(key):
			push_error("ScoreMath: 出分参数缺键 '%s'（真源 benchmarks.json）" % key)
			return {}

	var raw_multipliers: Dictionary = benchmark_row["compute_multipliers"]
	var multipliers: Dictionary = {}
	for tier_key: Variant in raw_multipliers:
		multipliers[int(tier_key)] = float(raw_multipliers[tier_key])

	var exponents: Dictionary = benchmark_row["ability_exponents"]
	for exp_key: String in ["research_eff", "tech_bonus"]:
		if not exponents.has(exp_key):
			push_error("ScoreMath: ability_exponents 缺键 '%s'" % exp_key)
			return {}

	return {
		"ability_scale": float(benchmark_row["ability_scale"]),
		"ability_exponents":
		{
			"research_eff": float(exponents["research_eff"]),
			"tech_bonus": float(exponents["tech_bonus"]),
		},
		"compute_multipliers": multipliers,
		"theta": float(benchmark_row["theta"]),
		"k": float(benchmark_row["k"]),
		"sigmoid_clamp_exponent": float(benchmark_row["sigmoid_clamp_exponent"]),
		"score_max": float(benchmark_row["score_max"]),
		"score_precision": float(benchmark_row["score_precision"]),
	}


## 基准出分参数 × 阶段覆盖（RS-04 θ/k 参数通路，issue #79；L0 纯函数零副作用）。
## - stage_data 无 "score_params" 键 → 原样返回基准副本（v1.0 真表零覆盖，零数值变更）；
## - 只覆盖部分键 → 缺键沿用基准（可只覆盖 θ 或只覆盖 k）；
## - 非法（非字典 / 非白名单键 / 非数值 / k == 0）→ push_error 熔断返回 {}（零默认值纪律）。
static func merge_stage_params(base_params: Dictionary, stage_data: Dictionary) -> Dictionary:
	if base_params.is_empty():
		push_error("ScoreMath.merge_stage_params: 基准出分参数为空（未注入 benchmarks.json）")
		return {}
	var merged: Dictionary = base_params.duplicate(true)
	if not stage_data.has("score_params"):
		return merged
	var override_variant: Variant = stage_data["score_params"]
	if not (override_variant is Dictionary):
		push_error("ScoreMath.merge_stage_params: score_params 必须是字典（真源 stages.json）")
		return {}
	var override: Dictionary = override_variant
	for key_variant: Variant in override:
		var key: String = str(key_variant)
		if not STAGE_OVERRIDE_KEYS.has(key):
			push_error(
				(
					"ScoreMath.merge_stage_params: 非法覆盖键 '%s'（仅允许 %s）"
					% [key, ", ".join(STAGE_OVERRIDE_KEYS)]
				)
			)
			return {}
		var value_variant: Variant = override[key_variant]
		if not (value_variant is float or value_variant is int):
			push_error("ScoreMath.merge_stage_params: 覆盖键 '%s' 必须为数值" % key)
			return {}
		var value: float = float(value_variant)
		if key == "k" and is_zero_approx(value):
			push_error("ScoreMath.merge_stage_params: k 不得为 0（sigmoid 分母）")
			return {}
		merged[key] = value
	return merged


## 获取算力档位质量乘子 m(compute_tier)；档位缺失返回 0（调用方按 0 分处理）。
static func get_compute_multiplier(params: Dictionary, tier: int) -> float:
	var multipliers: Dictionary = params.get("compute_multipliers", {})
	return float(multipliers.get(tier, 0))


## 计算综合能力分 A
static func calculate_ability(
	research_eff: int, tech_bonus: float, tier: int, quality: float, params: Dictionary
) -> float:
	if params.is_empty():
		push_error("ScoreMath.calculate_ability: 出分参数为空（未注入 benchmarks.json）")
		return 0.0
	if research_eff < 0:
		return 0.0

	var exponents: Dictionary = params["ability_exponents"]
	var m: float = get_compute_multiplier(params, tier)
	var term_eff: float = pow(1.0 + float(research_eff), float(exponents["research_eff"]))
	var term_tech: float = pow(1.0 + tech_bonus, float(exponents["tech_bonus"]))
	return float(params["ability_scale"]) * term_eff * term_tech * m * quality


## 将能力分 A 映射为 Sigmoid 评测百分制得分 score
static func calculate_score(ability: float, params: Dictionary) -> float:
	if params.is_empty():
		push_error("ScoreMath.calculate_score: 出分参数为空（未注入 benchmarks.json）")
		return 0.0
	var k_sigmoid: float = float(params["k"])
	if k_sigmoid == 0.0:
		return 0.0
	var clamp_exponent: float = float(params["sigmoid_clamp_exponent"])
	var score_max: float = float(params["score_max"])
	var exponent: float = -(ability - float(params["theta"])) / k_sigmoid
	# 防浮点溢出
	if exponent > clamp_exponent:
		return 0.0
	if exponent < -clamp_exponent:
		return score_max
	var raw_score: float = score_max / (1.0 + exp(exponent))
	return snappedf(raw_score, float(params["score_precision"]))
