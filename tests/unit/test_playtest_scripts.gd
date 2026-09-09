extends GutTest
## #154 试玩脚本 13→32 单落位 + DoD 闭环验收（issue #154 两条 [T]）：
## - test_playtest_scripts_format：docs/playtest/scripts.md 格式门禁——32 锚点
##   id 全覆盖（v0.1.5 13 单 → v1.0.0 32 单演进已登记）且每单含 前置/操作/
##   预期/代理指标 四段式（issue-spec §6 三段式 + 预期感受拆分为预期列）；
## - test_playtest_p_unchecked：全文 [P] 勾选框全部未勾（禁 agent 代勾，留真人）。
## 真源：issue-spec.md §6；release-plan-100 §〇 DoD；各 issue [P] 原文。

const SCRIPTS_PATH: String = "res://docs/playtest/scripts.md"
const PREFIX := "PT-"
## v1.0.0 全部 32 锚点（#123–#154 每单 1 [P]；数字源=issue 矩阵盘点）
const EXPECTED_ANCHOR_IDS: Array[String] = [
	"PT-123",
	"PT-124",
	"PT-125",
	"PT-126",
	"PT-127",
	"PT-128",
	"PT-129",
	"PT-130",
	"PT-131",
	"PT-132",
	"PT-133",
	"PT-134",
	"PT-135",
	"PT-136",
	"PT-137",
	"PT-138",
	"PT-139",
	"PT-140",
	"PT-141",
	"PT-142",
	"PT-143",
	"PT-144",
	"PT-145",
	"PT-146",
	"PT-147",
	"PT-148",
	"PT-149",
	"PT-150",
	"PT-151",
	"PT-152",
	"PT-153",
	"PT-154",
]
const SECTION_MARKERS: Array[String] = ["**前置**：", "**操作**：", "**预期**：", "**代理指标**："]


func test_playtest_scripts_format() -> void:
	var lines := _read_script_lines()
	assert_true(lines.size() > 100, "scripts.md 加载且非空（%d 行）" % lines.size())
	# 1) 每个锚点 id 至少出现一次（格式锚点行 "### PT-###"）
	for anchor_id: String in EXPECTED_ANCHOR_IDS:
		assert_true(
			_any_line_contains(lines, "### " + anchor_id),
			"缺锚点节 %s" % anchor_id,
		)
	# 2) 锚点节数量恰为 32（不允许多余/重复节）
	var anchor_count := _count_anchor_sections(lines)
	assert_eq(anchor_count, EXPECTED_ANCHOR_IDS.size(), "锚点节数=32")
	# 3) 四段式：每个锚点节内 前置/操作/预期/代理指标 标记齐全
	var sections := _split_anchor_sections(lines)
	for anchor_id: String in EXPECTED_ANCHOR_IDS:
		var section: Array[String] = []
		for item: Variant in sections.get(anchor_id, []) as Array:
			section.append(str(item))
		assert_false(section.is_empty(), "锚点 %s 有正文" % anchor_id)
		for marker: String in SECTION_MARKERS:
			assert_true(
				_any_line_contains(section, marker),
				"%s 缺四段式标记 %s" % [anchor_id, marker.trim_suffix("：")],
			)
	# 4) DoD 闭环锚点（PT-154）含教学节拍链的承接（release-plan §〇 口径）
	var dod_items: Array = sections.get("PT-154", [])
	var dod_section: Array[String] = []
	for item: Variant in dod_items:
		dod_section.append(str(item))
	assert_true(_any_line_contains(dod_section, "W1"), "PT-154 含 W1")
	assert_true(_any_line_contains(dod_section, "W10"), "PT-154 含 W10")
	assert_true(_any_line_contains(dod_section, "想截图"), "PT-154 含想截图判据")
	# 5) 附录 A 自检表：32 行锚点映射齐全（"| PT-### | #<n> |"）
	for anchor_id: String in EXPECTED_ANCHOR_IDS:
		assert_true(
			_any_line_contains(lines, "| %s | #%s |" % [anchor_id, anchor_id.trim_prefix(PREFIX)]),
			"附录 A 缺映射行 %s" % anchor_id,
		)
	# 6) 关键数据键引用备案（附录 B 数值引用，禁止脚本裸硬编码新数值）
	var has_appendix_b := _any_line_contains(lines, "附录 B")
	assert_true(has_appendix_b, "数值引用核对表存在")


func test_playtest_p_unchecked() -> void:
	# [P] 勾选=真人试玩后的唯一凭据；agent 禁代勾（issue-spec §6）
	var lines := _read_script_lines()
	var unchecked := 0
	for line: String in lines:
		if line.contains("- [ ] [P]"):
			unchecked += 1
		assert_false(line.contains("- [x] [P]"), "存在已勾 [P]（禁 agent 代勾）: %s" % line)
	assert_eq(unchecked, EXPECTED_ANCHOR_IDS.size(), "每个锚点恰一个未勾 [P] 行")
	# 附带：卷首 13→32 演进登记在案（防 v0.1.5 数字残留回潮）
	assert_true(
		_any_line_contains(lines, "32 张单"),
		"卷首覆盖范围=32 单（13→32 演进登记）",
	)


## ---------- 私有辅助 ----------


## 读 md 全文为行数组（#124 text_keys_fixture 同款 res:// 读取；中文保留）
func _read_script_lines() -> Array[String]:
	var file := FileAccess.open(SCRIPTS_PATH, FileAccess.READ)
	assert_true(file != null, "可打开 scripts.md（%s）" % SCRIPTS_PATH)
	if file == null:
		return []
	var text: String = file.get_as_text()
	file.close()
	var raw := text.split("\n")
	var lines: Array[String] = []
	for line: Variant in raw:
		lines.append(str(line))
	return lines


func _any_line_contains(lines: Array[String], needle: String) -> bool:
	for line: String in lines:
		if line.contains(needle):
			return true
	return false


func _count_anchor_sections(lines: Array[String]) -> int:
	var count := 0
	for line: String in lines:
		if line.begins_with("### " + PREFIX):
			count += 1
	return count


## 按 "### PT-<n>" 切块：{锚点 id: 该节行数组（不含标题行）}
func _split_anchor_sections(lines: Array[String]) -> Dictionary:
	var sections := {}
	var current_id := ""
	for line: String in lines:
		if line.begins_with("### " + PREFIX):
			current_id = line.trim_prefix("### ").split(" ")[0]
			sections[current_id] = []
		elif not current_id.is_empty() and line.begins_with("## ") and current_id != "":
			current_id = ""  # 遇到下一级大节停止收集
		elif not current_id.is_empty():
			(sections[current_id] as Array).append(line)
	return sections
