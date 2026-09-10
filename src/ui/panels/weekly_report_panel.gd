class_name WeeklyReportPanel
extends ZPanel
## L3 周报弹层 z2（批7.4 #194）：WeeklyReportDialog.render 复用包装（同构
## 自动弹/手动开——ADR-0028 停流挂 z2 遮罩状态，与触发源解耦：显著周自动弹
## 与灰点手开同一面板同一停流语义）。「知道了」关闭钮（z2 阻塞确认后弹层自收，
## 装配方消费 close_requested）。平淡周不自动弹（灰点语义由 ReportDual 承载）。
## 数据面=WeeklyReport.get_report_view（L2 行文本已格式化，本类只画）。

const KEY_ACK: String = "ui_report_ack"

var _dialog: WeeklyReportDialog
var _view_source: Callable = Callable()


## 注入数据面（装配方：() -> GameWorld.get_report_view()）
func bind(view_source: Callable) -> void:
	_view_source = view_source


## 统一刷新契约（main._show_panel 调用）：拉取周报 view 渲染
func refresh() -> void:
	if not _view_source.is_valid():
		return
	render(_view_source.call())


func _build_body(body_box: VBoxContainer) -> void:
	# 标题由 WeeklyReportDialog 自渲染（周数插值）——壳标题置空防双标题
	set_title("")
	_dialog = WeeklyReportDialog.new()
	body_box.add_child(_dialog)
	var ack_button := make_button(TextService.text(KEY_ACK))
	ack_button.pressed.connect(func() -> void: close_requested.emit())
	body_box.add_child(ack_button)


## 渲染周报 view（自动弹/灰点手开共用；重复调用=清行重建）
func render(report_view: Dictionary) -> void:
	_dialog.render(report_view)
