extends GutTest
## #144 验收点 5：RivalPack 容器——P0 单员无"单竞对特判"分支
## （GUT：`test_rivalpack_no_single_special_case`）。
## 真源=architecture-100 §7 E6（RivalPack 容器 P0 只装深巷 1 员；时间线
## 消费指针/分数曲线/预警谓词按"每竞对一份"设计；灰梯 P1/多竞对 P2=包内
## 加员；P0 不加任何"单竞对特判"分支——`if rival.name=="深巷"` 即违规）。
## 断言：源码无单竞对名字比较；容器接口按数组遍历（员数无关）。

const RIVALS_PATH: String = "res://src/data/rivals.json"


func test_rivalpack_no_single_special_case() -> void:
	# 容器从表 _order 驱动（加员=表加行，代码零改动）
	var table := DataLoader.load_json(RIVALS_PATH)
	var order: Array = table["rival_actors"]["_order"]
	var pack := RivalPack.new()
	autofree(pack)
	assert_eq(pack.count(), order.size(), "包员数=表 _order（表驱动）")
	# 接口按数组遍历：单员容器视图=数组长度 1（无特判形状）
	var views := pack.get_all_views()
	assert_eq(views.size(), pack.count(), "视图数组=员数（零特判遍历）")
	# 每员一份时间线消费指针/分数曲线（E6 按"每竞对一份"）
	for view: Dictionary in views:
		assert_false(str(view.get("actor_key", "")).is_empty(), "视图含 actor_key")
		assert_false(str(view.get("name_key", "")).is_empty(), "视图含 name_key（文案键）")
		assert_true(view.has("score_curve"), "每员一份 score_curve 容器位")
		assert_true(view.has("timeline_consumed"), "每员一份消费指针位")
	# 按 key 查询（容器通用查询面；未知 key=空 dict 不抛错）
	var known: Dictionary = pack.get_rival_view(str(order[0]))
	assert_eq(str(known["actor_key"]), str(order[0]), "按 key 查询命中")
	assert_true(pack.get_rival_view("no_such_actor").is_empty(), "未知 key=空 dict（防御）")


func test_rivalpack_no_deep_alley_name_branch() -> void:
	# 源码零"单竞对特判"：rivals/ 目录代码不得出现按名字 if 分支
	# （E6 违规判据：`if rival.name=="深巷"` / actor_key 字面量比较即违规）。
	# 文件头注释/常量/文案键引用豁免（表键名非特判）。
	var rival_code := ""
	for path: String in [
		"res://src/entities/rivals/rival.gd",
		"res://src/entities/rivals/rival_pack.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			rival_code += file.get_as_text() + "\n"
	# 特判形态=名字比较出现在逻辑分支；表键 "deep_alley" 只允许在测试/表出现。
	# 源码内若含 == "deep_alley" 即违规（本实现用 actor_key 参数化，零字面量）
	assert_false(
		rival_code.contains('== "deep_alley"') or rival_code.contains('"deep_alley" =='),
		"源码无 deep_alley 字面量比较（actor_key 参数化=零单竞对特判）",
	)
	assert_true(rival_code.contains("advance_week"), "Rival 周推进接口在位")
	assert_true(rival_code.contains("for rival"), "容器按数组遍历（员数无关）")
