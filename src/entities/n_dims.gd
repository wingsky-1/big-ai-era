class_name NDims
extends RefCounted
## L2 n 维共享组件（#132 最小骨架——仅"员工属性→产物维度贡献"源映射）。
## 定位（任务书/architecture-100 §4.2/ADR-0019）：n 维评分=共享组件，单一合成
## 公式真源 Σ(维×权)。**本单边界**（issue #132 改动面）：
## - 只做三大来源之一（员工属性源）的"源贡献映射"：员工 4 维属性 × 岗位适配
##   系数（staff_roles.attr_coef 表）→ 产物 n 维贡献（staff_ndim_map 表）；
## - 完整 compose()/dim 布局表/三源合成/饱和护栏=#141（architecture §4.2 类图
##   compose/saturate_clamp/guard_check + ndim_profiles 适配层全量落盘）；
## - 本类无 compose——合成点归属 #141，本单只供"各系统交自己的那一份原始值"
##   的员工侧取值（架构 §4.2 合成点归属句）；
## - 产物维度布局（论文 4 维/模型 5 维 dim_ids）已在 architecture §4.2 冻结
##   （novelty/rigor/impact/repro；reasoning/knowledge/chat/speed/cost），
##   但产物侧布局表/文案键数组（#133/#140 建表）+芯片维布局（ChipTier P2）
##   未冻结→映射表本单只含论文/模型两产品；芯片发挥列待 #141 核对补行。
## 硬约束：
## - RefCounted、零 Node/SceneTree 依赖（headless 可单测）；静态纯函数零状态；
## - **数值零硬编码**：岗位适配系数读注入 staff.json staff_roles.attr_coef
##   （#130 表驱动）+属性→维映射读 staff_ndim_map；代码零系数值/零维名；
## - 50% 员工源权重（numerics-master §1.2：论文/模型员工来源=最大单项 50%；
##   芯片 20%；护栏=任何产物员工来源权重 ≥20%）本单不落权重——权重表属
##   #141 dim 布局（每产物 {dim_ids, weights[]} 数据块）；本文件头注释+接口
##   注释预留，合成批 #141 断言（test_ndim_formula_all_products 同批）。
## 行数预算：≤500（architecture §8）。

## staff.json 表键（键名真源=numerics-master §1.3 staff_ndim_map/staff_roles）
const KEY_NDIM_MAP: String = "staff_ndim_map"
const KEY_ROLES: String = "staff_roles"

## 产物类型键（与 Project.type_to_key 同源派生；表内稳定字符串）
const PRODUCT_PAPER: String = "paper"
const PRODUCT_MODEL: String = "model"

## 属性四维稳定键（与 Staff.ATTR_KEYS 同源派生自 staff_roles.attr_coef）
const ATTR_THEORY: String = "theory"
const ATTR_ENGINEERING: String = "engineering"
const ATTR_DATA: String = "data"
const ATTR_COMMUNICATION: String = "communication"


