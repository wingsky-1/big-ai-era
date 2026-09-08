extends GutTest

## 周报 UI 渲染回归（#72 验收点 2 / RE-02 UI 侧断裂）：
## 此前 main.gd 传 get_resource_view()（无 rows 键）→ 周报恒显兜底文案，收支行不可见。

const WEEKLY_REPORT_SCENE: PackedScene = preload("res://src/ui/modals/weekly_report_dialog.tscn")


func test_weekly_report_renders_money_row() -> void:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(1)
	world.settle_week()

	var report: Dictionary = world.get_last_report()
	assert_false(report.is_empty(), "周结后应有最近一次报告")
	assert_true(report.has("rows"), "周报载荷必须含 rows 键")
	var rows: Array = report["rows"]
	assert_gt(rows.size(), 0, "rows 不应为空")
	assert_string_contains(str(rows[0]), "收支", "首行应为收支行")

	var dialog: WeeklyReportDialog = WEEKLY_REPORT_SCENE.instantiate()
	add_child_autofree(dialog)
	dialog.setup(report)
	await get_tree().process_frame
	await get_tree().process_frame

	var rows_vbox: VBoxContainer = dialog.get_node("%RowsVBox")
	assert_eq(rows_vbox.get_child_count(), rows.size(), "UI 应逐行渲染（不再恒显兜底文案）")
	var first_label: Label = rows_vbox.get_child(0) as Label
	assert_not_null(first_label, "首行应为 Label")
	assert_string_contains(first_label.text, "收支", "首行应渲染收支行")
	assert_false(first_label.text.contains("运转平稳"), "不应是兜底文案")

	# 空报告时仍渲染兜底文案（不出现空白面板）
	dialog.setup({})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(rows_vbox.get_child_count(), 1, "空报告应渲染一行兜底文案")
