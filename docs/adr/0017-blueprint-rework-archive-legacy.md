# 0017. 蓝图重构执行：src/ 归档重写为 _archive_legacy/（目录级豁免）

日期：2026-09-09 / 状态：accepted

## 背景

v1.0.0 以 `docs/blueprints/specs/`（13 规格 + decisions-100 + architecture-100 + release-plan-100）为唯一真源实施重构。旧 src/（44 脚本 / 17 数据表，v0.1.x 键名）作为工程底料保留，但**不能留在原路径**：新实现按 architecture-100 §2.1 以相同 src/ 顶层目录（core/systems/entities/ui/data）重建，若旧文件原位共存，会出现：

- preload/class_name 串档：新旧同路径同名类互相遮蔽（H13）；
- lint/GUT 扫到旧代码产生海量假红（旧代码不符新版分层/禁词纪律）；
- 评审 diff 混杂新旧两代实现，无法逐批验收。

## 决策

1. **归档姿势 = `git mv` 入 `src/_archive_legacy/`**（保 rename 历史 + `.uid` 引用链不散），
   新实现随后在 src/ 顶层**原位重建**（各层目录按 architecture-100 §2.1）。
2. **目录级豁免**：`src/_archive_legacy/.gdignore` + `tests/_archive_legacy/.gdignore`
   使 Godot 资源系统忽略归档目录；verify.sh（gdformat/gdlint/GUT 扫描范围）
   显式跳过 `_archive_legacy`（见 verify.sh 改动），旧测试一并归档避免旧断言引用旧类名假红。
3. **旧数据表不复用**：`economy/staff/rivals/texts…json` 键名按新规格重建，
   **新键名重建，非旧表迁移**（decisions-100 §〇）；旧表只作内容底料人工参考。
4. **重建顺序**（D8 规避 rename 误判）：先整目录 `git mv`（一次性 rename 块），
   再逐层铺新文件——Git 对"目录整体移动"判定为 rename，对新文件判定为新增，
   diff 可读不混淆；禁止"原位覆盖同名文件"写法（会被误判为 rename 导致评审不可读）。

## 备选方案

- **原位保留 + 逐文件 @warning_ignore**：需给 44 旧脚本逐个加豁免注释，且无法防止
  preload/class_name 串档，门禁不干净，放弃。
- **删除旧 src/（不进库）**：丢失工程底料与 git 历史参考价值，违反 decisions-100
  "保留作参考"裁明，放弃。
- **归档到仓库外目录**：破坏 .uid/资源相对引用，且贡献者 clone 即缺底料，放弃。

## 后果

- 正向：门禁只对新树生效（干净基线）；旧实现可随时 `git show`/目录查阅作为底料；
  git 历史完整（rename 保留）；CI/本地零配置差异。
- 代价：`_archive_legacy/` 常驻仓库体积（可接受，纯文本为主）；后续新实现若需参考
  旧键名必须显式打开归档目录（纪律成本）。
- 配套：ADR-0018/0019/0020/0026 首批 ADR 随 v1.0.0 实施落地（#129）。
