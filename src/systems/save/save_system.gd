extends Node
## SaveSystem（autoload，唯一全局服务；脚本禁 class_name，AGENTS.md 红线）。
## 只做 IO 壳（ADR-0003，单向依赖仅 L0/L1）：原子写 tmp→校验→rename 双缓冲 +
## JSON 读写；迁移逻辑全在 SaveMigrator（纯静态可单测）；快照映射在 SnapshotCodec
## （L2，本类不反向引用）。v1.0.0 原子写纪律（ADR-0005）：写失败保留磁盘原档。

const SAVE_PATH: String = "user://savegame.json"
const SAVE_BAK_SUFFIX: String = ".bak"
const SAVE_TMP_SUFFIX: String = ".tmp"


## 保存游戏数据：盖章当前 schema 版本 + 深拷贝防别名，双缓冲原子写。
## 两档（周结自动/手动）同格式同路径可覆盖——调用方用 SnapshotCodec.encode
## 选定 save_kind，本类不感知档类。返回是否成功（失败=磁盘原档未动）。
func save_game(data: Dictionary, path: String = SAVE_PATH) -> bool:
	var stamped := data.duplicate(true)
	stamped[SaveMigrator.VERSION_KEY] = SaveMigrator.CURRENT_VERSION
	return _write_json_atomic(stamped, path)


## 读取存档：JSON 解析 → SaveMigrator 迁移（版本纪律：缺失按 v1/只升不降/
## 禁跳步/未来版本拒绝）。主档读不出回退 .bak 备档；迁移拒绝=保留磁盘原档并返回空。
## 返回的档含信封（schema_version/save_kind），世界态重建由调用方经
## SnapshotCodec.decode 剥离（唯一映射点，本类不做业务解释）。
func load_game(path: String = SAVE_PATH) -> Dictionary:
	var parsed := _read_json(path)
	if parsed.is_empty():
		var bak_path := path + SAVE_BAK_SUFFIX
		if FileAccess.file_exists(bak_path):
			parsed = _read_json(bak_path)
			if not parsed.is_empty():
				push_warning("SaveSystem: 主档不可读，已从备档回退: %s" % path)
	if parsed.is_empty():
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + SAVE_BAK_SUFFIX):
			push_error("SaveSystem: 存档不可读（主档与备档均无效），磁盘原档保留: %s" % path)
		return {}
	var migrated := SaveMigrator.migrate(parsed)
	if migrated.is_empty():
		push_error("SaveSystem: 存档 schema 迁移被拒，已拒绝加载（磁盘原档保留）: %s" % path)
		return {}
	return migrated


## 判断存档是否存在（新游戏判定用；.bak 不算有效档）。
func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## 读单个 JSON 文件；缺失返回 {}（调用方用 file_exists 区分），损坏也返回 {}。
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: 无法读取存档 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("SaveSystem: 存档不是合法 JSON 对象，已拒绝加载: %s" % path)
		return {}
	return parsed


## 双缓冲原子写（唯一写点）：写 tmp → 重读校验（字节级+可解析）→ 换名落位。
## 任一步失败即中止，主档保持原样（DoD test_save_atomic_keep_old_on_fail）。
func _write_json_atomic(data: Dictionary, path: String) -> bool:
	var tmp_path := path + SAVE_TMP_SUFFIX
	var payload := JSON.stringify(data, "\t")
	# 残留 tmp（上次失败产物）先清，避免脏校验
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp == null:
		push_error(
			"SaveSystem: 无法写入临时档 %s（错误码 %d），磁盘原档未动" % [tmp_path, FileAccess.get_open_error()]
		)
		return false
	tmp.store_string(payload)
	if tmp.get_error() != OK:
		push_error("SaveSystem: 临时档写入失败（错误码 %d），磁盘原档未动" % tmp.get_error())
		return false
	tmp = null
	# 重读校验：JSON 可解析 + 字节级一致（防截断/写坏）。
	# 不能 stringify(parse(payload)) 后比对——引擎把 JSON 数字解析为 float，
	# 重序列化必得 "12345.0" != "12345" 永不相等，故按原始字节 sha256 比对。
	var verify := _read_json(tmp_path)
	if verify.is_empty() or not _read_raw(tmp_path).sha256_text() == payload.sha256_text():
		push_error("SaveSystem: 临时档校验失败（不可解析或字节不一致），磁盘原档未动: %s" % path)
		return false
	return _commit_tmp(tmp_path, path)


## 校验通过后的提交阶段：主档转 .bak 上一代，tmp 换名落位为主档。
## 任一步失败即中止并尽量还原，保证磁盘原档不被半写覆盖。
func _commit_tmp(tmp_path: String, path: String) -> bool:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		push_error("SaveSystem: 无法打开存档目录，磁盘原档未动: %s" % path)
		return false
	if (
		FileAccess.file_exists(path)
		and dir.rename(path.get_file(), path.get_file() + SAVE_BAK_SUFFIX) != OK
	):
		push_error("SaveSystem: 主档转备档失败，中止换名以保旧档: %s" % path)
		return false
	if dir.rename(tmp_path.get_file(), path.get_file()) != OK:
		push_error("SaveSystem: 临时档换名失败: %s" % path)
		if FileAccess.file_exists(path + SAVE_BAK_SUFFIX):
			dir.rename(path.get_file() + SAVE_BAK_SUFFIX, path.get_file())
		return false
	return true


## 读文件原始文本（字节级校验用，不做解析）。
func _read_raw(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
