class_name TaskBoardPanel
extends ZPanel
## L3 任务板 z1 面板（批7.3 #190 最小实体）：两段式=选题列表（接单入口）+
## 训练列表（排训练入口）+ 在跑槽摘要行。命令经注入 WorldCommands 委托
## （accept_paper/start_training，L2 命令面）；数据面经注入 Callable
## （get_dashboard/get_topic_options/get_base_options——L3 禁 import L2，
## ADR-0016）。拒绝文案=单因枚举→既有 texts 键映射（texts.json 零新键，
## #190 纪律）；硬约束：零业务计算；触控行 ≥48px（壳统一）。

const KEY_ACCEPT: String = "ui_accept"
const KEY_TRAIN: String = "ui_tab_training"
const KEY_SLOT_EMPTY: String = "ui_task_slot_empty"

## 单因拒绝→既有文案键（SlotRejectReason 枚举值键控）。TIER/CARD_HOURS 因
## 现有键均带 <X>/<Y> 插值且拒绝载荷无费用数据——本批走通用兜底，专属文案
## 键缺口登记为后批债（texts.json 零新键纪律）。
const REJECT_TEXT_KEYS: Dictionary = {
	CoreEnums.SlotRejectReason.ALL_SLOTS_FULL: "paper_slot_full_reason",
	CoreEnums.SlotRejectReason.NO_RUNNING_PROJECT: "ui_task_slot_empty",
}
const REJECT_FALLBACK_KEY: String = "ui_error_fallback"

var _get_dashboard: Callable = Callable()
var _commands: Object = null
var _topics_box: VBoxContainer
var _bases_box: VBoxContainer
var _slot_label: Label = null


## 注入数据面与命令面（装配方调用；get_dashboard=() -> dashboard view 字典）
func bind(get_dashboard: Callable, commands: Object) -> void:
	_get_dashboard = get_dashboard
	_commands = commands


func _build_body(body_box: VBoxContainer) -> void:
	set_title(TextService.text("ui_dock_taskboard"))
	# 面板内容可滚动（选题 12 行+基座 6 行超出小屏高；壳体高上限兜底）
	custom_minimum_size = Vector2(340.0, 0.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(316.0, 380.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	scroll.add_child(inner)
	inner.add_child(make_section_label(TextService.text("ui_tab_topics")))
	_topics_box = VBoxContainer.new()
	_topics_box.add_theme_constant_override("separation", 4)
	inner.add_child(_topics_box)
	inner.add_child(make_section_label(TextService.text(KEY_TRAIN)))
	_bases_box = VBoxContainer.new()
	_bases_box.add_theme_constant_override("separation", 4)
	inner.add_child(_bases_box)
	_slot_label = Label.new()
	_slot_label.add_theme_font_size_override("font_size", 13)
	_slot_label.add_theme_color_override("font_color", COLOR_INK3)
	_slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_slot_label)


## 打开/命令后全量刷新（选题池/基座池/在跑槽；无注入=防御空转）
func refresh() -> void:
	if not _get_dashboard.is_valid() or _commands == null:
		return
	var dashboard: Dictionary = _get_dashboard.call()
	_refresh_topics()
	_refresh_bases()
	_refresh_slot(dashboard)


## ---------- 私有（行装配；列表短，每次清段重建=帧预算内、无残留） ----------


func _refresh_topics() -> void:
	_clear_box(_topics_box)
	var options: Array = _options_of("get_topic_options")
	if options.is_empty():
		_topics_box.add_child(make_section_label(TextService.text("paper_pool_empty_hint")))
		return
	for topic: Dictionary in options:
		var row := _command_row(
			TextService.text(str(topic.get("title_key", ""))),
			TextService.text(KEY_ACCEPT),
		)
		row.pressed.connect(_on_accept_pressed.bind(str(topic.get("id", ""))))
		_topics_box.add_child(row)


func _refresh_bases() -> void:
	_clear_box(_bases_box)
	for option: Dictionary in _options_of("get_base_options"):
		var base_id := str(option.get("id", ""))
		var row := _command_row(
			TextService.text("model_base_%s" % base_id),
			TextService.text(KEY_TRAIN),
		)
		row.pressed.connect(_on_train_pressed.bind(base_id))
		_bases_box.add_child(row)


func _refresh_slot(dashboard: Dictionary) -> void:
	var lines: Array[String] = []
	for task: Dictionary in dashboard.get("tasks", []):
		var state := int(task.get("state", CoreEnums.ProjectState.EMPTY))
		if state == CoreEnums.ProjectState.EMPTY:
			continue
		var title_key := str(task.get("title_key", ""))
		var title := (
			TextService.text(title_key)
			if not title_key.is_empty()
			else TextService.text(KEY_SLOT_EMPTY)
		)
		lines.append("%s · %d%%" % [title, int(float(task.get("progress", 0.0)) * 100.0)])
	_slot_label.text = "\n".join(lines)
	_slot_label.visible = not lines.is_empty()


## 选项数据面（WorldCommands 只读委托；方法名键控防 L3 直取系统对象）
func _options_of(method_name: String) -> Array:
	if _commands == null or not _commands.has_method(method_name):
		return []
	return _commands.call(method_name)


func _on_accept_pressed(topic_id: String) -> void:
	if _commands == null:
		return
	var result: Dictionary = _commands.accept_paper(topic_id)
	if bool(result.get("ok", false)):
		set_footer(TextService.text(KEY_ACCEPT), true)
	else:
		set_footer(_reject_text(result.get("reason", -1)), false)
	refresh()


func _on_train_pressed(base_id: String) -> void:
	if _commands == null:
		return
	var result: Dictionary = _commands.start_training(base_id)
	if bool(result.get("ok", false)):
		set_footer(TextService.text(KEY_TRAIN), true)
	else:
		set_footer(_reject_text(result.get("reason", -1)), false)
	refresh()


## 单因枚举→文案（表驱动映射；未知因=通用兜底键）
func _reject_text(reason: Variant) -> String:
	var key := str(REJECT_TEXT_KEYS.get(int(reason), REJECT_FALLBACK_KEY))
	return TextService.text(key)


func _command_row(label_text: String, action_text: String) -> Button:
	var row := make_button("%s ｜ %s" % [label_text, action_text])
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return row


func _clear_box(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
