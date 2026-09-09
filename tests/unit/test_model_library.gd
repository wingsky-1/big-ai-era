extends GutTest
## #143 验收点 3：峰值分数显示——模型卡记历史最高（GUT：
## `test_model_peak_score`）。真源=models-spec OP-MDL-03/OP-MDL-04 +
## model_term_peak（"模型历史最高分=峰值分数；记在模型卡上"）+ architecture
## §9.1 products.models 行（id/name/base_id/ndim/score/peak/…）。
## 语义：入册即峰值（P2 迭代提升才可能再高）；库聚合=玩家历史最高
## （get_highest_peak）。ModelLibrary=收藏容器，不做 SOTA 判定（#142 解耦）。


func _make_library() -> ModelLibrary:
	var library := ModelLibrary.new()
	autofree(library)
	return library


func test_model_peak_score() -> void:
	var library := _make_library()
	# 首模型入册：peak=出分 score
	var first: Dictionary = library.add_model(
		"灵犀初号", "mini", [40.0, 40.0, 40.0, 40.0, 40.0], 55.5, 8
	)
	assert_false(first.is_empty(), "入册成功")
	assert_eq(str(first["name"]), "灵犀初号", "定名入册")
	assert_eq(str(first["base_id"]), "mini", "基座入册")
	assert_almost_eq(float(first["score"]), 55.5, 0.001, "出分入册")
	assert_almost_eq(float(first["peak"]), 55.5, 0.001, "首入册 peak=出分")
	# 第二模型（更高分）：各自 peak=各自出分（峰值=单模型历史最高）
	var second: Dictionary = library.add_model(
		"回声", "lingxi_1", [50.0, 50.0, 50.0, 50.0, 50.0], 72.0, 20
	)
	assert_almost_eq(float(second["peak"]), 72.0, 0.001, "第二模型 peak=72")
	# 单模型峰值不变（本批无迭代：再入册同模型=新条目，原条目峰值不变）
	library.add_model("回声2号", "lingxi_1", [50.0, 50.0, 50.0, 50.0, 50.0], 60.0, 30)
	var original: Dictionary = library.get_entry(str(first["id"]))
	assert_almost_eq(float(original["peak"]), 55.5, 0.001, "原模型 peak 不被后来者改（收藏语义）")
	# 玩家历史最高=各模型 peak 最大（模型卡"历史最高"数据面）
	assert_almost_eq(library.get_highest_peak(), 72.0, 0.001, "库峰值聚合=72")
	# ndim 数组化字段（5 维按序入档；architecture §9.1）
	assert_eq((first["ndim"] as Array).size(), 5, "ndim 5 维数组入档")
	# 空名/空基座=防御拒（先触发，assert_push_error 后消费缓冲）
	var bad := library.add_model("", "mini", [], 10.0)
	assert_true(bad.is_empty(), "空名入册拒")
	assert_push_error(
		"ModelLibrary.add_model: name/base_id 不可空", "空名入册须 push_error（Error Tracker 消费）"
	)
	# 查询：未知 id=空 dict
	assert_true(library.get_entry("m999").is_empty(), "未知 id 查询=空")


func test_model_library_restore_snapshot() -> void:
	# 读档重建（纯值注入零环；存档 schema products.models 段装配方=GameWorld
	# 批，本测试覆盖容器重建语义）
	var library := _make_library()
	library.add_model("小满", "mini", [40.0, 40.0, 40.0, 40.0, 40.0], 48.0, 6)
	library.add_model("候鸟", "changhe_1", [60.0, 60.0, 60.0, 60.0, 60.0], 81.2, 40)
	var snapshot: Array = library.get_all_entries()
	var rebuilt := ModelLibrary.new()
	autofree(rebuilt)
	rebuilt.restore_from_snapshot(snapshot)
	assert_eq(rebuilt.count(), 2, "重建后条数=快照")
	assert_almost_eq(rebuilt.get_highest_peak(), 81.2, 0.001, "重建后峰值聚合正确")
	var entry := rebuilt.get_entry("m1")
	assert_eq(str(entry["name"]), "小满", "重建后条目字段完整")
	# 续 id 防重复分配：重建后再入册 id 不冲突
	var added := rebuilt.add_model("回声", "mini", [40.0, 40.0, 40.0, 40.0, 40.0], 50.0, 50)
	assert_eq(str(added["id"]), "m3", "重建后续 id=m3（防覆写 m1/m2）")


func test_model_peak_signal_emitted() -> void:
	# 真实发射点纪律（架构 §5.2）：入册发 model_archived（L3 模型库/头条消费）
	var library := _make_library()
	watch_signals(library)
	library.add_model("守拙", "mini", [40.0, 40.0, 40.0, 40.0, 40.0], 44.0, 5)
	assert_signal_emitted(library, "model_archived", "入册发 model_archived 信号")
	# rename 路径（命名确认流；改名后库条目更新）
	var renamed := library.rename_model("m1", "守拙改")
	assert_true(renamed, "改名成功")
	assert_eq(str(library.get_entry("m1")["name"]), "守拙改", "库内名字更新")
	assert_signal_emitted(library, "model_renamed", "改名发 model_renamed 信号")
	# 空名改名=拒（先触发，assert_push_error 后消费）
	assert_false(library.rename_model("m1", ""), "空名改名拒")
	assert_push_error("ModelLibrary.rename_model: name 不可空", "空名改名须 push_error（Error Tracker 消费）")
	assert_false(library.rename_model("m999", "无名"), "未知模型改名拒")
