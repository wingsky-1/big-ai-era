# 测试规范

> 框架：GUT 9.7.1（锁定 Godot 4.7.x 配对，见 ADR-0001 版本矩阵）。
> 运行方式：`bash scripts/verify.sh`（本地与 CI 同一命令）。

## 目录与命名

```text
tests/
├── unit/           # 纯逻辑单测（RefCounted，毫秒级，无场景）
├── integration/    # 场景冒烟/集成测试（可加载 .tscn）
└── fixtures/       # 测试夹具（坏 JSON 等边界样本）
```

- 测试文件 `test_<被测对象>.gd`；用例 `func test_<行为>() -> void`。
- 断言必须带中文语义消息（失败时直接可读）。

## 分层边界

| 层 | 测什么 | 不测什么 |
| :--- | :--- | :--- |
| unit | 数值计算、状态机、迁移链、数据加载 | 节点树、渲染、输入 |
| integration | 场景可实例化、`%UniqueName` 完整、管线联通 | 具体像素/布局 |

核心规则：**新系统先写可测的纯逻辑（RefCounted），测试随之而来**；
逻辑不可测 = 架构有问题，先回头改结构而不是硬测 Node。

## GUT 9.7 关键机制（实战踩坑沉淀）

1. **错误追踪（Error Tracker）**：任何未被消费的 `push_error`/引擎错误都会让测试失败。
   测试"错误分支"时必须显式断言预期错误：

   ```gdscript
   var result := DataLoader.load_json("不存在.json")
   assert_true(result.is_empty())
   assert_push_error("文件不存在", "应有明确错误提示")   # 消费业务 push_error
   # assert_engine_error("Parse JSON failed", "...")     # 消费引擎层报错
   # assert_push_error_count(0, "...")                   # 断言无错误
   ```

2. **信号参数断言**：`assert_signal_emitted_with_parameters` 对 float/自定义类型
   有比较陷阱，优先 `assert_signal_emitted` + `get_signal_parameters()` 手动校验。
3. **Headless 环境坑**：
   - Control 布局需推两帧 `await get_tree().process_frame` × 2；
   - 输入模拟（Input 单例）在 headless 下**不可用**，相关测试用 `should_skip_script()`；
   - 启动参数必须带 `--audio-driver Dummy`（verify.sh 已内置）；
   - 编辑器关闭时的 ObjectDB 泄漏提示仅为 WARNING，不影响退出码，无需处理。
4. **先导入再测试**：全新 checkout 必须 `--headless --import --quit` 注册资源
   后再跑测试（verify.sh 与 CI 均已内置此步骤）。

## DoD（测试完成的定义）

- [ ] `verify.sh` 全绿，且新逻辑 assert 覆盖正常路径 + 至少一个边界/错误分支
- [ ] 错误分支测试的预期错误已显式消费
- [ ] 测试消息可读：只看失败输出就能定位问题
