extends GutTest
## #143 验收点 2/4（ModelCeremony 出分仪式编排）：
## - test_score_record_semantics：出分判定接线——score>当前 SOTA=破纪录入榜；
##   同分归霸主（SotaBoard 唯一权威经 ceremony 提交；判定结果回传载荷）；
## - test_default_name_pool_rotation：默认名池确定性轮转（跳过命名=按池序
##   循环取名；texts.json model_default_name_pool_01..06 表驱动）。
## 真源=models-spec OP-MDL-03（结果：模型入库+SOTA 更新；异常=命名被拒弹层
## 不关闭可重输；跳过=默认名池确定性轮转）+ onboarding OP-ONB-05（首模型
## 强制命名无跳过）+ architecture §5.3（模型完成槽经仪式释放回 EMPTY）。


## 从 models.json 建训练项目并跑满工期至 FINISHED_PENDING（表驱动；模拟
## 周结 phase 2 完成载荷）。返回 {project, slot_index}——经 TaskBoard 推进
## 到完成态，settle_finished 前置校验 is_finished_pending 真实通过。
func _make_finished_model(base_id: String = "mini") -> Dictionary:
	var table := DataLoader.load_json("res://src/data/models.json")
	var row: Dictionary = (table["model_bases"] as Dictionary)[base_id]
	var project := ModelProject.from_base(row)
	autofree(project)
	var board := TaskBoard.new()
	autofree(board)
	var started: Dictionary = board.start_training(project)
	var slot := int(started["slot_index"])
	var finished: Array = []
	for i: int in project.get_duration_weeks():
		finished = board.week_tick()
	return {"project": finished[0]["project"], "slot_index": slot}


func _make_ceremony(library: ModelLibrary, board: SotaBoard) -> ModelCeremony:
	var ceremony := ModelCeremony.new(library, board)
	autofree(ceremony)
	return ceremony


