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
	close_btn.pressed.connect(func() -> void: closed.emit())
	_render()


func _render() -> void:
	if _world == null or _world.tech_fog == null or _world.tech_tree == null:
		return

	var fog: TechFog = _world.tech_fog
	var counts: Dictionary = fog.get_domain_counts()
	domain_summary_label.text = (
		"领域探明: 模型架构 (%d/%d) | 算法演进 (%d/%d) | 工程基建 (%d/%d)"
		% [
			int(counts.get("architecture", {}).get("lit", 0)),
			int(counts.get("architecture", {}).get("total", 4)),
			int(counts.get("algorithm", {}).get("lit", 0)),
			int(counts.get("algorithm", {}).get("total", 5)),
			int(counts.get("infrastructure", {}).get("lit", 0)),
			int(counts.get("infrastructure", {}).get("total", 5)),
		]
	)

	for child in tech_list_vbox.get_children():
		child.queue_free()

	var nodes_data: Dictionary = DataLoader.load_json("res://src/data/techs.json").get("nodes", {})
	for tech_id: String in nodes_data:
		var state: String = fog.get_state(tech_id)
		var item_hbox := HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 10)

		var node_info: Dictionary = nodes_data[tech_id]
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		match state:
			TechFog.STATE_LIT:
				name_label.text = "✓ " + str(node_info.get("name", tech_id)) + " [已点亮]"
				item_hbox.add_child(name_label)

			TechFog.STATE_RESEARCHABLE:
				var cost: int = int(node_info.get("cost", 0))
				var rp: int = int(node_info.get("rp_cost", 0))
				name_label.text = (
					"● "
					+ str(node_info.get("name", tech_id))
					+ " (需: "
					+ Formatter.format_money(cost)
					+ ", %dRP)" % rp
				)
				var btn := Button.new()
				btn.custom_minimum_size = Vector2(48, 48)
				btn.text = "研发"
				var tid: String = tech_id
				btn.pressed.connect(func() -> void: _on_research_clicked(tid))
				item_hbox.add_child(name_label)
				item_hbox.add_child(btn)

			TechFog.STATE_VISIBLE:
				name_label.text = (
					"○ "
					+ str(node_info.get("name", tech_id))
					+ " [前置: %s]" % str(node_info.get("prerequisites", []))
				)
				item_hbox.add_child(name_label)

			TechFog.STATE_RUMORED:
				name_label.text = "? [传闻] " + str(node_info.get("name", "未知技术"))
				item_hbox.add_child(name_label)

			_:  # STATE_HIDDEN
				name_label.text = "??? [深层迷雾未探明]"
				item_hbox.add_child(name_label)

		tech_list_vbox.add_child(item_hbox)


func _on_research_clicked(tech_id: String) -> void:
	research_requested.emit(tech_id)
	_render()
