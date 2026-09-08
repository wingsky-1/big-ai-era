extends GutTest

## #71 批 0 数值数据化门禁（红线 3：数值禁硬编码，一切进 src/data/）：
## 1. test_no_hardcoded_numbers_outside_data —— src/** 数字字面量零命中
##    （白名单 0/1/-1；表现层/格式化系数须显式标 `# num-ok: 理由` 方可豁免）
## 2. test_formula_constants_driven_by_data —— K/θ/k/m/指数全部数据键驱动（改表即改行为）
## 3. test_single_source_of_truth_node_count_and_clock —— 节点总数单点 + clock.json 注入
## 4. test_same_seed_hash_stable_after_data_migration —— 同 seed 万周摘要稳定（确定性回归）

const SRC_ROOT: String = "res://src"
const NUM_OK_MARKER: String = "num-ok"
const WHITELIST: PackedStringArray = ["0", "1", "-1", "0.0", "1.0", "-1.0"]
const SEEDS: Array[int] = [42, 7]
const WEEKS: int = 10000

var _number_regex: RegEx


func before_all() -> void:
	_number_regex = RegEx.create_from_string("(?<![\\w.])(-?\\d+(?:\\.\\d+)?)(?![\\w.])")


func test_no_hardcoded_numbers_outside_data() -> void:
	var files: Array[String] = []
	_collect_gd_files(SRC_ROOT, files)
	assert_gt(files.size(), 0, "应扫描到 src/** 下的 GDScript 文件")

	var hits: Array[String] = []
	for path: String in files:
		hits.append_array(_scan_numeric_literals(path))
	if not hits.is_empty():
		gut.p("未豁免数值字面量命中（%d 处）：%s" % [hits.size(), hits])
	assert_eq(hits.size(), 0, "src/** 不应存在未豁免的数值字面量（数值必须进 src/data/ 或标 num-ok 理由）")


func test_formula_constants_driven_by_data() -> void:
	var benchmarks := DataLoader.load_json("res://src/data/benchmarks.json")
	var row: Dictionary = benchmarks[GameWorld.BENCHMARK_KEY]
	var params := ScoreMath.normalize_params(row)
	assert_false(params.is_empty(), "出分参数应从 benchmarks.json 规范化成功")

	# 基线：A 由数据键算出（K=ability_scale、指数 0.7/0.3、m(1)=0.6）
	var ability: float = ScoreMath.calculate_ability(70, 0.0, 1, 0.55, params)
	var expected: float = (
		float(row["ability_scale"])
		* pow(1.0 + 70.0, float(row["ability_exponents"]["research_eff"]))
		* pow(1.0, float(row["ability_exponents"]["tech_bonus"]))
		* float(row["compute_multipliers"]["1"])
		* 0.55
	)
	assert_almost_eq(ability, expected, 0.0001, "A 必须由 benchmarks.json 键值算出")

	# 改表即改行为：K
	var tweaked_k: Dictionary = params.duplicate(true)
	tweaked_k["ability_scale"] = float(params["ability_scale"]) * 2.0
	assert_almost_eq(
		ScoreMath.calculate_ability(70, 0.0, 1, 0.55, tweaked_k),
		ability * 2.0,
		0.0001,
		"ability_scale 改数据表即改行为"
	)

	# 改表即改行为：指数
	var tweaked_exp: Dictionary = params.duplicate(true)
	(tweaked_exp["ability_exponents"] as Dictionary)["research_eff"] = 1.0
	assert_gt(
		ScoreMath.calculate_ability(70, 0.0, 1, 0.55, tweaked_exp), ability, "指数 0.7 改数据表即改行为"
	)

	# 改表即改行为：m(tier)
	var tweaked_m: Dictionary = params.duplicate(true)
	(tweaked_m["compute_multipliers"] as Dictionary)[1] = 9.9
	assert_almost_eq(ScoreMath.get_compute_multiplier(tweaked_m, 1), 9.9, 0.0001, "m(1) 由数据键驱动")

	# 改表即改行为：θ / k
	var tweaked_theta: Dictionary = params.duplicate(true)
	tweaked_theta["theta"] = float(params["theta"]) - 10.0
	assert_gt(
		ScoreMath.calculate_score(80.0, tweaked_theta),
		ScoreMath.calculate_score(80.0, params),
		"θ 改数据表即改分数映射"
	)
	var tweaked_k_sigmoid: Dictionary = params.duplicate(true)
	tweaked_k_sigmoid["k"] = float(params["k"]) * 2.0
	assert_gt(
		ScoreMath.calculate_score(80.0, tweaked_k_sigmoid),
		ScoreMath.calculate_score(80.0, params),
		"k 改数据表即改分数映射"
	)


