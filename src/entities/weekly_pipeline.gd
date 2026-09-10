class_name WeeklyPipeline
extends RefCounted
## L2 周结相位 7-10 编排（批7.1 #188；architecture §5.3 phase 7-10 + ADR-0015
## 步序契约 ⑤）。Settlement 保持 phase0-6（收入/破产/账期），本类=phase7-10
## 硬序执行器，由 GameWorld 周结驱动调用。
## 硬序（ADR-0015/§5.3，评审修订②）：
##   7 事件/竞对/仪式序列（同帧按信号到达序串行）：
##     7a 出分/SOTA（模型完成扫描→ScoreComposer→ceremony；**必须先于竞对**，
##         player_released 是 7b 撞车判定的输入）
##     7b 竞对时间线推进（advance_all(week, player_released)）
##     7c 迷雾（research_tick 点亮 + 竞对 paper→spill_reveal + lit→cross_reveal）
##     7d 员工状态带掷点（roll_weekly_states，周粒度一次）
##   8 周报收口（begin_week 已在 phase 前由 Settlement 做，本类补行）
##   9 自动存档（注入 autosave 回调；GameWorld 组装 12 域经 SaveSystem）
##   10 广播 week_settled（GameWorld 层消费，L3 呈现）
## 职责纪律：只调用各系统结算接口（ADR-0020），不发明玩法逻辑；
## 全部系统引用=构造注入（防环：本类不反向持有 GameWorld）。

const ACTION_PAPER: String = "paper"

## 注入引用（装配方=GameWorld/WorldFactory 串接）
var board: Object = null  # TaskBoard
var ceremony: Object = null  # ModelCeremony
var tree: Object = null  # TechTree
var pack: Object = null  # RivalPack
var roster: Object = null  # Roster
var weekly_report: Object = null  # WeeklyReport（可空=不建周报行）
## 事件壳注入（批7.4 #194 phase11：周结事件判定；可空=不判定——空态静默）
var event_shell: Object = null  # EventShell
## 出分合成器注入（默认=ScoreComposer.compose_base_profile；三源合成为后续
## 数值批替换，同签名）
var compose_score: Callable = func(project: Object) -> Dictionary:
	return ScoreComposer.compose_base_profile(project as ModelProject)
## 自动存档回调注入（GameWorld 组装存档字典后经 SaveSystem 原子写）
var autosave: Callable = func(_week: int) -> void: pass


func _init(
	p_board: Object = null,
	p_ceremony: Object = null,
	p_tree: Object = null,
	p_pack: Object = null,
	p_roster: Object = null,
	p_weekly_report: Object = null,
) -> void:
	board = p_board
	ceremony = p_ceremony
	tree = p_tree
	pack = p_pack
	roster = p_roster
	weekly_report = p_weekly_report


## 相位 7-10 主入口（Settlement.run_settle phase6 后由 GameWorld 调一次）。
## 返回 {scored: Array, fired: Array, lit: Array, rolled: int} 供测试/日志。
func run(week: int) -> Dictionary:
	var result := {
		"scored": [],
		"fired": [],
		"lit": [],
		"rolled": 0,
	}
	# 7a 出分/SOTA（先于竞对：player_released 输入）
	var scored := _phase_score(week)
	result["scored"] = scored
	# 7b 竞对推进（撞车判定输入=玩家本周是否出分）
	var player_released := not scored.is_empty()
	var fired: Array = []
	if pack != null:
		fired = (pack as RivalPack).advance_all(week, player_released)
	result["fired"] = fired
	# 7c 迷雾（研究点亮 + 竞对 paper 外溢 + 交叉揭示）
	result["lit"] = _phase_fog(fired)
	# 7d 员工状态带掷点（周粒度一次；rng.staff 登记域消费）
	if roster != null:
		result["rolled"] = (roster as Roster).roll_weekly_states().size()
	# 11 事件判定（批7.4 phase11：hit 率门+决策级 pending 置位；管线不挂起——
	# 只判定+置 pending，选择/入账在管线外 UI 回调时点，ADR-0015 补登记）
	if event_shell != null:
		result["event"] = (event_shell as EventShell).roll_week()
	# 8 周报收口（Begin 已在 phase 前；模型出分/竞对行由周报构建方自行消费
	# 信号——本类不发明行）
	# 9 自动存档（周结后原子写；GameWorld 组装 12 域）
	autosave.call(week)
	return result


## ---------- 私有（相位实现） ----------


## 7a：扫描 TaskBoard FINISHED_PENDING 模型槽→出分→入待命名（命名=z2 阻塞，
## 周结内不完成：ceremony pending 后由 L3 命名框消费，settlement z2 门控
## 阻止跨周）。同周多模型=逐个入队（串行命名）。
func _phase_score(week: int) -> Array:
	var scored: Array = []
	if board == null or ceremony == null:
		return scored
	var task_board := board as TaskBoard
	for slot: int in task_board.get_slot_count():
		if task_board.get_slot_state(slot) != CoreEnums.ProjectState.FINISHED_PENDING:
			continue
		var project := task_board.get_project(slot)
		if project == null or project.get_type() != CoreEnums.ProjectType.MODEL:
			continue
		var composed: Dictionary = compose_score.call(project)
		var payload: Dictionary = {
			"project": project,
			"score": float(composed.get("score", 0.0)),
			"ndim": composed.get("ndim", {}) as Dictionary,
			"week": week,
			"slot_index": slot,
		}
		var submit_result: Dictionary = (ceremony as ModelCeremony).settle_finished(payload)
		if bool(submit_result.get("ok", false)):
			scored.append(payload)
			if weekly_report != null:
				var score_text := str(TextService.text("model_score_title"))
				(
					(weekly_report as WeeklyReport)
					. add_row(
						WeeklyReport.RowKind.RITUAL,
						score_text.replace("XX.X", "%.1f" % float(payload["score"])),
						true,
					)
				)
	return scored


## 7c：研究周推进（点亮 node_lit）+ 竞对 paper 动作外溢翻雾 + 交叉揭示。
## 返回点亮节点 id 数组。
func _phase_fog(fired: Array) -> Array:
	var lit: Array = []
	if tree == null:
		return lit
	var tech_tree := tree as TechTree
	for completed: Variant in tech_tree.research_tick():
		if completed is Dictionary:
			lit.append(str((completed as Dictionary).get("node_id", "")))
	# 竞对 paper 动作→外溢翻雾（rivals-spec A.2 通路②；#144 表驱动 spill_eligible）
	for payload: Variant in fired:
		if str((payload as Dictionary).get("action", "")) == ACTION_PAPER:
			var spill: Dictionary = tech_tree.spill_reveal()
			# spill 成功=新节点进 rumored/visible；失败=该周无外溢目标（合法空转）
			if bool(spill.get("ok", false)):
				var domain := str(spill.get("node_id", "")).get_slice("_", 0)
				if not domain.is_empty():
					_phase_cross(tech_tree, domain)
	# 交叉揭示：lit 后相邻域联动（表驱动 tree_reveal_cross）
	for node_id: String in lit:
		var domain := node_id.get_slice("_", 0)
		_phase_cross(tech_tree, domain)
	return lit


## 交叉揭示（table-driven cross_from 声明；无 lit 邻居=合法空转失败）
func _phase_cross(tech_tree: TechTree, domain: String) -> void:
	tech_tree.cross_reveal(domain)
