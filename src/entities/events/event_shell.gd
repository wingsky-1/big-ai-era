class_name EventShell
extends RefCounted
## L2 事件壳（批7.4 #194；randomness-spec OP-RND-01 决策级事件卡 P0 切片）：
## 周结 phase11 消费——hit(rnd_event_rate) → 决策级卡 pending（单周≤1，决策
## 在位次周顺延=rng 流位置不前进）；取卡=确定性轮转（已见集合最小频次挑选，
## 同种子同序零新 RNG——率门在 rng.event 域，文案轮转不做随机取句）。
## 效果三型（cash/influence/none）入账走注入执行器（WorldCommands 通道）+
## 周报 EVENT 行（对账闭合）；金额=静态绝对值（ADR-0028 效果基准裁定），
## 护栏=events.json _bounds 绝对区间（加载期校验，越界 fail-fast）。
## 纪律：管线只判定+置 pending，永不挂起等待 UI（ADR-0015 phase11 补登记）；
## pending/已见集合入档（存档域 events：游标语义对表序变更免疫）。

## 选项效果类型（本批面：cash/influence/none；share 类工期/质量修正=P1 扩面）
enum EffectType { CASH, INFLUENCE, NONE }

const EVENTS_PATH: String = "res://src/data/events.json"
const KEY_DECK: String = "event_deck"
const KEY_BOUNDS: String = "_bounds"

## 周报行文本（决策入账对账行；键渲染经 GameWorld 注入回调——对账行文本与
## 入账值同源组装，ADR-0028 对账闭合口径）
var text_for_event_row: Callable = Callable()

var _deck: Array = []
var _seen_counts: Dictionary = {}  # card_id → 已见次数（轮转游标：最小频次挑选）
var _pending_id: String = ""
var _rng: RngStream = null


## 装配（rng=world RngStream；加载期校验：越界/形状非法 fail-fast 拒载）
func _init(rng: RngStream) -> void:
	_rng = rng
	_load_and_validate()


## ---------- 周结判定（phase11；管线不挂起） ----------


## 周结事件判定（WeeklyPipeline.run 内调用一次）。返回 {fired, card_id}：
## - 决策在位=本周期顺延（跳过 hit 判定，rng 流位置不前进——在位语义入档后
##   读档重弹同卡）；无 pending 才消费 rng.event 率门。
## - 命中→轮转取卡置 pending；未命中→空态静默（无 toast 无行）。
func roll_week() -> Dictionary:
	if not _pending_id.is_empty():
		return {"fired": false, "card_id": _pending_id, "deferred": true}
	var rate := _rng.get_param("rnd_event_rate")
	if not _rng.hit_domain("event", rate):
		return {"fired": false, "card_id": "", "deferred": false}
	_pending_id = _pick_next_card_id()
	return {"fired": not _pending_id.is_empty(), "card_id": _pending_id, "deferred": false}


## ---------- pending 数据面（GameWorld 命令通道消费） ----------


func has_pending() -> bool:
	return not _pending_id.is_empty()


## 待决卡 view（L3 决策卡渲染面：id/标题键/正文键/选项[键,效果类型,金额,预览句插值]）
func get_pending_view() -> Dictionary:
	var card := _card_by_id(_pending_id)
	if card.is_empty():
		return {}
	var choices: Array = []
	for choice: Dictionary in card.get("choices", []):
		var effect: Dictionary = choice.get("effect", {})
		(
			choices
			. append(
				{
					"key": str(choice.get("key", "")),
					"effect_type": int(_effect_type_of(effect)),
					"amount": int(effect.get("amount", 0)),
				}
			)
		)
	return {
		"id": _pending_id,
		"title_key": str(card.get("title_key", "")),
		"body_key": str(card.get("body_key", "")),
		"choices": choices,
	}


## 提交选择（WorldCommands.submit_decision 委托）：效果入账（注入执行器）+
## 对账行文本回调 + 清 pending。返回 {ok, row_text, effect_type, amount}。
func submit_choice(
	choice_index: int, apply_cash: Callable, apply_influence: Callable
) -> Dictionary:
	var card := _card_by_id(_pending_id)
	var choices: Array = card.get("choices", [])
	if card.is_empty() or choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "row_text": "", "effect_type": EffectType.NONE, "amount": 0}
	var effect: Dictionary = (choices[choice_index] as Dictionary).get("effect", {})
	var amount := int(effect.get("amount", 0))
	var effect_type := _effect_type_of(effect)
	match effect_type:
		EffectType.CASH:
			if apply_cash.is_valid():
				apply_cash.call(amount)
		EffectType.INFLUENCE:
			if apply_influence.is_valid():
				apply_influence.call(amount)
		_:
			pass
	_seen_counts[_pending_id] = int(_seen_counts.get(_pending_id, 0)) + 1
	var row_text := ""
	if text_for_event_row.is_valid():
		row_text = str(text_for_event_row.call(str(card.get("title_key", "")), effect_type, amount))
	_pending_id = ""
	return {"ok": true, "row_text": row_text, "effect_type": effect_type, "amount": amount}


