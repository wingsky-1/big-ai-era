class_name PredicateRegistry
extends RefCounted

## 谓词注册表（L1 纯逻辑/数据服务，DR-011 禁 DSL 哲学）：
## - 纯函数求值，成对注册（none/never, tech_lit, rp_threshold, min_money, crossover_count）。
## - 支持单层 any_of（任一子谓词成立即为 true）。
## - 入参 context 严格为标量字典，零 L2 实体依赖。


static func evaluate(spec: Dictionary, context: Dictionary) -> bool:
	if spec.is_empty():
		return true

	# 1. 检查单层 any_of（任一满足即为 true）
	if spec.has("any_of"):
		var any_of_list: Variant = spec.get("any_of")
		if any_of_list is Array:
			var array_list: Array = any_of_list
			if array_list.is_empty():
				return false
			for sub_spec: Variant in array_list:
				if sub_spec is Dictionary and evaluate(sub_spec, context):
					return true
			return false

	# 2. 普通单谓词判定
	var predicate: String = str(spec.get("predicate", "none"))
	var params: Dictionary = spec.get("params", {})

	match predicate:
		"none":
			return true

		"never":
			return false

		"tech_lit":
			var lit_techs: Array = context.get("lit_techs", [])
			if params.has("tech_id"):
				var target_id: String = str(params.get("tech_id", ""))
				return lit_techs.has(target_id)
			if params.has("tech_ids"):
				var target_ids: Array = params.get("tech_ids", [])
				for tid: Variant in target_ids:
					if not lit_techs.has(str(tid)):
						return false
				return true
			return false

		"rp_threshold":
			var threshold: int = int(params.get("threshold", 0))
			# 优先检查 cumulative_rp，其次检查 influence/rp
			var available_rp: int = int(
				context.get("cumulative_rp", context.get("influence", context.get("rp", 0)))
			)
			return available_rp >= threshold

		"min_money":
			var amount: int = int(params.get("amount", 0))
			var current_money: int = int(context.get("money", 0))
			return current_money >= amount

		"crossover_count":
			var required_count: int = int(params.get("required_lit_count", 0))
			var current_count: int = int(context.get("crossover_count", 0))
			return current_count >= required_count

		_:
			push_warning("PredicateRegistry: 未知谓词 '%s'，拒绝通过" % predicate)
			return false
