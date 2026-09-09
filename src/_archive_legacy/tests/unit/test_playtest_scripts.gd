extends GutTest

## issue #100 门禁：`docs/playtest/scripts.md` 是 v0.1.5 全部 13 张单 `[P]` 验收的唯一凭据。
## 本用例锁定三件事（对应 issue #100 的三个 [T] 验收点）：
## 1. test_playtest_scripts_has_all_anchors      —— 13 个被 issue 正文逐字引用的锚点存在且索引表可跳转
## 2. test_playtest_script_sections_complete    —— 每节七段齐全（关联/前置/步骤脚本/预期感受/代理指标/判定/取证）
## 3. test_playtest_scripts_numbers_match_data  —— 文档中的关键数值与 src/data 真值一致（防文档漂移）
##
## 动机：`[P]` 是真人试玩验收，无法由 GUT 证明；但"脚本资产本身不缺失、不残缺、不漂移"可以。
## 若本用例亮红，说明 `[P]` 的验收依据本身不成立（比 `[P]` 未勾选更严重）。

const SCRIPTS_PATH: String = "res://docs/playtest/scripts.md"
const CLOCK_PATH: String = "res://src/data/clock.json"
const ECONOMY_PATH: String = "res://src/data/economy.json"
const EVENTS_PATH: String = "res://src/data/events.json"
const RIVALS_PATH: String = "res://src/data/rivals.json"
const TECHS_PATH: String = "res://src/data/techs.json"
const ASSERTION_BOUNDS_PATH: String = "res://src/data/assertion_bounds.json"

## 13 个锚点 ↔ issue 号（与各 issue 正文的 `docs/playtest/scripts.md#<锚点>` 逐字一致）。
const ANCHORS: Dictionary = {
	"V1-04": 67,
	"批0": 71,
	"RE-02": 72,
	"RP-02": 73,
	"RC-02": 74,
	"REV-03": 75,
	"RK-04": 76,
	"RR-02": 77,
	"RU-02": 78,
	"RS-05": 79,
	"RT-01": 80,
	"RK-06": 81,
	"RF-02": 82,
}

## 每节固定七段（缺失即脚本不可执行）。
const SECTION_MARKERS: PackedStringArray = [
	"**关联**",
	"**前置**",
	"**步骤脚本**",
	"**预期感受**",
	"**代理指标**",
	"**判定**",
	"**取证**",
]

var _doc: String = ""


func before_all() -> void:
	_doc = FileAccess.get_file_as_string(SCRIPTS_PATH)


func test_playtest_scripts_file_exists() -> void:
	assert_false(_doc.is_empty(), "%s 必须存在且非空（13 单 [P] 的验收凭据）" % SCRIPTS_PATH)


func test_playtest_scripts_has_all_anchors() -> void:
	# [T] 验收点 1：13 个锚点存在（`<a id>` 或 `<a name>` 任一形式），且索引表链接指向它们。
	for anchor: String in ANCHORS:
		assert_true(
			(
				_doc.contains('<a id="%s"></a>' % anchor)
				or _doc.contains('<a name="%s"></a>' % anchor)
			),
			"锚点 %s（issue #%d）必须存在，否则 scripts.md#%s 无法跳转" % [anchor, int(ANCHORS[anchor]), anchor]
		)
		assert_true(
			_doc.contains("](#%s)" % anchor),
			"索引表应链接到锚点 %s（issue #%d）" % [anchor, int(ANCHORS[anchor])]
		)
	assert_eq(ANCHORS.size(), 13, "13 单锚点全覆盖（少一个即有一张单的 [P] 无凭据）")


func test_playtest_script_sections_complete() -> void:
	# [T] 验收点 2：每节七段齐全（按锚点切段，段内逐标记断言）。
	for anchor: String in ANCHORS:
		var section: String = _section_of(anchor)
		assert_false(section.is_empty(), "锚点 %s 应能切出正文段" % anchor)
		for marker: String in SECTION_MARKERS:
			assert_true(
				section.contains(marker),
				"脚本 %s（issue #%d）缺少段落 %s" % [anchor, int(ANCHORS[anchor]), marker]
			)