func test_score_record_semantics() -> void:
	var library := ModelLibrary.new()
	autofree(library)
	var board := SotaBoard.new()
	autofree(board)
	var ceremony := _make_ceremony(library, board)
	var released: Array[int] = []
	ceremony.release_slot = func(slot: int) -> void: released.append(slot)
	# 首模型出分（命名强制）：55.5 无前纪录=破纪录入榜
	var done1 := _make_finished_model()
	var settle := (
		ceremony
		. settle_finished(
			{
				"project": done1["project"],
				"score": 55.5,
				"ndim":
				{"reasoning": 60.0, "knowledge": 50.0, "chat": 50.0, "speed": 50.0, "cost": 50.0},
				"week": 8,
				"slot_index": int(done1["slot_index"]),
			}
		)
	)
	assert_true(settle.ok, "出分入仪式")
	assert_eq(ceremony.get_state(), ModelCeremony.STATE_PENDING_NAMING, "命名待决")
	assert_true(bool(settle["pending"]["first"]), "首模型=署名仪式（强制命名）")
	var named := ceremony.submit_name("灵犀初号")
	assert_true(named.ok, "首模型命名确认")
	assert_eq(str(named["name"]), "灵犀初号", "定名=玩家输入")
	var m1: Dictionary = named["entry"]
	assert_almost_eq(float(m1["peak"]), 55.5, 0.001, "峰值=出分入册")
	assert_true(bool(named["broke_record"]), "55.5 首分=破纪录（空榜入榜）")
	assert_eq(released, [0], "定名后释放完成槽（防 4 槽死局）")
	# 第二模型（score>当前纪录）=破纪录
	var done2 := _make_finished_model("lingxi_1")
	var settle2 := (
		ceremony
		. settle_finished(
			{
				"project": done2["project"],
				"score": 72.0,
				"ndim":
				{"reasoning": 80.0, "knowledge": 70.0, "chat": 60.0, "speed": 60.0, "cost": 60.0},
				"week": 20,
				"slot_index": int(done2["slot_index"]),
			}
		)
	)
	assert_true(settle2.ok, "第二模型入仪式")
	assert_false(bool(settle2["pending"]["first"]), "非首模型=可跳过命名")
	assert_true(ceremony.skip_naming().ok, "交给命运跳过命名")
	# 跳过=默认名池轮转取名（池名精确断言在 test_default_name_pool_rotation）
	assert_false(str(library.get_entry("m2")["name"]).is_empty(), "跳过命名=非空默认名")
	# 第三模型 65<72=不破（低于纪录不入榜不改霸主）
	var done3 := _make_finished_model("mini")
	var settle3 := (
		ceremony
		. settle_finished(
			{
				"project": done3["project"],
				"score": 65.0,
				"ndim":
				{"reasoning": 70.0, "knowledge": 60.0, "chat": 60.0, "speed": 60.0, "cost": 60.0},
				"week": 30,
				"slot_index": int(done3["slot_index"]),
			}
		)
	)
	assert_true(settle3.ok, "第三模型入仪式")
	var named3 := ceremony.submit_name("回声")
	assert_true(named3.ok, "命名确认")
	assert_false(bool(named3["broke_record"]), "65<72 不破纪录（霸主保持）")
	assert_almost_eq(float(named3["record_score"]), 72.0, 0.001, "纪录仍 72")
	# 同分=平局归霸主（submit 72 平玩家自身纪录=不破）
	var done4 := _make_finished_model("qingyu_1")
	var settle4 := (
		ceremony
		. settle_finished(
			{
				"project": done4["project"],
				"score": 72.0,
				"ndim":
				{"reasoning": 80.0, "knowledge": 70.0, "chat": 60.0, "speed": 60.0, "cost": 60.0},
				"week": 40,
				"slot_index": int(done4["slot_index"]),
			}
		)
	)
	assert_true(settle4.ok, "第四模型入仪式")
	var named4 := ceremony.submit_name("小满")
	assert_true(named4.ok, "第四模型命名")
	assert_false(bool(named4["broke_record"]), "同分=平局不破纪录（霸主保持）")
	# 仪式回 IDLE（队列空）
	assert_eq(ceremony.get_state(), ModelCeremony.STATE_IDLE, "全部定名后回 IDLE")
	assert_false(ceremony.has_pending(), "无待定名")


func test_rejected_name_keeps_pending() -> void:
	# 命名被拒 → 状态保持 PENDING_NAMING 可重输（弹层不关闭语义=消费方据
	# reason 保持；本测试验仪式状态未被破坏）
	var library := ModelLibrary.new()
	autofree(library)
	var ceremony := _make_ceremony(library, SotaBoard.new())
	var done := _make_finished_model()
	(
		ceremony
		. settle_finished(
			{
				"project": done["project"],
				"score": 50.0,
				"ndim":
				{"reasoning": 50.0, "knowledge": 50.0, "chat": 50.0, "speed": 50.0, "cost": 50.0},
				"week": 6,
				"slot_index": int(done["slot_index"]),
			}
		)
	)
	var rejected := ceremony.submit_name("傻逼")
	assert_false(rejected.ok, "词表名被拒")
	assert_eq(rejected.reason, NameFilter.REASON_BLOCKLIST, "拒绝层=blocklist")
	assert_true(ceremony.has_pending(), "被拒后仍待定名（可重输）")
	assert_eq(ceremony.get_state(), ModelCeremony.STATE_PENDING_NAMING, "状态保持 pending")
	assert_eq(library.count(), 0, "被拒未入册（防污染库）")
	# 重输合法名=成功（弹层不关闭→玩家改输→通过）
	var retry := ceremony.submit_name("回声试")
	assert_true(retry.ok, "重输合法名通过")
	assert_eq(library.count(), 1, "重输后入册")


