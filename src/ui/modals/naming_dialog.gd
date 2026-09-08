class_name NamingDialog
extends PanelContainer

## 命名仪式弹窗（z2 阻塞层，X7 / DR-031 呈现层⑥）：
## 出分且未命名时由 DashboardPresenter 推入 NAMING_DIALOG；提交/跳过一律经契约命令
## GameWorld.submit_model_name，UI 零写路径、零业务计算（ADR-0016）。
## 文案真源：texts.json 既有 naming_* 键（不新增键，禁内联文案）。

signal submitted(raw_name: String)
signal skipped

@onready var title_label: Label = %TitleLabel
@onready var prompt_label: Label = %PromptLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var hint_label: Label = %HintLabel
@onready var submit_btn: Button = %SubmitBtn
@onready var skip_btn: Button = %SkipBtn


## 入参为当前模型名（未命名时为空串；命名后重开则回填，便于改名前复核）。
func setup(current_name: String) -> void:
	if is_inside_tree():
		_apply_texts()
		name_edit.text = current_name


func _ready() -> void:
	ModalSizing.apply(self)
	_apply_texts()
	submit_btn.pressed.connect(_on_submit_pressed)
	skip_btn.pressed.connect(func() -> void: skipped.emit())
	name_edit.text_submitted.connect(func(_text: String) -> void: _on_submit_pressed())


func _apply_texts() -> void:
	title_label.text = TextService.text("naming_title")
	prompt_label.text = TextService.text("naming_prompt")
	hint_label.text = TextService.text("naming_input_hint")
	submit_btn.text = TextService.text("naming_button_submit")
	skip_btn.text = TextService.text("naming_button_skip")
	name_edit.max_length = TextService.name_max_chars()


func _on_submit_pressed() -> void:
	submitted.emit(name_edit.text)