func test_single_source_of_truth_node_count_and_clock() -> void:
	var techs_cfg := DataLoader.load_json(TechFog.DEFAULT_TECHS_PATH)
	var nodes: Dictionary = techs_cfg["nodes"]
	assert_eq(int(techs_cfg["total_nodes"]), nodes.size(), "techs.json total_nodes 必须等于实表节点数（单点真源）")

	var fog := TechFog.new()
	autofree(fog)
	assert_eq(fog.get_total_nodes(), nodes.size(), "TechFog 节点总数取自数据键")

	watch_signals(fog)
	fog.reset()
	assert_eq(get_signal_parameters(fog, "fog_changed").size(), 1, "reset 应发 fog_changed")
	var payload: Dictionary = get_signal_parameters(fog, "fog_changed")[0]
	assert_eq(int(payload["total_nodes"]), nodes.size(), "fog_changed 载荷 total_nodes 与数据键同源")

	# clock.json 的 ticks_per_week 由 GameClock 注入消费（死键收口，无代码常量）
	var clock_cfg := DataLoader.load_json("res://src/data/clock.json")
	var clock := GameClock.new()
	autofree(clock)
	clock.setup(clock_cfg, self)
	assert_eq(
		clock.ticks_per_week,
		int(clock_cfg["ticks_per_week"]),
		"GameClock 注入 ticks_per_week（数据表改值即生效）"
	)

	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(1)
	world.settle_week()
	assert_eq(world.week, 1, "周结仍按注入节拍推进")


func test_same_seed_hash_stable_after_data_migration() -> void:
	# 确定性回归：同 seed 万周状态摘要双跑一致（批 0 改造前后由 PR 基线哈希对账）。
	var digests: Dictionary = {}
	for seed_value: int in SEEDS:
		digests[seed_value] = _run_weeks_digest(seed_value)
	for seed_value: int in SEEDS:
		assert_eq(
			_run_weeks_digest(seed_value),
			digests[seed_value],
			"seed %d 同 seed 万周摘要应稳定（确定性真源未受损）" % seed_value
		)


func _run_weeks_digest(seed_value: int) -> String:
	var world := GameWorld.new()
	autofree(world)
	world.start_new_game(seed_value)
	# 批 1a 后经营收入只来自占槽任务结算：万周回归需持续接任务
	var tasks := AutoTaskPolicy.new()
	var policy := AutoDecisionPolicy.new()
	for i: int in range(WEEKS):
		tasks.fill(world)
		world.simulate_weeks(1, policy)
	return SnapshotCodec.state_digest(world)


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_files(dir_path.path_join(entry), out)
		elif entry.ends_with(".gd"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_numeric_literals(path: String) -> Array[String]:
	var hits: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return hits
	var line_no: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_no += 1
		if line.contains(NUM_OK_MARKER):
			continue
		var code: String = _strip_comments_and_strings(line)
		for found: RegExMatch in _number_regex.search_all(code):
			var literal: String = found.get_string(1)
			if WHITELIST.has(literal):
				continue
			hits.append("%s:%d:%s" % [path, line_no, literal])
	return hits


## 去掉行内注释与字符串内容（数字只可能藏在字符串里时才被误判）
func _strip_comments_and_strings(line: String) -> String:
	var out: String = ""
	var idx: int = 0
	var quote: String = ""
	while idx < line.length():
		var ch: String = line[idx]
		if not quote.is_empty():
			if ch == "\\":
				idx += 2
				continue
			if ch == quote:
				quote = ""
			out += " "
			idx += 1
			continue
		if ch == '"' or ch == "'":
			quote = ch
			out += " "
			idx += 1
			continue
		if ch == "#":
			break
		out += ch
		idx += 1
	return out
