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
