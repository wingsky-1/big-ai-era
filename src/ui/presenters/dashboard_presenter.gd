class_name DashboardPresenter
extends RefCounted
## L3 主台数据适配器（#146；architecture-100 §2.1 presenters/dashboard_presenter.gd
## + ADR-0027：presenter=纯数据适配器（view 字典→界面字段，禁业务计算），headless
## 可单测；panel/控件只消费 presenter 产物，控件不自己拼句）。
## 槽卡适配=TaskBoard.get_task_view 的槽 view → TaskSlotCard 可读字段（标题句/
## 类型句/预计结账句/状态句/协作角标/上桌位），文本经 TextService 键面（L1）。
## 类型枚举→稳定字符串映射=Project.type_to_key 的 L3 镜像（防 L3 import L2；
## 一致性由 test_task_slot_card 断言锁同源）。
## 硬约束：只读输入只做格式适配；零业务计算（ADR-0016）；禁读 L4（表值经注入
## 的 view + 测试镜像断言到达，本类零 DataLoader）。

## 类型枚举→稳定字符串（镜像 Project.type_to_key；GUT 断言两源一致）
const TYPE_KEY: Dictionary = {
	CoreEnums.ProjectType.PAPER: "paper",
	CoreEnums.ProjectType.MODEL: "model",
	CoreEnums.ProjectType.COMPUTE: "compute",
}
## 类型枚举→类型句文案键（texts-keys.md ui_type_*）
const TYPE_LABEL_KEY: Dictionary = {
	CoreEnums.ProjectType.PAPER: "ui_type_paper",
	CoreEnums.ProjectType.MODEL: "ui_type_model",
	CoreEnums.ProjectType.COMPUTE: "ui_type_compute",
}
## 槽卡句键（预计结账=time-spec 同源键 #146 起插值化，槽卡/周报共用一词）
const KEY_ETA: String = "time_est_settle"
const KEY_SLOT_EMPTY: String = "ui_task_slot_empty"
const KEY_SLOT_FINISHED: String = "ui_task_finished"
## 协作角标前缀（数值格式非文案：×系数两位小数；spec B.2「角标 ×1.05/×1.15」）
const COLLAB_PREFIX: String = "×"
## 空槽 type 哨兵镜像（TaskBoard.EMPTY_SLOT_TYPE=-1；L3 镜像常量防 import L2，
## 一致性由 test_task_slot_card 断言锁同源）
const EMPTY_SLOT_TYPE: int = -1
## 员工卡句键（产出区间=状态数值带同源插值化；在岗=<项目名>）
const KEY_OUTPUT_HINT: String = "staff_state_output_hint"
const KEY_ONTABLE: String = "staff_ontable_project"
## 资源栏/竞对入口句键（净流入/警告横幅 #148 起插值化；档位标签=ui_grade_*）
const KEY_NET_INFLOW: String = "eco_net_inflow"
const KEY_WARNING_BANNER: String = "eco_warning_banner"
const KEY_GRADE: Array[String] = [
	"ui_grade_0",
	"ui_grade_1",
	"ui_grade_2",
	"ui_grade_3",
	"ui_grade_4",
]
## 档位标签阈值镜像（ui.json ui_score_grade_threshold：<10 榜外/10-30 新星/
## 30-60 中坚/60-85 第一梯队/85+ 登顶；仅显示分级口径，与 SOTA 守卫带不冲突）
const GRADE_THRESHOLD: Array = [10.0, 30.0, 60.0, 85.0]
## 显示分级呈现面（#150：主台=阈下档位标签/周报=恒显真值）
const SURFACE_MAIN: String = "main"
const SURFACE_REPORT: String = "report"


