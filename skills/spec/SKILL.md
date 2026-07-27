---
name: spec
description: >-
  Plan 专项 Skill：将已确认产品切片转成一份完整 Spec 执行合同、Scenario 与验收计划。
  先做入口事实映射；按纵向切片拆分；Unverified 不得进 Lock/P0。仅在 vibe-coding
  已路由到 Plan，或用户显式调用本 Skill 时使用。
---

# Spec：Plan 技术方案

只在 Plan 模式使用。先读宿主 `AGENTS.md`、已确认产品真源、`workflow-contract.md`（含
**证据分级**与 **Harness 适配**）、`workspace-contract.md` 与 `evidence-contract.md`。
新建 Spec 与跨阶段批准以 [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)
硬闸与阶段闸门为准。

## 核心工件

```text
docs/specs/<id>/
├── VERSION.md
├── context.md          # 含入口事实映射表
├── requirements.md
├── technical-plan.md   # 含纵向切片清单
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

## 事实映射门（Plan 硬前置）

在写 Requirement / technical-plan 硬合同之前，必须在 `context.md` 填完**入口事实映射**：

| 入口 | actor | 业务实体 / 表关系（含 FK） | 可信路径如何派生 | 代码调用点 | 越权反例 | 证据级 |
|---|---|---|---|---|---|---|
| … | … | … | … | … | … | Verified / Unverified |

规则：

1. **表关系与调用点未填完 → 不开始**设计抽象（ManagedRoot、通用 registry、默认 DDL 等）。
2. 仅 `Verified` 可进入 P0 Requirement、Requirements Lock、实施阻断、DDL 条件。
3. `Unverified` 只能列在「待验证」；先调查升级为 Verified，或明确降级为非阻断假设。
4. 「字段存了绝对路径」**不等于**「没有稳定真源」；必须先验证能否用业务 ID / owner 关系重解析。
5. 宣称「可以实施」须对每个 In-scope 入口具备：输入 → 实体解析 → 授权 → canonical path → 操作 → 越权拒绝的证据链（或明确标 Unverified 且不进硬闸）。

## 纵向切片铁律

默认拆分单位是**纵向切片**，不是横向基础设施层：

```text
真实入口 → 按关系解析实体与 owner → 可信路径 → 执行操作 → 验证成功与越权失败
```

| ❌ 禁止作为独立任务轴 | ✅ 正确 |
|---|---|
| root / resolver / provisioning / ACL / package / readiness 横向模块 | 按入口：如 Web 文件、Detached Job、Feishu、worktree、扩展包 |
| 先造平台概念再填入口 | 多切片重复同一逻辑后，再抽取共享 helper |
| 用编号/矩阵制造虚假精确 | 每个切片有可运行的行为 Oracle |

数据库迁移仅在某个切片 **Verified** 证明现有关联无法唯一解析时才出现。

Codex 上每个纵向切片同时是普通回合的默认完成单元（见 workflow-contract Harness）。

## Plan 流程

Plan 是一次连续动作：**在同一阶段内一口气产出整份 Spec 的全部设计工件，中途不向用户交还
控制权**。按以下顺序连续完成，把结论直接写入对应文件：

1. **入口事实映射**（写入 `context.md`；未完成不得进入步骤 2 的硬合同）；
2. 对照代码与宿主事实确认现状（补全 `context.md`）；
3. 建立 Requirement → Scenario 映射（`requirements.md` + `scenario-spec.md`）；每条 P0 标注证据级；
4. 按纵向切片形成最小技术方案与执行顺序（`technical-plan.md`）；
5. 写清单向门、外部依赖、授权、回滚与**仅 Verified** 的真实 Blocker（`technical-plan.md`）；
6. 为整个 Spec 选择 Workspace、owner、外部 Claim 和集成重测（Workspace Strategy 槽位）；
7. 写验收计划（`validation.md`：行为 Oracle 优先于文档对齐）、初始化 `spec-run.md` 静态头，并结构自检。

一次产出的设计工件是：`context.md`、`requirements.md`、`technical-plan.md`、`scenario-spec.md`、
`validation.md` 骨架，以及 `spec-run.md` 的静态头。**禁止“写一个文件就停下来问用户”**；只有遇到
产品互斥选择、不可逆授权或真实外部阻塞时才在阶段内暂停。内部并行只隔离 owner 和 Workspace，
不改变 Spec 是唯一交付单位的事实。

**禁止**：同一会话在无独立事实复核的情况下，仅凭文档自洽宣布「完整合理 / 可以实施」。

阶段边界语义以 [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 为唯一真源。
Plan 阶段全部工件产出后，按该合同向用户用一张卡汇总技术方案、纵向切片、执行边界、验收设计、
风险和未决项（区分 Verified / Unverified），取得明确批准后才进入 Build；不得要求用户重新发起任务。
