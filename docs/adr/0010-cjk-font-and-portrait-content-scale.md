# ADR-0010: CJK 字体内嵌与移动端内容基准切换

- 状态: Proposed
- 日期: 2026-09-07
- 关联: v0.1.1 Pages 试玩事故（中文豆腐块 + 竖屏排版破版）、issue #61 界面壳体系

## 背景与问题

v0.1.1 在线 Pages 试玩暴露两个渲染层缺陷：

1. **中文全部显示为豆腐块**。项目从未配置 `default_font`，Godot 内置默认字体不含
   CJK 字形；桌面端靠宿主系统字体回退侥幸可读，Web 端无宿主字体可回退，彻底裸奔。
2. **390×844 竖屏观感破版**。`canvas_items + expand` 拉伸策略下，逻辑宽恒等于
   内容基准宽 1280：手机物理宽 390 被映射为逻辑视口约 1280×2770，整体缩放
   ≈0.30，字号视觉上缩小到原来的三成，近一步加剧"豆腐块/看不清"的观感。
   此外 5 个弹层使用固定 offset 定尺寸（tech_tree 520px 宽），与窄视口无协同。

## 决策

### D1: 内嵌文泉驿微米黑，场景级 Theme 收口

- 资产: `assets/fonts/WQY-MicroHei.ttf`（自系统 wqy-microhei.ttc index 0 提取，
  4.6MB，许可全文随资产入库）。
- **许可选择依据**: WQY-MicroHei 为双许可（GPL with font exception / Apache 2.0），
  ttc index 0 为 Droid Sans Fallback 衍生的 Apache 分支——选 Apache 2.0 侧：
  与项目 MIT 主许可兼容且无 copyleft 传染，闭源分发亦无负担。
- 收口链: `dark_gold_theme.tres → default_font`（主链）。AppShell 根与 5 个弹层
  根均显式挂载该 Theme，覆盖全部游戏内控件。
- **`gui/theme/custom` 兜底层已移除**：CI 冷环境实证——首次 `--import` 时编辑器
  启动路径会先解析该设置，此刻字体尚未完成导入，主题解析必然报错（资源断链
  ERROR）。收益（仅覆盖"未来可能出现的原生 Window 弹窗"）不抵该确定性风险；
  若未来引入原生 Window 类弹窗，直接在其场景根挂同一 Theme 即可。
- 防回归: `verify.sh` 字体二进制门禁（防 LFS 指针入库）+ `test_theme_font.gd`
  （default_font 存在性 / 汉字与 UI 符号字形覆盖抽查 / 资产文件头 / 豁免规则）。
- **符号禁令**: WQY 无 U+23F8（⏸）/U+23F3（⏳）字形（截图实证豆腐），
  界面符号仅限 test_theme_font 抽查表白名单（✓✕●○‖ 等）。

**落选**: 思源黑体（单文件 >8MB，体积翻倍）、运行时动态加载（引入异步失败面）、
字体子集化（缺字即豆腐，与本次事故同构，收益不抵风险；列为后续体积优化选项）。

### D2: 竖屏内容基准切换（1280 → 480）

- 基准数学: `canvas_items+expand` 下缩放 = min(物理宽/基准宽, 物理高/基准高)。
  1280 基准时 390×844 → scale=390/1280≈0.30（字小如蚁）；480×854 基准时
  → scale=390/480≈0.81，逻辑视口 480×≈1039，字号恢复可读（截图实证）。
- `ResponsiveLayoutManager.resolve_content_scale()` 纯函数：物理视口 y>x 时
  返回 (480, 854)，否则 (1280, 720)；`main.gd` 在 `_ready` 与 RESIZED（deferred
  +幂等检查）时写入 `root.content_scale_size`。
- 弹层尺寸从"固定 offset"改为"中心锚 + custom_minimum_size + 视口 clamp"
  （`ModalSizing` 纯函数 + 脚本 `_ready` 应用 + `_on_viewport_resized` 统一刷新），
  窄视口收敛、宽视口保持 v0.1.1 观感，并设 `MIN_MODAL_SIZE` 下限防极小窗口塌缩。

**落选**: 保持 1280 基准（0.3 倍缩放不可接受）；换 `viewport` 拉伸模式
（控件类 UI 失去缩放一致性）；竖屏基准 360（对比 480 无进一步收益，缩放≈1 反而
让逻辑空间过窄，弹层可用宽度不足）。

### D3: 资产存储走 git 直存（豁免 LFS）

`.gitattributes` 末行追加 `assets/fonts/*.ttf` 与 `docs/playtest/screenshots/**`
的 `-filter -diff -merge -text` 豁免。理由：本仓库此前零 LFS 对象，为 1 字体 +
截图激活 LFS 会把环境依赖扩散到所有 CI/新环境（指针文件误入库会直接复现豆腐块，
Godot 无报错难以排查）。字体与截图属"一次入库永不改版"的低频静态资产。

### D4: 真实渲染截图留档机制

`scripts/capture_screens_web.mjs`（Node ≥22 原生 CDP 客户端，零第三方依赖）：
godot headless 导出 Web → 本地静态服务（正确 WASM MIME）→ headless Chrome CDP
→ 模拟 390×844@2x / 1280×720@1x → 轮询 `window.__DSH_SHOT_READY__` 精确就绪
（`main.gd` 仅 Web 且 `?shot=` 显式传参时激活的调试驱动）→ Page.captureScreenshot
→ 归档 `docs/playtest/screenshots/<date>-v<ver>/`。

**落选**: xvfb + 桌面导出（环境依赖重、且验证不了"Web 端打包后"的真实链路）；
纯延时等待（WASM 冷启动时间方差大，盲等既慢又脆）。

**调试驱动裁决**: `main.gd._setup_debug_shot_driver()`（约 30 行）仅 Web 平台且
显式 `?shot=<id>` 查询参数时激活：冻结时钟、丢弃挂起决策卡（防叠层污染证据）、
推目标弹层、置 `window.__DSH_SHOT_READY__` 就绪标志。正常游玩（无 query）零影响、
无写路径、无攻击面。**移除条件**: 若未来引入正式的 e2e/试玩自动化框架并覆盖
同等能力，应移除该驱动改走正式设施（跟踪于后续测试策略 ADR）。

## 后果

- 正面：Web/桌面/竖屏三形态中文渲染确定性解决；渲染回归有了像素级证据链。
- 代价：仓库 +4.6MB（字体）+ 截图增量；Web 包 +4.6MB（首载增加，可接受，
  未来如需优化再做子集化 ADR）；`main.gd` 增加约 30 行调试驱动（仅 Web 显式
  参数激活）。
- 中性：竖屏逻辑宽 480 下 UI 密度与桌面不同，后续新界面需同时适配两种基准
  （复用 `ModalSizing`/`ResponsiveLayoutManager` 即可）。
