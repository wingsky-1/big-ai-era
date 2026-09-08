class_name IntroDialog
extends PanelContainer

## 开场引导弹层（z1 常规层，DR-029 D-3"引导不拦流淌"）：
## 四句开场白（texts.json 真源）+ 开始经营按钮；世界照常流淌，点遮罩/按钮即关，
## 不阻塞 tick、不入档（v0.1 无读档入口，重开不复发由"仅启动推入一次"保证）。

signal closed

@onready var intro_label: Label = %IntroLabel
@onready var goal_label: Label = %GoalLabel
@onready var rival_label: Label = %RivalLabel
@onready var hint_label: Label = %HintLabel
@onready var start_btn: Button = %StartBtn


func _ready() -> void:
	ModalSizing.apply(self)
	intro_label.text = TextService.text("opening_line_intro")
	goal_label.text = TextService.text("opening_line_goal")
	rival_label.text = TextService.text("opening_line_rival")
	hint_label.text = TextService.text("opening_line_hint")
	start_btn.pressed.connect(func() -> void: closed.emit())
