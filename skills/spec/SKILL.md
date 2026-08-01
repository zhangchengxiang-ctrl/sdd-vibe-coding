---
name: spec
description: >-
  Plan 专项 Skill：将已确认产品切片转成一份完整 Spec 执行合同、测试用例与实施方案。
  用户说「切 Spec / Plan / 拆到能编码」即授权落盘；先做入口事实映射，纵向切片，写完
  tests.md（Given/When/Then）才可请求 Build。仅 Verified 进 Lock/P0。质量条默认执行。
  仅在 vibe-coding 已路由到 Plan，或用户显式调用本 Skill 时使用。
---

# Spec：Plan 技术方案

只在 Plan 模式使用。先读宿主 `AGENTS.md`、已确认产品真源、`workflow-contract.md`（含
**薄提示词原则**、**证据分级**、**Harness 适配**、**Plan 落盘授权**）、`workspace-contract.md`
与 `evidence-contract.md`，以及
[`design-standards/system-architecture.md`](../vibe-coding/references/design-standards/system-architecture.md)
（有 UI 时先读 [`LOAD-MAP.md`](../vibe-coding/references/design-standards/LOAD-MAP.md)；
合同字段强度只认该表；改存量注明 `change: refinement|redesign`）。
新建 Spec 与跨阶段批准以
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 硬闸与阶段闸门为准。

## 默认质量条

进入 Plan 后自动执行：

1. 先查真实代码 / Schema / 配置，再写 Requirement；
2. 按真实入口**纵向**切片；
3. 仅 `Verified` 进 P0 / Lock / 实施阻断；
4. `tests.md` 每个 P0 至少 1 success + 1 failure/permission，完整 Given/When/Then；
5. 本阶段只落盘 Spec（不改业务代码）；
6. 用户已说切 Spec/Plan → **直接写入** `docs/specs/<id>/`；
7. 齐套后只出一张卡：能否批准进入 Build + Unverified 清单 + **必给「新对话 Build 提示词」**
   （见 workflow-contract「Plan → Build 默认开新对话」；禁止只劝同聊回复）；
8. **骨架**：落盘 `VERSION` / `contract` / `tests` / `plan` / `run`；
9. **架构与设计边界轻门**：触及新入口 / 跨层 / 新存储 / 新权限模型 / 新部署单元时，
   `plan.md` 按 `system-architecture.md` §7 写明沿用或新开边界、C4 层级、ADR、Unverified；
   有 UI 时按 LOAD-MAP 字段门控补 Job Brief / `UI surface` / Design Read / `page_kind|motif` / `anchor` 等。齐套后再请求 Build。
10. **机检**：宣称 Plan 可实施或派 Build 前，运行
    `python3 <plugin>/skills/spec/scripts/check_spec.py <host> <spec-id>`
   （见 [`scripts/check_spec.py`](./scripts/check_spec.py)）。通过后再进 Build / 派 Codex。

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
Fail/Repair、关版结论由 Build/Verify 填写。

## 事实映射门（Plan 硬前置）

在写 Requirement / plan 硬合同之前，在 `contract.md` 填完**入口事实映射**：

| 入口 | actor | 业务实体 / 表关系（含 FK） | 可信路径如何派生 | 代码调用点 | 越权反例 | 证据级 |
|---|---|---|---|---|---|---|
| … | … | … | … | … | … | Verified / Unverified |

规则：

1. 表关系与调用点填完后再设计抽象；
2. 仅 `Verified` 进入 P0 Requirement、Requirements Lock、实施阻断、DDL 条件；
3. `Unverified` 列在「待验证」；调查升级为 Verified，或明确降级为非阻断假设；
4. 「字段存了绝对路径」时，先验证能否用业务 ID / owner 关系重解析；
5. 宣称「可以实施」时，每个 In-scope 入口具备：输入 → 实体解析 → 授权 → canonical path → 操作 → 越权拒绝的证据链（或明确标 Unverified 且不进硬闸）。

## 测试合同门（TDD · Plan 硬闸）

在宣称 Plan 可实施 / 请求进入 Build 之前，`tests.md` 满足：