## 槽 view → 槽卡字段（单点适配；空槽=状态句 + 其余留空，防假数据"A.5 空态"）。
## 返回字段全部为"显示就绪"值，控件直接取用，零二次计算。
static func slot_card_view(view: Dictionary) -> Dictionary:
	var state: int = int(view.get("state", CoreEnums.ProjectState.EMPTY))
	var slot_type: int = int(view.get("type", EMPTY_SLOT_TYPE))
	var fields := {
		"slot_index": int(view.get("slot_index", 0)),
		"state": state,
		"type": slot_type,
		"type_key": str(TYPE_KEY.get(slot_type, "")),
		"type_label": "",
		"title_text": "",
		"eta_text": "",
		"state_text": "",
		"progress": 0.0,
		"collab_badge": "",
		"seat_text": "",
	}
	if state == CoreEnums.ProjectState.EMPTY:
		# 空槽：只显空态句（不渲染类型/标题/进度假数据）
		fields["state_text"] = TextService.text(KEY_SLOT_EMPTY)
		return fields
	var type_label_key: String = str(TYPE_LABEL_KEY.get(slot_type, ""))
	if not type_label_key.is_empty():
		fields["type_label"] = TextService.text(type_label_key)
	var title_key: String = str(view.get("title_key", ""))
	if not title_key.is_empty():
		fields["title_text"] = TextService.text(title_key)
	if state != CoreEnums.ProjectState.EMPTY:
		# 进度=运行中逐周推进、完成态冻结 1.0（L2 冻结语义，两态都显）
		var progress := float(view.get("progress", 0.0))
		fields["progress"] = clampf(progress, 0.0, 1.0)
	if state == CoreEnums.ProjectState.IN_PROGRESS:
		# 预计结账 Wx 常显（运行中）；完成态=状态句接管，不显 W0
		var weeks_left: int = int(view.get("weeks_left", 0))
		fields["eta_text"] = TextService.format(KEY_ETA, {"周数": str(weeks_left)})
		var factor := float(view.get("collab_factor", 1.0))
		if factor > 1.0:
			# 同岗 ×1.0 是基准不显角标（task_board._slot_collab_kind 同源语义）
			fields["collab_badge"] = "%s%.2f" % [COLLAB_PREFIX, factor]
		var count := int(view.get("assigned_count", 0))
		var limit := int(view.get("seat_limit", 0))
		if limit > 0:
			fields["seat_text"] = "%d/%d" % [count, limit]
	if state == CoreEnums.ProjectState.FINISHED_PENDING:
		fields["state_text"] = TextService.text(KEY_SLOT_FINISHED)
	return fields


## 员工卡适配（#147）：staff view + 任务槽 views → 员工卡字段（名/岗位/状态带
## 色键+字样/产出区间/在岗项目/协作角标）。在岗信息=任务槽 view 反查（架构
## §4.1：指派唯一写点在槽成员，本适配只读 view 数组，零业务计算）；状态带=色
## +文字双通道（staff-spec A.1 状态带可读；产出区间=状态数值带同源防两张皮）。


## staff view + 全部槽 view → 员工卡字段（深拷贝输入，只读适配）。
static func staff_card_view(staff_view: Dictionary, task_views: Array) -> Dictionary:
	var staff_id := str(staff_view.get("id", ""))
	var fields := {
		"id": staff_id,
		"name": str(staff_view.get("name", "")),
		"role_name": _resolve_key(str(staff_view.get("role_name_key", ""))),
		"state_key": str(staff_view.get("state_key", "")),
		"state_name": _resolve_key(str(staff_view.get("state_name_key", ""))),
		"output_hint": "",
		"on_slot": false,
		"assigned_text": "",
		"collab_badge": "",
	}
	var state_key: String = fields["state_key"]
	if not state_key.is_empty():
		# 产出区间提示=状态数值带同源（modifier_min/max → 百分数，文案键插值）
		var band_min := float(staff_view.get("modifier_min", 0.0))
		var band_max := float(staff_view.get("modifier_max", 0.0))
		fields["output_hint"] = (
			TextService
			. format(
				KEY_OUTPUT_HINT,
				{"下限": str(round(band_min * 100.0)), "上限": str(round(band_max * 100.0))},
			)
		)
	# 在岗反查（架构 §4.1 唯一写点在槽成员；匹配即取标题/协作系数，break 单槽）
	for slot_view_variant: Variant in task_views:
		var slot_view: Dictionary = slot_view_variant
		var members: Array = slot_view.get("assigned_staff", [])
		if not members.has(staff_id):
			continue
		fields["on_slot"] = true
		fields["assigned_text"] = (
			TextService
			. format(
				KEY_ONTABLE,
				{"项目名": _resolve_key(str(slot_view.get("title_key", "")))},
			)
		)
		var factor := float(slot_view.get("collab_factor", 1.0))
		if factor > 1.0:
			# 协作 active=组合效率 >1.0（同岗/单人 ×1.0 基准不显，task_board 同源）
			fields["collab_badge"] = "%s%.2f" % [COLLAB_PREFIX, factor]
		break
	return fields