## ---------- 存档（events 域：pending+已见集合；对表序变更免疫） ----------


func to_save() -> Dictionary:
	return {"pending_id": _pending_id, "seen_counts": _seen_counts.duplicate()}


func restore_from_save(save: Dictionary) -> void:
	_pending_id = str(save.get("pending_id", ""))
	var counts: Variant = save.get("seen_counts", {})
	if counts is Dictionary:
		_seen_counts = (counts as Dictionary).duplicate()


## ---------- 私有（加载校验/轮转/效果映射） ----------


func _load_and_validate() -> void:
	var table := DataLoader.load_json(EVENTS_PATH)
	if table.is_empty():
		push_error("EventShell: events.json 加载失败（fail-fast）")
		return
	var deck: Variant = table.get(KEY_DECK)
	if deck is Array:
		_validate_deck(deck as Array, table.get(KEY_BOUNDS, {}))
		_deck = deck as Array
	else:
		push_error("EventShell: event_deck 缺失或非数组（fail-fast）")


## 加载期护栏校验（ADR-0022 跟键走；越界=拒载该卡，全越界=空牌堆静默空态）
func _validate_deck(deck: Array, bounds: Dictionary) -> void:
	var deck_bound: Array = bounds.get(KEY_DECK, [1, 32])
	if deck.size() < int(deck_bound[0]) or deck.size() > int(deck_bound[1]):
		push_error("EventShell: 牌堆数越界 %d（护栏 %s）" % [deck.size(), str(deck_bound)])
	var choices_bound: Array = bounds.get("choices_per_card", [2, 2])
	var cash_bound: Array = bounds.get("cash_amount", [-1000000, 1000000])
	var influence_bound: Array = bounds.get("influence_amount", [0, 1000000])
	var valid: Array = []
	for card: Dictionary in deck:
		var choices: Variant = card.get("choices")
		if not (choices is Array) or (choices as Array).size() != int(choices_bound[0]):
			push_error("EventShell: 卡 %s 选项数非法（护栏锁定二选一）" % str(card.get("id", "?")))
			continue
		var ok := true
		for choice: Dictionary in choices as Array:
			var effect: Dictionary = choice.get("effect", {})
			var amount := int(effect.get("amount", 0))
			match str(effect.get("type", "")):
				"cash":
					if amount < int(cash_bound[0]) or amount > int(cash_bound[1]):
						push_error(
							"EventShell: 卡 %s cash 越界 %d" % [str(card.get("id", "?")), amount]
						)
						ok = false
				"influence":
					if amount < int(influence_bound[0]) or amount > int(influence_bound[1]):
						push_error(
							"EventShell: 卡 %s influence 越界 %d" % [str(card.get("id", "?")), amount]
						)
						ok = false
				"none":
					pass
				_:
					push_error(
						(
							"EventShell: 卡 %s 效果类型非法 %s"
							% [str(card.get("id", "?")), str(effect.get("type", ""))]
						)
					)
					ok = false
		if ok:
			valid.append(card)
	_deck = valid


## 确定性轮转：已见频次最小的卡优先（同频=表序首个）；空牌堆=空串
func _pick_next_card_id() -> String:
	if _deck.is_empty():
		return ""
	var best: Dictionary = {}
	var best_count := -1
	for card: Dictionary in _deck:
		var card_id := str(card.get("id", ""))
		var count := int(_seen_counts.get(card_id, 0))
		if best_count == -1 or count < best_count:
			best_count = count
			best = card
	return str(best.get("id", ""))


func _card_by_id(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	for card: Dictionary in _deck:
		if str(card.get("id", "")) == card_id:
			return card
	return {}


func _effect_type_of(effect: Dictionary) -> EffectType:
	match str(effect.get("type", "")):
		"cash":
			return EffectType.CASH
		"influence":
			return EffectType.INFLUENCE
		_:
			return EffectType.NONE
