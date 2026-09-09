extends GutTest
## #135 集成：Settlement×TaskBoard×PaperArchive——论文完成经周结路由入谱+过账。
## 验证 phase 2 产出结算声明模式真实联通（ADR-0020）。

var _ledger: Ledger
var _resources: Resources
var _economy: Economy
var _board: TaskBoard
var _archive: PaperArchive


func before_each() -> void:
	_ledger = Ledger.new(1)
	autofree(_ledger)
	_resources = Resources.new(200000, 0)
	autofree(_resources)
	_economy = Economy.new()
	autofree(_economy)
	_board = TaskBoard.new()
	autofree(_board)
	_archive = PaperArchive.new()
	autofree(_archive)


func test_paper_finish_routes_to_archive_and_ledger() -> void:
	# 论文入槽（复现 3 周）→ 跑 3 周周结 → 完成入谱 + 收入过账
	var pool := PaperPool.new()
	autofree(pool)
	var topics := pool.get_topics_in_domain("align")
	assert_false(topics.is_empty(), "align 域有题")
	var paper := PaperProject.from_topic(topics[0])
	_board.start_paper(paper)
	var settlement := Settlement.new(_ledger, _resources, _economy, _board, _archive)
	autofree(settlement)
	var duration := paper.get_duration_weeks()
	for i: int in duration:
		var result: Dictionary = settlement.run_settle(1 + i)
		assert_false(result.skipped, "第 %d 周可结算" % (i + 1))
		assert_false(result.bankrupt, "不破产")
	# 完成：论文入谱
	assert_eq(_archive.count(), 1, "论文完成入谱")
	var entry := _archive.get_all_entries()[0]
	assert_eq(entry["domain"], "align", "入谱域=align")
	# 收入过账（复现型 income 3 万；行证据链）
	var income_total := 0
	for row: Dictionary in _ledger.get_all_rows():
		if str(row.get("category_key", "")) == "income_task":
			income_total += int(row.get("amount", 0))
	assert_eq(income_total, 30000, "复现论文收入 3 万过账（papers.json 表驱动）")
	# 影响力增益（#153：repro=18，tech-tree 护栏"首节点成本 ≤ 首任务影响力×2"）
	assert_eq(_resources.get_influence(), 18, "复现论文影响力 +18（papers.json 表驱动）")


func test_paper_contract_income_higher_than_research() -> void:
	# 课题型收入 > 研究型（papers-spec：课题=资金高 RP 低）
	var papers_table := DataLoader.load_json("res://src/data/papers.json")
	var incomes: Dictionary = papers_table["paper_income_cash"]
	assert_true(int(incomes["contract"]) > int(incomes["research"]), "课题收入>研究收入（表驱动）")
	assert_true(
		int(incomes["research"]) > int(incomes["repro"]) or int(incomes["repro"]) >= 0, "研究收入档位存在"
	)
