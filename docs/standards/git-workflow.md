# Git 工作流规范

> 模型：Trunk-based Development（主干开发）——适合"1 人 + Agent"的最小摩擦模式。

## 分支模型

```text
main ──────●────●────●──→  永远可玩、可发布（CI 全绿）
            \  /  /
        feat/xxx   从 main 切出，PR 合回，存活 ≤ 3 天
```

- `main` 受保护：必须走 PR，CI（ci-validate.yml）全绿才能合并。
- 分支命名：`feat/<特性>`、`fix/<修复>`、`docs/<文档>`、`chore/<杂务>`、`balance/<调参>`。
- 禁止长期分支；大特性拆成多个小 PR（feature flag 或分层合并）。

## Conventional Commits（机器可解析）

```text
<type>(<scope>): <一句话描述>

feat(stats): 支持百分比修正叠加
fix(save): 拒绝加载 schema 过新的存档
docs(standards): 补充信号命名规则
test(state_machine): 覆盖自转换拒绝分支
chore(ci): 升级 Godot 到 4.7.2
balance(combat): 基础伤害 10 -> 12
```

type 取值：`feat` / `fix` / `docs` / `test` / `refactor` / `chore` / `ci` / `balance`。

## PR 规则

- 使用 `.github/PULL_REQUEST_TEMPLATE.md`，自检清单逐项勾选。
- 小 PR 优先：单 PR 聚焦单一变更，< 400 行 diff 为佳。
- Agent 提交的 PR 必须附"本地 verify.sh 全绿"证据（勾选自检第一项）。
- 合并方式：Squash merge（保持 main 历史线性、可 revert）。

## 发布流（release-build.yml）

1. 确认 main 全绿 → 打 tag：`git tag v0.1.0 && git push origin v0.1.0`。
2. CI 自动：三平台构建（Windows exe / Linux / Web）→ GitHub Release 附件 + Pages 部署。
3. 人类收到可试玩链接，试玩反馈走 Issue 模板回到迭代循环。

版本号 SemVer：`vMAJOR.MINOR.PATCH`（存档 schema 破坏性变更 = MAJOR）。

## Git LFS

- `.gitattributes` 已预置音频/图像/模型规则；**首次提交二进制资产前执行 `git lfs install`**。
- 纯文本资产（.tscn/.tres/.gd）永不进 LFS，保证 diff 可读。
- **禁止给 .tscn/.tres 配 merge=union**——union 合并可能静默产生损坏文件（详见 scene-asset.md）。
