class_name LayoutPolicy
extends RefCounted
## L3 布局策略纯函数（#145；ui-ux-spec A.1/B.5 主台形态 + DR-009/015
## 竖屏纪律）。与渲染分离：只出"布局判定/约束"（headless 可单测），
## 装配方据返回值切形态。
## 职责：
## - **竖屏判定**：逻辑视口宽高 → portrait/landscape（触屏优先形态）；
## - **折叠形态**：竖屏下主区折叠（员工区横滑行/资源栏副行/工作区永不折叠
##   ——DR-009/015 硬纪律）；
## - **触控约束判定**：meets_touch_target(width, height, is_dot, touch_min,
##   touch_min_dot)——数值由调用方传参（真源 ui.json，经 L2 数据面/测试读表
##   下发，本类零读表=ADR-0016 L3 禁读 L4）。
## 硬约束：L3 零业务计算（ADR-0016）；纯静态零状态零 IO；数值零硬编码。

## 主区稳定键（A.1 四主区；竖屏折叠形态声明用）
const ZONE_WORKSPACE: String = "workspace"
const ZONE_STAFF: String = "staff"
const ZONE_RESOURCE_BAR: String = "resource_bar"
const ZONE_DOCK: String = "dock"

## 折叠形态（B.5 竖屏折叠形态列）
const FOLD_NONE: String = "none"  # 永不折叠（工作区）
const FOLD_HSCROLL: String = "hscroll"  # 横滑行单行（员工区）
const FOLD_SUBROW: String = "subrow"  # 单行折叠副行（资源栏）


## 竖屏判定（逻辑视口宽高；宽<高=竖屏。触屏优先：竖持=窄宽）
static func is_portrait(viewport_width: float, viewport_height: float) -> bool:
	return viewport_width < viewport_height


## 主区折叠形态（竖屏专用表；横屏=无折叠全显）。工作区恒 FOLD_NONE
## （DR-009/015：竖屏工作区永不折叠——断言锚点）
static func fold_shape(zone: String, portrait: bool) -> String:
	if not portrait:
		return FOLD_NONE
	match zone:
		ZONE_WORKSPACE, ZONE_DOCK:
			return FOLD_NONE
		ZONE_STAFF:
			return FOLD_HSCROLL
		ZONE_RESOURCE_BAR:
			return FOLD_SUBROW
	return FOLD_NONE


## 触控目标判定（ui-ux B.5/触屏纪律：可点 ≥touch_min 48；灰点例外
## ≥touch_min_dot 24——数值由调用方按 ui.json 传参，防 L3 读表违规）。
static func meets_touch_target(
	width: float, height: float, is_dot: bool, touch_min: float, touch_min_dot: float
) -> bool:
	var min_size: float = touch_min_dot if is_dot else touch_min
	return width >= min_size and height >= min_size