1. 每个 P0 Requirement 至少映射 **1 条 success + 1 条 failure/permission**（`T-xxx`）；
2. 每条用例含完整 **Given / When / Then（Oracle）**；Then 为可观察断言；
3. **Oracle 强度**：禁止弱 Then 独撑（见 [oracle-strength.md](./references/oracle-strength.md)）；
4. **数据面**（list/dashboard 或分页/排序/筛选）：Then 须含可两态证伪的断言（同文件）；
5. 层（V0–V3）与 Channel 已声明；自动化路径或 `manual-only` + 原因已写明；预期 Evidence Kind 建议写清；
6. 上述齐套后再进入 Build。

预期写在 `tests.md`；结果只写 `run.md`。Oracle 保持不变。
Verify 执行证伪见 testing [`falsify-checklist.md`](../testing/references/falsify-checklist.md)。

## 纵向切片

默认拆分单位是**纵向切片**：

```text
真实入口 → 按关系解析实体与 owner → 可信路径 → 执行操作 → 验证成功与越权失败
```

| 正确切片轴 | 例 |
|---|---|
| 按真实用户入口 | Web 文件、Detached Job、Feishu、worktree、扩展包 |
| 先落地入口，重复后再抽 helper | 多切片重复同一逻辑后，再抽取共享 helper |
| 完成定义链到可运行 Oracle | 每个切片链到 `T-xxx` |

数据库迁移仅在某个切片 **Verified** 证明现有关联无法唯一解析时才出现。

Codex 上每个纵向切片同时是普通回合的默认完成单元（见 workflow-contract Harness）。

## Plan 流程

Plan 是一次连续动作：在同一阶段内一口气产出整份 Spec 的全部设计工件。按以下顺序连续完成，把结论直接写入对应文件：

1. **入口事实映射**（写入 `contract.md`；齐后再写硬合同）；
2. 对照代码与宿主事实确认现状（补全 `contract.md`）；
3. 建立 Requirement → Test 映射（`contract.md` Requirements + `tests.md` 完整用例）；每条 P0
   标注证据级，并满足测试合同门；
4. 按纵向切片形成最小技术方案与执行顺序（`plan.md`；切片完成定义链 `T-xxx`）；
5. 填写「架构与设计边界」（`plan.md`；对照 design-standards 与 AGENTS / `docs/architecture/`）；
6. 写清单向门、外部依赖、授权、回滚与**仅 Verified** 的真实 Blocker（`plan.md`）；
7. 为整个 Spec 选择 Workspace、owner、外部 Claim 和集成重测（Workspace Strategy 槽位）；
8. 初始化 `run.md` 状态头，并结构自检。

一次产出：`VERSION.md`、`contract.md`、`tests.md`、`plan.md`，以及 `run.md` 的静态头
（按需 `optional/`）。调查结论边查边写进文件。

阶段内暂停仅限：产品互斥选择、不可逆授权、真实外部阻塞。

可实施条件：有独立事实复核；`tests.md` 含 Given/When/Then 正文；质量条与 `check_spec` 已过。

## 机检（check_spec）

```bash
python3 skills/spec/scripts/check_spec.py <host> <spec-id>
# 或：bash skills/spec/scripts/check_spec.sh <host> <spec-id>
# 全部非模板 Spec：… --all
# 仅 AGENTS 就绪度警告：… --agents-only
```

校验：核心五件套、骨架文件名、事实映射列与填充、P0↔tests、Given/When/Then 正文、
弱 Oracle / 数据面证伪断言、`plan.md` 架构与设计边界、`run.md` 诚实性
（acceptance/可交付 vs Fail/Blocked；Pass 禁纯 smoke Evidence）、
可选 AGENTS 空槽 WARN。清单真源：
[`design-standards/*.checklist.json`](../vibe-coding/references/design-standards/)。
Oracle 强度说明：[oracle-strength.md](./references/oracle-strength.md)。

阶段边界语义以 [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 为唯一真源。
Plan 阶段全部工件**已落盘**后，按该合同向用户用一张卡汇总技术方案、纵向切片、测试合同、执行边界、
风险和未决项（区分 Verified / Unverified）。卡尾**必须**附可复制的「新对话 Build 提示词」
（填好 Spec 路径与切片顺序），并默认引导用户**开新对话粘贴**开工；同聊「批准 Build / 开始做」仅作备选。