func test_default_name_pool_rotation() -> void:
	# 默认名池确定性轮转：跳过命名=按池序取（01 灵犀初号→02 小满→…循环）
	var library := ModelLibrary.new()
	autofree(library)
	var ceremony := _make_ceremony(library, SotaBoard.new())
	# 池名真源=texts.json（texts-keys.md model_default_name_pool_* 登记）
	var table := DataLoader.load_json("res://src/data/texts.json")
	var pool: Array[String] = []
	for i: int in range(6):
		pool.append(str(table.get("model_default_name_pool_%02d" % (i + 1), "")))
	# 首模型强制命名（无跳过路径），用 submit 后第二模型起测轮转
	var done1 := _make_finished_model()
	(
		ceremony
		. settle_finished(
			{
				"project": done1["project"],
				"score": 45.0,
				"ndim":
				{"reasoning": 45.0, "knowledge": 45.0, "chat": 45.0, "speed": 45.0, "cost": 45.0},
				"week": 5,
				"slot_index": int(done1["slot_index"]),
			}
		)
	)
	# 首模型跳过=拒（署名仪式强制）
	var skip_first := ceremony.skip_naming()
	assert_false(skip_first.ok, "首模型跳过命名=拒（强制署名）")
	assert_eq(skip_first.reason, "first_mandatory", "拒绝原因=first_mandatory")
	assert_true(ceremony.submit_name("署名号").ok, "首模型走命名确认")
	# 第二模型起：跳过=名池 01 → 第三=02（确定性递增）
	for i: int in range(2, 5):
		var done := _make_finished_model()
		(
			ceremony
			. settle_finished(
				{
					"project": done["project"],
					"score": 40.0 + float(i),
					"ndim":
					{
						"reasoning": 40.0,
						"knowledge": 40.0,
						"chat": 40.0,
						"speed": 40.0,
						"cost": 40.0
					},
					"week": 10 + i * 5,
					"slot_index": int(done["slot_index"]),
				}
			)
		)
		assert_true(ceremony.skip_naming().ok, "第 %d 模型跳过" % i)
	var m2: Dictionary = library.get_entry("m2")
	assert_eq(str(m2["name"]), pool[0], "第 2 模型跳过=池名 01（%s）" % pool[0])
	var m3: Dictionary = library.get_entry("m3")
	assert_eq(str(m3["name"]), pool[1], "第 3 模型跳过=池名 02（%s）" % pool[1])
	var m4: Dictionary = library.get_entry("m4")
	assert_eq(str(m4["name"]), pool[2], "第 4 模型跳过=池名 03（%s）" % pool[2])
	# 轮转游标确定性：连续 skip 取模循环（游标推进可查）
	assert_eq(ceremony.get_pool_index(), 3, "轮转游标=3（已用 3 个名）")


func test_ceremony_multiple_finished_serial_naming() -> void:
	# 同周多模型出分 → 命名队列串行（逐个 z2；架构 §5.3"同周多模型出分→
	# 命名队列串行"）；逐个定名释放各自槽
	var library := ModelLibrary.new()
	autofree(library)
	var released: Array[int] = []
	var ceremony := _make_ceremony(library, SotaBoard.new())
	ceremony.release_slot = func(slot: int) -> void: released.append(slot)
	for i: int in 2:
		var done := _make_finished_model()
		(
			ceremony
			. settle_finished(
				{
					"project": done["project"],
					"score": 50.0 + float(i),
					"ndim":
					{
						"reasoning": 50.0,
						"knowledge": 50.0,
						"chat": 50.0,
						"speed": 50.0,
						"cost": 50.0
					},
					"week": 12,
					"slot_index": int(done["slot_index"]),
				}
			)
		)
	assert_true(ceremony.has_pending(), "两模型待定名")
	assert_true(ceremony.submit_name("先声").ok, "队首定名")
	assert_true(ceremony.has_pending(), "队尾仍待定名（串行逐个 z2）")
	assert_eq(released, [0], "先释放队首槽（独立 board 均落槽 0）")
	assert_true(ceremony.submit_name("次声").ok, "队尾定名")
	assert_eq(released, [0, 0], "再释放队尾槽（串行两笔均释放）")
	assert_eq(ceremony.get_state(), ModelCeremony.STATE_IDLE, "队列清空回 IDLE")
