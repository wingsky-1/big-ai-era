# Playtest Log - PR-B 试玩闭环端到端留档

- **日期**: 2026-09-07
- **测试环境**: Headless GUT 9.7.1 + Godot 4.7.2
- **测试用例**: tests/integration/test_playtest_loop_headless.gd
- **链路覆盖**:
  1. 新开一局 (start_new_game) 初始字段与资金校验通过 (¥50.0万, 40卡时)
  2. 员工指派 (assign_staff: r_lin -> slot_core)
  3. 4x 挂机推演与时钟流淌 (feed_frame, 速度倍率 4.0)
  4. 触发并消费决策卡 (choose_decision, z2 阻塞栈弹出)
  5. 跨周界周报双挂载弹出与确认 (PANEL_AUTO_REPORT, z2 阻塞栈)
  6. 资金耗尽越过破产线 short-circuit 触发 Game Over 并结算
- **验证结论**: 全链路确定性跑通，零写路径合规，门控与遮罩逻辑符合 DR-020。
