class_name CoreEnums
## L0 全局枚举集中地（v1.0.0 重建骨架，占位）。
## 纪律：enum 是编译期符号，其值与数据表 JSON 内稳定字符串的映射只允许
## 单向（enum→字符串经集中映射函数），禁止散落字符串字面量比较。

## 任务槽项目三类（#131；真源=architecture-100 §4.1/ADR-0018 三类共槽：
## 论文/训练/算力互斥占同一批 4 槽）。表内以稳定字符串承载（papers.json/
## models.json 等），代码侧 enum→字符串映射单向集中在 Project.type_to_key。
enum ProjectType {
	## 论文项目（复现/研究/课题三型，#133 落地）
	PAPER,
	## 模型训练项目（基座/checkpoint，#140 落地）
	MODEL,
	## 算力项目（自研/出租/集群——P2 内容占位，E5；本批仅同接口 stub 占槽）
	COMPUTE,
}

## 任务槽/项目状态（#131；真源=architecture-100 §4.4：P0 三态
## EMPTY/IN_PROGRESS/FINISHED_PENDING；QUEUED 预留给 P2 深队列——本批不写，
## 加枚举值=纯扩展零迁移，enum 值不入档）。
enum ProjectState {
	## 槽空（无项目；仅槽级状态，Project 对象本身无此态）
	EMPTY,
	## 进行中（项目入空槽即 IN_PROGRESS——P0 直接入空槽不排队，§4.4）
	IN_PROGRESS,
	## 活已干完待结算揭晓（产出结算声明已生成；槽消费/释放由 Settlement #135 承接）
	FINISHED_PENDING,
}

## 槽操作拒绝原因单一源（#131；硬约束：禁字符串散落，各拒绝路径恰返回一枚举码；
## 对应 *_disabled_reason 文案键由 L3 按码拼接（#124 键面），本层只出原因码）。
## 校验顺序=各命令方法体内固定自上而下命中即返（单因语义，不叠加不拼接）。
enum SlotRejectReason {
	## 成功/无阻塞（非拒绝，作为命令"通过"返回值）
	NONE = 0,
	## 槽位越界（防御：命令层不应发生）
	SLOT_OUT_OF_RANGE,
	## 该槽无进行中项目（空槽/完成待结算槽：不能指派/取消）
	NO_RUNNING_PROJECT,
	## 无此员工（装配注入的名册存在性谓词未通过）
	STAFF_UNKNOWN,
	## 重复指派（该员工已是本槽上桌成员）
	STAFF_ALREADY_ASSIGNED,
	## 该员工已在别槽上桌（每员工至多一槽断言，防双写漂移）
	STAFF_ON_OTHER_SLOT,
	## 员工当前不可派（装配注入的可派性谓词未通过；#132 接 Roster 谓词/状态）
	STAFF_NOT_ASSIGNABLE,
	## 上桌人数已达本槽项目上限（上限来自 Project 声明的上桌上限，非 TaskBoard 自定）
	SEAT_LIMIT_REACHED,
	## 撤派对象不在本槽上桌（unassign 无对象）
	UNASSIGN_NOT_ON_TABLE,
	## 任务槽已满（4 槽全占——恒 4 常量见 TASK_SLOT_COUNT）
	ALL_SLOTS_FULL,
	## 基座档位门槛未达（#140：训练启动校验档位因；ModelProject.tier_required
	## vs 注入的档位谓词；models-spec 六因"算力档不足"单一原因码）
	TIER_REQUIRED_NOT_MET,
	## 本周卡时不足（#140：训练启动校验卡时因；注入的预算谓词判周耗 vs 剩余；
	## models-spec 六因"本周卡时不足"+chips-spec OP-CHP-03 拒绝条件）
	CARD_HOURS_INSUFFICIENT,
}

## 员工岗位四类（#130；真源=staff-spec G3 拍板"直接 4 岗"+staff-spec C.1 岗位文案键
## staff_role_research/eval/data/engineering）。表内以稳定字符串承载（staff.json
## staff_roles 键），代码侧 enum 映射单向集中在 Staff/Roster 解析处。
enum StaffRole {
	RESEARCH,
	EVAL,
	DATA,
	ENGINEERING,
}

## 员工状态带三态（#130；真源=staff-spec A.3/B.2/C.1：专注/摸鱼/灵感走高）。
## 状态值=enum 禁字符串（硬约束 3）；周粒度掷点由周结外部调用驱动（Settlement #135）。
## 表内稳定字符串键真源=staff_state_weights/staff_state_modifier 三态键
## （focus/slacking/inspired），enum→字符串映射集中在 Staff 内（同源派生）。
enum StaffState {
	FOCUS,
	SLACKING,
	INSPIRED,
}

## 时间节拍仪式类型（#127：节拍日历行类型；与 time.json 节拍表键同源派生，
## enum 只在 L0/L2 内使用，数据表 JSON 内以稳定字符串承载）。
enum RitualType {
	## 季度 SOTA 大赏（季度末 13n 周）
	QUARTER_AWARD,
	## 年度实验室排名（年末 52n 周，年度大节拍位）
	ANNUAL_RANK,
	## 竞对发版（rivals 时间线共享节拍表；#144 联动，本批只落日历接口）
	RIVAL_RELEASE,
}
