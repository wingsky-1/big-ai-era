extends Node

## 存档服务（autoload 单例）：只负责持久化 IO 与升轨调度，迁移逻辑全部在
## [class SaveMigrator]（纯静态、可单测）。
##
## 架构红线：autoload 脚本禁止声明 class_name——类名会与 autoload
## 单例名冲突导致解析失败（Godot 4 明确报 "hides an autoload singleton"）。
## 全局通过 autoload 名 `SaveSystem` 访问。
##
## 唯一写入口（DR-008）：全库存档磁盘写路径只允许出现在本文件的
## `_write_json_atomic`；其余系统一律经 [method save_game] 间接落盘（PR8 三保险）。
## 双缓冲写（tmp→校验→换名+.bak）：
## 1. 写 `*.tmp` 并重读校验（字符串一致 + JSON 可解析），磁盘满/写坏不落主档；
## 2. 校验通过后主档改名 `.bak`，tmp 换名为主档；
## 3. 加载时主档损坏自动回退 `.bak`（尽量少丢周目）。

const SAVE_PATH: String = "user://savegame.json"
const SAVE_BAK_SUFFIX: String = ".bak"
const SAVE_TMP_SUFFIX: String = ".tmp"


## 保存游戏数据；自动补写当前 schema_version，成功返回 true。
func save_game(data: Dictionary, path: String = SAVE_PATH) -> bool:
	var stamped := data.duplicate(true)
	stamped["schema_version"] = SaveMigrator.CURRENT_VERSION
	return _write_json_atomic(stamped, path)


## 读取并升轨存档；无存档、主备皆损坏或 schema 过新时返回空字典。
## 主档损坏时自动回退 .bak 备档；主备皆无属正常新档状态，不报错。
func load_game(path: String = SAVE_PATH) -> Dictionary:
	var parsed := _read_json(path)
	if parsed.is_empty():
		# 主档缺失或读不出有效数据 → 尝试 .bak 回退
		var bak_path := path + SAVE_BAK_SUFFIX
		if FileAccess.file_exists(bak_path):
			parsed = _read_json(bak_path)
			if not parsed.is_empty():
				push_warning("SaveSystem: 主档损坏，已从备档回退: %s" % path)
	if parsed.is_empty():
		# 主档存在但主备均无效才是错误；完全无档=新游戏正常态
		if FileAccess.file_exists(path):
			push_error("SaveSystem: 存档不可读（主档与备档均无效）: %s" % path)
		return {}
	var migrated := SaveMigrator.migrate(parsed)
	if migrated.is_empty():
		push_error("SaveSystem: 存档 schema 无法迁移，已拒绝加载（保留磁盘原档）")
		return {}
	return migrated


## 读单个 JSON 文件；文件缺失返回 {}（调用方以 file_exists 区分），损坏也返回 {}。
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: 无法读取存档 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("SaveSystem: 存档内容不是合法 JSON 对象，已拒绝加载: %s" % path)
		return {}
	return parsed


## 读文件原始文本（字节级校验用，不做解析）。
func _read_raw(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## 双缓冲原子写：tmp→重读校验→主档转 .bak→换名；任一步失败主档保持原样。
func _write_json_atomic(data: Dictionary, path: String) -> bool:
	var tmp_path := path + SAVE_TMP_SUFFIX
	var bak_path := path + SAVE_BAK_SUFFIX
	var payload := JSON.stringify(data, "\t")
	# 1. 写临时文件并显式检查落盘错误（磁盘满等静默失败会导致丢档）
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp == null:
		push_error("SaveSystem: 无法写入临时档 %s（错误码 %d）" % [tmp_path, FileAccess.get_open_error()])
		return false
	tmp.store_string(payload)
	if tmp.get_error() != OK:
		push_error("SaveSystem: 临时档写入未完成（错误码 %d），拒绝虚报成功" % tmp.get_error())
		return false
	tmp = null
	# 2. 重读校验：字节级一致（写入完整性，防截断）且 JSON 可解析。
	#    注意不能 stringify(parse(payload)) 后对比——引擎把 JSON 数字全部
	#    解析为 float，再序列化必得 "12345.0" != "12345"，永不相等。
	var verify := _read_json(tmp_path)
	if verify.is_empty() or not _read_raw(tmp_path).sha256_text() == payload.sha256_text():
		push_error("SaveSystem: 临时档校验失败，主档未动: %s" % path)
		return false
	# 3. 主档转备档（首次保存无主档则跳过），失败则中止换名
	if FileAccess.file_exists(path) and not _rename_file(path, bak_path):
		push_error("SaveSystem: 主档转备档失败，中止换名以保旧档: %s" % path)
		return false
	# 4. tmp 换名为主档；失败时尝试用备档还原主档
	if not _rename_file(tmp_path, path):
		push_error("SaveSystem: 临时档换名失败: %s" % path)
		if FileAccess.file_exists(bak_path):
			_rename_file(bak_path, path)
		return false
	return true


## 文件改名（相对其所在目录执行）。
func _rename_file(from: String, to: String) -> bool:
	var dir := DirAccess.open(from.get_base_dir())
	if dir == null:
		return false
	return dir.rename(from.get_file(), to.get_file()) == OK
