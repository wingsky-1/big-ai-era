extends GutTest

## 文本体系三断言测试（issue #2 / DR-010）：
## 1. 断链（missing）：所有代码路径引用的键必须存在于 texts.json；
## 2. 死键（dead）：texts.json 里代码不再引用的键必须进入 TEST_KEYS 白名单；
## 3. 长度（too_long）：插值结果超出该键 max_len 即失败（{var} 按 0 字计，
##    结构化数值行由 Formatter 调用方豁免，不在本断言范围）。
## 另覆盖：防二次解析（插值值含 "{week}" 不被展开）、变量声明一致性、
## 敏感词表结构。TEST_KEYS 是唯一手工维护点——PR 消费新键时在此同步登记。

const TEXTS_PATH: String = "res://src/data/texts.json"

## 43 键起步集白名单：尚未被代码消费的键登记在此（key -> 说明），
## 出现在这里即豁免死键断言；PR 接入消费后应移出白名单并同步消费点。
const TEST_KEYS: Dictionary = {
	"opening_line_intro": "开场白 4 句——PR9b 开场流程接入",
	"opening_line_goal": "开场白 4 句——PR9b 开场流程接入",
	"opening_line_rival": "开场白 4 句——PR9b 开场流程接入",
	"opening_line_hint": "开场白 4 句——PR9b 开场流程接入",
	"naming_title": "命名域——PR9b 命名仪式接入",
	"naming_prompt": "命名域——PR9b 命名仪式接入",
	"naming_input_hint": "命名域——PR9b 命名仪式接入",
	"naming_button_submit": "命名域——PR9b 命名仪式接入",
	"naming_button_skip": "命名域——PR9b 命名仪式接入",
	"naming_too_long_toast": "命名域——PR6 命名校验接入",
	"naming_sensitive_toast": "命名域——PR6 命名校验接入",
	"naming_empty_toast": "命名域——PR6 命名校验接入",
	"naming_success_toast": "命名域——PR6 命名通路接入",
	"naming_banner": "命名域——PR9b 出分播报接入",
	"naming_default_toast": "命名域——PR6 默认名池接入",
	"naming_fallback_01": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_02": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_03": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_04": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_05": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_06": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_07": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_08": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_09": "默认名池 10 个——PR6 轮转消费（数据键）",
	"naming_fallback_10": "默认名池 10 个——PR6 轮转消费（数据键）",
	"report_headline": "周报 6 模板——PR4 周结接入",
	"report_money_row": "周报 6 模板——PR4 周结接入（结构化数值行，长度豁免）",
	"report_reputation_row": "周报 6 模板——PR4 周结接入（结构化数值行，长度豁免）",
	"report_event_row": "周报 6 模板——PR7 事件接入",
	"report_fog_row": "周报 6 模板——PR5 迷雾接入",
	"report_training_row": "周报 6 模板——PR6 训练接入",
	"sys_app_title": "sys 常驻——PR9a 标题渲染接入",
	"sys_week_label": "sys 常驻——PR9a 资源栏接入",
	"sys_money_label": "sys 常驻——PR9a 资源栏接入",
	"sys_compute_label": "sys 常驻——PR9a 资源栏接入",
	"sys_influence_label": "sys 常驻——PR9a 资源栏接入",
	"sys_speed_paused": "sys 常驻——PR3 暂停键接入",
	"sys_save_hint": "sys 常驻——PR8 存档提示接入",
	"sys_menu_new_game": "sys 常驻——MENU 接入",
	"sys_menu_continue": "sys 常驻——MENU 接入",
	"report_quiet_week": "周报兜底——批 1a 周报 UI 修复接入",
	"compute_upgrade_button": "买卡入口——批 1c 资源栏按钮接入",
	"compute_upgrade_maxed": "买卡入口——批 1c 顶档提示接入",
}

## 各插值变量的引用样例值（PR 消费点的最长口径；{var} 按 0 字计，长度断言用）。
const REFERENCE_VALUES: Dictionary = {
	"name": "十二个字符的名字就是它了",  # 12 字 = 命名上限
	"week": "160",
	"income": "¥9999万",
	"expense": "¥9999万",
	"net": "¥9999万",
	"influence": "9999",
	"influence_delta": "+¥9999万",
	"headline": "",
	"event_text": "",
	"fog_text": "",
	"training_text": "",
}


