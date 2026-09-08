extends GutTest

## issue #84 门禁：verify.sh 必须隔离 Godot 的 user:// 目录。
## 根因：同一机器上多个 worktree/并发 GUT 进程共享 app_userdata，
## SaveSystem 原子写（tmp→校验→rename）互相踩踏 → 与代码无关的假失败。

const VERIFY_PATH: String = "res://scripts/verify.sh"


func test_verify_isolates_user_data_dir() -> void:
	var file := FileAccess.open(VERIFY_PATH, FileAccess.READ)
	assert_not_null(file, "scripts/verify.sh 应可读")
	if file == null:
		return
	var script: String = file.get_as_text()

	assert_true(script.contains("XDG_DATA_HOME"), "verify.sh 应导出 XDG_DATA_HOME 隔离 user:// 目录")
	assert_true(script.contains("mktemp -d"), "隔离目录应由 mktemp -d 生成（每次运行唯一）")
	assert_true(script.contains('rm -rf "$XDG_DATA_HOME"'), "verify.sh 退出时应清理隔离目录（trap EXIT）")
