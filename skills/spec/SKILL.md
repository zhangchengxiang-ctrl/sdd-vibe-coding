---
name: spec
description: >-
  Codex 的 Plan 专项 Skill：把已确认的产品切片转成技术计划、Scenario、Task Graph
  和单 Task Work Order，并为每个 Task 决定 Local/Worktree/PR 策略。仅在
  vibe-coding 已路由到 Plan，或用户显式调用本 Skill 时使用；不隐式接管实施请求，不写业务代码。
---

# Spec：Plan 技术拆解

本 Skill 只负责已确认的 Plan Rail。先读：

- 宿主 `AGENTS.md`；
- 已确认的产品真源；
- [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)；
- [`task-contract.md`](../vibe-coding/references/task-contract.md)；
- [`workspace-contract.md`](../vibe-coding/references/workspace-contract.md)；
- Worktree 被选中时读取
  [`codex-worktree-execution.md`](../vibe-coding/references/codex-worktree-execution.md)；
- [`evidence-contract.md`](../vibe-coding/references/evidence-contract.md)。

## 进入条件

至少要知道目标用户、可观察结果、当前切片 In / Out 和关键产品不变量。缺失会改变结果的
信息时回到 Shape；普通可逆技术细节由 Plan 自主决定。

非 trivial 使用 `docs/specs/<id>/`。trivial / small fix 可以直接形成轻量 Work Order，
但仍要写目标、边界和验收。

## 核心工件

```text
docs/specs/<id>/
├── VERSION.md
├── context.md
├── requirements.md
├── technical-plan.md
├── scenario-spec.md
├── tasks.md
├── tasks/
│   ├── T-001.md
│   └── T-002.md
├── routes/
│   ├── T-001.next-rail.md
│   └── T-002.next-rail.md
├── validation.md
└── evidence/
```

- `technical-plan.md`：现状、方案、影响面、单向门、迁移/回滚和关键决策；
- `scenario-spec.md`：用户结果与可执行 Oracle；
- `tasks.md`：Task Graph、索引和依赖；
- `tasks/T-xxx.md`：唯一执行合同；
- `routes/T-xxx.next-rail.md`：下一对话的单 Task 路由；
- `validation.md`：版本级验收与真实证据。

按风险添加 `clarify.md`、`migration-design.md`、`threat-model.md`、`test-plan.md` 等，不为
形式完整创建空文档。

## Plan 流程

1. 对照代码和宿主事实确认现状，不从产品蓝图猜实现；
2. 建立 Requirement → Scenario 映射；
3. 选择最小但完整的技术方案，列出备选和取舍；
4. 标记宿主单向门、外部依赖、环境和回滚边界；
5. 以可独立判断的垂直结果拆 Task，不默认按 DB/API/UI 横切；
6. 为每个 Task 填完整 Work Order；
7. 分析 Task 依赖、文件写入重叠和共享资源；
8. 为每个 Task 明确 Workspace Strategy、Claim 与 Delivery；
9. 为每个 ready Task 创建独立 Route，并登记 handoff；
10. 写版本级验证计划和集成重测点；
11. 运行结构/一致性自检，输出 `code-ready`。

Major、单向门或破坏性方案在 Work Order ready 前需要用户批准技术计划。

## Task 拆分标准

每个 Task 都必须：

- 一句话说明用户或系统结果；
- In / Out 明确；
- 有稳定写入边界和不变量；
- 能独立取得最低证据；
- 依赖和共享资源已列明；
- 有明确失败路由；
- 大到有价值，小到单个对话可完成。

若两个“任务”必须一起才能观察结果，应合成一个 Task 的内部步骤。若两个 Task 可独立
实现、验证和合并，才考虑并行 Worktree / PR。

## Workspace 决策

- 默认先比较 Local 与 Worktree 的隔离收益和环境成本；
- 当前工作区有无关 WIP、独立 PR、Hotfix、长时并行任务时倾向 Worktree；
- 同文件、迁移、公共 API、账号/数据库/端口竞争时禁止并行；
- commit、push、PR、merge 和 deploy 的授权分别记录，不相互推出。

## 内部模式

- `generate`：从已确认产品切片创建 Plan；
- `clarify`：只清除阻断实施的歧义；
- `converge`：只读对照 Spec 与代码，提出缺口；
- `analyze`：检查 Requirement / Scenario / Task / Validation 覆盖；
- `checklist`：按决策充分性、范围诚实度、下游可执行性和验证性审查。

这些模式都不得写业务代码。

## Plan 交付

向用户只展示技术方案摘要、关键代价、需要批准的单向门、Task 顺序/并行关系和第一张
Work Order。把 handoff 指向首个 ready Task 的 `routes/T-xxx.next-rail.md`，下一对话进入
`build`；并行 Task 分别使用自己的 Route。
