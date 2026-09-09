extends GutTest
## #129 验收点 1：ADR-0018/0019/0020/0026 四篇落 docs/adr/ 且含 背景/备选/后果。
## 验收点 2：各 ADR 与 architecture-100.md 对应节一致（引用核对=文件存在性+关键术语）。

const ADR_FILES: Array[String] = [
	"res://docs/adr/0018-unified-task-board.md",
	"res://docs/adr/0019-n-dims-shared-component.md",
	"res://docs/adr/0020-output-settlement-declaration.md",
	"res://docs/adr/0026-l2-contract-upgrade.md",
]

const MANDATORY_SECTIONS: Array[String] = ["背景", "决策", "备选方案", "后果"]

## 各 ADR 与 architecture-100 对应节的一致锚点（出现即核对通过）
const ARCH_ANCHORS: Dictionary = {
	"0018": ["TaskBoard", "4 槽"],
	"0019": ["n_dims", "Σ(维×权)"],
	"0020": ["Settlement", "产出结算声明"],
	"0026": ["数据面", "命令面"],
}


func test_adr_files_exist() -> void:
	for path: String in ADR_FILES:
		assert_true(FileAccess.file_exists(path), "ADR 文件须存在: %s" % path)


func test_adr_mandatory_fields() -> void:
	for path: String in ADR_FILES:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		for section: String in MANDATORY_SECTIONS:
			assert_true(
				content.contains(section),
				"%s 缺必需小节：%s" % [path.get_file(), section],
			)


func test_adr_consistent_with_architecture() -> void:
	for path: String in ADR_FILES:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		var prefix: String = path.get_file().substr(0, 4)
		if not ARCH_ANCHORS.has(prefix):
			continue
		for anchor: String in ARCH_ANCHORS[prefix]:
			assert_true(
				content.contains(anchor),
				"%s 应含架构一致锚点 '%s'" % [path.get_file(), anchor],
			)
