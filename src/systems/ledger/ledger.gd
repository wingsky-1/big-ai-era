class_name Ledger
extends RefCounted
## L1 唯一过账口（#135 原位填充 #123 占位）：收支行/类别枚举/周内累计/对账闭合。
## 契约（economy-spec D.3/ADR-0015/architecture §5.3 phase 4）：
## - **唯一过账口**：一切资源变更经本类记账（行只增不删=对账证据链）；
## - **周结闭合**：每周收入-支出=净（对账恒等断言）；账期翻页由 Settlement
##   phase 6 调 set_week；
## - 类别=enum（H6 stringly-typed 防线；禁字符串散落），存档序列化走
##   category_to_key 单向映射；
## - 行只增：周内累计在内存；历史行滚最旧由容量上限（防无限膨胀）。
## RefCounted 零 Node；headless 可单测。

signal transaction_recorded(row: Dictionary)

enum Category {
	INCOME_TASK,  # 任务/论文/课题收入
	INCOME_DEPLOY,  # 部署收入
	INCOME_JOB,  # 私活收入
	INCOME_LOAN,  # 贷款到账
	INCOME_OTHER,
	EXPENSE_SALARY,  # 工资
	EXPENSE_OPS,  # 运维
	EXPENSE_LOAN,  # 贷款还款
	EXPENSE_TRAINING,  # 培训
	EXPENSE_OTHER,
}

## 类别→稳定字符串（存档/数据面用；单向映射，禁反向散落）
const CATEGORY_TO_KEY: Dictionary = {
	Category.INCOME_TASK: "income_task",
	Category.INCOME_DEPLOY: "income_deploy",
	Category.INCOME_JOB: "income_job",
	Category.INCOME_LOAN: "income_loan",
	Category.INCOME_OTHER: "income_other",
	Category.EXPENSE_SALARY: "expense_salary",
	Category.EXPENSE_OPS: "expense_ops",
	Category.EXPENSE_LOAN: "expense_loan",
	Category.EXPENSE_TRAINING: "expense_training",
	Category.EXPENSE_OTHER: "expense_other",
}

## 历史保留上限（行只增防无限膨胀；当周行永不动——对账闭合不受滚行影响）
const HISTORY_CAP: int = 208

var _week: int = 1
var _rows: Array[Dictionary] = []
## 当周累计（income/expense 分离，phase 4 对账快照用）
var _week_income: int = 0
var _week_expense: int = 0


func _init(week: int = 1) -> void:
	_week = week


## 唯一过账口：记录一笔收支。amount>0=收入，<0=支出，0=拒绝。
## 返回行（含类别键）；账期不符（跨周）由 Settlement 调 set_week 先行。
func record(category: Category, amount: int, note: String = "") -> Dictionary:
	if amount == 0:
		push_error("Ledger.record: 金额不可为 0（零额过账=记账噪声）")
		return {}
	if not CATEGORY_TO_KEY.has(category):
		push_error("Ledger.record: 未知类别 %d" % category)
		return {}
	var row := {
		"week": _week,
		"category": category,
		"category_key": str(CATEGORY_TO_KEY.get(category, "")),
		"amount": amount,
		"note": note,
	}
	_rows.append(row)
	if amount > 0:
		_week_income += amount
	else:
		_week_expense += -amount
	_trim_history()
	transaction_recorded.emit(row.duplicate())
	return row.duplicate()


## 账期翻页（Settlement phase 6）：周累计清零，周号前进。
## 翻页前调用方须已做 phase 4 快照（本类不替调用方保存周净——对账由
## Settlement 层收口，本类只保证"累计口径正确"）。
func set_week(week: int) -> void:
	_week = week
	_week_income = 0
	_week_expense = 0


func get_week() -> int:
	return _week


## 当周净（收入-支出；对账恒等断言用）
func get_week_net() -> int:
	return _week_income - _week_expense


func get_week_income() -> int:
	return _week_income


func get_week_expense() -> int:
	return _week_expense


## 全部行（深拷贝；只增不删证据链）
func get_all_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _rows:
		result.append(row.duplicate())
	return result


func get_row_count() -> int:
	return _rows.size()


## 类别名（数据面/周报行展示用；键位=category_key 同源）
static func category_to_key(category: Category) -> String:
	return str(CATEGORY_TO_KEY.get(category, ""))


## ---------- 私有 ----------


## 滚最旧行（容量上限；当周行永不动）
func _trim_history() -> void:
	while _rows.size() > HISTORY_CAP:
		_rows.pop_front()