func test_playtest_scripts_numbers_match_data() -> void:
	# [T] 验收点 3：文档中的关键数值与 src/data 真值一致（防"文档写 1600s、表里改了"的漂移）。
	var clock_cfg: Dictionary = DataLoader.load_json(CLOCK_PATH)
	var seconds_per_week: int = int(
		float(clock_cfg["tick_seconds"]) * float(clock_cfg["ticks_per_week"])
	)
	var run_weeks: int = int(clock_cfg["run_weeks"])
	assert_true(_doc.contains("%ds" % seconds_per_week), "应写明 %ds/周" % seconds_per_week)
	assert_true(_doc.contains(str(run_weeks)), "应写明单局 %d 周" % run_weeks)
	assert_true(
		_doc.contains(str(seconds_per_week * run_weeks)),
		"应写明单局总时长 %ds（%d 周 × %ds）" % [seconds_per_week * run_weeks, run_weeks, seconds_per_week]
	)

	# 禁调参数组（交接 016 §4.2）：Σrp_cost / RP 供给带 / 竞对 L4 / 固定运维 / 事件命中率门 / 饱和阈值。
	var techs_cfg: Dictionary = DataLoader.load_json(TECHS_PATH)
	var rp_cost_total: int = 0
	for node_id: String in techs_cfg["nodes"]:
		rp_cost_total += int(techs_cfg["nodes"][node_id].get("rp_cost", 0))
	assert_true(_doc.contains(str(rp_cost_total)), "应写明 Σrp_cost %d（禁调）" % rp_cost_total)

	var bounds: Dictionary = DataLoader.load_json(ASSERTION_BOUNDS_PATH)["v6_tech_lit_distribution"]
	for key: String in ["supply_band_rp_min", "supply_band_rp_max"]:
		assert_true(
			_doc.contains(str(int(bounds[key]))), "应写明 RP 供给带端点 %s=%d" % [key, int(bounds[key])]
		)

	var rivals_cfg: Dictionary = DataLoader.load_json(RIVALS_PATH)
	var max_launch_score: float = 0.0
	for row_variant: Variant in rivals_cfg["timeline"]:
		var row: Dictionary = row_variant
		if str(row.get("type", "")) == "launch":
			max_launch_score = maxf(max_launch_score, float(row.get("score", 0.0)))
	assert_gt(max_launch_score, 0.0, "rivals.json 应存在 launch 行（竞对发版分真源）")
	assert_true(_doc.contains(str(int(max_launch_score))), "应写明竞对最高发版分 %d" % int(max_launch_score))

	var economy_cfg: Dictionary = DataLoader.load_json(ECONOMY_PATH)
	assert_true(
		_doc.contains(str(int(economy_cfg["upkeep_weekly"]))),
		"应写明固定运维 %d/周" % int(economy_cfg["upkeep_weekly"])
	)

	var events_cfg: Dictionary = DataLoader.load_json(EVENTS_PATH)
	assert_true(
		_doc.contains(str(events_cfg["event_spec"]["p_week"])),
		"应写明事件命中率门 p_week=%s" % str(events_cfg["event_spec"]["p_week"])
	)


## 按锚点切出该脚本的正文段（到下一个锚点为止；别名锚点包含在内）。
func _section_of(anchor: String) -> String:
	var start: int = _doc.find('<a id="%s"></a>' % anchor)
	if start < 0:
		start = _doc.find('<a name="%s"></a>' % anchor)
	if start < 0:
		return ""
	var end: int = _doc.length()
	for other: String in ANCHORS:
		if other == anchor:
			continue
		var other_idx: int = _doc.find('<a id="%s"></a>' % other)
		if other_idx > start and other_idx < end:
			end = other_idx
	return _doc.substr(start, end - start)
