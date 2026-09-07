class_name TextService
extends RefCounted

## 文本单真源入口（DR-010 / 架构稿 v1.1 §A）：texts.json 的唯一消费面。
## - {var} 单大括号插值，未提供的变量以空串替换；变量值只做一次直拼，绝不参与
##   再次解析——玩家名含 "{week}" 也不会被二次展开（防注入，issue #2 验收点）。
## - 静态初始化即校验表完整性（missing/max_len/vars 一致性）；失败则熔断降级
##   返回空串并 push_error，由三断言测试把表错误红灯暴露出来。
## 纯静态服务、无状态、仅依赖 L0/DataLoader，可无头单测。

const TEXTS_PATH: String = "res://src/data/texts.json"
const SENSITIVE_WORDS_PATH: String = "res://src/data/sensitive_words.json"
const DEFAULT_NAMES: Array[String] = [
	"夸父",
	"精卫",
	"望舒",
	"天枢",
	"织女",
	"晨曦",
	"远航",
	"星火",
	"启明",
	"逐光",
]
const ERROR_MISSING_KEY: String = "missing key"
const ERROR_MISSING_VARIABLE: String = "missing variable"
## 敏感词三层之①：玩家命名 Unicode 白名单（中日韩统一表意文字基本区 +
## 字母数字下划线）；层②③否定词表见 sensitive_words.json。
const NAME_CHARS_PATTERN: String = "^[0-9A-Za-z_一-鿿]+$"
## 结构化数值行（DR-010 长度豁免）：含"标签｜数值"分隔符的模板键。
const TEXT_STAT_LINE_KEYS: PackedStringArray = ["report_money_row", "report_reputation_row"]

static var _table: Dictionary = {}
static var _enabled: bool = true
static var _reported_missing: Dictionary = {}
static var _name_chars: RegEx = null


## 引擎加载脚本时执行一次：装载并校验文本表，失败则熔断（后续方法全部返回空串）。
static func _static_init() -> void:
	var raw := DataLoader.load_json(TEXTS_PATH)
	if raw.is_empty():
		push_error("TextService: 文本表加载失败，文本服务已熔断")
		_enabled = false
		return
	var invalid := _validate_entries(raw)
	if not invalid.is_empty():
		push_error("TextService: 文本表存在非法条目（缺 text/max_len 或 vars 非数组）: %s" % [invalid])
		_enabled = false
		return
	_table = raw
	_name_chars = RegEx.create_from_string(NAME_CHARS_PATTERN)
	if _name_chars == null or _name_chars.search("夸父") == null:
		# 白名单正则失效 = 敏感词层①未生效，熔断并由三断言测试暴露
		push_error("TextService: Unicode 白名单正则失效，敏感词层①未生效")
		_enabled = false


## 取原文案（无插值）。键不存在时 push_error 并返回空串（同键去重，防刷屏）。
static func text(key: String) -> String:
	if not _enabled:
		return ""
	var entry: Variant = _table.get(key)
	if entry is not Dictionary:
		if not _reported_missing.has("key/" + key):
			_reported_missing["key/" + key] = true
			push_error("TextService: %s '%s'" % [ERROR_MISSING_KEY, key])
		return ""
	return str((entry as Dictionary).get("text", ""))


## 取文案并做 {var} 单次插值。vars 的键必须与模板声明一致，多余键忽略、
## 缺失键以空串替换并 push_error。插值值不参与再次解析（防注入）。
static func format(key: String, variables: Dictionary = {}) -> String:
	var template := text(key)
	if template.is_empty() or not _enabled:
		return template
	var result := ""
	var pos := 0
	while true:
		var open := template.find("{", pos)
		if open < 0:
			result += template.substr(pos)
			break
		var close := template.find("}", open + 1)
		if close < 0:
			result += template.substr(pos)
			break
		result += template.substr(pos, open - pos)
		var name := template.substr(open + 1, close - open - 1)
		if variables.has(name):
			result += str(variables[name])
		elif not _reported_missing.has(key + "/" + name):
			# 同键同变量只报一次（测试按条消费 push_error）
			_reported_missing[key + "/" + name] = true
			push_error("TextService: %s '%s' in '%s'" % [ERROR_MISSING_VARIABLE, name, key])
		pos = close + 1
	return result


