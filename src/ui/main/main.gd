class_name MainScene
extends Control

## 启动自检场景（非游戏 Demo）：
## 验证场景树完整性 + 数据管线（DataLoader）在真实引擎环境中可用。
## 表现层只读，逻辑验证全部在 tests/ 下完成。

const ITEMS_PATH: String = "res://src/data/items.json"

var _item_count: int = -1

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	var items := DataLoader.load_json(ITEMS_PATH)
	_item_count = items.size()
	_status_label.text = "SCAFFOLD OK | items=%d" % _item_count


## 供冒烟测试断言（不进入渲染逻辑）。
func get_item_count() -> int:
	return _item_count
