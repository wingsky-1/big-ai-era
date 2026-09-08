class_name ResponsiveLayoutManager
extends RefCounted

## 竖屏折叠与动画预算管理器（L3 RefCounted，DR-009 / DR-020 / DR-022③）：
## - 竖屏折叠序（DR-009）：
##   第一折：资源栏副行折叠（折入折叠菜单）
##   永不折叠：工作区永不折叠（核心快感区）
## - 动画三级预算（DR-009）：
##   L1 常规微动（0s，无次数限制）
##   L2 展开过渡（0.15s，无限制）
##   L3 重磅仪式（出分/阶段跃迁/终局，一局 <= 3 次）
## - 术语首次触发式提示（DR-022③）：记录已提示术语，防频繁打扰

signal layout_folded(folded: bool, folded_elements: Array[String])
signal l3_animation_triggered(anim_id: String, used_count: int, remaining: int)

const MAX_L3_ANIMATIONS_PER_GAME: int = 3  # num-ok: L3 动画上限（表现层）

# 竖屏内容基准（v0.1.2）：canvas_items+expand 下逻辑宽恒等于基准宽，
# 1280 基准会让 390 物理宽的手机整体缩到 ~0.3 倍（字小如蚁）。
# 竖屏改用 480 基准：390/480 ≈ 0.81 缩放，字号恢复可读。
const PORTRAIT_CONTENT_SCALE: Vector2i = Vector2i(480, 854)  # num-ok: 竖屏内容基准分辨率（表现层）
const LANDSCAPE_CONTENT_SCALE: Vector2i = Vector2i(1280, 720)  # num-ok: 横屏内容基准分辨率（表现层）

var _is_portrait: bool = false
var _resource_subrow_folded: bool = false
var _workspace_folded: bool = false  # 硬约束：永不为 true
var _l3_animation_counter: int = 0
var _shown_terms: Dictionary = {}


## 纯函数：由物理视口尺寸解析内容缩放基准（可 GUT 单测，无 Node 依赖）。
## 判定与 update_viewport 一致：y > x 视为竖屏。
static func resolve_content_scale(physical_size: Vector2i) -> Vector2i:
	return PORTRAIT_CONTENT_SCALE if physical_size.y > physical_size.x else LANDSCAPE_CONTENT_SCALE


func setup(viewport_size: Vector2) -> void:
	update_viewport(viewport_size)
	_l3_animation_counter = 0
	_shown_terms.clear()


func is_portrait() -> bool:
	return _is_portrait


func is_resource_subrow_folded() -> bool:
	return _resource_subrow_folded


func is_workspace_folded() -> bool:
	return _workspace_folded


func get_l3_animation_count() -> int:
	return _l3_animation_counter


func get_remaining_l3_animations() -> int:
	return maxi(0, MAX_L3_ANIMATIONS_PER_GAME - _l3_animation_counter)


## 视口大小变化响应（竖屏折叠规则）
func update_viewport(viewport_size: Vector2) -> void:
	_is_portrait = (viewport_size.y > viewport_size.x)
	var folded_elements: Array[String] = []

	if _is_portrait:
		# 第一折：资源栏副行折叠
		_resource_subrow_folded = true
		folded_elements.append("resource_subrow")
	else:
		_resource_subrow_folded = false

	# 核心红线：工作区永不折叠！
	_workspace_folded = false

	layout_folded.emit(_is_portrait, folded_elements)


## 申请播放 L3 重磅动画（一局严格 <= 3 次）
func request_l3_animation(anim_id: String) -> bool:
	if _l3_animation_counter >= MAX_L3_ANIMATIONS_PER_GAME:
		return false

	_l3_animation_counter += 1
	var rem: int = get_remaining_l3_animations()
	l3_animation_triggered.emit(anim_id, _l3_animation_counter, rem)
	return true


## 术语首次触发式提示（首次触发返回 true，之后返回 false）
func trigger_term_hint_if_first_time(term_id: String) -> bool:
	if _shown_terms.has(term_id):
		return false
	_shown_terms[term_id] = true
	return true
