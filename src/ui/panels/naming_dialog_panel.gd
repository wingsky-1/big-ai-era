class_name NamingDialogPanel
extends ZPanel
## L3 命名弹层 z2（批7.3 #190）：出分命名主路径的阻塞入口——提交经
## NamingDialogLogic（#151 纯逻辑：NameFilter 单源校验+注入命令转发），
## 本面板=该逻辑的渲染壳（LineEdit+确认/命运双键+原因行）。pending 数据面
## =dashboard["naming_pending"] 谓词 + ceremony peek（经注入 Callable 读
## _state_view：score/first/base_id，L3 禁直取 ceremony 对象，ADR-0016）。
## z2 语义：遮罩点击不关+无关闭钮（world set_z2_blocked 停流由 main 门控）。
## 文案=既有 onb_naming_hint/name_filter_reason/model_score_title/ui_confirm
## 零新键。硬约束：过滤=NameFilter 单源（逻辑层）；本面板零业务计算。

const KEY_CONFIRM: String = "ui_confirm"
const KEY_REASON: String = "name_filter_reason"

var _logic: NamingDialogLogic
var _get_pending: Callable = Callable()
var _input: LineEdit
var _score_label: Label


## 注入纯逻辑（NamingDialogLogic 已 bind L2 命令）与 pending 数据面
## （get_pending=() -> ModelCeremony._state_view 形状字典）
func bind(logic: NamingDialogLogic, get_pending: Callable) -> void:
	_logic = logic
	_get_pending = get_pending


func _build_body(body_box: VBoxContainer) -> void:
	set_title(TextService.text("onb_naming_hint"))
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", COLOR_INK3)
	body_box.add_child(_score_label)
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(0.0, MIN_TOUCH)
	_input.max_length = _logic.get_max_len() if _logic != null else 12
	_input.add_theme_font_size_override("font_size", 16)
	_input.text_submitted.connect(func(_text: String) -> void: _on_submit())
	body_box.add_child(_input)
	var confirm_button := make_button(TextService.text(KEY_CONFIRM))
	confirm_button.pressed.connect(_on_submit)
	body_box.add_child(confirm_button)
	# 首模型无跳过路径（L2 first_mandatory 拒绝）——「交给命运」仅非首模型
	# 可见：绑定后 peek 首标判定（open 时刷新）
	var skip_button := make_button(TextService.text("model_default_name_pool_01"))
	skip_button.name = "SkipButton"
	skip_button.pressed.connect(_on_skip)
	body_box.add_child(skip_button)


## 打开（main z2 门控翻转为 pending 时调用）：读 pending 刷分数行/首模型标
func refresh() -> void:
	if _logic == null or not _get_pending.is_valid():
		return
	var pending: Dictionary = _get_pending.call()
	var first := bool(pending.get("first", false))
	var skip_button := get_body().get_node_or_null("SkipButton") as Button
	if skip_button != null:
		skip_button.visible = not first
	var score := float(pending.get("score", 0.0))
	_score_label.text = TextService.text("model_score_title").replace("XX.X", "%.1f" % score)
	_logic.open()


## 输入框当前值（测试/装配方读）
func get_input_text() -> String:
	return _input.text


## 外部等价键入提交（Web 信标测试钩子/测试驱动；仍走 Logic→NameFilter→L2
## 命令全链——非绕过过滤的直通口）
func submit_text(text: String) -> void:
	_input.text = text
	_on_submit()


## 外部等价「交给命运」（同上；首模型被 L2 拒时原因行回显）
func skip_external() -> void:
	_on_skip()


## ---------- 私有（提交/跳过转发纯逻辑；被拒=原因行，弹层不关） ----------


func _on_submit() -> void:
	if _logic == null:
		return
	var result: Dictionary = _logic.submit(_input.text)
	if bool(result.get("accepted", false)):
		clear_footer()
		_input.text = ""
	else:
		set_footer(TextService.text(KEY_REASON), false)


func _on_skip() -> void:
	if _logic == null:
		return
	var result: Dictionary = _logic.skip()
	if not bool(result.get("accepted", false)):
		set_footer(TextService.text(KEY_REASON), false)
