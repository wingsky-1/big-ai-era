class_name UnlockPopupLogic
extends RefCounted
## L3 解锁弹卡逻辑（#151；ui-ux A.2 z2「解锁弹卡（轻量自动收）」：非金框非阻塞
## 视觉通道，≤3s 自动收）。纯逻辑 RefCounted（headless 可单测）：show→open，
## 定时自动收（时长=ui_unlock_popup_dur 镜像；计时由装配方/测试 tick 驱动，
## 本类只提供确定性状态机：open→auto_closed，一次消费）。
## 阻塞语义：解锁弹卡注册于 z2（A.2 注册表）但轻量自动收=短暂阻塞自动解除
## （≠决策卡强迫处理；不消耗 L3 全屏预算——非金框）。

## ---------- ui.json 镜像常量（GUT test_unlock_popup_autoclose 断言=表值） ----------

const AUTO_CLOSE_DUR: float = 3.0  # ui_unlock_popup_dur（≤3s 自动收）

var _visible: bool = false
var _consumed: bool = false


## 展示一张解锁弹卡（重置状态；先前未消费的自动作废——防叠卡）。
func show() -> void:
	_visible = true
	_consumed = false


## 计时到点自动收（≤3s；一次消费=收完即不可再关）。
func auto_close() -> void:
	if not _visible or _consumed:
		return
	_visible = false
	_consumed = true


func is_visible() -> bool:
	return _visible


func is_consumed() -> bool:
	return _consumed


func get_duration() -> float:
	return AUTO_CLOSE_DUR