## 员工侧源贡献映射（表驱动单点；#132 接口形状，任务书"员工属性×岗位适配→
## 通用贡献字典+表驱动映射"落点）：
## 贡献值=Σ_{属性维} 属性值 × 岗位适配系数（映射到该产物维的属性才计）。
## 岗位适配系数=staff_roles[role_key].attr_coef[attr]（读表；role_key=岗位表内
## 稳定字符串，Staff.role_to_key 同源派生）；属性→产物维=staff_ndim_map。
## 参数：attrs={attr_key: value}（Staff.get_staff_view 的 attrs 同构）、
## role_key、product_key（paper/model）、staff_table（staff.json 整表）。
## 返回 {known: bool, contributions: {dim_key: value}, total: float}：
## - contributions=该员工对产物各维的贡献（dim=staff_ndim_map 真源键，代码
##   零维名硬编码）；total=Σ 贡献（单一数值表达，供 #141 合成取用）；
## - known=false（表缺键/属性空/未知岗位或产品）=防御回退空贡献不抛错。
static func staff_contribution(
	attrs: Dictionary, role_key: String, product_key: String, staff_table: Dictionary
) -> Dictionary:
	var empty: Dictionary = {"known": false, "contributions": {}, "total": 0.0}
	if attrs.is_empty() or role_key.is_empty() or product_key.is_empty() or staff_table.is_empty():
		return empty
	var map_block: Variant = staff_table.get(KEY_NDIM_MAP)
	if map_block is not Dictionary:
		return empty
	var roles: Variant = staff_table.get(KEY_ROLES)
	if roles is not Dictionary:
		return empty
	var role_def: Variant = (roles as Dictionary).get(role_key)
	if role_def is not Dictionary:
		return empty
	var coefs: Variant = (role_def as Dictionary).get("attr_coef")
	if coefs is not Dictionary:
		return empty
	var contributions: Dictionary = {}
	var total := 0.0
	for attr_key: Variant in (map_block as Dictionary).keys():
		var attr := str(attr_key)
		if not attrs.has(attr):
			continue
		var per_product: Variant = (map_block as Dictionary).get(attr)
		if per_product is not Dictionary:
			continue
		var dims: Variant = (per_product as Dictionary).get(product_key)
		if dims is not Array:
			continue
		var attr_value := float(attrs[attr])
		var coef := float((coefs as Dictionary).get(attr, 0.0))
		for dim: Variant in dims as Array:
			var dim_key := str(dim)
			var gain := attr_value * coef
			# 零增益属性（值 0/无适配系数）不占贡献键——贡献字典=真实产出维集，
			# 下游合成（#141）把缺键当 0 贡献，与显式 0 等价且防"零值占位歧义"
			if gain <= 0.0:
				continue
			contributions[dim_key] = float(contributions.get(dim_key, 0.0)) + gain
			total += gain
	if contributions.is_empty():
		return {"known": false, "contributions": {}, "total": 0.0}
	return {"known": true, "contributions": contributions, "total": total}


## 员工来源权重接口预留（numerics-master §1.2：论文/模型员工来源=最大单项 50%、
## 芯片 20%；护栏=任何产物员工来源权重 ≥20%）。本单权重表未落：权重属 #141
## dim 布局数据块（每产物 {dim_ids, weights[]}），#141 compose 合成时逐产物
## 读取并断言"员工来源为最大单项且 ≥20%"（同批 test_ndim_formula_all_products
## 收口），本文件不设伪权重接口——代码零 0.5 字面量（防双真源）。
## 岗位适配系数查询（供详情/预判"匹配度 ★★★"与 #141 合成共用；
## staff_roles.attr_coef 表驱动；无岗无维返回 0）
static func role_coef(role_key: String, attr_key: String, staff_table: Dictionary) -> float:
	var roles: Variant = staff_table.get(KEY_ROLES)
	if roles is Dictionary:
		var role_def: Variant = (roles as Dictionary).get(role_key)
		if role_def is Dictionary:
			var coefs: Variant = (role_def as Dictionary).get("attr_coef")
			if coefs is Dictionary and (coefs as Dictionary).has(attr_key):
				return float((coefs as Dictionary).get(attr_key, 0.0))
	return 0.0


## #133 增补：通用加权和纯函数（Σ(维×权)，单一公式真源架构 §4.2/ADR-0019；
## 三产物同构——#141 完整 compose 复用本函数，本函数不绑定产物）。
## 权重表真源=各产物数据表（论文 paper_ndim_weight；模型/芯片 #140/#139 建表）。
## 参数：values={dim_key: value}（0–100 原始维值）、weights={dim_key: weight}。
## 返回：score ∈[0,100]（权重和=1 由表断言保证；本函数防御缺权重维=按 0 计）。
## 零硬编码：权重值全部来自调用方传入表块；本函数只做 Σ。
static func weighted_sum(values: Dictionary, weights: Dictionary) -> float:
	if values.is_empty() or weights.is_empty():
		return 0.0
	var score := 0.0
	for dim: Variant in values.keys():
		var dim_key := str(dim)
		if not weights.has(dim_key):
			continue
		score += float(values[dim_key]) * float(weights[dim_key])
	return score


## 权重和=1 校验（表断言辅助：#128 数据框架外对权重表块的运行时护栏；
## 防"加维忘改权重"导致分数域漂移——numerics-master"权重公开+和=1"契约）
static func weights_sum_to_one(weights: Dictionary) -> bool:
	var total := 0.0
	for dim: Variant in weights.keys():
		total += float(weights[dim])
	return absf(total - 1.0) < 0.0001


## ---------- #141 三源合成（architecture §4.2 compose 落点） ----------


