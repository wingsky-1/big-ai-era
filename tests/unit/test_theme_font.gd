extends GutTest

## CJK 字体内嵌回归门禁（v0.1.2）：
## 任何一层收口失效，Web 端都会复现 v0.1.1 豆腐块事故，故逐层断言。

const THEME: Theme = preload("res://src/ui/theme/dark_gold_theme.tres")
const FONT_PATH := "res://assets/fonts/WQY-MicroHei.ttf"


func test_theme_default_font_is_cjk_capable() -> void:
	var font := THEME.default_font
	assert_not_null(font, "dark_gold_theme.default_font 必须指向内嵌字体")
	assert_true(font is FontFile, "default_font 应为 FontFile")
	var font_file := font as FontFile
	assert_eq(font_file.get_font_name(), "WenQuanYi Micro Hei", "应为文泉驿微米黑")
	# 覆盖面抽查：常用界面汉字必须全部有字形，缺字即豆腐
	for codepoint: int in [0x4E2D, ord("资"), ord("算"), ord("誉"), ord("研"), ord("科")]:
		assert_true(font_file.has_char(codepoint), "字体应含字形 U+%04X" % codepoint)


func test_project_custom_theme_fallback() -> void:
	var custom: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_eq(custom, "res://src/ui/theme/dark_gold_theme.tres", "gui/theme/custom 兜底应指向主 Theme")


func test_font_asset_is_real_binary_not_lfs_pointer() -> void:
	var f := FileAccess.open(FONT_PATH, FileAccess.READ)
	assert_not_null(f, "字体资产应可读")
	if f == null:
		return
	var head := f.get_buffer(8)
	# 真 TTF 以 00 01 00 00 开头；LFS 指针文件以 ASCII "version https" 开头
	assert_true(head[0] == 0 and head[1] == 1, "字体文件应为 TrueType 二进制而非 LFS 指针")


func test_gitattributes_exempts_font_and_screenshots() -> void:
	var txt := FileAccess.get_file_as_string("res://.gitattributes")
	assert_true(txt.contains("assets/fonts/*.ttf"), ".gitattributes 应含字体直存豁免")
	assert_true(txt.contains("docs/playtest/screenshots/"), ".gitattributes 应含截图直存豁免")
