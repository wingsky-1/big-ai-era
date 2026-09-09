extends GutTest
## #126 验收点 2：快照=唯一映射点：SnapshotCodec roundtrip 无损（architecture-100 §9.2）。
## 世界态 ↔ 存档字典经唯一映射点往返（真实 JSON 字符串化/解析），Dictionary 深比较无损；
## 信封（schema_version/save_kind）只由 Codec 盖章/剥离；非法 save_kind 拒绝（stringly-typed 防线）。


func _world_state() -> Dictionary:
	# 覆盖 §9.1 全部业务域 + 开放容器（flags 字符串键）+ 数组/嵌套字典/布尔/空值
	return {
		"meta": {"saved_at_week": 3, "created_at": "2026-09-09T12:00:00"},
		"game":
		{
			"seed": 12345,
			"week": 3,
			"quarter": 1,
			"year": 2022,
			"speed": 2,
			"lab": {"name": "灵犀实验室"},
			"rng": {"event": 5, "insight": 2},
		},
		"resources":
		{
			"cash": 123456,
			"influence": 23,
			"card_hours_used": 7,
			"ledger": [{"week": 2, "delta": 50}, {"week": 3, "delta": -20}],
		},
		"staff":
		[
			{
				"id": "s1",
				"role": "research",
				"attrs": {"theory": 52, "data": 44.5},
				"state": {"current": "focus", "weeks_in": 2},
			},
			{"id": "s2", "role": "engineer", "attrs": {"engineering": 48}},
		],
		"task_board":
		{
			"slots":
			[
				{
					"type": "paper",
					"assigned_staff": ["s1"],
					"project": {"id": "p1", "progress": 0.6},
				},
				{"type": null, "assigned_staff": []},
			]
		},
		"tree":
		{
			"fog": {"align": {"deep": "lit"}},
			"nodes_lit": {"deep": 1},
			"rp_by_domain": {"align": 45, "nlp": 0},
		},
		"rivals":
		{
			"deep_alley":
			{
				"timeline_consumed": 8,
				"score_curve": [10.0, 12.5, 15.25],
				"actual_weeks": [1, 2, 3],
			}
		},
		"products":
		{
			"papers":
			[
				{
					"id": "p1",
					"title_key": "paper_topic_01",
					"domain": "align",
					"ndim": [71, 62, 55, 68],
					"cites": ["rival_p1"],
				}
			],
			"models": [],
			"chips": {"owned_tier": "t1", "selfmade": null},
		},
		"economy":
		{
			"stage": "labor",
			"loan": {"active": false, "left": 0},
			"market_boost": {"left_weeks": 0},
			"private_jobs_left": 3,
			"deploy_penalty": 0.0,
		},
		"flags": {"onb_step": "step_4", "scored": true, "freedom_0": 1},
		"events": {"pool_cursor": 5, "cd_left": {"grant": 0}},
		"reports": [{"week": 3, "headline_key": "w3_bland", "significant": false}],
	}


## 深层值等价：JSON 数字边界做数值归一化（int 123 与 float 123.0 视作等值），
## 其余类型直接 str 归一比对；字典/数组递归。
func _value_eq(actual: Variant, expected: Variant) -> bool:
	if (actual is float or actual is int) and (expected is float or expected is int):
		return is_equal_approx(float(actual), float(expected))
	return str(actual) == str(expected)


