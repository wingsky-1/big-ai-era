class_name DataSchema
extends RefCounted
## L1 数据表 schema 断言框架（#128）：键名拼写/类型/必需键/护栏跟键（D6）。
##
## 用法：每张表在 src/data/ 内嵌 `"_bounds"` 或独立描述块声明护栏；
## 引擎按"键描述表"校验：键必须存在、类型必须匹配、值必须在 bound 区间。
## 键名拼写真源 = texts-keys.md / numerics-master.md（各规格 D.1/D.2）；
## 本引擎只做机制，具体键名由各表 schema 描述声明（运行时读键，防改数不改护栏）。

## 表内嵌护栏块键名（D6 跟键走：护栏随数值键同表存放）
const BOUNDS_KEY: String = "_bounds"


## 校验结果结构：{ok: bool, errors: Array[String]}
static func validate_table(table: Dictionary, schema: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for key: String in schema.keys():
		var rule: Dictionary = schema[key]
		var required: bool = rule.get("required", true)
		if not table.has(key):
			if required:
				errors.append("缺必需键 '%s'" % key)
			continue
		var value: Variant = table[key]
		# 类型校验
		if rule.has("type"):
			var expected: String = rule["type"]
			if not _type_matches(value, expected):
				errors.append("键 '%s' 类型不符：期望 %s，实际 %s" % [key, expected, _type_name(value)])
		# 护栏跟键：bound 区间（数值键）
		if rule.has("bounds") and (value is float or value is int):
			var bounds: Array = rule["bounds"]
			var min_v: float = float(bounds[0])
			var max_v: float = float(bounds[1])
			if float(value) < min_v or float(value) > max_v:
				errors.append(
					"键 '%s' 越界：值 %s 不在 [%s, %s]" % [key, str(value), str(min_v), str(max_v)]
				)
	return {"ok": errors.is_empty(), "errors": errors}


## 断言表内嵌 _bounds 块（防改数不改护栏：数值键必带护栏声明）
static func validate_inline_bounds(table: Dictionary, numeric_keys: Array[String]) -> Dictionary:
	var errors: Array[String] = []
	if not table.has(BOUNDS_KEY):
		errors.append("表缺少内嵌护栏块 '%s'（D6 跟键走）" % BOUNDS_KEY)
		return {"ok": false, "errors": errors}
	var bounds_block: Dictionary = table[BOUNDS_KEY]
	for key: String in numeric_keys:
		if not bounds_block.has(key):
			errors.append("数值键 '%s' 缺护栏声明（防改数不改护栏）" % key)
			continue
		var bound: Variant = bounds_block[key]
		if bound is not Array or bound.size() != 2:
			errors.append("键 '%s' 的护栏必须是 [min, max] 二元数组" % key)
	return {"ok": errors.is_empty(), "errors": errors}


## 键名拼写自检：期望键集合与表实际键集合精确相等（缺键/多余键都报错）
static func validate_key_spelling(table: Dictionary, expected_keys: Array[String]) -> Dictionary:
	var errors: Array[String] = []
	var actual: Array = table.keys()
	for key: String in expected_keys:
		if not table.has(key):
			errors.append("缺真源键 '%s'" % key)
	for key: Variant in actual:
		if str(key).begins_with("_"):
			# 元数据键（_comment/_bounds 等）豁免拼写比对
			continue
		if key not in expected_keys:
			errors.append("多余未知键 '%s'（键名拼写与真源不符）" % str(key))
	return {"ok": errors.is_empty(), "errors": errors}


static func _type_matches(value: Variant, expected: String) -> bool:
	match expected:
		"int":
			# JSON.parse_string 将所有数字解析为 float；整数值 float 视为 int 兼容
			if value is float:
				return is_equal_approx(value, roundf(value))
			return value is int
		"float":
			return value is float or value is int
		"number":
			return value is float or value is int
		"string":
			return value is String
		"bool":
			return value is bool
		"array":
			return value is Array
		"dict":
			return value is Dictionary
	return true


static func _type_name(value: Variant) -> String:
	if value is Dictionary:
		return "dict"
	if value is Array:
		return "array"
	if value is bool:
		return "bool"
	if value is String:
		return "string"
	if value is float:
		return "float"
	if value is int:
		return "int"
	return "unknown"
