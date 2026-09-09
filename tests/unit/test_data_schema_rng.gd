extends GutTest
## #125 rng.json 数据表断言（#128 schema 框架挂载）：
## 键名拼写真源=randomness-spec.md D.2 公式与参数表（精确拼写，缺/多余键都报）；
## 域清单真源=A.1 随机源登记表（六域 id + 供给口径注释）；护栏跟键走（D6）。

const RNG_PATH: String = "res://src/data/rng.json"
## randomness-spec D.2 全部数值键（除域清单 rng_domains/频率带 rnd_freq_band 为结构块）
const SOURCE_KEYS: Array[String] = [
	"rng_global_seed",
	"rng_domain_derivation",
	"rnd_event_rate",
	"rnd_task_var_rate",
	"rnd_task_var_cd",
	"rnd_task_var_range",
	"rnd_task_var_net",
	"rnd_task_bonus_p",
	"rnd_task_accident_p",
	"rnd_staff_mod_range",
	"rnd_staff_exp",
	"rnd_staff_pity",
	"rnd_insight_pity_max",
	"rnd_rival_jitter",
	"rnd_worst_case_floor",
	"rnd_bankrupt_shield",
]
## randomness-spec A.1 六域登记表 id（含域用途注释供给口径）
const SOURCE_DOMAINS: Array[String] = [
	"event",
	"insight",
	"rival",
	"task",
	"staff",
	"recruit",
]
## 结构块（spec 明示的表级键：A.1 域清单 + D.2 rnd_freq_band_* 频率带）
const STRUCT_KEYS: Array[String] = ["rng_domains", "rnd_freq_band"]

const RNG_SCHEMA: Dictionary = {
	"rng_global_seed": {"type": "int"},
	"rng_domain_derivation": {"type": "int"},
	"rnd_event_rate": {"type": "float"},
	"rnd_task_var_rate": {"type": "float"},
	"rnd_task_var_cd": {"type": "int"},
	"rnd_task_var_range": {"type": "float"},
	"rnd_task_var_net": {"type": "float"},
	"rnd_task_bonus_p": {"type": "float"},
	"rnd_task_accident_p": {"type": "float"},
	"rnd_staff_mod_range": {"type": "float"},
	"rnd_staff_exp": {"type": "float"},
	"rnd_staff_pity": {"type": "int"},
	"rnd_insight_pity_max": {"type": "int"},
	"rnd_rival_jitter": {"type": "float"},
	"rnd_worst_case_floor": {"type": "float"},
	"rnd_bankrupt_shield": {"type": "int"},
	"rng_domains": {"type": "dict"},
	"rnd_freq_band": {"type": "dict"},
}


func test_rng_table_loads_and_validates() -> void:
	var table := DataLoader.load_json(RNG_PATH)
	assert_false(table.is_empty(), "rng.json 可加载")
	var result := DataSchema.validate_table(table, RNG_SCHEMA)
	assert_true(result.ok, "rng.json schema 校验全过: %s" % str(result.errors))


func test_rng_numeric_keys_inline_bounds_present() -> void:
	var table := DataLoader.load_json(RNG_PATH)
	var numeric_keys: Array[String] = SOURCE_KEYS.duplicate()
	var result := DataSchema.validate_inline_bounds(table, numeric_keys)
	assert_true(result.ok, "rng.json 数值键全部带内嵌护栏: %s" % str(result.errors))


func test_rng_key_spelling_matches_source() -> void:
	var table := DataLoader.load_json(RNG_PATH)
	var full_keys: Array[String] = SOURCE_KEYS + STRUCT_KEYS
	var result := DataSchema.validate_key_spelling(table, full_keys)
	assert_true(
		result.ok,
		"rng.json 键名拼写与 randomness-spec D.2 一致: %s" % str(result.errors),
	)


