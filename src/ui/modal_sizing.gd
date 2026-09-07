class_name ModalSizing
extends RefCounted

## 弹层自适应尺寸纯函数（v0.1.2，L3 无 Node 依赖，可 GUT 单测）：
## 弹层根 PanelContainer 采用"中心锚 + custom_minimum_size"替代 v0.1.1 的固定
## offsets——固定尺寸在 480 逻辑宽竖屏基准下会横向溢出（tech_tree 520 > 480）。
## 期望尺寸存入节点 meta，视口变化时随窗口伸缩（不小于设计期望，不大于视口减边距）。

const VIEWPORT_MARGIN: int = 24
## 预留 Dock 之上的纵向安全边距（竖屏下顶部条区更高）
const VERTICAL_MARGIN: int = 96

const DESIGN_SIZES: Dictionary = {
	"DecisionCardDialog": Vector2(360, 280),
	"WeeklyReportDialog": Vector2(360, 320),
	"TechTreeDialog": Vector2(520, 440),
	"StaffRosterDialog": Vector2(440, 400),
	"GameOverDialog": Vector2(360, 280),
}


## 由视口大小与设计期望解析弹层根节点的 custom_minimum_size。
static func resolve_min_size(viewport_size: Vector2, expected: Vector2) -> Vector2:
	var avail_w: float = maxf(0.0, viewport_size.x - VIEWPORT_MARGIN * 2.0)
	var avail_h: float = maxf(0.0, viewport_size.y - VERTICAL_MARGIN)
	return Vector2(minf(expected.x, avail_w), minf(expected.y, avail_h))


## 弹层根节点挂载后调用：写入设计期望并按当前视口收敛 min size。
static func apply(root: Control) -> void:
	if root == null:
		return
	var expected: Vector2 = root.get_meta("modal_design_size", Vector2.ZERO)
	if expected == Vector2.ZERO:
		var key: String = root.get_script().resource_path.get_file().get_basename()
		expected = DESIGN_SIZES.get(key, Vector2(360, 280))
		root.set_meta("modal_design_size", expected)
	root.custom_minimum_size = resolve_min_size(ModalViewportReader.read(root), expected)


## 视口变化时调用：按当前视口重新收敛（期望尺寸从 meta 恢复，可反复重算）。
static func refresh(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var expected: Vector2 = root.get_meta("modal_design_size", Vector2.ZERO)
	if expected == Vector2.ZERO:
		apply(root)
		return
	root.custom_minimum_size = resolve_min_size(ModalViewportReader.read(root), expected)


## 测试后门：清理 meta，让 apply 重新按脚本名解析设计期望。
static func reset(root: Control) -> void:
	if root != null and is_instance_valid(root):
		root.remove_meta("modal_design_size")
