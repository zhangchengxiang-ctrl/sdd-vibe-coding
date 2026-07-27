# Plugin Architecture

本文件给维护者说明「哪里是唯一真源、改动应落在哪一层、如何避免双写」。

## 分层模型

```text
入口层
  README.md
  skills/vibe-coding/SKILL.md

合同层（跨仓唯一真源）
  skills/vibe-coding/references/workflow-contract.md
  skills/vibe-coding/references/evidence-contract.md
  skills/vibe-coding/references/workspace-contract.md

执行层（按 Rail）
  skills/design
  skills/spec
  skills/testing
  skills/debug

宿主脚手架层（可被 scaffold 复制）
  templates/AGENTS.md
  templates/docs/**

校验层（维护者工具）
  evals/tools/check_docs.py
  evals/verify.sh
  evals/fixtures/**
```

## 真源边界

- 流程、状态词、完成声明：只改 `workflow-contract.md`
- 验证层次、Deliver Gate、Fail 分类：只改 `evidence-contract.md`
- Workspace / Worktree / Claim：只改 `workspace-contract.md`
- 单个 Rail 的前台话术与执行约束：改对应 `skills/<rail>/SKILL.md`
- 宿主填写槽位与文档模板：改 `templates/docs/**` 与 `templates/AGENTS.md`
- 结构校验规则：改 `evals/tools/check_docs.py`

禁止在 `templates/docs` 复制合同正文；模板只保留最小落盘结构并链接合同真源。

## 常见改动路径

| 目标 | 首选修改点 | 联动检查 |
|---|---|---|
| 新增状态词或调整语义 | `workflow-contract.md` | `templates/docs/README.md`, `VERSION.md`, `check_docs.py` |
| 调整 Fail 分类 | `evidence-contract.md` | `templates/docs/specs/_template/validation.md` |
| 调整 Workspace 字段 | `workspace-contract.md` | `technical-plan.md`, `spec/SKILL.md`, `check_docs.py` |
| 调整 optional 文档策略 | `VERSION.md` + `optional/README.md` | 对应 optional 模板 |
| 调整产品回归策略 | `product-regression.md` | `regression-register.md`, `regression-map.md` |

## 防双写清单

提交前确认：

1. 一个概念只在一个合同文件定义；
2. 模板没有复制同一合同大段正文；
3. `make verify` 通过；
4. 文档中的状态词与 `workflow-contract.md` 一致。

