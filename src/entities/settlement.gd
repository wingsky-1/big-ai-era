class_name Settlement
extends RefCounted
## L2 周结序列编排（#135 MVP；architecture §5.3 phase 0-10 + ADR-0020）：
## 只调用各系统结算接口，不发明玩法（ADR-0020：产出结算声明按型路由唯一
## 过账——一切资源变更经 Ledger）。
## 本批切片（#135 DoD）：
## - phase 0 门控（z2 阻塞谓词注入——决策/命名未决跳过本 tick）
## - phase 1 卡时重置（#139 真实供给前=清周内计数）
## - phase 2 经营收入：TaskBoard 逐槽 week_tick → 完成项目按型路由
##   （论文=PaperArchive 入谱+RP/影响力/资金过账；模型/算力 #140/#141 接线）
## - phase 3 固定支出：周工资×阶段（在册 4 人基准）+ 运维×档位
## - phase 4 ledger 快照（周净对账断言）
## - phase 5 破产判定短路（cash<0 且无可用救济——#136 前救济查询=恒 false）
## - phase 6 账期翻页（ledger.set_week）
## - phase 7-10 事件/竞对/仪式/周报/存档：#144/#149/#126 接线（本批接口预留）
## 确定性纪律：phase 内零墙钟依赖（周数=唯一时间单位）。
## RefCounted 零 Node；headless 可单测。

signal week_settled(payload: Dictionary)
signal game_over_triggered(payload: Dictionary)

## z2 阻塞谓词注入（决策卡/命名框未决=跳过本 tick；批5 UI 接 PanelStack）
var z2_blocked: Callable = func() -> bool: return false

## 救济可用性谓词注入（#136 前=恒 false：cash<0 即破产信号）
var relief_available: Callable = func() -> bool: return false

var _ledger: Ledger
var _resources: Resources
var _economy: Economy
var _task_board: Object = null  # 弱引用语义：经装配方注入（防环）
var _paper_archive: Object = null
var _weekly_report: Object = null  # #149 周报构建（可选注入：未注入=跳过周报行）
var _week: int = 1


func _init(
	ledger: Ledger,
	resources: Resources,
	economy: Economy,
	task_board: Object = null,
	paper_archive: Object = null,
	weekly_report: Object = null,
) -> void:
	_ledger = ledger
	_resources = resources
	_economy = economy
	_task_board = task_board
	_paper_archive = paper_archive
	_weekly_report = weekly_report


## 周结主入口（装配方按墙钟/倍率喂 tick；phase 0-6 本批实落，7-10 接口）。
## 返回 {ok, skipped, bankrupt, week, report}：
## - skipped=true=z2 阻塞跳过本 tick（不推进周号）
## - bankrupt=true=破产短路（负债入结算，周号不推进）
func run_settle(week: int) -> Dictionary:
	if _ledger.get_week() != week:
		_ledger.set_week(week)
	_week = week
	# phase 0：z2 门控
	if z2_blocked.call():
		return {"ok": true, "skipped": true, "bankrupt": false, "week": week}
	# #149 周报周起始（z2 阻塞跳过周不 begin——跳过的周不产生周报）
	if _weekly_report != null:
		_weekly_report.begin_week(week)
	# phase 1：卡时重置 + 预算重占（#140：重置后对在跑训练项目扣本周周耗）
	_resources.reset_weekly_card_hours()
	if _task_board != null:
		_task_board.consume_weekly_budget()
	# phase 2：经营收入结算（项目推进+完成路由）
	var finished := _settle_projects()
	# phase 3：固定支出（工资+运维）
	_settle_fixed_costs()
	# phase 4：ledger 快照（周净=对账闭合断言点）
	var week_net := _ledger.get_week_net()
	# phase 5：破产判定短路（全部收入后）
	var bankrupt := _check_bankrupt()
	if bankrupt:
		(
			game_over_triggered
			. emit(
				{
					"kind": "bankrupt",
					"week": week,
					"debt": -mini(_resources.get_cash(), 0),
					"week_net": week_net,
				}
			)
		)
		return {
			"ok": true,
			"skipped": false,
			"bankrupt": true,
			"week": week,
			"debt": -mini(_resources.get_cash(), 0),
		}
	# phase 6：账期翻页（周累计清零；周号由装配方推进）
	_ledger.set_week(week + 1)
	# phase 7-10：事件/竞对/仪式/周报/存档——后续批接线（#144/#149/#126）
	(
		week_settled
		. emit(
			{
				"week": week,
				"quarter": _quarter_of(week),
				"finished": finished,
				"week_net": week_net,
				"cash": _resources.get_cash(),
			}
		)
	)
	return {
		"ok": true,
		"skipped": false,
		"bankrupt": false,
		"week": week,
		"finished": finished,
	}