## 资源栏/预警适配（#148）：L2 聚合数据 → 显示字段（三主资源/净流入预告副行/
## 警告横幅+救济三键）。净流入=周净（ledger 同源口径）；负值=forecast_negative
## 文本通道（负值非单色，economy-spec A.1）；警告=现金<警告线且周净为负（亏钱
## 才预警，"还能撑 X 周"公式 eco_solvency_weeks：cash÷周净流出，上限 99）。
static func resource_bar_view(data: Dictionary) -> Dictionary:
	var cash := int(data.get("cash", 0))
	var weekly_net := int(data.get("weekly_net", 0))
	var warning_line := int(data.get("warning_line", 0))
	var solvency_weeks := int(data.get("solvency_weeks", 0))
	var warning_active: bool = cash < warning_line and weekly_net < 0
	var fields := {
		"cash_text": _money(cash),
		"influence_text": str(int(data.get("influence", 0))),
		"card_hours_text":
		(
			"%d/%d"
			% [
				int(data.get("card_hours_used", 0)),
				int(data.get("card_hours_supply", 0)),
			]
		),
		"forecast_text": TextService.format(KEY_NET_INFLOW, {"净流入": _signed_money(weekly_net)}),
		"forecast_negative": weekly_net < 0,
		"warning_active": warning_active,
		"warning_text": "",
		"solvency_weeks": solvency_weeks,
	}
	if warning_active:
		fields["warning_text"] = (
			TextService
			. format(
				KEY_WARNING_BANNER,
				{"周亏": _money(-weekly_net), "周数": str(solvency_weeks)},
			)
		)
	return fields


## 竞对轻量入口适配（#148；OP-UX-04：无数字无红点；<10 只显档位标签，
## ≥10 不显任何数字——真值在周报/曲线面板，周报恒显）。score<0=未出分（不渲染）。
static func rival_light_view(score: float) -> Dictionary:
	var grade_index := -1
	if score >= 0.0:
		grade_index = GRADE_THRESHOLD.size()  # 默认最高档（≥85 登顶档）
		for i: int in GRADE_THRESHOLD.size():
			if score < float(GRADE_THRESHOLD[i]):
				grade_index = i
				break
	return {
		"has_data": score >= 0.0,
		"show_badge": score >= 0.0 and score < float(GRADE_THRESHOLD[0]),
		"grade_index": grade_index,
		"grade_text":
		(
			TextService.text(KEY_GRADE[grade_index])
			if grade_index >= 0 and grade_index < KEY_GRADE.size()
			else ""
		),
	}


## 显示分级适配（#150；ui-ux B.2 显示分级/OP-UX-04「score<10 主台不显裸数字
## 只显档位标签，≥10 显真值，周报恒显」）。surface=见 SURFACE_MAIN/REPORT。


static func score_display(score: float, surface: String) -> Dictionary:
	var has_data := score >= 0.0
	var show_number := false
	if has_data:
		show_number = surface == SURFACE_REPORT or score >= float(GRADE_THRESHOLD[0])
	var grade_index := _grade_index_of(score)
	return {
		"has_data": has_data,
		"show_number": show_number,
		"number": str(int(round(score))) if show_number else "",
		"grade_text":
		(
			TextService.text(KEY_GRADE[grade_index])
			if has_data and not show_number and grade_index >= 0 and grade_index < KEY_GRADE.size()
			else ""
		),
	}


## n 维条形数据适配（#150；L2 ndim 视图{文本键:数值}→条形行 [{label,value}]，
## 标签=TextService 解析（paper_ndim_*/model_ndim_* 键面）；数值降序=揭晓序。
static func ndim_bars_view(ndim_data: Dictionary) -> Array:
	var bars: Array = []
	for key: String in ndim_data.keys():
		var label := _resolve_key(key)
		if label.is_empty():
			continue
		bars.append({"label": label, "value": float(ndim_data[key])})
	bars.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"])
	)
	return bars


## 文案键安全解析（空键=直接留空，防 TextService 对空键 push_error 熔断）
static func _resolve_key(text_key: String) -> String:
	if text_key.is_empty():
		return ""
	return TextService.text(text_key)


## 金额显示（¥前缀整数；无千分位——移动端紧凑口径）
static func _money(amount: int) -> String:
	return "¥%d" % amount


## 带符号金额（净流入预告：+¥120 / -¥45；负值走文本通道非单色）
static func _signed_money(amount: int) -> String:
	var prefix: String = "+¥" if amount >= 0 else "-¥"
	return "%s%d" % [prefix, absi(amount)]


## 分数→档位下标（<10=0/10-30=1/30-60=2/60-85=3/≥85=4；score<0=-1 未出分）
static func _grade_index_of(score: float) -> int:
	if score < 0.0:
		return -1
	var index := GRADE_THRESHOLD.size()
	for i: int in GRADE_THRESHOLD.size():
		if score < float(GRADE_THRESHOLD[i]):
			index = i
			break
	return index