func test_texts_table_shape_is_valid() -> void:
	assert_true(TextService.is_enabled(), "TextService 静态初始化应成功（熔断即全断言空洞通过）")
	var texts: Dictionary = DataLoader.load_json(TEXTS_PATH)
	assert_eq(texts.size(), 43, "起步集应为 43 键（DR-010 起步集约定 + 批 1a 三键）")
	for key: String in texts:
		var entry: Variant = texts[key]
		assert_true(entry is Dictionary, "键 %s 应为对象条目" % key)
		if entry is not Dictionary:
			continue
		var entry_dict: Dictionary = entry
		assert_true(entry_dict.has("text"), "键 %s 缺 text" % key)
		assert_true(entry_dict.has("max_len"), "键 %s 缺 max_len" % key)
		assert_true(entry_dict.get("vars", null) is Array, "键 %s 的 vars 应为数组" % key)
		assert_true(int(entry_dict.get("max_len", -1)) > 0, "键 %s 的 max_len 应为正数" % key)


func test_no_dead_keys_and_no_untracked_keys() -> void:
	# 死键方向：白名单必须与表一致——表里不存在或表里多出的键都算漂移。
	var texts: Dictionary = DataLoader.load_json(TEXTS_PATH)
	for key: String in TEST_KEYS:
		assert_true(texts.has(key), "白名单键 %s 不在 texts.json（表被删改，需同步白名单）" % key)
	for key: String in texts:
		assert_true(TEST_KEYS.has(key), "texts.json 新键 %s 未登记白名单（禁止无消费无登记的键）" % key)
	assert_eq(texts.size(), TEST_KEYS.size(), "白名单与表键数应一致")


func test_no_linked_key_breaks_on_whitelist_template_variables() -> void:
	# 断链方向①：每个键模板引用的 {var} 必须在该键 vars 中声明（防漏声明）。
	var texts: Dictionary = DataLoader.load_json(TEXTS_PATH)
	for key: String in texts:
		var entry: Dictionary = texts[key]
		var declared: Array = entry.get("vars", [])
		for name in TextService.template_variables(key):
			assert_has(declared, name, "键 %s 模板使用了未声明变量 {%s}" % [key, name])


func test_format_rejects_undeclared_variable_usage() -> void:
	# 声明了 vars 的键在 vars 为空时插值应报错并被消费（防错插值；同键同变量去重）。
	TextService.format("naming_success_toast")
	assert_push_error("missing variable", "缺变量插值应有错误提示")
	TextService.format("report_money_row", {"income": "¥1万", "expense": "¥1万"})
	assert_push_error("missing variable", "收支行缺 net 变量应报错")


func test_stat_line_keys_are_exempted_from_entry_limit() -> void:
	# 结构化数值行豁免口径生效验证：max_len 已上浮防呆（60），引用插值后仍远小于上限。
	assert_true(TextService.TEXT_STAT_LINE_KEYS.has("report_money_row"), "收支行应在豁免清单")
	var rendered := (
		TextService
		. format(
			"report_money_row",
			{
				"income": "¥9999万",
				"expense": "¥9999万",
				"net": "¥9999万",
			}
		)
	)
	assert_eq(rendered.length(), 34, "引用口径下收支行 34 字")
	assert_true(rendered.length() <= TextService.max_len("report_money_row"), "防呆上限应容纳引用口径")


func test_no_too_long_after_reference_interpolation() -> void:
	# 长度断言：以引用值做最长插值后，结果不超过 max_len（{var} 按 0 字计口径）。
	var texts: Dictionary = DataLoader.load_json(TEXTS_PATH)
	for key: String in texts:
		var entry: Dictionary = texts[key]
		var variables: Dictionary = {}
		for name: String in entry.get("vars", []):
			variables[name] = _reference_value(name)
		var rendered := TextService.format(key, variables)
		assert_true(
			rendered.length() <= int(entry["max_len"]),
			"键 %s 插值后 %d 字超上限 %d：%s" % [key, rendered.length(), int(entry["max_len"]), rendered]
		)


