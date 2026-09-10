class_name PanelHost
extends Control
## L3 面板宿主（批7.3 #190）：z1 轻遮罩（点外可关）+ z2 阻塞遮罩（点外不关，
## 强迫处理）两层全屏覆盖——ui-ux A.2 PanelStack z1/z2 语义的渲染侧。
## 栈语义单点仍在 PanelStack（本类不重复判定层级）；面板实例由装配方
## （main 组合根）构造移交，本类只管挂载/显隐/遮罩事件。零业务计算
## （ADR-0016）；实例缓存权在装配方（mount），close 只 detach 不释放。

## z1 遮罩点击（装配方消费：栈回退+收起；z2 遮罩无信号=点击不关闭）
signal z1_backdrop_pressed

## 遮罩浓度（z1 轻/z2 深；ui.json token 化留后续批，本批常量与 #146 同款）
const DIM_Z1: Color = Color(0.0, 0.0, 0.0, 0.35)
const DIM_Z2: Color = Color(0.0, 0.0, 0.0, 0.55)

var _z1_layer: Control
var _z2_layer: Control
var _z1_slot: CenterContainer
var _z2_slot: CenterContainer
var _z1_panel: Control = null
var _z2_panel: Control = null


func _init() -> void:
	# 宿主自身透明不挡主台；拦截全部由两层遮罩按 visible 承担
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_z1_layer = _build_layer(DIM_Z1, true)
	_z1_slot = _build_slot()
	_z1_layer.add_child(_z1_slot)
	_z2_layer = _build_layer(DIM_Z2, false)
	_z2_slot = _build_slot()
	_z2_layer.add_child(_z2_slot)


## ---------- z1（轻遮罩，点外关闭） ----------


func show_z1(panel: Control) -> void:
	if panel == null:
		return
	_attach(_z1_slot, panel)
	_z1_panel = panel
	_z1_layer.visible = true


func close_z1() -> void:
	_z1_layer.visible = false
	if _z1_panel != null and _z1_panel.get_parent() == _z1_slot:
		_z1_slot.remove_child(_z1_panel)
	_z1_panel = null


func is_z1_open() -> bool:
	return _z1_layer.visible


func get_z1_panel() -> Control:
	return _z1_panel


## ---------- z2（阻塞遮罩，点外不关） ----------


func show_z2(panel: Control) -> void:
	if panel == null:
		return
	_attach(_z2_slot, panel)
	_z2_panel = panel
	_z2_layer.visible = true


func close_z2() -> void:
	_z2_layer.visible = false
	if _z2_panel != null and _z2_panel.get_parent() == _z2_slot:
		_z2_slot.remove_child(_z2_panel)
	_z2_panel = null


func is_z2_open() -> bool:
	return _z2_layer.visible


func get_z2_panel() -> Control:
	return _z2_panel


## ---------- 私有 ----------


## 层骨架：全屏 Control + 全屏遮罩 ColorRect（STOP 吃点击）
func _build_layer(dim: Color, dismissable: bool) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	var backdrop := ColorRect.new()
	backdrop.color = dim
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if dismissable:
		backdrop.gui_input.connect(_on_z1_backdrop_input)
	layer.add_child(backdrop)
	add_child(layer)
	return layer


## 面板槽：全屏 CenterContainer 居中 + 不拦点击（面板自身 STOP，槽外命中
## 穿透到遮罩=点外关闭）
func _build_slot() -> CenterContainer:
	var slot := CenterContainer.new()
	slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


## 面板挂载（实例复用：先 detach 旧槽位再入新槽，防同实例双父）
func _attach(slot: CenterContainer, panel: Control) -> void:
	if _z1_panel == panel and _z1_panel.get_parent() == _z1_slot:
		_z1_slot.remove_child(_z1_panel)
	if _z2_panel == panel and _z2_panel.get_parent() == _z2_slot:
		_z2_slot.remove_child(_z2_panel)
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	slot.add_child(panel)


func _on_z1_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			z1_backdrop_pressed.emit()
