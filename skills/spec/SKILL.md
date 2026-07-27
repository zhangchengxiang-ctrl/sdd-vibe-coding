---
name: spec
description: >-
  Plan 专项 Skill：将已确认产品切片转成一份完整 Spec 执行合同、Scenario 与验收计划。
  一个 Spec 是一个完整 Build；仅在 vibe-coding 已路由到 Plan，或用户显式调用本 Skill 时使用。
---

# Spec：Plan 技术方案

只在 Plan 模式使用。先读宿主 `AGENTS.md`、已确认产品真源、`workflow-contract.md`、
`workspace-contract.md` 与 `evidence-contract.md`。新建 Spec 与跨阶段批准以
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 硬闸与阶段闸门为准。

## 核心工件

```text
docs/specs/<id>/
├── VERSION.md
├── context.md
├── requirements.md
├── technical-plan.md
├── scenario-spec.md
├── validation.md
├── spec-run.md
└── evidence/
```

`technical-plan.md` 定义整份 Spec 的执行顺序、写入边界、外部授权、风险与回滚；
`scenario-spec.md` 定义用户结果；`validation.md` 定义实现、集成和真实通道验收。

`spec-run.md` 是 Build 阶段的持久运行时状态。scaffold 已随模板复制它；Plan 只初始化其
“交付目标”静态部分（用户结果、In / Out Scope），运行时字段（实现冻结时间、单元测试批次、
Verify 批次、统一 Repair 方案）由 Build 首次提交时填写，**Plan 不得填充**。

## Plan 流程

Plan 是一次连续动作：**在同一阶段内一口气产出整份 Spec 的全部设计工件，中途不向用户交还
控制权**。按以下顺序连续完成，把结论直接写入对应文件：

1. 对照代码与宿主事实确认现状（写入 `context.md`）；
2. 建立 Requirement → Scenario 映射（`requirements.md` + `scenario-spec.md`）；
3. 形成最小但完整的技术方案与连续执行策略（`technical-plan.md`）；
4. 写清单向门、外部依赖、授权、回滚与真实 Blocker（`technical-plan.md`）；
5. 为整个 Spec 选择 Workspace、owner、外部 Claim 和集成重测（写入
   `technical-plan.md` 的 Workspace Strategy 槽位）；
6. 写验收计划（`validation.md` 骨架）、初始化 `spec-run.md` 的“交付目标”静态部分，并运行结构自检。

一次产出的设计工件是：`context.md`、`requirements.md`、`technical-plan.md`、`scenario-spec.md`、
`validation.md` 骨架，以及 `spec-run.md` 的静态头。**禁止“写一个文件就停下来问用户”**；只有遇到
产品互斥选择、不可逆授权或真实外部阻塞时才在阶段内暂停。内部并行只隔离 owner 和 Workspace，
不改变 Spec 是唯一交付单位的事实。

阶段边界语义（何时连续、何时暂停、跨阶段如何总结与批准）以
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 为唯一真源。Plan 阶段全部工件
产出后，按该合同向用户用一张卡汇总技术方案、执行边界、验收设计、风险和未决项，取得明确批准
后才在同一目标进入 Build；不得要求用户重新发起任务。
