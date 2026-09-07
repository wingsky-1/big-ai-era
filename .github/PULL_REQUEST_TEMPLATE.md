# 变更说明

<!-- 一句话概括本次变更做了什么、为什么做 -->
<!-- 关联 Issue：Closes #123 -->

## 变更类型

- [ ] 新特性（feat）
- [ ] Bug 修复（fix）
- [ ] 重构（refactor，不改行为）
- [ ] 文档（docs）
- [ ] 测试（test）
- [ ] 构建/CI（chore/ci）

## 自检清单（Agent 提交前必须逐项确认）

- [ ] `bash scripts/verify.sh` 本地全绿（lint + import + GUT）
- [ ] 新增/变更逻辑有对应单元测试覆盖
- [ ] 核心逻辑保持纯逻辑（RefCounted）与表现层（Node）分离
- [ ] 遵守 docs/standards/code-style.md（强类型、命名、定义顺序）
- [ ] 涉及数值/配置的改动已外置到 src/data/*.json，未硬编码
- [ ] 涉及架构决策时已补 ADR（docs/adr/）
- [ ] 涉及玩法机制变更时已同步 GDD（docs/gdd/）

## 试玩验收指引（供人类试玩用）

<!-- 描述合并后人类应如何验证本次变更：打开哪个入口、做什么操作、期待看到什么 -->
