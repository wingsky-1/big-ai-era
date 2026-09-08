# 场景与资产规范

> 目标：让 .tscn 在 Git 中可读、可合并、不出现"幽灵资源"。

## 场景组织（.tscn）

- 场景文件放其脚本同目录：`src/ui/main/main.tscn` ↔ `main.gd`。
- 节点命名 PascalCase；需要被代码引用的节点**一律勾选 Scene Unique Name**（`%NodeName`）。
- 根节点类型选择：UI 用 `Control` 系；实体用 `CharacterBody2D/3D`；纯容器用 `Node`。
- 场景只做**结构组装**，复杂逻辑下沉到脚本/纯逻辑类；禁止在场景里堆 10 层以上的纯布局节点
  （用子场景拆分）。

## .tscn / .tres 的 Git 合并纪律

- 这两类文件**不用 merge=union**（可能静默合并出损坏资源），冲突时手动解决。
- 冲突解决流程：
  1. `git checkout --theirs/ours` 先取一边；
  2. 在 Godot 编辑器中手动重做另一边的改动（ID 类冲突无法文本合并）；
  3. 打开场景确认无红字 → `verify.sh` 全绿再提交。
- 预防胜于解决：**大 .tres 拆小**；同一资源不要两分支同时改；数值尽量走 JSON。

## 资产导入

- `.import` 元数据文件**必须提交**（多机/CI 一致性）；`.godot/` 目录**必须忽略**。
- 新增资产后本地跑一次 `--headless --import --quit`，连同生成的 `.uid` 一起提交。
- 图像/音频/模型按 `.gitattributes` 自动进 LFS；首次提交前 `git lfs install`。

## 资产存储策略（v0.1.2 裁决更新：字体/截图 git 直存）

- **字体与试玩截图走 git 直存，不进 LFS**：`.gitattributes` 末行对
  `assets/fonts/*.ttf` 与 `docs/playtest/screenshots/**` 显式豁免
  （`-filter -diff -merge -text`，后行规则覆盖前方 LFS 通配）。
  理由（ADR-0010 D3）：低频静态资产激活 LFS 会把环境依赖扩散到所有 CI/新环境，
  而 LFS 指针文件误入库 → Godot 无报错 → 运行时豆腐块（与 v0.1.1 事故同构）。
- **兜底门禁**：`verify.sh` 资产完整性检查（字体文件头含 `git-lfs` 即 fail）+
  `test_theme_font.gd` 文件头断言；新增直存二进制资产时照此加门禁。
- 其余二进制（未来音效/贴图）仍按上方通配走 LFS，启用前须完成
  `git lfs install` + 两个 workflow 的 `checkout lfs: true` 配套。

## 字体/本地化资产

- 中文字体必须**内嵌**（Web 端无宿主字体可回退），当前真源：
  `assets/fonts/WQY-MicroHei.ttf` + 许可证副本同目录。
- **字体接线纪律**（v0.1.1 豆腐块事故沉淀）：
  - 收口链 = `dark_gold_theme.tres → default_font`（主链，主壳与所有弹层根
    必须显式挂同一 Theme，`test_theme_font.gd` 逐场景断言）；
  - **禁用 `gui/theme/custom` 工程设置兜底**（冷导入序必炸，见
    gd-godot4-gotchas 条目 12 / ADR-0010 D1）；
  - 新增界面符号前查字形覆盖（`font.has_char()`），WQY 缺字形黑名单：`⏸ ⏳`；
  - UI/主题改动后用截图管线归档真实渲染证据（testing.md 渲染验证纪律）。
- 文本内容一律外置 `*.csv`（Godot 原生 i18n 格式）或 JSON，禁止散落在场景/代码中。

## 幽灵资源预防（UID 机制）

- Godot 4 资源靠 `uid://` 寻址；**移动/重命名文件用编辑器内操作**（自动更新引用），
  纯文件系统移动会断链。
- verify.sh 的导入步骤会暴露断链：`Failed to load script/resource` 即幽灵资源信号。
