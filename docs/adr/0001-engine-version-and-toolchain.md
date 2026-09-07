# 0001. 引擎版本与工具链选型（Godot 4.7.2 + GUT 9.7.1 + gdtoolkit 4.3）

日期：2026-09-07 / 状态：accepted

## 背景

脚手架需要锁定一套长期可维护的引擎与工具链组合。约束：
- AI 编码（Agent）需要 headless 可运行引擎做自验证；
- Web 导出必须零 Header 配置即可部署 GitHub Pages（人类试玩最低门槛）；
- 测试框架与引擎版本必须严格配对。

## 决策

| 组件 | 版本 | 配对理由 |
| :--- | :--- | :--- |
| Godot | **4.7.2-stable** | 当前 stable 支持线（4.7 于 2026.06 发布）；GL Compatibility 渲染（Web/移动端最稳） |
| GUT | **9.7.1** | 官方矩阵：9.7.x ↔ 4.7.x；带错误追踪（Error Tracker）API |
| gdtoolkit | 4.3.4 | gdformat/gdlint，CI 与本地统一格式化 |
| Web 导出 | Single-Threaded | `variant/thread_support=false`，绕开 SharedArrayBuffer/COOP-COEP 限制 |

引擎版本在以下位置统一声明（换版本只改这三处 + 重装插件）：
- `scripts/setup_env.sh`（GODOT_VERSION 环境变量默认值）
- `.github/workflows/*.yml`（env.GODOT_VERSION）
- `project.godot`（config/features）

## 备选方案

- **Godot 4.6 + GUT 9.6.1**：可行但非最新支持线，升级只是时间问题，直接选 4.7。
- **GDUnit4**：API 更现代（before/after 钩子等），但 GUT 错误追踪对"错误分支测试"
  场景更贴合本项目需求，且社区资料更多，Agent 出错率更低。
- **Web 多线程导出**：性能上限更高，但需要 COOP/COEP Header，GitHub Pages 不支持，
  会被 coi-serviceworker 兼容性问题（iOS Safari 等）反噬，放弃。

## 后果

- 正向：三端一致性（同一 gl_compatibility 渲染管线）；CI/本地命令同源；Web 即推即玩。
- 代价：Single-Threaded Web 的性能上限；引擎升级需维护版本配对表（见 testing.md）。