## 文案的字数上限（max_len 按字符数，DR-010；结构化数值行调用方自行豁免）。
static func max_len(key: String) -> int:
	var entry: Variant = _table.get(key)
	if entry is not Dictionary:
		return -1
	return int((entry as Dictionary).get("max_len", -1))


## 模板中 {var} 引用的变量名集合（供测试断链：模板引用未声明变量=断链）。
static func template_variables(key: String) -> PackedStringArray:
	var entry: Variant = _table.get(key)
	if entry is not Dictionary:
		return PackedStringArray()
	return _extract_variables(str((entry as Dictionary).get("text", "")))


## 文本中残留的单个大括号（不构成 {name} 对，或花括号不成对）→ 死键判定依据。
static func contains_dead_braces(text_string: String) -> bool:
	var depth := 0
	for i in text_string.length():
		match text_string[i]:
			"{":
				depth += 1
			"}":
				depth -= 1
				if depth < 0:
					return true
			_:
				if depth > 0 and text_string[i] != "{" and not _is_var_char(text_string[i]):
					# {name} 中出现非法字符视为残留花括号
					return true
				if depth == 0 and i > 0 and text_string[i - 1] == "}" and text_string[i] == "}":
					return true
	return depth != 0


## 命中否定词表（wordlist+sensitive_words 合并）则返回该词，干净文本返回空串。
static func find_sensitive_word(text_string: String) -> String:
	if not _enabled:
		return ""
	var raw := DataLoader.load_json(SENSITIVE_WORDS_PATH)
	if raw.is_empty():
		return ""
	var words: Dictionary = {}
	for word: String in raw.get("wordlist", []):
		words[word] = true
	for word: String in raw.get("sensitive_words", []):
		words[word] = true
	var lowered := text_string.to_lower()
	for word: String in words:
		if lowered.contains(word.to_lower()):
			return word
	return ""


## 命名通路校验（PR6 消费）：字数上限内 + Unicode 白名单 + 不命中否定词表。
static func is_name_allowed(raw_name: String, limit: int = 12) -> bool:
	if raw_name.is_empty() or raw_name.length() > limit:
		return false
	if _name_chars == null or _name_chars.search(raw_name) == null:
		return false
	return find_sensitive_word(raw_name).is_empty()


## 默认名池确定性轮转（round3 Minor：零 RNG 消费点），游标由调用方入档。
static func default_name(cursor: int) -> String:
	return DEFAULT_NAMES[posmod(cursor, DEFAULT_NAMES.size())]


## 返回表快照（测试驱动用；调用方修改不影响服务内部状态）。
static func table() -> Dictionary:
	return _table.duplicate(true)


static func _validate_entries(raw: Dictionary) -> Array[String]:
	var invalid: Array[String] = []
	for key: String in raw:
		var entry: Variant = raw[key]
		if entry is not Dictionary:
			invalid.append(key)
			continue
		var entry_dict := entry as Dictionary
		if not entry_dict.has("text") or not entry_dict.has("max_len"):
			invalid.append(key)
		elif entry_dict.get("vars", null) is not Array:
			invalid.append(key)
	return invalid


## 扫描 {name} 模板变量名（name 限字母/数字/下划线；不合法片段不产出）。
static func _extract_variables(template: String) -> PackedStringArray:
	var names := PackedStringArray()
	var pos := 0
	while true:
		var open := template.find("{", pos)
		if open < 0:
			break
		var close := template.find("}", open + 1)
		if close < 0:
			break
		var name := template.substr(open + 1, close - open - 1)
		if not name.is_empty() and not name.contains("{") and not name.contains("}"):
			var valid := true
			for i in name.length():
				if not _is_var_char(name[i]):
					valid = false
					break
			if valid:
				names.append(name)
		pos = close + 1
	return names


## 插值变量名字符判定：字母/数字/下划线（is_valid_identifier 覆盖 Unicode 字母，
## 会把中文误判为合法，故自写 ASCII 版本）。
static func _is_var_char(ch: String) -> bool:
	return (
		(ch >= "a" and ch <= "z")
		or (ch >= "A" and ch <= "Z")
		or (ch >= "0" and ch <= "9")
		or ch == "_"
	)
