class_name NamingDialogLogic
extends RefCounted
## L3 命名框逻辑（#151；ui-ux A.3 OP-UX-05「输入 ≤12 字 → 确认（或交给命运）；
## 被拒弹层不关闭可重输+原因句」+ onboarding A.2 naming_dialog）。
## 本类=纯逻辑（headless 可单测）：提交→NameFilter.check（L1 三层过滤机制，
## #151 裁决：本批只启用长度≤12/字符白名单/空校验路径，敏感词表 =#143 既有
## 内容不动，词表层留后续批；机制层仍走 NameFilter 单入口=零双源）。
## 被拒=保持打开可重输（不接受不关闭）；通过=调注入的 submit_name（L2
## ModelCeremony 命令，注入防 L3 import L2）；skip=「交给命运」默认池轮转。
## 硬约束：零业务计算（过滤=NameFilter 单源）；数值零硬编码（长度上限=
## ui_naming_max_len 镜像，=sensitive_words name_filter_max_len 断言锁同源）。

## ---------- ui.json 镜像常量（GUT test_naming_dialog_three_layers 断言=表值） ----------

const NAMING_MAX_LEN: int = 12  # ui_naming_max_len（=name_filter_max_len 同源）

var _submit_name: Callable = Callable()
var _skip_naming: Callable = Callable()
var _peek_pending: Callable = Callable()
var _open: bool = false
var _last_reason: String = ""


## 绑定 L2 命令（装配方注入 ModelCeremony 方法；防 L3 import L2）。
func bind(submit_name: Callable, skip_naming: Callable, peek_pending: Callable) -> void:
	_submit_name = submit_name
	_skip_naming = skip_naming
	_peek_pending = peek_pending


## 弹开命名框（pend 在=打开等待输入）。
func open() -> void:
	_open = true
	_last_reason = ""


## 提交候选名（NameFilter 单入口校验）。返回：
## - {accepted:true}：通过 → 调注入 submit_name（clean 文本），弹层由装配方关
## - {accepted:false, reason}：被拒 → 弹层保持打开可重输（本类 _open 不变）
func submit(name: String) -> Dictionary:
	if not _open:
		return {"accepted": false, "reason": "closed"}
	var result := NameFilter.check(name)
	if not bool(result.get("ok", false)):
		_last_reason = str(result.get("reason", ""))
		return {"accepted": false, "reason": _last_reason}
	if _submit_name.is_valid():
		var clean := str(result.get("clean", name))
		_submit_name.call(clean)
	_open = false
	return {"accepted": true, "reason": ""}


## 「交给命运」默认池轮转（独立口，不经 check——防空串绕过语义，L2 侧守）。
func skip() -> Dictionary:
	if not _open:
		return {"accepted": false, "reason": "closed"}
	if _skip_naming.is_valid():
		_skip_naming.call()
	_open = false
	return {"accepted": true, "reason": ""}


## 当前待命名模型（L2 ceremony 数据面经注入读取）。
func peek_pending() -> Dictionary:
	if _peek_pending.is_valid():
		return _peek_pending.call()
	return {}


func is_open() -> bool:
	return _open


func get_last_reason() -> String:
	return _last_reason


func get_max_len() -> int:
	return NAMING_MAX_LEN
