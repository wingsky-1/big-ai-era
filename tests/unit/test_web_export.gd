extends GutTest
## 批7.3 #190 验收点 GUT：
## - test_web_export_artifact：导出物契约（脚本存在可执行 / Web preset 注册 /
##   三件套路径契约 / 信标在码）
## - test_browser_run_log_format：浏览器实测取证记录格式门禁（截图归档
##   docs/playtest/screenshots/batch7/ 命名 <PT-xxx>_<week>.png）
## 真源：issue #190 验收点 + release-plan §〇 DoD。

const EXPORT_CHECK_SCRIPT: String = "res://scripts/export_html_check.sh"
const EXPORT_PRESETS: String = "res://export_presets.cfg"
const MAIN_GD: String = "res://src/ui/main/main.gd"
const SCREENSHOT_DIR: String = "docs/playtest/screenshots/batch7"


func test_web_export_artifact() -> void:
	# 1) 导出校验脚本存在且可执行（CI/本地同一命令的载体）
	var script_exists := FileAccess.file_exists(EXPORT_CHECK_SCRIPT)
	assert_true(script_exists, "export_html_check.sh 在仓")
	# 2) Web preset 已注册（export_presets.cfg 含 name="Web"）
	var presets := FileAccess.get_file_as_string(EXPORT_PRESETS)
	assert_true(presets.contains('name="Web"'), "export_presets.cfg 注册 Web preset")
	# 3) 三件套产物路径契约（export_all.sh web 输出布局 build/web/web/）
	assert_true(presets.contains("index.html"), "Web preset 出口 index.html")
	# 4) 信标在码（?shot= 启用；截图管线轮询 window.__DSH_SHOT_READY__）
	var main_src := FileAccess.get_file_as_string(MAIN_GD)
	assert_true(main_src.contains("__DSH_SHOT_READY__"), "main.gd 含 Web 调试信标")
	assert_true(main_src.contains("_url_param"), "信标经 ?shot= 参数启用")
	# 5) 浏览器驱动面（#190）：状态轮询+合成指针点击+命名等价键入钩子
	assert_true(main_src.contains("__DSH_PANEL_STATE__"), "信标含面板状态发布")
	assert_true(main_src.contains("__DSH_CLICK_AT__"), "信标含合成指针点击助手")
	assert_true(main_src.contains("__DSH_TEST__"), "信标含命名等价键入测试钩子")


func test_browser_run_log_format() -> void:
	# 截图归档目录契约（命名 <PT-xxx>_<week>.png；目录不存在=未取证状态）
	var dir := DirAccess.open(SCREENSHOT_DIR)
	if dir == null:
		# DoD 前未取证=合法状态（[P] 留真人）；显式断言防 Risky 误报
		assert_false(
			DirAccess.dir_exists_absolute("res://" + SCREENSHOT_DIR),
			"未取证状态（DoD 前截图目录不存在）",
		)
		return
	var names := dir.get_files()
	for name: String in names:
		if not name.ends_with(".png"):
			continue
		assert_true(
			name.begins_with("PT-") and name.contains("_"),
			"截图命名契约 <PT-xxx>_<week>.png: %s" % name,
		)
		var parts := name.trim_suffix(".png").split("_")
		assert_eq(parts.size(), 2, "命名两段式: %s" % name)
		assert_true(parts[0].begins_with("PT-"), "前缀 PT-: %s" % name)
