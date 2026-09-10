class_name WorldFactory
extends RefCounted
## L2 世界装配工厂（批7.1 #188）：把 v1.0.0 全部 L2 系统组合成可玩一局。
## 职责边界（架构评审修订：门面/工厂/相位三职责拆分）：
## - 本类只做**装配**（构造+读表注入谓词+信号互连），零玩法逻辑；
## - 玩法编排在 GameWorld 门面（命令/数据面/周结驱动），相位在 Settlement 扩展；
## - 装配模式沿袭 #153 E2E（tests/simulation/test_first_loop_e2e.gd）同款，
##   收敛为正式装配并复用于回归。
## 纪律：谓词注入只读世界状态（AGENTS 引导红线）；RngStream 强制注入（#125
## 同种子确定性：自建流=破坏登记制）；零硬编码（全部读表）。

const ECONOMY_PATH: String = "res://src/data/economy.json"
const STAFF_PATH: String = "res://src/data/staff.json"
const TECH_TREE_PATH: String = "res://src/data/tech_tree.json"
const TIME_PATH: String = "res://src/data/time.json"
const CHIPS_PATH: String = "res://src/data/chips.json"
const RIVALS_PATH: String = "res://src/data/rivals.json"


## 装配全部系统并互连，返回 {world 引用的命名集合}。
## seed=开局种子（RngStream 根种子；同种子=同局可复现，#125）。
## 幂等：每 World 实例恰装配一次（本方法只被 GameWorld 调用）。
static func assemble(seed: int) -> Dictionary:
	var rng := RngStream.new()
	rng.setup(seed)

	var economy_table := DataLoader.load_json(ECONOMY_PATH)
	var resources := Resources.new(
		int(economy_table["eco_startup_cash"]), int(economy_table["eco_startup_influence"])
	)
	# 周卡时供给=T0 档位（chips.json 表驱动；World 装配批接 ChipYard 的等价注入）
	var chips_table := DataLoader.load_json(CHIPS_PATH)
	var t0_supply := int(((chips_table["chip_tiers"] as Dictionary)["t0"] as Dictionary)["supply"])
	resources.weekly_supply_provider = func() -> int: return t0_supply
	# 开局预算就位（W1 可排训练）：provider 注入后即 reset——对齐全部既有
	# 消费方惯例（test_card_hours_budget before_each 等）；漏置时 W1 剩余=0，
	# 首训练被 CARD_HOURS_INSUFFICIENT 拒（#190 浏览器实测暴露）
	resources.reset_weekly_card_hours()

	var clock := GameClock.new(DataLoader.load_json(TIME_PATH))
	var ledger := Ledger.new(1)
	var economy := Economy.new()
	var roster := Roster.new(DataLoader.load_json(STAFF_PATH), rng)
	var archive := PaperArchive.new()
	var library := ModelLibrary.new()
	var sota := SotaBoard.new()
	# 周报构建（批7.4 #194 补装配：批7.1 遗漏致周报通道全死——begin_week/
	# 行写入/自动弹判定均依赖本实例；begin_week 由 Settlement 周结驱动）
	var weekly_report := WeeklyReport.new()

	var board := TaskBoard.new()
	board.is_staff_known = func(staff_id: String) -> bool: return roster.is_assignable(staff_id)
	board.is_staff_assignable = func(staff_id: String) -> bool:
		return roster.is_assignable(staff_id)
	board.get_staff_role_key = func(staff_id: String) -> String:
		return Staff.role_to_key(roster.get_staff(staff_id).get_role())
	board.staff_table = DataLoader.load_json(STAFF_PATH)
	board.tier_met = func(_tier: String) -> bool: return true
	board.budget_met = func(hours: int) -> bool:
		return resources.get_card_hours_remaining() >= hours
	board.consume_card_hours = func(hours: int) -> bool:
		return bool(resources.consume_card_hours(hours).get("ok", false))

	var tree := TechTree.new(DataLoader.load_json(TECH_TREE_PATH), rng)
	var research := tree.get_research()
	research.spend_influence = func(amount: int) -> bool: return resources.spend_influence(amount)

	var ceremony := ModelCeremony.new(library, sota)
	ceremony.release_slot = func(slot: int) -> void: board.release_finished_slot(slot)

	var pack := RivalPack.new()

	return {
		"rng": rng,
		"clock": clock,
		"resources": resources,
		"ledger": ledger,
		"economy": economy,
		"roster": roster,
		"board": board,
		"archive": archive,
		"library": library,
		"sota": sota,
		"tree": tree,
		"ceremony": ceremony,
		"pack": pack,
		"weekly_report": weekly_report,
		"chips": chips_table,
	}
