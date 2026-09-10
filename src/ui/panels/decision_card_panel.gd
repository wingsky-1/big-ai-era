class_name DecisionCardPanel
extends ZPanel
## L3 决策卡 z2（批7.4 #194；ui-ux A.2「决策卡通道」+ randomness OP-RND-01
## 决策级）：标题/正文/两选项（≥48px，各带效果预览句）→ 选择经注入提交回调
## （WorldCommands.submit_decision 命令通道）→ 结果句刷新 → 装配方关层。
## z2 语义：遮罩点击不关+无关闭钮（强迫处理，世界已停流——挂遮罩状态统一
## 门控，ADR-0028）。预览句=承诺：渲染值与实际入账同源（events.json 效果对象
## 单源，零业务计算）。文案=view 键引用经 TextService（L3 禁读表）。

const KEY_CASH_PREVIEW: String = "rnd_event_cash_preview"
const KEY_INFLUENCE_PREVIEW: String = "rnd_event_influence_preview"
const KEY_NONE_PREVIEW: String = "rnd_event_none_preview"

## 效果类型（与 EventShell.EffectType 数值对齐；L3 禁 import L2——数字面经
## view 下发，此处镜像枚举值，GUT 断言两值一致防漂移）
const EFFECT_CASH: int = 0
const EFFECT_INFLUENCE: int = 1
const EFFECT_NONE: int = 2

var _submit: Callable = Callable()
var _view_source: Callable = Callable()
var _body_text: Label
var _choices_box: VBoxContainer
var _ack_button: Button = null


## 注入提交回调与数据面（装配方：submit=WorldCommands.submit_decision；
## view_source=() -> get_decision_view）
func bind(submit: Callable, view_source: Callable) -> void:
	_submit = submit
	_view_source = view_source


## 统一刷新契约（main._show_panel 调用）：拉取 pending view 渲染
func refresh() -> void:
	if not _view_source.is_valid():
		return
	render(_view_source.call())


func _build_body(body_box: VBoxContainer) -> void:
	set_close_visible(false)
	_body_text = Label.new()
	_body_text.add_theme_font_size_override("font_size", 14)
	_body_text.add_theme_color_override("font_color", COLOR_INK3)
	_body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_text.custom_minimum_size = Vector2(292.0, 0.0)
	body_box.add_child(_body_text)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	body_box.add_child(_choices_box)


## 渲染待决卡（view=WorldCommands.get_decision_view()；重复调用=重建选项）
func render(view: Dictionary) -> void:
	_clear_choices()
	_hide_ack()
	if view.is_empty():
		set_title("")
		_body_text.text = ""
		return
	set_title(TextService.text(str(view.get("title_key", ""))))
	_body_text.text = TextService.text(str(view.get("body_key", "")))
	for i: int in (view.get("choices", []) as Array).size():
		var choice: Dictionary = view["choices"][i]
		var label_text := (
			"%s ｜ %s"
			% [
				TextService.text(str(choice.get("key", ""))),
				_preview_text(
					int(choice.get("effect_type", EFFECT_NONE)), int(choice.get("amount", 0))
				),
			]
		)
		var button := make_button(label_text)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choices_box.add_child(button)


## 结果句刷新（选择后：装配方以提交结果调；绿色反馈+确认钮出现——结果句
## 即时可读，玩家确认后经 close_requested 收层，防"一闪而过"）
func show_result(text: String) -> void:
	set_footer(text, true)
	if _ack_button != null:
		return
	_ack_button = make_button(TextService.text("ui_report_ack"))
	_ack_button.pressed.connect(func() -> void: close_requested.emit())
	_choices_box.add_child(_ack_button)


func get_choice_count() -> int:
	return _choices_box.get_child_count()


## ---------- 私有 ----------


func _on_choice_pressed(choice_index: int) -> void:
	if not _submit.is_valid():
		return
	var result: Dictionary = _submit.call(choice_index)
	if bool(result.get("ok", false)):
		# 先禁用原选项再出确认钮（顺序红线：确认钮后加则被循环误禁——
		# disabled 钮吃事件不响应，浏览器实测暴露；emit 直发的 GUT 盲区）
		for child: Node in _choices_box.get_children():
			(child as Button).disabled = true
		show_result(str(result.get("row_text", "")))


## 预览句（效果三型；amount=实际入账值同源，插值 X=金额）
func _preview_text(effect_type: int, amount: int) -> String:
	match effect_type:
		EFFECT_CASH:
			return TextService.format(KEY_CASH_PREVIEW, {"X": str(amount)})
		EFFECT_INFLUENCE:
			return TextService.format(KEY_INFLUENCE_PREVIEW, {"X": str(amount)})
		_:
			return TextService.text(KEY_NONE_PREVIEW)


func _clear_choices() -> void:
	for child: Node in _choices_box.get_children():
		_choices_box.remove_child(child)
	_ack_button = null


func _hide_ack() -> void:
	_ack_button = null
