class_name CoreEnums
## L0 全局枚举集中地（v1.0.0 重建骨架，占位）。
## 纪律：enum 是编译期符号，其值与数据表 JSON 内稳定字符串的映射只允许
## 单向（enum→字符串经集中映射函数），禁止散落字符串字面量比较。

enum ProjectType {
	PAPER,
	MODEL,
	COMPUTE,
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
