---
name: spec
description: >-
  Plan 专项 Skill：将已确认产品切片转成一份完整 Spec 执行合同、测试用例与实施方案。
  先做入口事实映射；写完 tests.md（Given/When/Then）才算 Plan 可实施；按纵向切片拆分；
  Unverified 不得进 Lock/P0。仅在 vibe-coding 已路由到 Plan，或用户显式调用本 Skill 时使用。
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
├── contract.md   # 目标、事实映射、Requirements、In/Out
├── tests.md      # TDD 测试合同：索引 + Given/When/Then
├── plan.md       # 方案差量、纵向切片、单向门、Workspace
└── run.md        # 运行态（Plan 只初始化静态头）
```

`contract.md` 定义做什么；`tests.md` 定义如何判定做对（完整可执行用例）；
`plan.md` 定义怎么做与隔离边界；`run.md` 是 Build/Verify/Repair 的唯一运行态。

`run.md` 由 scaffold 随模板复制。Plan 只初始化其状态头（若需要）；批次结果、追踪矩阵、
Fail/Repair、关版结论由 Build/Verify 填写，**Plan 不得填充结果**。

## 事实映射门（Plan 硬前置）

在写 Requirement / plan 硬合同之前，必须在 `contract.md` 填完**入口事实映射**：

| 入口 | actor | 业务实体 / 表关系（含 FK） | 可信路径如何派生 | 代码调用点 | 越权反例 | 证据级 |
|---|---|---|---|---|---|---|
| … | … | … | … | … | … | Verified / Unverified |

规则：

1. **表关系与调用点未填完 → 不开始**设计抽象（ManagedRoot、通用 registry、默认 DDL 等）。
2. 仅 `Verified` 可进入 P0 Requirement、Requirements Lock、实施阻断、DDL 条件。
3. `Unverified` 只能列在「待验证」；先调查升级为 Verified，或明确降级为非阻断假设。
4. 「字段存了绝对路径」**不等于**「没有稳定真源」；必须先验证能否用业务 ID / owner 关系重解析。
5. 宣称「可以实施」须对每个 In-scope 入口具备：输入 → 实体解析 → 授权 → canonical path → 操作 → 越权拒绝的证据链（或明确标 Unverified 且不进硬闸）。

## 测试合同门（TDD · Plan 硬闸）

在宣称 Plan 可实施 / 请求进入 Build 之前，`tests.md` 必须满足：

1. 每个 P0 Requirement 至少映射 **1 条 success + 1 条 failure/permission**（`T-xxx`）；
2. 每条用例含完整 **Given / When / Then（Oracle）**；Then 必须是可观察断言，禁止「功能正常」；
3. 层（V0–V3）与 Channel 已声明；自动化路径或 `manual-only` + 原因已写明；
4. 未完成上述条款 → **不得**进入 Build。

预期写在 `tests.md`；结果只写 `run.md`。禁止把 Oracle 改成实际观察。

## 纵向切片铁律

默认拆分单位是**纵向切片**，不是横向基础设施层：

```text
真实入口 → 按关系解析实体与 owner → 可信路径 → 执行操作 → 验证成功与越权失败
```

| ❌ 禁止作为独立任务轴 | ✅ 正确 |
|---|---|
| root / resolver / provisioning / ACL / package / readiness 横向模块 | 按入口：如 Web 文件、Detached Job、Feishu、worktree、扩展包 |
| 先造平台概念再填入口 | 多切片重复同一逻辑后，再抽取共享 helper |
| 用编号/矩阵制造虚假精确 | 每个切片链到可运行的 `T-xxx` Oracle |

数据库迁移仅在某个切片 **Verified** 证明现有关联无法唯一解析时才出现。

Codex 上每个纵向切片同时是普通回合的默认完成单元（见 workflow-contract Harness）。

## Plan 流程

Plan 是一次连续动作：**在同一阶段内一口气产出整份 Spec 的全部设计工件，中途不向用户交还
控制权**。按以下顺序连续完成，把结论直接写入对应文件：

1. **入口事实映射**（写入 `contract.md`；未完成不得进入步骤 2 的硬合同）；
2. 对照代码与宿主事实确认现状（补全 `contract.md`）；
3. 建立 Requirement → Test 映射（`contract.md` Requirements + `tests.md` 完整用例）；每条 P0
   标注证据级，并满足测试合同门；
4. 按纵向切片形成最小技术方案与执行顺序（`plan.md`；切片完成定义链 `T-xxx`）；
5. 写清单向门、外部依赖、授权、回滚与**仅 Verified** 的真实 Blocker（`plan.md`）；
6. 为整个 Spec 选择 Workspace、owner、外部 Claim 和集成重测（Workspace Strategy 槽位）；
7. 初始化 `run.md` 状态头，并结构自检。

一次产出的设计工件是：`contract.md`、`tests.md`、`plan.md`，以及 `run.md` 的静态头。
**禁止“写一个文件就停下来问用户”**；只有遇到产品互斥选择、不可逆授权或真实外部阻塞时才在
阶段内暂停。内部并行只隔离 owner 和 Workspace，不改变 Spec 是唯一交付单位的事实。

**禁止**：同一会话在无独立事实复核的情况下，仅凭文档自洽宣布「完整合理 / 可以实施」。
**禁止**：`tests.md` 只有索引表、没有 Given/When/Then 正文时宣称可实施。

阶段边界语义以 [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 为唯一真源。
Plan 阶段全部工件产出后，按该合同向用户用一张卡汇总技术方案、纵向切片、测试合同、执行边界、
风险和未决项（区分 Verified / Unverified），取得明确批准后才进入 Build；不得要求用户重新发起任务。
