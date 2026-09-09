class_name TechTreeDialog
extends PanelContainer

## 迷雾科技树弹窗（§13 C 方案：列表 + 1-hop 微图 + "???"行 + 域计数，禁交互画布）
## 仅经由 GameWorld.start_research(tech_id) 触发研发，保持零写路径。

signal closed
signal research_requested(tech_id: String)

var _world: GameWorld

@onready var title_label: Label = %TitleLabel
@onready var close_btn: Button = %CloseBtn
@onready var domain_summary_label: Label = %DomainSummaryLabel
@onready var tech_list_vbox: VBoxContainer = %TechListVBox


func setup(world: GameWorld) -> void:
	_world = world
	if is_inside_tree():
		_render()


func _ready() -> void:
	ModalSizing.apply(self)
	domain_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_btn.pressed.connect(func() -> void: closed.emit())
	_render()


func _render() -> void:
	if _world == null:
		return

	# 域口径一律经 L2 数据面（ADR-0016 决策②：L3 禁读 L4 数据表）：
	# progress.domains 同时供汇总行与列表行的"域显示名 + 是否可研"使用。
	var progress: Dictionary = _world.get_domain_progress()
	var summary: Dictionary = progress.get("summary", {})
	var unresearchable_note: String = str(summary.get("unresearchable_note", ""))
	var domain_meta: Dictionary = {}
	for domain_variant: Variant in progress.get("domains", []):
		var domain: Dictionary = domain_variant
		domain_meta[str(domain.get("id", ""))] = domain

	domain_summary_label.text = _build_domain_summary(progress, unresearchable_note)

	for child in tech_list_vbox.get_children():
		child.queue_free()

	# 节点元数据与状态一律来自 L2 数据面
	for node_info: Dictionary in _world.get_tech_list_view():
		var state: String = str(node_info.get("state", TechFog.STATE_HIDDEN))
		var domain_row: Dictionary = domain_meta.get(str(node_info.get("domain", "")), {})
		var domain_label: String = str(domain_row.get("label", ""))
		var researchable: bool = bool(domain_row.get("researchable", true))
		var item_hbox := HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 10)  # num-ok: 布局间距（表现层）

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		match state:
			TechFog.STATE_LIT:
				name_label.text = "✓ " + str(node_info.get("name", "")) + " [已点亮]"
				item_hbox.add_child(name_label)

			TechFog.STATE_RESEARCHABLE:
				var cost: int = int(node_info.get("cost", 0))
				var rp: int = int(node_info.get("rp_cost", 0))
				name_label.text = (
					"● "
					+ str(node_info.get("name", ""))
					+ " (需: "
					+ Formatter.format_money(cost)
					+ ", %dRP)" % rp
				)
				var btn := Button.new()
				btn.custom_minimum_size = Vector2(48, 48)  # num-ok: 触控最小热区（表现层）
				btn.text = "研发"
				var tid: String = str(node_info.get("id", ""))
				btn.pressed.connect(func() -> void: _on_research_clicked(tid))
				item_hbox.add_child(name_label)
				item_hbox.add_child(btn)

			TechFog.STATE_VISIBLE:
				name_label.text = (
					"○ "
					+ str(node_info.get("name", ""))
					+ " [前置: %s]" % str(node_info.get("parents", []))
				)
				item_hbox.add_child(name_label)

			TechFog.STATE_RUMORED:
				if researchable:
					name_label.text = "? [传闻] " + str(node_info.get("name", ""))
				else:
					# 他者道路：显示占位行但注明不可研（DR-031/D3 分母口径 b）
					name_label.text = (
						"??? [%s·%s] %s"
						% [domain_label, unresearchable_note, str(node_info.get("name", ""))]
					)
				item_hbox.add_child(name_label)

			_:  # STATE_HIDDEN
				name_label.text = "??? [深层迷雾未探明]"
				item_hbox.add_child(name_label)

		tech_list_vbox.add_child(item_hbox)


## 域进度行（真值来自 L2 get_domain_progress：逐域 {lit,total} 与域名由 L2 提供，
## 分母 = 该域实表节点数，非可研域（elsewhere）标注不可研——旧实现显示
## architecture/algorithm/infrastructure 三域且分母硬编码 4/5/5，属"显示错误值"缺陷）。
func _build_domain_summary(progress: Dictionary, unresearchable_note: String) -> String:
	var summary: Dictionary = progress.get("summary", {})
	var separator: String = str(summary.get("separator", ""))
	var parts: Array[String] = []
	for domain_variant: Variant in progress.get("domains", []):
		var domain: Dictionary = domain_variant
		var row: String = (
			"%s %d/%d"
			% [str(domain.get("label", "")), int(domain.get("lit", 0)), int(domain.get("total", 0))]
		)
		if not bool(domain.get("researchable", true)):
			row += "(%s)" % unresearchable_note
		parts.append(row)
	var text: String = (
		str(summary.get("label", ""))
		+ str(summary.get("label_separator", ""))
		+ separator.join(parts)
	)
	return (
		text
		+ separator
		+ (
			"%s %d/%d"
			% [
				str(summary.get("total_label", "")),
				int(progress.get("lit_total", 0)),
				int(progress.get("total_nodes", 0)),
			]
		)
	)


func _on_research_clicked(tech_id: String) -> void:
	research_requested.emit(tech_id)
	_render()
