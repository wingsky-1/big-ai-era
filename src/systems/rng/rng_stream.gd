class_name RngStream
extends RefCounted
## L1 分域 counter 确定性 RNG（ADR-0008 继承，#125 六域登记原位填充）。
## - 三元组派生：对 (root_seed, 域名, counter) 播种 RandomNumberGenerator 后取一次
##   PCG32 输出（#92 修正：字符串哈希相邻值差 ~5e-10 会让概率判定退化为恒真/恒假）。
## - 六域独立流：域 id 来自 rng.json 登记表（randomness-spec A.1 精确拼写）；
##   各域计数器互不串扰——新增随机域 = 表加行 + 代码零改（ADR-0008 决策 1/2）。
## - 计数器入档：savegame.rng{} 开放 dict（root_seed + 各域 int 计数器，缺省 0，
##   JSON 安全零迁移）；restore 补齐表内全部登记域。
## - 数值零硬编码：参数只经 get_param() 读 rng.json（randomness-spec D.2 键名），
##   代码内仅出现键名/域 id 引用；pity/对称波动等为通用机制载体，玩法规则不入本类。

const RNG_TABLE_PATH: String = "res://src/data/rng.json"
## rng.json 域登记表根键与子键（表驱动真源，randomness-spec A.1）
const DOMAIN_REGISTRY_KEY: String = "rng_domains"
const DOMAIN_ORDER_KEY: String = "_order"
const FREQ_BAND_KEY: String = "rnd_freq_band"
const FREQ_TOLERANCE_KEY: String = "theory_tolerance"

var _root_seed: int = 0
var _counters: Dictionary = {}
var _params: Dictionary = {}
var _hasher: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_params = DataLoader.load_json(RNG_TABLE_PATH)


## 重置种子并清零各登记域计数器（同种子=同世界，ADR-0008 决策 4）。
func setup(seed_val: int) -> void:
	_root_seed = seed_val
	_counters.clear()
	for domain: String in get_registered_domains():
		_counters[domain] = 0


func get_root_seed() -> int:
	return _root_seed


## 域清单唯一真源 = rng.json 登记表（新增域=表加行，代码零改）。
func get_registered_domains() -> Array[String]:
	var domains: Array[String] = []
	var registry: Dictionary = _params.get(DOMAIN_REGISTRY_KEY, {})
	var order: Variant = registry.get(DOMAIN_ORDER_KEY, [])
	if order is Array:
		for item: Variant in order:
			if item is String:
				domains.append(item)
	# 表损坏（缺 _order）兜底：rng.json 由 DataSchema 单测门禁守护（test_data_schema_rng）
	return domains


## 读 rng.json 数值参数（randomness-spec D.2 键名；缺键=0 并报错由数据层测试兜底）。
func get_param(key: String) -> float:
	return float(_params.get(key, 0.0))


func get_int_param(key: String) -> int:
	return int(roundf(get_param(key)))


## 万周频率带容差（rnd_freq_band.theory_tolerance，理论率 ±容差）。
func get_freq_tolerance() -> float:
	var band: Dictionary = _params.get(FREQ_BAND_KEY, {})
	return float(band.get(FREQ_TOLERANCE_KEY, 0.2))


## 派生 [0.0, 1.0) 确定性随机数并把该域计数器 +1。
## counter-based：每个三元组独立派生，不依赖同域前一个样本（读档/跳步零漂移）。
func randf_domain(domain: String) -> float:
	var counter: int = _next_counter(domain)
	_hasher.seed = hash("%d:%s:%d" % [_root_seed, domain, counter])
	return _hasher.randf()


## 派生 [min_val, max_val] 闭区间确定性整数。
func randi_range_domain(domain: String, min_val: int, max_val: int) -> int:
	if min_val >= max_val:
		return min_val
	var span: int = max_val - min_val + 1
	return min_val + int(floor(randf_domain(domain) * float(span)))


## 派生 [min_val, max_val] 确定性浮点。
func randf_range_domain(domain: String, min_val: float, max_val: float) -> float:
	if min_val >= max_val:
		return min_val
	return min_val + randf_domain(domain) * (max_val - min_val)


## 概率判定：命中返回 true（chance ∈ [0,1]，边界短路不消费样本）。
func hit_domain(domain: String, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return randf_domain(domain) < chance


## 对称波动 [-magnitude, +magnitude]（任务波动/竞对扰动共用载体，幅度由调用方读表）。
func symmetric_domain(domain: String, magnitude: float) -> float:
	if magnitude <= 0.0:
		return 0.0
	return randf_domain(domain) * 2.0 * magnitude - magnitude


## 通用 pity 保底抽取（保底=连续失败不缺席超过 pity_max-1）：
## current_fail_streak 为调用方累计的连续失败次数；当 streak+1 >= pity_max 时
## 必成功且不掷骰（保底确定性事件，与旧 cap 硬保底同语义）；否则按 base_chance
## 掷骰。返回 {hit, forced}；每次尝试（含保底周）该域计数器 +1（计数=周粒度消费）。
func pity_pull_domain(
	domain: String, base_chance: float, pity_max: int, current_fail_streak: int
) -> Dictionary:
	if pity_max <= 1 or current_fail_streak + 1 >= pity_max:
		_next_counter(domain)
		return {"hit": true, "forced": true}
	return {"hit": hit_domain(domain, base_chance), "forced": false}


## 确定性跳步：该域计数器前移 steps（读档/模拟对齐用，不产出样本）。
func advance_domain(domain: String, steps: int) -> void:
	if steps <= 0:
		return
	_counters[domain] = get_counter(domain) + steps


func get_counter(domain: String) -> int:
	return int(_counters.get(domain, 0))


## 计数器快照（入档面）：savegame.rng{} 开放 dict 形状。
func to_save() -> Dictionary:
	var snapshot: Dictionary = {"root_seed": _root_seed}
	for domain: String in get_registered_domains():
		snapshot[domain] = get_counter(domain)
	return snapshot


## 读档恢复：计数器缺省 0、表内新增域自动补齐（ADR-0008 决策 2：加键零迁移）。
func restore(data: Dictionary) -> void:
	_root_seed = int(data.get("root_seed", 0))
	_counters.clear()
	for domain: String in get_registered_domains():
		_counters[domain] = int(data.get(domain, 0))


func _next_counter(domain: String) -> int:
	var counter: int = int(_counters.get(domain, 0))
	_counters[domain] = counter + 1
	return counter
