class_name TechTreePanel
extends ZPanel
## L3 科技树 z1 面板（批7.3 #190 最小实体）：全雾组逐行渲染 fog view
## （节点名键→TextService；雾态 hidden=？？？/rumored=传闻句），可研究态
## （researchable）行点击=研究命令（WorldCommands.start_research）。
## 树数据面=dashboard["tree"]（TechTree.get_fog_view 下发，L3 只画零计算）；
## 拒绝文案=既有 tree_research_disabled_reason（占位直出，L2 拒因无差值载荷，
## 插值消费登记后批债）。硬约束：零业务计算；触控行 ≥48px。

const STATE_VISIBLE: String = "visible"
const STATE_RESEARCHABLE: String = "researchable"
const STATE_LIT: String = "lit"

var _get_dashboard: Callable = Callable()
var _commands: Object = null
var _rows_box: VBoxContainer


func bind(get_dashboard: Callable, commands: Object) -> void:
	_get_dashboard = get_dashboard
	_commands = commands


func _build_body(body_box: VBoxContainer) -> void:
	set_title(TextService.text("ui_dock_tree"))
	body_box.add_child(make_section_label(TextService.text("tree_table_title")))
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	body_box.add_child(_rows_box)


## 打开/命令后全量刷新（雾态随周结推进；无注入=防御空转）
func refresh() -> void:
	if not _get_dashboard.is_valid():
		return
	_clear_box(_rows_box)
	var tree: Dictionary = _get_dashboard.call().get("tree", {})
	for group_id: String in tree.get("groups", {}).keys():
		# 组头=有文案键才渲染（五域键在；cross/rumor 组无键只渲染行——
		# 键存在性经 TextService.table 无副作用查询，后批补键自动出组头）
		var group_key := "tree_domain_%s" % group_id
		if TextService.table().has(group_key):
			_rows_box.add_child(make_section_label(TextService.text(group_key)))
		for row: Dictionary in tree["groups"][group_id].get("rows", []):
			_rows_box.add_child(_make_node_row(row))
	if _rows_box.get_child_count() == 0:
		_rows_box.add_child(make_section_label(TextService.text("paper_pool_empty_hint")))


## ---------- 私有 ----------


func _make_node_row(row: Dictionary) -> Control:
	var state := str(row.get("state", "hidden"))
	var node_id := str(row.get("node_id", ""))
	var name_key := str(row.get("name_key", "tree_fog_hidden"))
	var text := TextService.text(name_key)
	match state:
		STATE_LIT:
			return _info_row("● %s" % text, COLOR_OK)
		STATE_RESEARCHABLE:
			var button := make_button("▶ %s ｜ %s" % [text, TextService.text("ui_confirm")])
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_research_pressed.bind(node_id))
			return button
		STATE_VISIBLE:
			return _info_row("· %s" % text, COLOR_INK3)
		_:
			return _info_row("　 %s" % text, COLOR_INK3)


func _on_research_pressed(node_id: String) -> void:
	if _commands == null:
		return
	var result: Dictionary = _commands.start_research(node_id)
	if bool(result.get("ok", false)):
		set_footer(TextService.text("ui_confirm"), true)
	else:
		# L2 拒因（影响不足等）无差值载荷——既有文案占位直出（插值消费后批债）
		set_footer(TextService.text("tree_research_disabled_reason"), false)
	refresh()


func _info_row(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_box(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
