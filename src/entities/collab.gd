class_name CollabFactor
extends RefCounted
## L2 协作组合系数计算器（#132）：双人岗位组合→同岗/相邻/互补 + 组合效率值。
## 真源=staff-spec.md A.1/D.2（组合效率=两人同桌配合系数；staff_collab_same/
## adjacent/complement = ×1.0/×1.08/×1.18——数值席 G4 修正值已冻结）+ D.2
## staff_collab_adjacent_table + numerics-master §五（相邻表全连通：任何两岗可
## 构成某组合效率；研究×工程/数据×评测 等对角相异组=互补）。
## 硬约束：
## - RefCounted、零 Node/SceneTree 依赖（headless 可单测）；静态纯函数零状态；
## - **系数数值零硬编码**：三系数/岗位相邻表一律读调用方注入的 staff.json 整表
##   （本类持键名常量），代码零系数值——缺键回退 1.0+known=false（防御不抛错）；
## - 分类语义=表结构保证：两岗同 key=同岗组合；岗位相邻表内直连=相邻组合；
##   其余（相邻表全连通保证下的对角）=互补组合；严格序 互补>相邻>同岗 且
##   同岗=1.0 由表值序 + test_collab_order_strict 断言（本类不回退硬编码）；
## - ≥3 人上桌的组合语义=#140/#141 收口（staff-spec 双人触发协作，多人协作系数
##   真源未冻结），本类只算两人对；多人取最弱配对的保守下限在 TaskBoard（见
##   task_board.gd _refresh_slot_collab 注释），本类不发明多人规则。

## 组合分类稳定字符串（view/载荷承载；none=未触发协作的空位哨兵）
const KIND_NONE: String = "none"
const KIND_SAME: String = "same"
const KIND_ADJACENT: String = "adjacent"
const KIND_COMPLEMENT: String = "complement"

## staff.json 表键（staff-spec D.2 真源拼写；数值读表，键名集中本类）
const KEY_COLLAB_SAME: String = "staff_collab_same"
const KEY_COLLAB_ADJACENT: String = "staff_collab_adjacent"
const KEY_COLLAB_COMPLEMENT: String = "staff_collab_complement"
const KEY_ADJACENT_TABLE: String = "staff_collab_adjacent_table"

## 岗位相邻表内岗位键（与 Staff.ROLE_KEY_* 同源派生自 staff.json staff_roles）
const ROLE_RESEARCH: String = "research"
const ROLE_EVAL: String = "eval"
const ROLE_DATA: String = "data"
const ROLE_ENGINEERING: String = "engineering"


## 两人岗位组合 → 组合分类+效率值（表驱动唯一计算点）。
## 参数：role_key_a/role_key_b=岗位表内稳定字符串（Staff.role_to_key 同源派生；
## 查询方=装配注入的 TaskBoard.get_staff_role_key）；staff_table=staff.json 整表。
## 返回 {known: bool, kind: String, factor: float}：
## - known=false（表缺键/岗位键空）=防御回退 {kind:same, factor:1.0} 不抛错；
## - 同岗（key 相等）=same 档；相邻表直连=adjacent 档；全连通补集=complement 档。
static func pair_factor(
	role_key_a: String, role_key_b: String, staff_table: Dictionary
) -> Dictionary:
	if role_key_a.is_empty() or role_key_b.is_empty() or staff_table.is_empty():
		return _fallback()
	if role_key_a == role_key_b:
		var same: float = _table_factor(staff_table, KEY_COLLAB_SAME)
		return {"known": true, "kind": KIND_SAME, "factor": same}
	var adjacent: Variant = staff_table.get(KEY_ADJACENT_TABLE)
	if adjacent is Dictionary and (adjacent as Dictionary).has(role_key_a):
		var neighbors: Variant = (adjacent as Dictionary).get(role_key_a)
		if neighbors is Array and (neighbors as Array).has(role_key_b):
			var factor_a: float = _table_factor(staff_table, KEY_COLLAB_ADJACENT)
			return {"known": true, "kind": KIND_ADJACENT, "factor": factor_a}
	# 表内非直连（相邻表全连通假设下=对角）=互补档
	var complement: float = _table_factor(staff_table, KEY_COLLAB_COMPLEMENT)
	return {"known": true, "kind": KIND_COMPLEMENT, "factor": complement}


## 读表系数（缺键/非数值=防御回退 1.0+known=false；表完整时返回冻结值）
static func _table_factor(staff_table: Dictionary, key: String) -> float:
	var value: Variant = staff_table.get(key)
	if value is float or value is int:
		return float(value)
	return 1.0


## 缺表防御回退（不抛错：表驱动缺失=按无协作基准 1.0 处理，由 schema/测试护表）
static func _fallback() -> Dictionary:
	return {"known": false, "kind": KIND_SAME, "factor": 1.0}


## 岗位相邻表结构自检（测试/schema 守护用）：四岗键全在、边集对称、全连通。
## 返回错误消息数组（空=通过）。相邻关系全连通（numerics-master §五）由
## 本自检+test_collab_order_strict 断言：任意两岗必属 same/adjacent/complement 之一。
static func validate_adjacent_table(staff_table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if staff_table.is_empty():
		errors.append("staff_table 为空（无法校验岗位相邻表）")
		return errors
	var adjacent: Variant = staff_table.get(KEY_ADJACENT_TABLE)
	if adjacent is not Dictionary:
		errors.append("缺岗位相邻表键 '%s'" % KEY_ADJACENT_TABLE)
		return errors
	var rows: Dictionary = adjacent as Dictionary
	var role_keys: Array[String] = [ROLE_RESEARCH, ROLE_EVAL, ROLE_DATA, ROLE_ENGINEERING]
	for role_key: String in role_keys:
		if not rows.has(role_key):
			errors.append("岗位相邻表缺行 '%s'" % role_key)
			continue
		var neighbors: Variant = rows.get(role_key)
		if neighbors is not Array:
			errors.append("岗位相邻表行 '%s' 须是数组" % role_key)
			continue
		for neighbor: Variant in neighbors as Array:
			var neighbor_key := str(neighbor)
			if not role_keys.has(neighbor_key):
				errors.append("岗位相邻表行 '%s' 含未知岗位 '%s'" % [role_key, neighbor_key])
				continue
			# 对称断言：a∈b.adj ⇔ b∈a.adj（无向边只存一侧，读取按行命中）
			var back: Variant = rows.get(neighbor_key)
			if back is Array and not (back as Array).has(role_key):
				errors.append("岗位相邻表不对称：'%s'∈'%s' 但反向缺失" % [neighbor_key, role_key])
			# 自环断言：岗位不得与自己相邻（同岗=同岗档，不占相邻边）
			if neighbor_key == role_key:
				errors.append("岗位相邻表含自环：'%s' 与自身相邻" % role_key)
	return errors
