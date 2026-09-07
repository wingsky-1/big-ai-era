# Issue #61 PR-A / PR-B 测试计划草案（由 gd-test-engineer 主持产出）

> 依据：`.agents/skills/gd-test-engineer/SKILL.md` 契约规范。
> 状态：约定草案（正式门禁阈值落 `docs/standards/testing.md` 须双签确认）。

---

## 一、PR-A 主题与壳测试计划

### 1. 测试目标与覆盖范围
- **视觉 Theme 收口**：深色金 Theme 资源（panel, panel2, line, ink, ink2, ink3, accent 等 token）全量定义，拆分为子 `.tres`（colors.tres, stylebox_panel.tres, stylebox_btn.tres 等），防止 `.tres` 冲突。
- **对比度与触控面硬防护**：
  - `ink3` 灰在 panel 背景上的对比度必须 ≥4.5:1（修正旧稿 #5d6b80 约 2.97:1 硬伤，新值选取符合 WCAG AA 要求的深灰蓝浅色阶）；
  - 速度按钮（⏸, 1x, 2x, 4x）等交互触控最小尺寸 ≥48px。
- **防散落静态门禁（Grep 门禁）**：
  - 扫描 `src/ui/**/*.gd`，禁止出现 `#RRGGBB` 十六进制字符串字面量或裸 `Color("...")` 字面量构造；
  - 色值/圆角/边距必须收口在 `.tres` 或继承自 Theme。
- **AppShell 场景与自检重写**：
  - 重写 `tests/integration/test_main_scene_smoke.gd`：断言 `main.tscn` 实例化成功，具备 AppShell 根节点；
  - 断言必需的 UniqueName 节点存在：`%ResourceBar`, `%WeekBar`, `%RivalTrack`, `%Workspace`, `%Dock` 等；
  - 迁移旧版 `test_main_scene_smoke.gd` 中的自检断言（texts 加载等）进 GUT，确保旧资产不丢；
  - 监听 `ResponsiveLayoutManager` 的折叠信号切 visible，验证竖屏折叠规则生效。

### 2. 门禁与用例设计（GUT + 脚本）
- `tests/integration/test_main_scene_smoke.gd`:
  - `test_app_shell_instantiation_and_unique_names()`: 实例化 `main.tscn`，推 2 帧，断言各 UniqueName 节点有效；
  - `test_theme_tokens_and_contrast_bounds()`: 检查全局 Theme 变量，断言 ink3 与 panel 背景对比度 ≥ 4.5:1；断言速度按钮 custom_minimum_size ≥ Vector2(48, 48)；
  - `test_ui_script_zero_color_literals()`: 自动化扫描 `src/ui/` 下所有 `.gd` 文件，断言无 `#` 颜色字面量与裸 `Color(...)` 写法；
  - `test_responsive_layout_folding_visibility()`: 触发竖屏宽度切换，断言副行折叠。

---

## 二、PR-B 试玩闭环测试计划

### 1. 测试目标与覆盖范围
- **弹层接入与栈深互斥**：
  - 周报双挂载（自动弹 z2 停喂 tick / Dock 重看 z1 不暂停）；
  - 决策卡（z2 阻塞，GameClock.paused 置 blocked_by_card，确定性入档）；
  - Game Over 结算（z2 阻塞，短路后续 tick，展示破产与三项 summary）；
- **DR-020 回归防护与同帧信号序**：
  - z2 遮罩点击不关闭（必须通过按钮或确定交互关闭）；
  - 同帧到达多个信号时，决策卡严格先于周报弹起；
- **引用安全与零写路径**：
  - `GameLoopDriver` 对 L2 `GameWorld` 保持 `weakref`，失效安全降级且不崩溃；
  - UI 零写路径：静态门禁扫描 `src/ui/`，断言没有任何直接修改 `GameWorld` 内部状态或 `SaveSystem` 磁盘写操作的代码，一律经由 `GameWorld` 11 项契约命令。
- **Headless 全链路确定性仿真（固定 seed）**：
  - 编写集成测试，从新游戏启动 → 指派员工 → 4x 加速流淌 → 触发决策卡并做出选择 → 跨过周界弹出周报 → 经历经济消耗触发破产 Game Over；
  - 验证全流程无异常、无未消费 push_error。

### 2. 门禁与用例设计
- `tests/integration/test_playtest_loop_headless.gd`:
  - `test_headless_full_loop_deterministic()`: 固定 seed（如 42），跑完整生命周期；
  - `test_panel_stack_z2_mask_click_no_op()`: 遮罩点击事件模拟，断言栈顶未被 pop；
  - `test_same_frame_decision_card_before_weekly_report()`: 同帧发射两信号，验证弹窗层级与激活顺序；
  - `test_ui_zero_write_paths_grep()`: 门禁断言，确保 UI 只有只读监听与契约命令调用。
