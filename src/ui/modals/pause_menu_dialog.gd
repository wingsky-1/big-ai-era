class_name PauseMenuDialog
extends PanelContainer

## 暂停菜单弹层（z2 阻塞层 / dismissable，DR-020，issue #67）：
## 三入口（继续 / 重开 / 设置）+ Esc 可关；纯表现层——只发信号，
## 恢复与重开一律由 AppShell 走 GameWorld 契约命令（L3 零写路径）。
## 文案口径：标题取 texts.json 现存键 sys_speed_paused（不新增不重命名）；
## 三入口标签因 texts.json 无"设置"键、本 PR 禁区不含 src/data/ 暂内联于 .tscn，
## 与既有 modals 的静态标签写法一致，外置化随文案批统一收口。

signal closed  ## 继续 / Esc：请求恢复游戏（由 AppShell 归零 user_paused）
signal restart_requested  ## 重开：请求重新开局
signal settings_requested  ## 设置：设置面板未落地，先上报信号供宿主给反馈

@onready var title_label: Label = %TitleLabel
@onready var continue_btn: Button = %ContinueBtn
@onready var restart_btn: Button = %RestartBtn
@onready var settings_btn: Button = %SettingsBtn


func _ready() -> void:
	ModalSizing.apply(self)
	title_label.text = TextService.text("sys_speed_paused")
	continue_btn.pressed.connect(func() -> void: closed.emit())
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	settings_btn.pressed.connect(func() -> void: settings_requested.emit())


## Esc 可关（映射表 §2 PAUSE_MENU 行），与遮罩点击同语义：出栈即恢复流淌。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		closed.emit()
