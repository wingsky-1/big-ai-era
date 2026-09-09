class_name NameFilter
extends RefCounted
## L1/L2 命名三层过滤（#143；真源=onboarding-spec C.5 敏感词三层 +
## ui-ux-spec OP-UX-05）。三层顺序固定（命中即拒，各出独立原因）：
##   1. Unicode 白名单：只放行"中文 CJK 统一表意文字 + 拉丁字母 + 数字 +
##      空格 + 常用标点（-_.·）"；白名单外字符=拒（name_filter_rules 规则句）；
##   2. 词表：侮辱/政治敏感/广告示例词（sensitive_words.json blocklist）；
##   3. 防真人近音：白名单通过的文本做常见近音/全拼/拼音首字母组合检测
##      （sensitive_words.json homophone_map），命中即拒。
## 通用超长前置校验：> name_filter_max_len（sensitive_words.json 表驱动，占位
## 12 字）=拒；空输入=拒（防跳过语义被空串绕过——跳过走 skip_naming 独立口）。
## 三层均过=通过（返回 ok + 清洗后文本）。
## 硬约束：RefCounted 零 Node；纯静态可单测；**数值零硬编码**（长度上限读表、
## 字符类别开关读表）；词表=配置（内容席维护，本类只做机制）。
## 消费方=ModelCeremony（#143 命名待办流校验）与 L3 命名框（#151 批）；本类
## 不读 texts.json 文案键（原因句取键 name_filter_reason 由消费方拼接）。

const SENSITIVE_PATH: String = "res://src/data/sensitive_words.json"

## 表键名（真源=onboarding-spec C.5；键名集中本类防散落字面量）
const KEY_MAX_LEN: String = "name_filter_max_len"
const KEY_WHITELIST: String = "name_filter_whitelist"
const KEY_BLOCKLIST: String = "name_filter_blocklist"
const KEY_HOMOPHONE: String = "name_filter_homophone_map"

## 白名单字符类别键（表内布尔开关；extra=常用标点字符集字符串）
const WL_CJK: String = "cjk"
const WL_LATIN: String = "latin"
const WL_DIGIT: String = "digit"
const WL_SPACE: String = "space"
const WL_EXTRA: String = "extra"

## 拒绝原因稳定字符串（消费方据此拼 name_filter_reason 文案/toast；
## 层序号=三层顺序可 grep）
const REASON_WHITELIST: String = "whitelist"
const REASON_BLOCKLIST: String = "blocklist"
const REASON_HOMOPHONE: String = "homophone"
const REASON_TOO_LONG: String = "too_long"
const REASON_EMPTY: String = "empty"

static var _table: Dictionary = {}


## 校验名字（三层过滤 + 超长 + 空）。参数：text=玩家输入原名。
## 返回 {ok, clean, reason}：
## - ok=true：三层均过，clean=原文本（trim 尾随空白后；白名单含空格，
##   首尾空白不参与命名——防"空格名"绕过空语义）；
## - ok=false：reason=命中层稳定字符串（消费方选原因句/弹层不关闭重输）。
## 表缺失=防御放行（known=false 语义：不因词表故障阻塞游戏，push_error 上报；
## 测试用断言表存在性兜底）。
static func check(text: String) -> Dictionary:
	var table := _ensure_table()
	if table.is_empty():
		return {"ok": true, "clean": text.strip_edges(), "reason": ""}
	var clean := text.strip_edges()
	if clean.is_empty():
		return {"ok": false, "clean": "", "reason": REASON_EMPTY}
	var max_len := int(table.get(KEY_MAX_LEN, 12))
	if clean.length() > max_len:
		return {"ok": false, "clean": "", "reason": REASON_TOO_LONG}
	if not _passes_whitelist(clean, table):
		return {"ok": false, "clean": "", "reason": REASON_WHITELIST}
	if _hits_blocklist(clean, table):
		return {"ok": false, "clean": "", "reason": REASON_BLOCKLIST}
	if _hits_homophone(clean, table):
		return {"ok": false, "clean": "", "reason": REASON_HOMOPHONE}
	return {"ok": true, "clean": clean, "reason": ""}


