class_name CoreEnums
## L0 全局枚举集中地（v1.0.0 重建骨架，占位）。
## 纪律：enum 是编译期符号，其值与数据表 JSON 内稳定字符串的映射只允许
## 单向（enum→字符串经集中映射函数），禁止散落字符串字面量比较。

enum ProjectType {
	PAPER,
	MODEL,
	COMPUTE,
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