## 来源权重合法校验（numerics-master §1.2 护栏）：和=1 + 员工来源为最大
## 单项且 ≥0.20（防员工被碾压成摆设，tech-tree 开放问题 6 收口）。
## drivers={源键: 权重}（各产物表 drivers 块；源键=staff/tree/topic/chip）。
## 论文=paper_quality_drivers{staff,tree,topic}；模型=model_ndim_drivers
## {staff,tree,chip}；芯片=无外部源（空表=恒合法：不进三源合成）。
## 返回 {ok, errors[]}。
static func validate_drivers(drivers: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if drivers.is_empty():
		# 空 drivers=产物无外部源（芯片档位画像自持）→ 合法
		return {"ok": true, "errors": errors}
	if not weights_sum_to_one(drivers):
		errors.append("来源权重和≠1（%s）" % str(drivers))
	var staff_wt := float(drivers.get("staff", 0.0))
	if staff_wt < 0.2:
		errors.append("员工来源权重 ≥0.20（护栏；当前 %s）" % str(staff_wt))
	var max_wt := 0.0
	for key: Variant in drivers.keys():
		max_wt = maxf(max_wt, float(drivers[key]))
	if not is_equal_approx(max_wt, staff_wt):
		errors.append("员工来源须为最大单项（当前 staff=%s，max=%s）" % [str(staff_wt), str(max_wt)])
	return {"ok": errors.is_empty(), "errors": errors}


## 三源合成（architecture §4.2 compose 单一公式真源；#141 落位）：
## 逐维合成值 = Σ_{源} 源对该维的原始值 × 源权重（drivers 表驱动）；
## score = Σ(合成值 × 维权重)（加权和，复用 weighted_sum）。
## 参数：
## - drivers={源键: 源权重}（产物表 drivers 块；空=单源直通）
## - sources={源键: {dim: 值}}：每源各维的**原始贡献值**（同尺度 0–100，
##   由各系统提供：员工=staff_contribution 折算、树=TechTree 强化查询、
##   芯片=ChipYard 档位画像发挥；本函数不发明源取值）
## - weights={dim: 权重}（产物表 weight 块）
## 返回 {values: {dim: 合成值}, score}：
## - 逐维防御：某源缺该维=按 0 计（不抛错）；drivers 缺源=跳过该源；
## - 合成值经 saturate_clamp 收口 ∈[0,100]（score 域护栏）。
## 零硬编码：全部权重来自调用方传入表块。
static func compose(drivers: Dictionary, sources: Dictionary, weights: Dictionary) -> Dictionary:
	var values := {}
	var max_dim := 100.0
	var min_dim := 0.0
	# 维集=全部源贡献维 + weights 维的并集（缺源维=按 0 计）
	var dims: Array[String] = []
	for source_key: Variant in sources.keys():
		var per_source: Variant = sources[source_key]
		if per_source is not Dictionary:
			continue
		for dim: Variant in (per_source as Dictionary).keys():
			if str(dim) not in dims:
				dims.append(str(dim))
	for dim: Variant in weights.keys():
		if str(dim) not in dims:
			dims.append(str(dim))
	for dim: String in dims:
		var value := 0.0
		if drivers.is_empty():
			# 无外部源产物：单源直通（源值即合成值）
			for source_key: Variant in sources.keys():
				var per_source: Variant = sources[source_key]
				if per_source is Dictionary:
					value += float((per_source as Dictionary).get(dim, 0.0))
		else:
			for source_key: Variant in sources.keys():
				var per_source: Variant = sources[source_key]
				if per_source is not Dictionary:
					continue
				var src_wt := float(drivers.get(str(source_key), 0.0))
				if src_wt <= 0.0:
					continue
				value += float((per_source as Dictionary).get(dim, 0.0)) * src_wt
		values[dim] = clampf(value, min_dim, max_dim)
	var score := weighted_sum(values, weights)
	return {"values": values, "score": clampf(score, 0.0, 100.0)}


## 饱和收口（#141 域护栏）：score 合成收口 ∈[0,100]（numerics-master
## §1.4 ndim_dim_cap=100；饱和阈值 98 语义=#143 守卫带/迭代护栏同批联标，
## 本函数只做分数域收口不做玩法饱和判定）。
static func saturate_clamp(score: float) -> float:
	return clampf(score, 0.0, 100.0)
