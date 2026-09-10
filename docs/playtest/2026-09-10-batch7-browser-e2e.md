# 批7.3 浏览器实测取证记录（issue #190）

- 日期：2026-09-10 ｜ 执行：Agent（gd-lead-programmer 席 + agent-browser v0.37.1 CDP 真实鼠标）
- 构建：`bash scripts/export_html_check.sh build/web` 全过（三件套+信标就绪）
- 环境：本地 http://127.0.0.1:8971（python http.server）+ headless Chromium；WASM 冷启动 ~10s
- 驱动方式：信标（`?shot=main_path` 门控 `window.__DSH_PANEL_STATE__`）+ `agent-browser mouse move/down/up`
  （CDP 真实输入，经 Godot 输入管线驱动 GUI，非直调命令）；命名提交经 `window.__DSH_TEST__` 队列
  （等价键入，仍走 NamingDialogLogic→NameFilter→WorldCommands 全链）

## 主路径锚点（接单→点树→排训练→出分命名→W10 首对手）

| 截图 | 锚点 | 周 | 证据 |
|---|---|---|---|
| PT-123_W1.png | 新局主台就位 | W1 | 目标带"点开迷雾第一格·约再跑 2 周"；槽卡"用 LoRA 复现对齐·预计结账 W2"；员工四卡；¥200000 |
| PT-131_W5.png | 任务板选题列表 | W5 | 面板 5 选题（收下钮）+训练段+槽摘要；点击"收下"后首空槽入项目 |
| PT-140_W5.png | 排训练 | W5 | 点"迷你基座｜训练"→首槽"训练｜迷你基座·预计结账 W4"，页脚绿色"训练"回显，卡时 8→0 |
| PT-147_W5.png | 指派第 1 击 | W5 | 点林以川员工卡→指派面板（迷你基座 0/1 行） |
| PT-147B_W5.png | 指派第 2 击 | W5 | 点槽行→槽 1/1+林以川卡"在岗：迷你基座"+面板绿"收下" |
| PT-137_W5.png | 科技树雾态 | W5 | 对照表+五域组+？？？雾行+首节点绿灯"深思（对齐）" |
| PT-143_W9.png | 出分命名 z2 | W9 | 迷你基座 100%"完成·待结算"；z2 弹层"出分 score 40.0"+≤12 字提示；世界停流；首模型无"交给命运" |
| PT-153_W11.png | 首循环完成 | W11 | 目标卡带空态（六步全点亮，含 W10 迎战首对手步）+世界续流+现金轨迹正常 |

命名闭环数据（信标轮询）：W9 pending=true→z2 自开→提交"灵犀一号"→pending=false→z2 自收→世界恢复流动
→W11 目标卡带空态（step=-1=引导机六步全通过，其中第 6 步"迎战首个对手"需 deep_alley 时间线已消费）。

## 实测发现与修复（同批 PR 落地）

1. **开局卡时预算=0（L2 装配缺陷，阻塞主路径）**：`world_factory.assemble` 注入
   `weekly_supply_provider` 后未调 `reset_weekly_card_hours()`——W1 剩余恒 0，
   首训练被 CARD_HOURS_INSUFFICIENT 拒（所有既有消费方惯例均为注入后即 reset，
   门面装配漏一步）。已修（开局预算=W1 供给 8）。
2. **CJK 字体主题断链（#117 归档重build 后丢失，ADR-0010 决策①回退）**：活跃场景零
   theme 挂载，Web 导出全画面豆腐块（ADR-0010 主链 `dark_gold_theme.tres` 已随
   `_archive_legacy` 断链）。已修：新建 `src/ui/theme/main_theme.tres`
   （default_font=WQY-MicroHei）挂 main.tscn 根，浏览器截图实证全中文可读。
3. **任务板数据面缺失（#190 自身债）**：选题/基座列表需 WorldCommands 只读委托，
   首版遗漏。已补 `get_topic_options()/get_base_options()`（PaperPool/models.json
   表序透传，零业务计算）。
4. 观察（不修，登记）：z1 面板开着时 Dock 键被遮罩盖住（点外关闭语义 ui-ux A.2），
   面板间切换需先点外关再点 Dock=两击——符合 z1 轻遮罩语义，若试玩反馈繁琐再议
   Dock 直切。

## 红线声明

- [P] 锚点（无指导走通且想截图，PT-154 DoD 主脚本）**留真人勾选**，Agent 不代勾。
- 截图命名契约：`PT-<锚点>_<week>.png` 两段式（GUT `test_browser_run_log_format` 校验）。