func test_rng_domain_registry_matches_source() -> void:
	# 域清单=表驱动且与 A.1 精确一致；每域带供给口径注释（登记三件套之供给口径）
	var table := DataLoader.load_json(RNG_PATH)
	var registry: Dictionary = table["rng_domains"]
	var order: Array = registry["_order"]
	assert_eq(order.size(), SOURCE_DOMAINS.size(), "域清单条目=6（A.1 六源登记表）")
	for i: int in SOURCE_DOMAINS.size():
		assert_eq(str(order[i]), SOURCE_DOMAINS[i], "域 id 精确拼写（%s）" % SOURCE_DOMAINS[i])
		var entry: Variant = registry.get(SOURCE_DOMAINS[i])
		assert_true(entry is Dictionary, "域登记条目存在（%s）" % SOURCE_DOMAINS[i])
		if entry is Dictionary:
			var note: Variant = (entry as Dictionary).get("supply_note")
			assert_true(
				note is String and str(note).length() > 0,
				"每域带供给口径注释 supply_note（%s）" % SOURCE_DOMAINS[i],
			)


func test_rng_guardrail_values_follow_spec_bands() -> void:
	# 护栏跟键走：任务壳与状态带参数带与 randomness-spec D.2 护栏列一致
	var table := DataLoader.load_json(RNG_PATH)
	var bounds: Dictionary = table[DataSchema.BOUNDS_KEY]
	assert_almost_eq(float(bounds["rnd_task_var_rate"][0]), 0.10, 0.0001, "触发率带下限 0.10")
	assert_almost_eq(float(bounds["rnd_task_var_rate"][1]), 0.20, 0.0001, "触发率带上限 0.20")
	assert_almost_eq(float(bounds["rnd_task_var_cd"][0]), 4.0, 0.0001, "冷却带下限 4")
	assert_almost_eq(float(bounds["rnd_task_var_cd"][1]), 8.0, 0.0001, "冷却带上限 8")
	assert_almost_eq(float(bounds["rnd_task_var_range"][1]), 0.10, 0.0001, "波动带上限 ≤±10%")
	assert_almost_eq(float(bounds["rnd_staff_pity"][1]), 3.0, 0.0001, "摸鱼保底上限 3（连 3 必转）")
	assert_almost_eq(float(bounds["rnd_insight_pity_max"][0]), 5.0, 0.0001, "灵感保底下限 5")
	assert_almost_eq(float(bounds["rnd_insight_pity_max"][1]), 8.0, 0.0001, "灵感保底上限 8")
	assert_almost_eq(float(bounds["rnd_rival_jitter"][1]), 2.0, 0.0001, "竞对扰动 ≤±2")
	assert_almost_eq(float(bounds["rnd_staff_mod_range"][1]), 0.10, 0.0001, "状态带乘数 ≤±10%")


func test_rng_freq_band_tolerance_bounds_follow_key() -> void:
	# 频率带容差 0.2=±20%（spec D.2 行）且带内护栏随块跟键走
	var table := DataLoader.load_json(RNG_PATH)
	var band: Dictionary = table["rnd_freq_band"]
	assert_almost_eq(float(band["theory_tolerance"]), 0.20, 0.0001, "频率带容差=±20%")
	var tol_bounds: Array = band["theory_tolerance_bounds"]
	assert_almost_eq(float(tol_bounds[0]), 0.10, 0.0001, "容差护栏下限 0.10")
	assert_almost_eq(float(tol_bounds[1]), 0.30, 0.0001, "容差护栏上限 0.30")
	var entries: Dictionary = band["domains"]
	for entry_key: String in ["event", "task_var", "task_bonus", "task_accident"]:
		var entry: Dictionary = entries[entry_key]
		assert_true(
			table.has(str(entry["rate_key"])),
			"频率带登记率键须存在于表（%s -> %s）" % [entry_key, str(entry["rate_key"])],
		)
		assert_true(
			SOURCE_DOMAINS.has(str(entry["domain"])),
			"频率带登记域须 ∈ A.1 六域（%s -> %s）" % [entry_key, str(entry["domain"])],
		)


func test_rng_required_keys_all_present() -> void:
	var table := DataLoader.load_json(RNG_PATH)
	for key: String in SOURCE_KEYS:
		assert_true(table.has(key), "rng.json 缺必需键 %s" % key)
	assert_true(table.has("rng_domains"), "rng.json 缺域登记表 rng_domains")
	assert_true(table.has("rnd_freq_band"), "rng.json 缺频率带块 rnd_freq_band")
