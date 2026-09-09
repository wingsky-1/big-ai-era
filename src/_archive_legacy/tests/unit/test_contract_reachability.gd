extends GutTest

## #104 PR-C 契约可达性门禁（防"契约面存在但玩家永不可达"复发）：
## 1. test_contract_signals_have_emit_sites      —— 11 个契约信号在 `src/**` 至少 1 个 emit 点
## 2. test_contract_commands_reachable_from_ui   —— 12 个契约命令在 `src/ui/**` 至少 1 个调用点
## 3. test_panels_have_mount_or_push_sites       —— 12 个面板枚举都有挂载/推入点（防"入栈但不渲染"）
##
## 背景（issue #104）：本轮实测三条同类断链——`enqueue_task`/`start_training` 零 UI 调用方、
## `decision_pending` 零 emit 点（决策卡永不可见）。契约面存在 ≠ 玩家可达，故用门禁锁死。

const MAIN_PATH: String = "res://src/ui/main/main.gd"
const PRESENTER_PATH: String = "res://src/ui/dashboard_presenter.gd"

## 面板注册表（与 PanelStack.PanelId 同名；NONE/DASHBOARD 为哨兵/常驻概念位，不入栈）。
const PANEL_IDS: PackedStringArray = [
	"ROSTER",
	"TECH_TREE",
	"TASK_MGMT",
	"REPORT_ARCHIVE",
	"INTRO",
	"DECISION_CARD",
	"NAMING_DIALOG",
	"GAME_OVER",
	"PAUSE_MENU",
	"AUTO_REPORT",
	"FINALE",
	"TRAINING",
]


func test_contract_signals_have_emit_sites() -> void:
	var sources: Dictionary = _read_gd_sources("res://src")
	assert_gt(sources.size(), 0, "应能读到 src/** 的 GDScript")
	for signal_variant: Variant in GameWorld.CONTRACT_SIGNALS:
		var signal_name: String = str(signal_variant)
		var needle: String = "%s.emit(" % signal_name
		var hits: int = 0
		for path: String in sources:
			hits += (sources[path] as String).count(needle)
		assert_gt(hits, 0, "契约信号 %s 必须至少有一个 emit 点（否则 UI 永不可达）" % signal_name)


func test_contract_commands_reachable_from_ui() -> void:
	var ui_sources: Dictionary = _read_gd_sources("res://src/ui")
	assert_gt(ui_sources.size(), 0, "应能读到 src/ui/** 的 GDScript")
	for command_variant: Variant in GameWorld.CONTRACT_COMMANDS:
		var command: String = str(command_variant)
		var needle: String = "%s(" % command
		var hits: int = 0
		for path: String in ui_sources:
			hits += (ui_sources[path] as String).count(needle)
		assert_gt(hits, 0, "契约命令 %s 必须有 src/ui/** 调用点（玩家可达，issue #104）" % command)


func test_panels_have_mount_or_push_sites() -> void:
	var combined: String = (
		FileAccess.get_file_as_string(MAIN_PATH) + FileAccess.get_file_as_string(PRESENTER_PATH)
	)
	assert_false(combined.is_empty(), "AppShell/presenter 源码应可读取")
	for panel_id: String in PANEL_IDS:
		assert_true(
			combined.contains("PanelId.%s" % panel_id), "面板 %s 必须有挂载或推入点（防'入栈但不渲染'）" % panel_id
		)


## 递归读取目录下全部 .gd 源码（键 = res:// 路径，值 = 源码文本）。
func _read_gd_sources(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	var files: Array[String] = []
	_collect(dir_path, files)
	for path: String in files:
		out[path] = FileAccess.get_file_as_string(path)
	return out


func _collect(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(dir_path.path_join(entry), out_files)
		elif entry.ends_with(".gd"):
			out_files.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
