class_name RngStream
extends RefCounted

## 分域 counter-based 确定性随机数系统（L1，ADR-0008 / DR-001）：
## - 三元组派生：hash(root_seed, domain, counter)
## - 域隔离：各域计数器独立自增，一个域的抽样绝不影响其他域（防跨域串扰）
## - 开放 dict 计数器入档：支持新增域零迁移加键（计数器缺省为 0）
## - 官方登记三大消费域：DOMAIN_RIVAL_JITTER, DOMAIN_INSPIRATION, DOMAIN_EVENT_ROLL

const DOMAIN_RIVAL_JITTER: String = "rival_jitter"
const DOMAIN_INSPIRATION: String = "inspiration"
const DOMAIN_EVENT_ROLL: String = "event_roll"

const REGISTERED_DOMAINS: Array[String] = [
	DOMAIN_RIVAL_JITTER,
	DOMAIN_INSPIRATION,
	DOMAIN_EVENT_ROLL,
]

var _root_seed: int = 0
var _counters: Dictionary = {}
## 派生用哈希器：每个 (root_seed, domain, counter) 重置 seed 后取一次输出（PCG32）。
var _hasher: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_val: int = 0) -> void:
	setup(seed_val)


func setup(seed_val: int) -> void:
	_root_seed = seed_val
	_counters.clear()
	for dom: String in REGISTERED_DOMAINS:
		_counters[dom] = 0


func get_root_seed() -> int:
	return _root_seed


func get_counter(domain: String) -> int:
	return int(_counters.get(domain, 0))


## 派生一个 [0.0, 1.0) 的确定性浮点随机数，并将对应域计数器 +1
## counter-based：每个三元组独立派生，不依赖同域前一个随机数（读档/跳步不漂移）。
## 实现注意（#75 修复）：GDScript 的 `hash(String)` 对相邻字符串（counter+1）输出
## 仅差个位数，直接归一化会让同域连续抽样几乎相同（实测相邻差 ~5e-10）→ 概率
## 机制退化成"整局恒真/恒假"。故改用 RandomNumberGenerator 重置 seed 后取一次输出
## （PCG32 充分去相关），派生仍只依赖三元组，确定性不变。
func randf_domain(domain: String) -> float:
	var c: int = int(_counters.get(domain, 0))
	_counters[domain] = c + 1
	_hasher.seed = hash("%d:%s:%d" % [_root_seed, domain, c])
	return _hasher.randf()


## 派生一个 [min_val, max_val] 的确定性整数随机数
func randi_range_domain(domain: String, min_val: int, max_val: int) -> int:
	if min_val >= max_val:
		return min_val
	var f: float = randf_domain(domain)
	var span: int = max_val - min_val + 1
	return min_val + int(floor(f * float(span)))


## 派生一个 [min_val, max_val] 的确定性浮点随机数
func randf_range_domain(domain: String, min_val: float, max_val: float) -> float:
	if min_val >= max_val:
		return min_val
	var f: float = randf_domain(domain)
	return min_val + f * (max_val - min_val)


## 判定概率（例如灵感触发 hit(p)）
func hit_domain(domain: String, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return randf_domain(domain) < chance


## 存档与快照（对齐 savegame.rng{} 开放容器）
func to_save() -> Dictionary:
	var out: Dictionary = {
		"root_seed": _root_seed,
	}
	for dom: String in _counters:
		out[dom] = int(_counters[dom])
	return out


func restore(data: Dictionary) -> void:
	_root_seed = int(data.get("root_seed", 0))
	_counters.clear()
	for k: String in data:
		if k != "root_seed":
			_counters[k] = int(data[k])
	# 补齐未登记但已存在的域
	for dom: String in REGISTERED_DOMAINS:
		if not _counters.has(dom):
			_counters[dom] = 0
