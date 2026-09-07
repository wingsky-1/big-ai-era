class_name MainScene
extends Control

## 启动自检场景（非游戏 Demo）：
## 验证场景树完整性 + 文本管线（TextService/Formatter，PR1）在真实引擎环境中可用。
## 表现层只读，逻辑验证全部在 tests/ 下完成。

var _text_count: int = -1

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_text_count = TextService.table().size()
	_status_label.text = (
		"SCAFFOLD OK | texts=%d | %s"
		% [
			_text_count,
			Formatter.format_money(50000),
		]
	)


## 供冒烟测试断言（不进入渲染逻辑）。
func get_text_count() -> int:
	return _text_count
