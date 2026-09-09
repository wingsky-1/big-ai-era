extends GutTest
## #143 验收点 1：命名框三层过滤（GUT：`test_name_filter_three_layers`）。
## 真源=onboarding-spec C.5（三层顺序）+ ui-ux-spec OP-UX-05：
## - 白名单外字符（如 emoji/emoji/异体字符）→ 拒（reason=whitelist）；
## - 词表命中（侮辱/政治敏感/广告）→ 拒（reason=blocklist）；
## - 防真人近音（组合近音/全拼/拼音首字母）→ 拒（reason=homophone）；
## - 超长（>max_len 表驱动 12 字）→ 拒（reason=too_long）；空→拒（empty）；
## - 合法名（中文/英文/数字/空格/-_.·）→ 过（ok=true，clean=trim 后原名）。
## 弹层不关闭可重输=消费方（ModelCeremony/L3）据 reason 保持 pending 状态，
## 本文件断言过滤层语义（拒绝 reason 齐全可路由）。


func test_name_filter_three_layers() -> void:
	# 层 1：白名单外字符（emoji 不在 CJK/拉丁/数字/空格/-_.· 集）
	var emoji := NameFilter.check("灵犀🚀")
	assert_false(emoji.ok, "emoji 非白名单=拒")
	assert_eq(emoji.reason, NameFilter.REASON_WHITELIST, "白名单外→whitelist 层")
	# 层 2：词表命中（blocklist 示例条目）
	var bad_word := NameFilter.check("傻逼")
	assert_false(bad_word.ok, "词表命中=拒")
	assert_eq(bad_word.reason, NameFilter.REASON_BLOCKLIST, "词表→blocklist 层")
	# 层 3：防真人近音（homophone_map 示例条目：拼音首字母组合）
	var near := NameFilter.check("xjp小助手")
	assert_false(near.ok, "近音表命中=拒")
	assert_eq(near.reason, NameFilter.REASON_HOMOPHONE, "近音→homophone 层")
	# 三层均过：中文+数字合法
	var good := NameFilter.check("灵犀1号")
	assert_true(good.ok, "合法中文数字=过")
	assert_eq(good.clean, "灵犀1号", "clean=原名")


func test_name_filter_whitelist_chars() -> void:
	# 白名单字符明细：中文 CJK/拉丁/数字/空格/常用标点均放行
	for char: String in ["灵", "A", "a", "5", " ", "-", "_", ".", "·"]:
		assert_true(NameFilter.is_char_allowed(char), "白名单字符放行: %s" % char)
	# 白名单外：emoji/全角符号/控制符拒
	for char: String in ["🚀", "（", "\n"]:
		assert_false(NameFilter.is_char_allowed(char), "白名单外字符拒: %s" % char)
	# 组合句通过（标点在内）
	var sentence := NameFilter.check("回声-A.5·试")
	assert_true(sentence.ok, "组合合法名通过")


func test_name_filter_extra_boundaries() -> void:
	# 超长拒（max_len 表驱动 12 字；中文每字=1）
	var long_name := NameFilter.check("一二三四五六七八九十一二三四五")
	assert_false(long_name.ok, ">12 字=拒")
	assert_eq(long_name.reason, NameFilter.REASON_TOO_LONG, "超长→too_long 层")
	# 恰好 12 字=过（边界）
	var edge := NameFilter.check("一二三四五六七八九十一二")
	assert_true(edge.ok, "恰 12 字=过（边界）")
	# 空输入=拒（防空串绕过；跳过走 skip_naming 独立口）
	var empty := NameFilter.check("")
	assert_false(empty.ok, "空=拒")
	assert_eq(empty.reason, NameFilter.REASON_EMPTY, "空→empty 层")
	# 纯空白 trim 后=空=拒
	var spaces := NameFilter.check("   ")
	assert_false(spaces.ok, "纯空格 trim 后空=拒")
	# 大小写不敏感近音（全拼变体大写绕过）
	var upper := NameFilter.check("XJP助手")
	assert_false(upper.ok, "近音大写变体=拒（to_lower 比对）")
