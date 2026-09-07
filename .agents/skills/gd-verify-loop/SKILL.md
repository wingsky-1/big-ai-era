---
name: gd-verify-loop
description: Agent 自验证闭环：改完代码后的完整自检流程（gdformat→gdlint→import→GUT→导出抽查）与"全绿才汇报"纪律。任何代码改动完成后必须执行。
whenToUse: 完成一段代码修改之后、汇报完成之前；CI 红了排查时。
---

# 自验证闭环（Verify Loop）

Agent 没有眼睛，`verify.sh` 就是你的眼睛。**没有跑过验证的代码等于没写**。

## 标准流程（每次代码改动后）

```bash
# 1. 一条龙验证（lint + 引擎导入校验 + GUT 测试）
bash scripts/verify.sh

# 2.（涉及导出配置/资源变更时）导出抽查
bash scripts/export_all.sh all build   # 或单平台: windows / linux / web
```

## 全绿标准

1. gdformat --check：无 "would reformat"
2. gdlint：`Success: no problems found`
3. 引擎导入：无 `ERROR`（WARNING/ObjectDB 泄漏提示可忽略，CI 已禁 leak check）
4. GUT：`All tests passed!`，且**新增逻辑有对应测试**（不是只跑旧测试）

## 红了怎么办（分层排查）

| 失败层 | 常见原因 | 解法 |
| :--- | :--- | :--- |
| gdformat | 手写格式冲突 | `gdformat src tests` 自动修 |
| gdlint | 定义顺序/命名 | 看 code-style.md §4（@onready 位置！） |
| 导入 ERROR | UID 断链/场景损坏/autoload 解析 | 读首个 SCRIPT ERROR 行，通常是 class_name 冲突 |
| GUT Failed | 断言失败 | 读语义消息；**Unexpected Errors** = 错误未消费，用 assert_push_error 消费 |
| GUT 脚本解析失败 | 测试文件自身语法错 | 脚本级 Parse Error，测试整个被跳过（注意 Scripts 数对不对） |

> 关键陷阱：GUT 显示 "All tests passed" 但 **Scripts 数量比预期少** =
> 某测试文件解析失败被静默跳过——回看 stderr 里的 SCRIPT ERROR。

## 汇报纪律

完成后汇报必须附证据：
- verify.sh 关键输出行（Tests 数 / Passing 数 / All tests passed）
- 若涉及数值/玩法：说明预期人类试玩会感知到什么变化

## 红线

- 禁止在测试失败时改断言"让它变绿"（除非确证测试本身错误，且需说明理由）
- 禁止跳过任何一层（lint 不是可选的）