func _assert_deep_equal(actual: Dictionary, expected: Dictionary, context: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s 键数量一致" % context)
	for key: Variant in expected.keys():
		assert_true(actual.has(key), "%s 缺键 %s" % [context, str(key)])
		var av: Variant = actual.get(key)
		var ev: Variant = expected.get(key)
		if av is Dictionary and ev is Dictionary:
			_assert_deep_equal(av, ev, "%s.%s" % [context, str(key)])
		elif av is Array and ev is Array:
			assert_eq(av.size(), ev.size(), "%s.%s 数组长度一致" % [context, str(key)])
			for i: int in range(ev.size()):
				var a_item: Variant = av[i]
				var e_item: Variant = ev[i]
				if a_item is Dictionary and e_item is Dictionary:
					_assert_deep_equal(a_item, e_item, "%s.%s[%d]" % [context, str(key), i])
				elif a_item is Array and e_item is Array:
					assert_eq(
						a_item.size(), e_item.size(), "%s.%s[%d] 嵌套数组长度一致" % [context, str(key), i]
					)
					for j: int in range(e_item.size()):
						assert_true(
							_value_eq(a_item[j], e_item[j]),
							(
								"%s.%s[%d][%d] 值一致（%s vs %s）"
								% [context, str(key), i, j, str(a_item[j]), str(e_item[j])]
							),
						)
				else:
					assert_true(
						_value_eq(a_item, e_item),
						"%s.%s[%d] 值一致（%s vs %s）" % [context, str(key), i, str(a_item), str(e_item)]
					)
		else:
			assert_true(
				_value_eq(av, ev), "%s.%s 值一致（%s vs %s）" % [context, str(key), str(av), str(ev)]
			)


func test_snapshot_codec_roundtrip() -> void:
	# 世界态 → encode → 真实 JSON 往返 → decode：Dictionary 深比较无损
	var world: Dictionary = _world_state()
	var encoded := SnapshotCodec.encode(world, SnapshotCodec.SAVE_KIND_MANUAL)
	assert_eq(
		int(encoded.get(SnapshotCodec.VERSION_KEY)),
		SaveMigrator.CURRENT_VERSION,
		"encode 自动盖章当前 schema 版本",
	)
	assert_eq(
		str(encoded.get(SnapshotCodec.KIND_KEY)), SnapshotCodec.SAVE_KIND_MANUAL, "encode 记录档类"
	)
	var text := JSON.stringify(encoded)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "JSON 往返后仍是字典")
	var decoded := SnapshotCodec.decode(parsed)
	assert_false(decoded.has(SnapshotCodec.VERSION_KEY), "decode 剥离版本信封")
	assert_false(decoded.has(SnapshotCodec.KIND_KEY), "decode 剥离档类信封")
	_assert_deep_equal(decoded, world, "roundtrip")
	# 唯一映射点深拷贝隔离（功能性断言）：改动解码结果不得污染世界态
	(decoded.get("game", {}) as Dictionary)["week"] = 999
	assert_eq(int((world.get("game", {}) as Dictionary).get("week")), 3, "decode 深拷贝隔离：世界态不受影响")


func test_encode_world_state_isolation() -> void:
	# encode 返回深拷贝：改返回档不得影响世界态（防别名）
	var world: Dictionary = _world_state()
	var encoded := SnapshotCodec.encode(world, SnapshotCodec.SAVE_KIND_AUTO)
	(encoded.get("game", {}) as Dictionary)["week"] = 999
	assert_eq(int((world.get("game", {}) as Dictionary).get("week")), 3, "encode 深拷贝隔离：世界态不受影响")
	assert_eq((world.get("flags", {}) as Dictionary).get("onb_step"), "step_4", "嵌套容器隔离")


func test_decode_rejects_illegal_kind() -> void:
	# 非法 save_kind：拒绝解码并报错
	var bad := SnapshotCodec.encode(_world_state(), SnapshotCodec.SAVE_KIND_AUTO)
	bad[SnapshotCodec.KIND_KEY] = "autosave"
	var decoded := SnapshotCodec.decode(bad)
	assert_true(decoded.is_empty(), "非法 save_kind 拒绝解码（防脏档混入世界态）")
	assert_push_error("save_kind 非法", "非法档类应有可读错误")


func test_encode_rejects_illegal_kind() -> void:
	var encoded := SnapshotCodec.encode(_world_state(), "resume")
	assert_true(encoded.is_empty(), "非法 save_kind 拒绝编码（防落盘脏档）")
	assert_push_error("非法 save_kind", "非法档类编码应有可读错误")
