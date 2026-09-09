class_name TextService
extends RefCounted
## L1 文案键查表服务（#124）：texts.json 查表 + <X> 插值。
## 键名唯一真源=texts-keys.md（键表中文列即键值，逐字转录 src/data/texts.json）；
## 键缺失/插值变量缺失 = push_error + 返回安全值（熔断语义继承 #128 data_loader）。
## 纯静态、无状态、零 Node 依赖；headless 可单测。autoload 只有 SaveSystem，本类非 autoload。
## 文案键只承载"给人看的话"；数值一律由调用方以插值变量注入（键值零硬编码数值纪律）。

const TEXTS_PATH: String = "res://src/data/texts.json"
## 插值占位形态：<X>（texts-keys 契约；不做业务格式化，只做占位替换）
const INTERP_OPEN: String = "<"
const INTERP_CLOSE: String = ">"
const ERROR_MISSING_KEY: String = "missing key"
const ERROR_MISSING_VARIABLE: String = "missing variable"
## TextService 声明可提供的插值变量全集（真源=texts-keys.md §二 全部 <X> 占位名；
## L2 view 未来以此清单向 format() 传值——文本侧集中契约点，防断链）。
const SUPPORTED_INTERP_VARS: Array[String] = [
	"实验室名",
	"日期",
	"周数",
	"名字",
	"课程",
	"节点名",
	"选题名",
	"基座名",
	"档位名",
	"落后原因",
	"模型名",
	"一句话战绩",
	"标题",
	"论文名",
	"域标签",
	"目标维",
	"面板名",
	"下限",
	"上限",
	"项目名",
	"净流入",
	"周亏",
	"影响",
	## 通用占位（texts.json 27 键裸占位对齐 `<X>` 契约形态后注册；X/Y 语义由
	## 消费方传值——周数/金额/百分比等。批7.2 #189 首消费暴露的既有数据债收口）
	"X",
	"Y",
]

static var _table: Dictionary = {}
static var _enabled: bool = false


## 首次调用时装载表；失败即熔断（后续查询返回安全值并 push_error）。
static func _ensure_loaded() -> void:
	if _enabled:
		return
	if not _table.is_empty():
		_enabled = true
		return
	var raw := DataLoader.load_json(TEXTS_PATH)
	if raw.is_empty():
		push_error("TextService: 文案表加载失败，文本服务已熔断（真源 %s）" % TEXTS_PATH)
		return
	_table = raw
	_enabled = true


## 表是否已成功装载（测试显式断言，防熔断后查询空洞通过）。
static func is_enabled() -> bool:
	_ensure_loaded()
	return _enabled


## 取原文案（无插值）。键缺失时 push_error 并返回空串（安全值）。
static func text(key: String) -> String:
	_ensure_loaded()
	var value: Variant = _table.get(key)
	if value is not String:
		push_error("TextService: %s '%s'" % [ERROR_MISSING_KEY, key])
		return ""
	return value as String


## 取文案并做 <X> 单次插值。variables 未提供的占位变量：push_error 并保留占位原文。
## 插值值只直拼一次，不参与再次解析（防注入）。所有插值变量调用方以字符串提供。
static func format(key: String, variables: Dictionary = {}) -> String:
	var template := text(key)
	if template.is_empty():
		return template
	var result := ""
	var pos := 0
	while true:
		var open_idx := template.find(INTERP_OPEN, pos)
		if open_idx < 0:
			result += template.substr(pos)
			break
		var close_idx := template.find(INTERP_CLOSE, open_idx + INTERP_OPEN.length())
		if close_idx < 0:
			# 未闭合 <X>：视为残留占位，报错并保留原文
			push_error(
				(
					"TextService: %s '%s' in '%s'"
					% [ERROR_MISSING_VARIABLE, template.substr(open_idx), key]
				)
			)
			result += template.substr(pos)
			break
		result += template.substr(pos, open_idx - pos)
		var name := template.substr(
			open_idx + INTERP_OPEN.length(), close_idx - open_idx - INTERP_OPEN.length()
		)
		if variables.has(name):
			result += str(variables[name])
		else:
			push_error("TextService: %s '%s' in '%s'" % [ERROR_MISSING_VARIABLE, name, key])
			result += template.substr(open_idx, close_idx - open_idx + INTERP_CLOSE.length())
		pos = close_idx + INTERP_CLOSE.length()
	return result


## 模板中 <X> 引用的变量名集合（供断链断言：模板变量必须 ⊆ SUPPORTED_INTERP_VARS）。
static func template_variables(key: String) -> PackedStringArray:
	var names := PackedStringArray()
	if not _enabled:
		return names
	var template: Variant = _table.get(key)
	if template is not String:
		return names
	var template_str: String = template
	var pos := 0
	while true:
		var open_idx: int = template_str.find(INTERP_OPEN, pos)
		if open_idx < 0:
			break
		var close_idx: int = template_str.find(INTERP_CLOSE, open_idx + INTERP_OPEN.length())
		if close_idx < 0:
			break
		names.append(
			template_str.substr(
				open_idx + INTERP_OPEN.length(), close_idx - open_idx - INTERP_OPEN.length()
			)
		)
		pos = close_idx + INTERP_CLOSE.length()
	return names


## 文案表快照（测试驱动用；调用方修改不影响服务内部状态）。
static func table() -> Dictionary:
	_ensure_loaded()
	return _table.duplicate(true)


## 插值断链自检：模板引用但服务未声明的变量 → {键: [缺失变量]}（测试消费）。
static func missing_interp_variables() -> Dictionary:
	var broken := {}
	if not is_enabled():
		return broken
	for key: String in _table.keys():
		var missing := PackedStringArray()
		for name: String in template_variables(key):
			if not SUPPORTED_INTERP_VARS.has(name):
				missing.append(name)
		if not missing.is_empty():
			broken[key] = missing
	return broken
