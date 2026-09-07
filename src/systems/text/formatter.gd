class_name Formatter
extends RefCounted

## 金额与数值行的格式化单真源（DR-010）：
## - 金额一律 ¥ 前缀 + 万缩写（>=1 万自动缩写，<10 万保留 1 位小数并去尾零）；
## - 负号前置（负号在 ¥ 之前：¥-1.2万 形态），全文只有此处生成货币串；
## - 结构化数值行（"标签｜值"）不计入 max_len 字数（DR-010 长度豁免约定）。
## 纯静态、无状态、零依赖，可无头单测。

const MONEY_PREFIX: String = "¥"
const MONEY_UNIT_WAN: String = "万"
const WAN_THRESHOLD: int = 10000
const STAT_LINE_SEPARATOR: String = "｜"


## 金额格式化：12345 -> "¥1.2万"；950000 -> "¥95万"；50000 -> "¥5万"；-12000 -> "¥-1.2万"。
static func format_money(amount: int) -> String:
	var magnitude := absi(amount)
	var magnitude_text := ""
	if magnitude < WAN_THRESHOLD:
		magnitude_text = str(magnitude)
	else:
		var wan := magnitude / float(WAN_THRESHOLD)
		if wan < 100.0:
			magnitude_text = _trim_trailing_zero("%.1f" % wan) + MONEY_UNIT_WAN
		else:
			magnitude_text = str(int(round(wan))) + MONEY_UNIT_WAN
	# 负号前置：负号在数值部分之前，货币符号仅出现一次（"¥-1.2万"）
	return MONEY_PREFIX + ("-" if amount < 0 else "") + magnitude_text


## 带正负号的增量格式（周报 delta 口径）：+12000 -> "+¥1.2万"；-800 -> "-¥800"；0 -> "±¥0"。
static func format_delta(amount: int) -> String:
	if amount > 0:
		return "+" + format_money(amount)
	if amount < 0:
		return format_money(amount)
	return "±" + format_money(amount)


## 结构化数值行："资金｜¥1.2万"。数值部分已由本类格式化，行整体豁免 max_len 检查。
static func format_stat_line(label: String, value_text: String) -> String:
	return label + STAT_LINE_SEPARATOR + value_text


## 小数去尾零："5.0" -> "5"，"1.20" -> "1.2"（内部工具）。
static func _trim_trailing_zero(text: String) -> String:
	if not text.contains("."):
		return text
	var trimmed := text.rstrip("0").rstrip(".")
	return trimmed if not trimmed.is_empty() else "0"
