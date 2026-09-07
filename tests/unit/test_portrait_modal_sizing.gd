extends GutTest

## 竖屏内容基准切换 + 弹层自适应纯函数回归（v0.1.2）


func test_resolve_content_scale_portrait_and_landscape() -> void:
	assert_eq(
		ResponsiveLayoutManager.resolve_content_scale(Vector2i(390, 844)),
		Vector2i(480, 854),
		"390x844 竖屏应切 480 基准"
	)
	assert_eq(
		ResponsiveLayoutManager.resolve_content_scale(Vector2i(1280, 720)),
		Vector2i(1280, 720),
		"桌面 1280x720 应保持 1280 基准（零回归）"
	)
	assert_eq(
		ResponsiveLayoutManager.resolve_content_scale(Vector2i(844, 390)),
		Vector2i(1280, 720),
		"横屏 y<x 应保持 1280 基准"
	)
	assert_eq(
		ResponsiveLayoutManager.resolve_content_scale(Vector2i(768, 1024)),
		Vector2i(480, 854),
		"平板竖屏 y>x 同样切 480 基准"
	)


func test_modal_sizing_clamps_within_narrow_viewport() -> void:
	# 480 逻辑宽竖屏（减两侧 24 边距）：tech_tree 期望 520 宽必须被收敛
	var clamped: Vector2 = ModalSizing.resolve_min_size(Vector2(480, 1039), Vector2(520, 440))
	assert_eq(clamped.x, 432.0, "tech_tree 宽应收敛到 480-48=432")
	assert_eq(clamped.y, 440.0, "高度未超限应保留期望值")
	# 桌面 1280 视口：期望尺寸原样生效
	var desktop: Vector2 = ModalSizing.resolve_min_size(Vector2(1280, 720), Vector2(520, 440))
	assert_eq(desktop, Vector2(520, 440), "桌面视口下弹层期望尺寸不受影响")


func test_modal_sizing_apply_and_refresh_roundtrip() -> void:
	# 用裸 PanelContainer 测纯函数行为：%UniqueName 依赖场景注册，脚本化节点无此表
	var root_stub: Control = Control.new()
	add_child_autofree(root_stub)
	root_stub.size = Vector2(480, 1039)
	var dlg: PanelContainer = PanelContainer.new()
	root_stub.add_child(dlg)
	dlg.set_meta("modal_design_size", Vector2(520, 440))
	ModalSizing.apply(dlg)
	assert_true(
		dlg.custom_minimum_size.x <= 480.0 - ModalSizing.VIEWPORT_MARGIN * 2.0 + 0.01,
		"窄视口下弹层宽不得溢出视口"
	)
	root_stub.size = Vector2(1280, 720)
	ModalSizing.refresh(dlg)
	assert_eq(dlg.custom_minimum_size, Vector2(520, 440), "宽视口下 refresh 应回到期望尺寸")


func test_all_modal_design_sizes_fit_landscape_base() -> void:
	# 桌面基准下所有弹层期望尺寸不得小于 v0.1.1 固定尺寸（观感零回退）
	var expected := {
		"DecisionCardDialog": Vector2(360, 280),
		"WeeklyReportDialog": Vector2(360, 320),
		"TechTreeDialog": Vector2(520, 440),
		"StaffRosterDialog": Vector2(440, 400),
		"GameOverDialog": Vector2(360, 280),
	}
	for key: String in expected:
		assert_true(ModalSizing.DESIGN_SIZES.has(key), "DESIGN_SIZES 应包含 %s" % key)
		assert_eq(ModalSizing.DESIGN_SIZES[key], expected[key], "%s 期望尺寸应与 v0.1.1 一致" % key)