## ---------- 数据面（只读） ----------


func get_week() -> int:
	return _week


## ---------- 私有（phase 实现） ----------


## phase 2：TaskBoard 逐槽推进 + 完成项目按型路由（产出结算声明模式）
func _settle_projects() -> Array[Dictionary]:
	var finished: Array[Dictionary] = []
	if _task_board == null:
		return finished
	var completed := _task_board.week_tick() as Array
	for item: Variant in completed:
		var info := item as Dictionary
		if info.is_empty():
			continue
		var project: Object = info.get("project")
		var project_type: int = int(info.get("type", -1))
		match project_type:
			CoreEnums.ProjectType.PAPER:
				var result := _route_paper_finished(project)
				finished.append(result)
				# #149 论文完成槽释放（防 4 槽死局；#143 模型侧=仪式命名后释放，
				# 论文侧=本批收口：路由已取完产出数据，槽即回收可复用）
				_task_board.release_finished_slot(int(info.get("slot_index", -1)))
			_:
				# 模型/算力：#140/#141 接线（本批不路由，项目留 FINISHED_PENDING）
				finished.append({"type": project_type, "routed": false})
	return finished


## 论文完成路由（#133 PaperProject → 入谱+RP/影响力/资金过账；#134 Archive）
func _route_paper_finished(project: Object) -> Dictionary:
	var route := {"type": CoreEnums.ProjectType.PAPER, "routed": false}
	if _paper_archive == null or project == null:
		return route
	var paper_view := project.get_paper_view() as Dictionary
	var title_key := str(paper_view.get("title_key", ""))
	var domain := str(paper_view.get("domain", ""))
	if title_key.is_empty():
		return route
	# 影响力与资金产出读 papers.json（表驱动：型→收入/影响力）
	var papers_table := DataLoader.load_json("res://src/data/papers.json")
	var kind_key := str(paper_view.get("paper_kind_key", "repro"))
	var influence := int((papers_table.get("paper_influence", {}) as Dictionary).get(kind_key, 0))
	var income := int((papers_table.get("paper_income_cash", {}) as Dictionary).get(kind_key, 0))
	# RP 入账（主域 RP 值读表；#138 树接 rp_by_domain 前=记 ledger note）
	var rp_primary := int(papers_table.get("paper_rp_primary", 0))
	# 过账（唯一过账口）：资金收入
	if income != 0:
		_ledger.record(Ledger.Category.INCOME_TASK, income, "paper_%s" % kind_key)
		_resources.apply_change(income)
	# 影响力增益（现金外第二资源；供给台账后续批）
	if influence != 0:
		_resources.gain_influence(influence)
	# 入谱（#134 PaperArchive；cites 空=独立工作）
	var ndim: Array = []
	if paper_view.has("ndim"):
		ndim = paper_view["ndim"]
	_paper_archive.add_paper(title_key, domain, ndim, 0.0, influence)
	# #149 周报行（账本对账行：论文影响力 +X；显著=谓词 0→influence，防零值噪声）
	if _weekly_report != null and influence != 0:
		var report_text := TextService.format("paper_impact_row", {"影响": str(influence)})
		_weekly_report.add_delta_row(
			WeeklyReport.RowKind.LEDGER, report_text, 0.0, float(influence)
		)
	route["routed"] = true
	route["influence"] = influence
	route["income"] = income
	route["rp"] = rp_primary
	route["domain"] = domain
	return route


## phase 3：固定支出（周工资×阶段 + 运维×注入档位）
func _settle_fixed_costs() -> void:
	var stage := _economy.get_stage(_week)
	var salary := _economy.get_weekly_salary(stage)
	if salary > 0:
		_ledger.record(Ledger.Category.EXPENSE_SALARY, -salary, "weekly_salary")
		_resources.apply_change(-salary)
	var ops := _economy.get_weekly_ops_cost()
	if ops > 0:
		_ledger.record(Ledger.Category.EXPENSE_OPS, -ops, "weekly_ops")
		_resources.apply_change(-ops)


## phase 5：破产判定（cash<0 且无可用救济；负债=abs(cash) 入结算）
func _check_bankrupt() -> bool:
	return _resources.get_cash() < 0 and not relief_available.call()


## 周→季度（L0 clock_math 同源；此处避免依赖注入直接用表常量）
func _quarter_of(week: int) -> int:
	return int(ceilf(float(week) / 13.0))
