extends GutTest

## AppShell 场景集成冒烟与门禁测试：
## 1. 验证 main.tscn 改造为 AppShell 后的节点与 UniqueName 完整性；
## 2. 验证深色金 Theme、ink3 对比度 ≥4.5:1、速度按钮触控面 ≥48px；
## 3. 验证 src/ui/**/*.gd 零硬编码颜色字面量（Grep 门禁）；
## 4. 验证 ResponsiveLayoutManager 竖屏折叠规则切 visible；
## 5. 迁移旧自检断言（文本管线 40 键等），确保自检资产不丢。

const MAIN_SCENE: PackedScene = preload("res://src/ui/main/main.tscn")
const TOKENS_COLORS: Resource = preload("res://src/ui/theme/tokens_colors.tres")


func test_main_scene_instantiates_and_app_shell_unique_names() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	# Headless 下布局与 _ready 需要显式推两帧
	await get_tree().process_frame
	await get_tree().process_frame

	var main_scene := main as MainScene
	assert_not_null(main_scene, "根脚本应为 MainScene")

	# 1. 验证 AppShell 核心区域 UniqueName 节点完整寻址
	assert_not_null(main.get_node("%ResourceBar"), "%ResourceBar 应存在")
	assert_not_null(main.get_node("%ResourceSubrow"), "%ResourceSubrow 应存在")
	assert_not_null(main.get_node("%WeekBar"), "%WeekBar 应存在")
	assert_not_null(main.get_node("%RivalTrack"), "%RivalTrack 应存在")
	assert_not_null(main.get_node("%Workspace"), "%Workspace 应存在")
	assert_not_null(main.get_node("%Dock"), "%Dock 应存在")
	assert_not_null(main.get_node("%ModalContainer"), "%ModalContainer 应存在")

	# 2. 验证 Dock 三键（砍掉旧原型'事件'键，定稿为科技/周报/暂停）
	assert_not_null(main.get_node("%DockTechBtn"), "%DockTechBtn 应存在")
	assert_not_null(main.get_node("%DockReportBtn"), "%DockReportBtn 应存在")
	assert_not_null(main.get_node("%DockPauseBtn"), "%DockPauseBtn 应存在")
	assert_null(main.get_node_or_null("%DockEventBtn"), "Dock 严禁存在'事件'键（GDD §13 / 否决点 1）")

	# 3. 验证向后兼容旧自检资产
	assert_eq(main_scene.get_text_count(), 43, "文本管线应加载到 43 个键（批 1a 三键）")
	assert_not_null(main_scene.get_world(), "AppShell 应初始化 GameWorld")
	assert_not_null(main_scene.get_driver(), "AppShell 应初始化 GameLoopDriver")


func test_theme_contrast_and_touch_target_bounds() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. 速度按钮触控面 ≥48px (否决点 1 / GDD §13)
	var speed_btns: Array[Button] = [
		main.get_node("%SpeedPauseBtn") as Button,
		main.get_node("%Speed1xBtn") as Button,
		main.get_node("%Speed2xBtn") as Button,
		main.get_node("%Speed4xBtn") as Button,
	]
	for btn: Button in speed_btns:
		assert_not_null(btn, "速度按钮应存在")
		assert_true(
			btn.custom_minimum_size.x >= 48.0 and btn.custom_minimum_size.y >= 48.0,
			"速度按钮触控尺寸必须 ≥48px (当前: %s)" % str(btn.custom_minimum_size)
		)

	# 2. ink3 灰在 panel 底上对比度 ≥4.5:1 (否决点 1 / WCAG AA)
	assert_not_null(TOKENS_COLORS, "tokens_colors.tres 应能成功加载")
	var panel_col: Color = TOKENS_COLORS.get_meta("panel")
	var ink3_col: Color = TOKENS_COLORS.get_meta("ink3")
	var contrast: float = _calculate_contrast_ratio(panel_col, ink3_col)
	assert_true(contrast >= 4.5, "ink3 灰在 panel 底上的对比度必须 ≥4.5:1 (当前: %.2f:1)" % contrast)


func test_src_ui_scripts_zero_color_literals_grep() -> void:
	# 否决点 5 防散落门禁：src/ui/**/*.gd 禁 #RRGGBB / Color() 裸字面量
	var dir := DirAccess.open("res://src/ui")
	assert_not_null(dir, "src/ui 目录应可访问")

	var ui_gd_files: Array[String] = []
	_collect_gd_files("res://src/ui", ui_gd_files)
	assert_true(ui_gd_files.size() > 0, "应搜集到 src/ui 下的 gd 文件")

	var regex_hex := RegEx.new()
	# 匹配形如 "#1d222a", "#fff", 'Color("#...")'，忽略纯注释行
	regex_hex.compile("(?i)Color\\([\"']#[0-9a-f]{3,8}[\"']\\)|[\"']#[0-9a-f]{6}[\"']")

	for path: String in ui_gd_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var line_idx: int = 0
		while not file.eof_reached():
			line_idx += 1
			var line: String = file.get_line().strip_edges()
			if line.begins_with("#"):
				continue
			var match_result: RegExMatch = regex_hex.search(line)
			assert_null(
				match_result, "文件 %s 第 %d 行发现散落颜色字面量: %s (必须收口在 .tres 中)" % [path, line_idx, line]
			)


func test_responsive_layout_manager_folding_visibility() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var subrow: HBoxContainer = main.get_node("%ResourceSubrow")
	var layout_mgr: ResponsiveLayoutManager = (main as MainScene).get_layout_manager()
	assert_not_null(layout_mgr, "ResponsiveLayoutManager 应存在")

	# 1. 桌面视口宽屏模式 (1280x720) -> 资源栏副行展开
	layout_mgr.update_viewport(Vector2(1280, 720))
	assert_false(layout_mgr.is_portrait(), "1280x720 应判定为横屏")
	assert_false(layout_mgr.is_resource_subrow_folded(), "宽屏下副行不折叠")
	assert_true(subrow.visible, "宽屏下副行控件 visible 应为 true")

	# 2. 手机竖屏模式 (390x844) -> 资源栏副行折叠
	layout_mgr.update_viewport(Vector2(390, 844))
	assert_true(layout_mgr.is_portrait(), "390x844 应判定为竖屏")
	assert_true(layout_mgr.is_resource_subrow_folded(), "竖屏下第一折副行折叠")
	assert_false(subrow.visible, "竖屏下副行控件 visible 应为 false")


func _collect_gd_files(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_collect_gd_files(dir_path.path_join(file_name), out_files)
		elif file_name.ends_with(".gd"):
			out_files.append(dir_path.path_join(file_name))
		file_name = dir.get_next()


func _calculate_contrast_ratio(c1: Color, c2: Color) -> float:
	var l1 := _relative_luminance(c1)
	var l2 := _relative_luminance(c2)
	var lighter: float = maxf(l1, l2)
	var darker: float = minf(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)


func _relative_luminance(c: Color) -> float:
	var r := _channel_lum(c.r)
	var g := _channel_lum(c.g)
	var b := _channel_lum(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


func _channel_lum(val: float) -> float:
	if val <= 0.03928:
		return val / 12.92
	return pow((val + 0.055) / 1.055, 2.4)
