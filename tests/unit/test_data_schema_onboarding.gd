extends GutTest
## #152 onboarding.json schema 断言（#128 D6 框架挂载；onboarding-spec D.1/D.2 键名）。
## 护栏跟键走：数值键必带内嵌 _bounds；键名拼写与真源精确相等（防改数不改护栏）。

const ONBOARDING_PATH: String = "res://src/data/onboarding.json"
const TEXTS_PATH: String = "res://src/data/texts.json"

## onboarding.json schema 描述（键名真源=onboarding-spec.md D.2 引导自有键；
## 全部消费方=TutorialMachine/GoalCard/教学节拍断言，无死配置键）
const ONBOARDING_SCHEMA: Dictionary = {
	"onb_goal_card_steps": {"type": "int"},
	"onb_first_task_duration": {"type": "int"},
	"onb_first_node_duration": {"type": "int"},
	"onb_first_train_duration": {"type": "int"},
	"onb_first_rival_week": {"type": "int"},
}

const ONBOARDING_NUMERIC_KEYS: Array[String] = [
	"onb_goal_card_steps",
	"onb_first_task_duration",
	"onb_first_node_duration",
	"onb_first_train_duration",
	"onb_first_rival_week",
]


func test_onboarding_table_loads_and_validates() -> void:
	var table := DataLoader.load_json(ONBOARDING_PATH)
	assert_false(table.is_empty(), "onboarding.json 可加载")
	var result := DataSchema.validate_table(table, ONBOARDING_SCHEMA)
	assert_true(result.ok, "onboarding.json schema 校验全过: %s" % str(result.errors))


func test_onboarding_table_inline_bounds_present() -> void:
	var table := DataLoader.load_json(ONBOARDING_PATH)
	var result := DataSchema.validate_inline_bounds(table, ONBOARDING_NUMERIC_KEYS)
	assert_true(result.ok, "onboarding.json 数值键全部带内嵌护栏: %s" % str(result.errors))


func test_onboarding_key_spelling_exact() -> void:
	var table := DataLoader.load_json(ONBOARDING_PATH)
	var expected: Array[String] = [
		"onb_goal_card_steps",
		"onb_first_task_duration",
		"onb_first_node_duration",
		"onb_first_train_duration",
		"onb_first_rival_week",
	]
	var result := DataSchema.validate_key_spelling(table, expected)
	assert_true(result.ok, "键名拼写与真源精确相等: %s" % str(result.errors))


func test_onboarding_goal_text_keys_present() -> void:
	# TutorialMachine.goal_key 派生消费面（onb_goal_N / onb_goal_N_detail）：
	# 文案真源=texts.json（texts-keys.md onb_ 22 键已落），派生键必须存在
	var texts := DataLoader.load_json(TEXTS_PATH)
	for i: int in 6:
		assert_true(texts.has("onb_goal_%d" % (i + 1)), "texts.json 缺 onb_goal_%d" % (i + 1))
		assert_true(
			texts.has("onb_goal_%d_detail" % (i + 1)), "texts.json 缺 onb_goal_%d_detail" % (i + 1)
		)
	assert_true(texts.has("onb_week_hint"), "texts.json 缺 onb_week_hint")
	assert_true(texts.has("onb_state_machine_error"), "texts.json 缺 onb_state_machine_error")
