class_name NdimProfiles
extends RefCounted
## L2 n 维布局表驱动适配层（#141；architecture-100 §4.2 落点）：
## "数据真源=各表 dims/weights 数组；适配层=表→结构体唯一转换点"。
## 三产物（论文/模型/芯片）共用同构合成，但各表键名/键前缀不同
## （paper_ndim_*/model_ndim_*/chip_ndim_*）→ 本层=唯一转换点，
## 产物侧/合成引擎不直接读表（防表键漂移/散落）。
## 职责：
## - layout(product_key) → {dim_ids[], weights{dim:wt}, drivers{dim源:wt}}：
##   dim_ids=维度序（数组化：加维=表加项零代码）；weights=公开权重；
##   drivers=三源权重（论文=paper_quality_drivers staff/tree/topic；
##   模型=model_ndim_drivers staff/tree/chip；芯片=无外部源=空）；
## - 只做读表归一化，零数值发明；表缺失/键错=防御回退空布局不抛错。
## 纯静态 RefCounted，headless 可单测；依赖 L0/L1（DataLoader）。

## 产物键（与 Project.type_to_key/NDims.PRODUCT_* 同源派生；稳定字符串）
const PRODUCT_PAPER: String = "paper"
const PRODUCT_MODEL: String = "model"
const PRODUCT_CHIP: String = "chip"

const PAPER_PATH: String = "res://src/data/papers.json"
const MODELS_PATH: String = "res://src/data/models.json"
const CHIPS_PATH: String = "res://src/data/chips.json"

## 各产物表键（真源=各规格 D.2：paper_ndim_set/weight/quality_drivers；
## model_ndim_set/weight/drivers；chip_ndim_set/weight——键名前缀分区，
## 表不同名，适配层集中声明）
const KEY_SET_PAPER: String = "paper_ndim_set"
const KEY_WEIGHT_PAPER: String = "paper_ndim_weight"
const KEY_DRIVERS_PAPER: String = "paper_quality_drivers"
const KEY_SET_MODEL: String = "model_ndim_set"
const KEY_WEIGHT_MODEL: String = "model_ndim_weight"
const KEY_DRIVERS_MODEL: String = "model_ndim_drivers"
const KEY_SET_CHIP: String = "chip_ndim_set"
const KEY_WEIGHT_CHIP: String = "chip_ndim_weight"


## 产物布局（唯一转换点）：{dim_ids, weights, drivers, path}。
## dim_ids=表 set 数组（稳定序=合成/揭晓顺序）；weights/drivers=表 dict；
## drivers 空=产物无外部源（芯片=档位画像自持，P2 工程岗/树强化批再扩）。
## 未知产物/表缺键=空 dict（防御，不抛错）。
static func layout(product_key: String) -> Dictionary:
	var path := ""
	var set_key := ""
	var weight_key := ""
	var drivers_key := ""
	match product_key:
		PRODUCT_PAPER:
			path = PAPER_PATH
			set_key = KEY_SET_PAPER
			weight_key = KEY_WEIGHT_PAPER
			drivers_key = KEY_DRIVERS_PAPER
		PRODUCT_MODEL:
			path = MODELS_PATH
			set_key = KEY_SET_MODEL
			weight_key = KEY_WEIGHT_MODEL
			drivers_key = KEY_DRIVERS_MODEL
		PRODUCT_CHIP:
			path = CHIPS_PATH
			set_key = KEY_SET_CHIP
			weight_key = KEY_WEIGHT_CHIP
		_:
			return {}
	var table := DataLoader.load_json(path)
	if table.is_empty():
		return {}
	var set_v: Variant = table.get(set_key)
	var weight_v: Variant = table.get(weight_key)
	if set_v is not Array or weight_v is not Dictionary:
		return {}
	var dim_ids: Array[String] = []
	for dim: Variant in set_v as Array:
		dim_ids.append(str(dim))
	var drivers: Dictionary = {}
	if not drivers_key.is_empty():
		var d: Variant = table.get(drivers_key)
		if d is Dictionary:
			drivers = (d as Dictionary).duplicate(true)
	return {
		"product": product_key,
		"path": path,
		"dim_ids": dim_ids,
		"weights": (weight_v as Dictionary).duplicate(true),
		"drivers": drivers,
	}


## 全部产物键（表驱动遍历/断言用）
static func all_products() -> Array[String]:
	return [PRODUCT_PAPER, PRODUCT_MODEL, PRODUCT_CHIP]


## 布局可解析（测试/装配前自检：三产物布局齐备）
static func is_layout_ready(product_key: String) -> bool:
	var layout_data := layout(product_key)
	return not layout_data.is_empty() and not (layout_data.get("dim_ids", []) as Array).is_empty()