## ---------- 白名单明细（单字符可测；供 L3 输入法预拦截/提示） ----------


## 单字符是否白名单内（字符类别表驱动）。超长/空/词表命中=字符级不管，
## 由 check 整体判定（本函数只做"字符是否被允许"）。
static func is_char_allowed(char: String) -> bool:
	var table := _ensure_table()
	if table.is_empty():
		return true
	var wl: Variant = table.get(KEY_WHITELIST)
	if wl is not Dictionary:
		return true
	var allowed := wl as Dictionary
	if char.length() != 1:
		return false
	var cp := char.unicode_at(0)
	if bool(allowed.get(WL_CJK, false)) and cp >= 0x4E00 and cp <= 0x9FFF:
		return true
	if bool(allowed.get(WL_LATIN, false)) and _is_latin(cp):
		return true
	if bool(allowed.get(WL_DIGIT, false)) and _is_digit(cp):
		return true
	if bool(allowed.get(WL_SPACE, false)) and (char == " " or char == "\t"):
		return true
	var extra := str(allowed.get(WL_EXTRA, ""))
	return extra.contains(char)


## ---------- 私有 ----------


## 白名单整体校验：逐字符放行（字符类别表驱动；防"类别开关关闭仍放行"）
static func _passes_whitelist(text: String, table: Dictionary) -> bool:
	var wl: Variant = table.get(KEY_WHITELIST)
	if wl is not Dictionary:
		return true
	var allowed := wl as Dictionary
	for i: int in text.length():
		var char := text[i]
		var cp := char.unicode_at(0)
		var pass_char := false
		if bool(allowed.get(WL_CJK, false)) and cp >= 0x4E00 and cp <= 0x9FFF:
			pass_char = true
		elif bool(allowed.get(WL_LATIN, false)) and _is_latin(cp):
			pass_char = true
		elif bool(allowed.get(WL_DIGIT, false)) and _is_digit(cp):
			pass_char = true
		elif bool(allowed.get(WL_SPACE, false)) and (char == " " or char == "\t"):
			pass_char = true
		elif str(allowed.get(WL_EXTRA, "")).contains(char):
			pass_char = true
		if not pass_char:
			return false
	return true


## 词表命中（blocklist 子串匹配；表内项=全等整词或子串均拒——内容席按
## 词条粒度维护，本类子串匹配保守拦截）
static func _hits_blocklist(text: String, table: Dictionary) -> bool:
	var list: Variant = table.get(KEY_BLOCKLIST)
	if list is not Array:
		return false
	for item: Variant in list as Array:
		if text.contains(str(item)):
			return true
	return false


## 近音映射命中（homophone_map 子串匹配；全拼/拼音首字母大小写不敏感——
## 转小写比对，防 XiJinPing/XJP 变体绕过）
static func _hits_homophone(text: String, table: Dictionary) -> bool:
	var list: Variant = table.get(KEY_HOMOPHONE)
	if list is not Array:
		return false
	var lowered := text.to_lower()
	for item: Variant in list as Array:
		if lowered.contains(str(item).to_lower()):
			return true
	return false


static func _ensure_table() -> Dictionary:
	if _table.is_empty():
		var loaded := DataLoader.load_json(SENSITIVE_PATH)
		if loaded.is_empty():
			push_error("NameFilter: sensitive_words.json 加载失败")
			return {}
		_table = loaded
	return _table


static func _is_latin(cp: int) -> bool:
	return (
		(cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A) or (cp >= 0xC0 and cp <= 0x24F)
	)


static func _is_digit(cp: int) -> bool:
	return cp >= 0x30 and cp <= 0x39
