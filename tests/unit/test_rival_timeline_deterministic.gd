extends GutTest
## #144 验收点 1：确定性红线——同种子下竞对时间线逐周可复现，零博弈 AI
## （GUT：`test_rival_timeline_deterministic`）。
## 真源=rivals-spec A.1/D.2（全部动作=时间线脚本表驱动，零博弈 AI；
## ±扰动唯一随机源=rng.rival 幅度 ≤±2，randomness-spec 同源）。
## 语义：无扰动注入（零扰动路径）两次独立周推进=载荷全等；时间线=静态表
## 无运行时决策（消费指针单调推进）。

const RIVALS_PATH: String = "res://src/data/rivals.json"


func _make_pack() -> RivalPack:
	var pack := RivalPack.new()
	autofree(pack)
	return pack


func _advance_all_weeks(pack: RivalPack, up_to_week: int) -> Array[Dictionary]:
	var all_fired: Array[Dictionary] = []
	for week: int in range(1, up_to_week + 1):
		var fired := pack.advance_all(week)
		all_fired.append_array(fired)
	return all_fired


func test_rival_timeline_deterministic() -> void:
	# 同一时间线表 + 零扰动：两次独立推进（每步周号相同）载荷序列全等
	var pack_a := _make_pack()
	var pack_b := _make_pack()
	var fired_a := _advance_all_weeks(pack_a, 100)
	var fired_b := _advance_all_weeks(pack_b, 100)
	assert_eq(fired_a.size(), fired_b.size(), "两实例触发动作数相等（确定性）")
	assert_eq(fired_a.size(), 12, "W1-100 深巷触发 12 动作（表脚本核对）")
	for i: int in fired_a.size():
		assert_eq(
			str(fired_a[i].get("action", "")),
			str(fired_b[i].get("action", "")),
			"动作序一致（%d）" % i,
		)
		assert_eq(int(fired_a[i]["week"]), int(fired_b[i]["week"]), "动作周一致（%d）" % i)
	# 零博弈 AI：无 RNG 注入时载荷无随机漂移（rival_jitter_fn 恒等=默认）
	var view: Dictionary = pack_a.get_rival_view("deep_alley")
	assert_eq(view["timeline_consumed"], 12, "消费指针=已消费动作数（表驱动推进）")
	# 表驱动核对：W1-100 深巷动作序=时间线脚本逐周命中（升序无跳漏）
	var expected: Array[Dictionary] = [
		{"week": 10, "action": "paper"},
		{"week": 22, "action": "release"},
		{"week": 30, "action": "paper"},
		{"week": 40, "action": "release"},
		{"week": 48, "action": "pricewar"},
		{"week": 54, "action": "release"},
		{"week": 62, "action": "paper"},
		{"week": 70, "action": "release"},
		{"week": 76, "action": "poach"},
		{"week": 86, "action": "release"},
		{"week": 94, "action": "paper"},
		{"week": 100, "action": "pricewar"},
	]
	for i: int in expected.size():
		assert_eq(
			str(fired_a[i]["action"]),
			str(expected[i]["action"]),
			"第 %d 动作=%s" % [i, expected[i]["action"]]
		)
		assert_eq(
			int(fired_a[i]["week"]),
			int(expected[i]["week"]),
			"第 %d 动作周=%d" % [i, int(expected[i]["week"])]
		)


func test_rival_restore_deterministic_replay() -> void:
	# 读档重建：存档快照注入后状态一致（确定性续跑，零环）
	var pack := _make_pack()
	_advance_all_weeks(pack, 60)
	var snapshot: Dictionary = pack.get_save_view()
	var rebuilt := _make_pack()
	rebuilt.restore_from_save(snapshot)
	var view_a: Dictionary = pack.get_rival_view("deep_alley")
	var view_b: Dictionary = rebuilt.get_rival_view("deep_alley")
	assert_eq(int(view_a["timeline_consumed"]), int(view_b["timeline_consumed"]), "重建后消费指针一致")
	assert_eq(str(view_a["last_action"]), str(view_b["last_action"]), "重建后 last_action 一致（重放）")
	assert_almost_eq(
		float(view_a["latest_score"]),
		float(view_b["latest_score"]),
		0.001,
		"重建后最新发版分一致",
	)
	# 重建后继续推进（W61-70）=动作继续命中（不重复不遗漏）
	var continued := _advance_all_weeks(rebuilt, 70)
	assert_eq(continued.size(), 2, "W61-70 再触发 2 动作（W62 论文/W70 发版）")
	assert_eq(int(continued[1]["week"]), 70, "续跑命中 W70 发版")
	assert_eq(str(continued[1]["action"]), "release", "续跑动作=release")
