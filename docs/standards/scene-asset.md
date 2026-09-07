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

## 字体/本地化资产

- 字体文件（.ttf/.otf）进 LFS；UI 主题（.tres）拆分到 `src/ui/theme/`。
- 文本内容一律外置 `*.csv`（Godot 原生 i18n 格式）或 JSON，禁止散落在场景/代码中。

## 幽灵资源预防（UID 机制）

- Godot 4 资源靠 `uid://` 寻址；**移动/重命名文件用编辑器内操作**（自动更新引用），
  纯文件系统移动会断链。
- verify.sh 的导入步骤会暴露断链：`Failed to load script/resource` 即幽灵资源信号。
