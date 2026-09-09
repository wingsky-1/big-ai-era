extends Control
## 主台占位壳（#123 骨架）：v1.0.0 重建中占位画面。
## 无旧场景/主题依赖，保证空壳开局可运行不崩（验收 [P] 试玩项基础）。

@onready var _label: Label = %PlaceholderLabel


func _ready() -> void:
	_label.text = "《大 AI 时代》v1.0.0 重建中（src/ 已归档 _archive_legacy）"
