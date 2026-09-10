class_name PauseMenuPanel
extends ZPanel
## L3 暂停菜单 z1 面板（批7.3 #190 最小实体）：变速轮转（1x→2x→4x→1x，
## WorldCommands.cycle_speed）+ 暂停/继续 + 手动存档（GameWorld.manual_save
## 委托经 commands 载体注入——暂停菜单唯一需要门面级命令的面板，注入
## Callable 防面板持世界引用）。时钟数据面=dashboard["clock"]（speed_index/
## user_paused 同源显示）；文案=既有 time_speed_*/time_pause_* 键零新键。
## 硬约束：零业务计算（ADR-0016）；触控 ≥48px（壳统一）。

const SPEED_KEYS: Array[String] = ["time_speed_1x", "time_speed_2x", "time_speed_4x"]

var _get_dashboard: Callable = Callable()
var _cycle_speed_cmd: Callable = Callable()
var _set_paused_cmd: Callable = Callable()
var _manual_save_cmd: Callable = Callable()
var _speed_button: Button
var _pause_button: Button


## 注入数据面与命令面（装配方调用；命令全部 Callable，防持 World 引用）
func bind(
	get_dashboard: Callable,
	cycle_speed_cmd: Callable,
	set_paused_cmd: Callable,
	manual_save_cmd: Callable,
) -> void:
	_get_dashboard = get_dashboard
	_cycle_speed_cmd = cycle_speed_cmd
	_set_paused_cmd = set_paused_cmd
	_manual_save_cmd = manual_save_cmd


func _build_body(body_box: VBoxContainer) -> void:
	set_title(TextService.text("ui_dock_pause"))
	_speed_button = make_button("")
	_speed_button.pressed.connect(_on_speed_pressed)
	body_box.add_child(_speed_button)
	_pause_button = make_button("")
	_pause_button.pressed.connect(_on_pause_pressed)
	body_box.add_child(_pause_button)
	var save_button := make_button(TextService.text("time_pause_save"))
	save_button.pressed.connect(_on_save_pressed)
	body_box.add_child(save_button)


## 打开/命令后按时钟 view 刷新按钮态（无注入=防御空转）
func refresh() -> void:
	if not _get_dashboard.is_valid():
		return
	var clock: Dictionary = _get_dashboard.call().get("clock", {})
	var speed_index := int(clock.get("speed_index", 0))
	var key := SPEED_KEYS[clampi(speed_index, 0, SPEED_KEYS.size() - 1)]
	_speed_button.text = TextService.text(key)
	var paused := bool(clock.get("user_paused", false))
	_pause_button.text = (
		TextService.text("time_pause_continue") if paused else TextService.text("time_paused_label")
	)


## ---------- 私有（命令转发+footer 回显；结果文案=既有键） ----------


func _on_speed_pressed() -> void:
	if _cycle_speed_cmd.is_valid():
		_cycle_speed_cmd.call()
	refresh()


func _on_pause_pressed() -> void:
	if not _get_dashboard.is_valid() or not _set_paused_cmd.is_valid():
		return
	var paused := bool(_get_dashboard.call().get("clock", {}).get("user_paused", false))
	_set_paused_cmd.call(not paused)
	refresh()


func _on_save_pressed() -> void:
	if not _manual_save_cmd.is_valid():
		return
	var ok := bool(_manual_save_cmd.call())
	set_footer(TextService.text("time_save_ok" if ok else "time_save_fail"), ok)
