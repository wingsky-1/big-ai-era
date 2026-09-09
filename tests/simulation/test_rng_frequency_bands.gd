extends GutTest
## #125 万周模拟：各域频率 ∈ 理论带 ±20%（randomness-spec 验收点 3 + ADR-0008 决策 4）。
## 口径：万周=单 seed 连续推进 10000 周、每周对登记域做 1 次触发判定；理论率与
## 登记域全部读 rng.json（表驱动，代码零硬编码）。rnd_freq_band.domains 首批挂载
## spec D.2 已冻结率键（event/task_var/task_bonus/task_accident）；insight/rival/
## recruit/staff 分布率键随 #137/#144/#130 模块表落位后在此加行（表驱动零改码）。
## 性能：counter 派生每次 1 hash+1 PCG32，本脚本 ~4 万判定双跑量级，秒级完成
## （计时断言宽限 5s 防 flaky，testing.md 机制 6）。

const N_WEEKS: int = 10000
const N_WEEKS_TIMING: int = 2000
const RNG_TABLE_PATH: String = "res://src/data/rng.json"
## 频率带登记子键（rnd_freq_band.domains 表驱动，域 -> rate_key）
const BAND_ENTRIES: Array[String] = ["event", "task_var", "task_bonus", "task_accident"]


func test_rng_frequency_bands_10k_weeks() -> void:
	var table: Dictionary = DataLoader.load_json(RNG_TABLE_PATH)
	var bands: Dictionary = table["rnd_freq_band"]
	var entries: Dictionary = bands["domains"]
	for entry_key: String in BAND_ENTRIES:
		var entry: Dictionary = entries[entry_key]
		var rate_key := str(entry["rate_key"])
		var domain := str(entry["domain"])
		var theoretical := float(table[rate_key])
		assert_true(
			theoretical > 0.0 and theoretical < 1.0,
			"率键 %s 值 ∈(0,1)（%s 域频率带登记）" % [rate_key, entry_key],
		)
		var rng := RngStream.new()
		rng.setup(2026)
		var hits := 0
		for week: int in N_WEEKS:
			if rng.hit_domain(domain, theoretical):
				hits += 1
		var observed := float(hits) / float(N_WEEKS)
		var tol := rng.get_freq_tolerance()
		assert_true(
			observed >= theoretical * (1.0 - tol) and observed <= theoretical * (1.0 + tol),
			(
				"频率带 %s（%s 域）万周频率 %.4f ∈ 理论 %.3f ±%.0f%%（实测 %d/%d 周）"
				% [entry_key, domain, observed, theoretical, tol * 100.0, hits, N_WEEKS]
			),
		)


func test_same_seed_double_run_hash() -> void:
	# ADR-0008 决策 4：万周模拟同 seed 双跑哈希一致（确定性验收）
	var run_a := _sample_digest(2026)
	var run_b := _sample_digest(2026)
	assert_eq(run_a, run_b, "同 seed 万周模拟双跑哈希一致（ADR-0008 决策 4）")
	var run_c := _sample_digest(2027)
	assert_ne(run_c, run_a, "异 seed 摘要不同（种子参与三元组派生）")


func test_10k_simulation_seconds_fast() -> void:
	# 性能防呆：万周量级模拟秒级完成（testing.md 机制 6 宽限防 flaky）
	var started := Time.get_ticks_msec()
	var rng := RngStream.new()
	rng.setup(42)
	var table: Dictionary = DataLoader.load_json(RNG_TABLE_PATH)
	var bands: Dictionary = table["rnd_freq_band"]
	var entries: Dictionary = bands["domains"]
	for entry_key: String in BAND_ENTRIES:
		var entry: Dictionary = entries[entry_key]
		var theoretical := float(table[str(entry["rate_key"])])
		for week: int in N_WEEKS_TIMING:
			rng.hit_domain(str(entry["domain"]), theoretical)
	var elapsed := Time.get_ticks_msec() - started
	assert_lt(
		elapsed,
		5000,
		"万周量级模拟须秒级完成（实测 %d ms，判定 %d×%d 次）" % [elapsed, BAND_ENTRIES.size(), N_WEEKS_TIMING],
	)


func _sample_digest(seed: int) -> String:
	# 同 seed 全登记域各 10000 次触发的确定性摘要（双跑哈希验收）
	var rng := RngStream.new()
	rng.setup(seed)
	var table: Dictionary = DataLoader.load_json(RNG_TABLE_PATH)
	var entries: Dictionary = (table["rnd_freq_band"] as Dictionary)["domains"]
	var acc := 0
	var salt := 0
	for entry_key: String in BAND_ENTRIES:
		var entry: Dictionary = entries[entry_key]
		var theoretical := float(table[str(entry["rate_key"])])
		for week: int in N_WEEKS:
			acc = int(acc + int(rng.hit_domain(str(entry["domain"]), theoretical)) * (salt + week))
			salt += 1
	return str(acc)
