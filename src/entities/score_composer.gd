class_name ScoreComposer
extends RefCounted
## L2 出分合成注入器（批7.1 #188；架构评审修订④）。
## 背景：architecture §1.2 三源合成（员工 50%×树 25%×芯片 25%）在 v1.0.0
## 缺数据面（树无 per-dim 映射/芯片维集与模型维集不对齐/staff_ndim_map 无
## 芯片行/rng.json 无 chip 域——评审实证）——硬接会改变分数尺度冲击 SOTA
## 守卫带与显示分级。
## 裁决：v1 出分=注入式 Composer，默认实现=基座画像 weighted_sum（与 #153
## E2E 同口径，节拍断言不依赖分数值）；三源合成为后续数值批的替换实现
## （同接口换注入，零改动消费方）。

const MODELS_PATH: String = "res://src/data/models.json"


## 基座画像加权出分（v1 默认实现）：score=Σ(画像维×表权重)，全表驱动。
## 返回 {score, ndim}：ndim=画像原值（ceremony _dict_to_dim_array 按
## model_ndim_set 序排列）；score=加权和。表缺键=防御 0（不抛错）。
static func compose_base_profile(project: ModelProject) -> Dictionary:
	var models_table := DataLoader.load_json(MODELS_PATH)
	var base_id := project.get_base_id()
	var row: Dictionary = (models_table["model_bases"] as Dictionary)[base_id]
	var profile: Dictionary = row["ndim_profile"]
	var weights: Dictionary = models_table["model_ndim_weight"]
	var score := 0.0
	for dim: Variant in weights.keys():
		var weight := float(weights[dim])
		score += float(profile.get(dim, 0.0)) * weight
	return {"score": score, "ndim": profile.duplicate()}


## 三源合成扩展位（P2 数值批）：满三源时替换注入点，本类只留接口形状。
## 参数待数值批定稿（员工上桌属性×适配 / 树乘子 per-dim / 芯片画像映射）。
static func compose_three_sources(
	_project: ModelProject, _roster: Object, _tree: Object, _chip: Object
) -> Dictionary:
	return compose_base_profile(_project)
