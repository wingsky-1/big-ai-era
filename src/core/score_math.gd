class_name ScoreMath
extends RefCounted

## 出分与评测数学公式（L0 纯静态计算服务，DR-005 / DR-005R / DR-027③）：
## - Cobb-Douglas 求和聚合：
##   A = K · (1 + research_eff)^0.7 · (1 + tech_bonus)^0.3 · m(compute_tier) · q(base)
## - Sigmoid 标定映射：score = 100 / (1 + exp(-(A - theta) / k))

const DEFAULT_K: float = 4.0
const DEFAULT_THETA: float = 95.0
const DEFAULT_K_SIGMOID: float = 13.0

const COMPUTE_MULTIPLIERS: Dictionary = {
	1: 0.6,
	2: 0.75,
	3: 0.9,
	4: 1.05,
}


## 获取算力档位质量乘子 m(compute_tier)
static func get_compute_multiplier(tier: int) -> float:
	return float(COMPUTE_MULTIPLIERS.get(tier, 0.6))


## 计算综合能力分 A
static func calculate_ability(
	research_eff: int, tech_bonus: float, tier: int, quality: float, k: float = DEFAULT_K
) -> float:
	if research_eff < 0:
		return 0.0

	var m: float = get_compute_multiplier(tier)
	var term_eff: float = pow(1.0 + float(research_eff), 0.7)
	var term_tech: float = pow(1.0 + tech_bonus, 0.3)
	return k * term_eff * term_tech * m * quality


## 将能力分 A 映射为 Sigmoid 评测百分制得分 score
static func calculate_score(
	ability: float, theta: float = DEFAULT_THETA, k_sigmoid: float = DEFAULT_K_SIGMOID
) -> float:
	if k_sigmoid == 0.0:
		return 0.0
	var exponent: float = -(ability - theta) / k_sigmoid
	# 防浮点溢出
	if exponent > 60.0:
		return 0.0
	if exponent < -60.0:
		return 100.0
	var raw_score: float = 100.0 / (1.0 + exp(exponent))
	return snappedf(raw_score, 0.1)
