extends GutTest
## #145 验收点 2：Dock 三键冻结——任务板/科技树/暂停（增键=变更控制标志位）
## （GUT：`test_dock_three_keys_frozen`）。
## 真源=ui-ux-spec A.2（Dock 三键冻结注册纪律：任务板/科技树/暂停；增键=
## 变更控制）+ B.2 Dock 三键行 + texts.json ui_dock_taskboard/tree/pause。
## 断言：Dock 冻结标志位=true；三键精确集合=TASK_BOARD/TECH_TREE/PAUSE_MENU
## （不多不少）；三键文案键在 texts.json 已落盘。

const DOCK_BUTTON_PANELS: Array = [
	PanelStack.PanelId.TASK_BOARD,
	PanelStack.PanelId.TECH_TREE,
	PanelStack.PanelId.PAUSE_MENU,
]


func test_dock_three_keys_frozen() -> void:
	# 冻结标志位（增键=变更控制：改 DOCK_KEYS 须过变更流程）
	assert_true(PanelStack.DOCK_KEYS_FROZEN, "Dock 冻结标志位=true（增键=变更控制）")
	# 三键精确集合=冻结常量（不多不少）
	var frozen: Array = PanelStack.DOCK_KEYS.duplicate()
	assert_eq(frozen.size(), 3, "Dock 恰 3 键")
	assert_eq(frozen, DOCK_BUTTON_PANELS, "三键=任务板/科技树/暂停（PanelId 冻结集）")
	# 三键均 z1 面板（点开=z1 内容面板通道）
	for panel: PanelStack.PanelId in frozen:
		assert_eq(PanelStack.z_of(panel), 1, "Dock 键全 z1: %s" % panel)
	# 文案键落盘（texts.json ui_dock_*：#124 键面真源）
	var texts := TextService.table()
	for key: String in ["ui_dock_taskboard", "ui_dock_tree", "ui_dock_pause"]:
		assert_true(texts.has(key), "Dock 键文案在位: %s" % key)
		assert_false(str(texts[key]).is_empty(), "Dock 键文案非空: %s" % key)
