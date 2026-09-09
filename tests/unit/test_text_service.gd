extends GutTest
## #124 验收点 1-4 GUT 断言（texts-keys.md 键名/长度/插值/禁用原因）。
## 真源：docs/blueprints/specs/texts-keys.md §二 全表（texts.json 同源转录）。
## 长度口径=显示宽：CJK/全角=1、ASCII/半角=0.5，向上取整（键表「长度」列自检 ✓ 口径，
## 如 staff_collab_same「同岗组合 ×1.0」≈6.5→7≤8 选项）。
## 预算：选项≤8 / toast≤20 / 标题≤12 / 周报≤30 / 正文≤60。
## 键名/类别常量由 TextKeysFixture 提供（texts-keys.md §二 复刻，独立文件控 tests 单文件行数）。
## 值未定稿占位键 model_train_blocked_reason（空串）豁免预算/插值断言，键名仍须存在。

const TEXTS_PATH: String = "res://src/data/texts.json"


## 顶层数据键（排除 _ 前缀元数据键：_comment 等）
static func _data_keys(table: Dictionary) -> Array[String]:
	var data_keys: Array[String] = []
	for key: String in table.keys():
		if not key.begins_with("_"):
			data_keys.append(key)
	return data_keys


## 显示宽：CJK/全角=1、ASCII/半角=0.5，向上取整（与键表「长度」列口径一致）
static func _display_len(text_string: String) -> int:
	var width := 0.0
	for ch: String in text_string:
		width += 1.0 if ch.unicode_at(0) > 127 else 0.5
	return ceili(width)


func _load_table() -> Dictionary:
	var table := DataLoader.load_json(TEXTS_PATH)
	assert_false(table.is_empty(), "texts.json 可加载（路径 %s）" % TEXTS_PATH)
	return table


## ===== DoD 用例 1：键名唯一 =====
func test_text_keys_unique() -> void:
	var table := _load_table()
	var expected := TextKeysFixture.source_keys()
	assert_eq(expected.size(), 337, "texts-keys.md §二 全表键数=337（展开/排除/占位处理）")
	var data_keys := _data_keys(table)
	assert_eq(
		data_keys.size(),
		expected.size(),
		"texts.json 数据键数与全表一致（无多余/无缺键），实际 %d 期望 %d" % [data_keys.size(), expected.size()],
	)
	for key: String in expected:
		assert_true(table.has(key), "texts.json 缺真源键: %s" % key)
		assert_true(table[key] is String, "键 %s 值必须为字符串" % key)


## ===== DoD 用例 2：长度预算 =====
func test_text_key_length_budget() -> void:
	var table := _load_table()
	_assert_budget(table, TextKeysFixture.KEYS_OPTION, 8, "选项")
	_assert_budget(table, TextKeysFixture.KEYS_TOAST, 20, "toast")
	_assert_budget(table, TextKeysFixture.KEYS_TITLE, 12, "标题")
	_assert_budget(table, TextKeysFixture.KEYS_REPORT, 30, "周报")
	_assert_budget(table, TextKeysFixture.KEYS_BODY, 60, "正文")


func _assert_budget(
	table: Dictionary, keys: Array[String], max_len: int, group_name: String
) -> void:
	for key: String in keys:
		if key in TextKeysFixture.PENDING_EMPTY_KEYS:
			continue
		var value: String = table[key]
		var measured := _display_len(value)
		assert_true(
			measured <= max_len,
			"键 %s 属%s（≤%d），实测显示宽 %d 超预算: %s" % [key, group_name, max_len, measured, value],
		)


## ===== DoD 用例 3：插值完整 =====
func test_text_interpolation_complete() -> void:
	var table := _load_table()
	var broken := TextService.missing_interp_variables()
	assert_true(
		broken.is_empty(),
		"含插值键的变量缺失=断链: %s" % str(broken),
	)
	for key: String in table.keys():
		for name: String in TextService.template_variables(key):
			assert_true(
				TextService.SUPPORTED_INTERP_VARS.has(name),
				"键 %s 模板变量 <%s> TextService 未提供" % [key, name],
			)


## ===== DoD 用例 4：禁用原因单一源 =====
## 语义：texts-keys §四「*_disabled_reason 由 L2 get_*_view() 提供单一值」——
## 每个禁用原因键=一个原因枚举值的话术承载（键家族完整、非空、无 <X> 断链），
## 键表内 *_disabled_reason 全部为无插值单句（与 L2 原因枚举一一对应）。
func test_disabled_reason_single_source() -> void:
	var table := _load_table()
	for key: String in TextKeysFixture.REASON_KEYS:
		assert_true(table.has(key), "禁用原因键缺失（L2 枚举无话术承载）: %s" % key)
		if key in TextKeysFixture.PENDING_EMPTY_KEYS:
			continue
		var value: String = table[key]
		assert_true(not value.is_empty(), "禁用原因键值为空（单一原因源必须有话术）: %s" % key)
		if key.ends_with("_disabled_reason"):
			assert_true(
				not value.contains("<") and not value.contains(">"),
				"禁用原因键 %s 是 L2 单一原因枚举的映射，禁止 <X> 断链: %s" % [key, value],
			)
	# 通用原因键（_reason 非 disabled）允许 <X> 指名（如 <节点名>），由
	# test_text_interpolation_complete 统一兜底插值完整。


## ===== 补充：真实插值冒烟 =====
func test_format_interpolation_smoke() -> void:
	var formatted := TextService.format(
		"onb_first_score_byline", {"实验室名": "北辰", "日期": "2026-10-01"}
	)
	assert_eq(formatted, "署名：北辰 实验室 · 2026-10-01", "两个 <X> 占位被正确替换")
	assert_eq(
		TextService.text("onb_first_score_byline"),
		"署名：<实验室名> 实验室 · <日期>",
		"原文案保留 <X> 占位（键值不落地机制纪律）",
	)


## ===== 补充：键缺失报错分支 =====
func test_missing_key_reports_and_returns_safe() -> void:
	var missing_value := TextService.text("no_such_key_124")
	assert_eq(missing_value, "", "键缺失返回安全空串")
	assert_push_error("missing key", "键缺失必须 push_error（断言错误语义）")
