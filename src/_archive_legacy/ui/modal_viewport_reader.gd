class_name ModalViewportReader
extends RefCounted

## 弹层视口读取器（纯函数可单测）：
## 优先取父容器（ModalContainer）实际区域——即弹层的真实可用上界；
## 挂载瞬间父区域可能尚未布局（0 尺寸），此时回退根窗口尺寸。


static func read(root: Control) -> Vector2:
	if root.get_parent() != null:
		var parent_ctrl := root.get_parent() as Control
		if parent_ctrl != null:
			var area: Vector2 = parent_ctrl.get_global_rect().size
			if area.x > 0.0 and area.y > 0.0:
				return area
	return root.get_tree().root.size