func test_anti_double_parse_player_name_injection() -> void:
	# 玩家名含 {week} 等模板记号：只展开自身变量，绝不二次解析。
	var evil := "{week}{name}收"
	var rendered := TextService.format("naming_success_toast", {"name": evil})
	assert_eq(rendered, "「{week}{name}收」正式发布！", "插值值内的花括号记号必须原样保留，不得二次解析")
	assert_false(rendered.contains("第"), "注入值不应触发其它模板的展开")


func test_anti_double_parse_nested_brace_value() -> void:
	# 极端嵌套：值含配平花括号也不展开任何记号。
	var rendered := TextService.format("naming_success_toast", {"name": "{a{b}c}"})
	assert_eq(rendered, "「{a{b}c}」正式发布！", "嵌套花括号值原样保留")


func test_missing_and_dead_key_service_paths() -> void:
	# 服务级断链/死键行为：未知键报错返回空串（由三断言在 CI 兜底）。
	assert_eq(TextService.text("no_such_key"), "")
	assert_push_error("missing key", "未知键应有错误提示")
	assert_eq(TextService.format("no_such_key", {}), "")
	assert_eq(TextService.max_len("no_such_key"), -1)


func test_default_name_pool_round_robin_without_rng() -> void:
	# 默认名池 10 个：确定性轮转、四系命名不重复（round3 Minor：零 RNG）。
	var seen: Dictionary = {}
	for i in 10:
		var name := TextService.default_name(i)
		assert_false(seen.has(name), "名池第 %d 个不应重复：%s" % [i, name])
		seen[name] = true
	assert_eq(TextService.default_name(10), TextService.default_name(0), "游标应回卷")


func test_default_name_pool_matches_texts_table() -> void:
	# 服务内名池与 texts.json 的 naming_fallback_* 数据键一致（单一事实源在表）。
	for i in 10:
		var key := "naming_fallback_%02d" % (i + 1)
		assert_eq(
			TextService.default_name(i), TextService.text(key), "名池第 %d 个应与 %s 一致" % [i + 1, key]
		)


func test_sensitive_words_table_is_structured() -> void:
	var table: Dictionary = DataLoader.load_json(TextService.SENSITIVE_WORDS_PATH)
	assert_true(table.has("wordlist"), "敏感词表应有 wordlist 层")
	assert_true(table.has("sensitive_words"), "敏感词表应有 sensitive_words 层")
	assert_true((table["wordlist"] as Array).size() >= 5, "wordlist 自造词层不应为空")
	assert_true((table["sensitive_words"] as Array).size() >= 30, "敏感词表应满足 30±词起步量")
	for word: String in (table["wordlist"] as Array) + (table["sensitive_words"] as Array):
		assert_true(word.length() >= 2, "词 %s 长度不应小于 2（防误伤）" % word)


func test_name_validation_hits_wordlist_and_sensitive_layers() -> void:
	# 层②业务自造词：他人不可冒用换皮名。
	assert_eq(TextService.find_sensitive_word("我的灵犀Chat"), "灵犀", "应命中 wordlist 层")
	# 层③公共敏感词：禁真人公司名。
	assert_eq(TextService.find_sensitive_word("超大模型OpenAI"), "OpenAI", "应命中 sensitive_words 层")
	# 干净名不误伤。
	assert_eq(TextService.find_sensitive_word("璞玉"), "", "单字不误伤：璞玉不应命中璞石")
	assert_true(TextService.is_name_allowed("逐光二号", TextService.name_max_chars()), "干净中文名应放行")
	assert_false(TextService.is_name_allowed("大模型公司腾讯", TextService.name_max_chars()), "命中敏感词应拒绝")
	assert_false(
		TextService.is_name_allowed("名字超长超过十二个字符上限", TextService.name_max_chars()), "超长应拒绝"
	)
	assert_false(TextService.is_name_allowed("Bad!", TextService.name_max_chars()), "非法字符应拒绝")


func test_fallback_name_cursor_respects_name_validation() -> void:
	# 名池兜底与命名校验联动：名池全部名字都应通过敏感词校验（防自锁）。
	for i in 10:
		var name := TextService.default_name(i)
		assert_true(
			TextService.is_name_allowed(name, TextService.name_max_chars()),
			"名池名字 %s 不应被自家词表拦截" % name
		)


func _reference_value(name: String) -> String:
	return str(REFERENCE_VALUES.get(name, ""))
