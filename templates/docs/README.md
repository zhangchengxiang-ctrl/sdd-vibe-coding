# SDD 文档地图

这些文档是 Agent 跨任务的交付记忆。用户只需确认产品方向、单向门和真实结果。

## 权威来源

| 事实 | 唯一真源 |
|---|---|
| 项目命令、环境、架构、红线、就绪度 | `AGENTS.md` |
| 社区设计底线（系统架构 / UX / 视觉） | 插件 `design-standards/`（AGENTS 可覆盖） |
| 可选 as-built 边界与 ADR | 仓库 `docs/architecture/`（非 SDD 保留路径） |
| 产品愿望与长期蓝图 | `product/` |
| 当前版本实施合同 | `specs/<id>/`（`contract` + `tests` + `plan` + `run`） |
| 活跃任务、Workspace、PR 和下一步 | `reference/handoff.md`（索引，不复制合同正文） |
| 并行互斥 Claim | `reference/claims.md` |
| 实际实现 | 代码、迁移和配置 |
| 验收证据 | `specs/<id>/run.md`（附件路径写在 Evidence 列） |
| 一轮迭代的目标、含哪些 Spec、并行矩阵、何时算关 | `iterations/<id>/`（只链接 Spec，不抄状态） |
| 跨团队请求：找谁、要对方做什么、做没做 | `operations/requests/` |
| 生产事故 | `operations/incidents/` |
| 可重复的运维步骤（症状 → 动作 → 回滚） | `operations/runbooks/` |
| 某次调查 / 评审 / 审计 / 基准的结论 | `reports/`（带日期、不可变） |

同一规则只维护一处；其他文档只链接权威来源。

### SDD 保留路径（独占语义）

下列路径由 SDD 占用；宿主原有技术文档请放在其他子树（例如 `docs/architecture/`、`docs/api/`），或迁到 `docs/_host/`：

| 路径 | 语义 |
|---|---|
| `product/` | 愿望、蓝图、gap（含 `modules/`、`foundation/`） |
| `specs/` | 实施合同与 `_template/` |
| `reference/handoff.md` · `reference/claims.md` | 交付索引与 Claim |
| `planning/roadmap.md` | 排期（full scaffold；minimal 可后补） |
| `iterations/` | 迭代层：一轮 = 多个 Spec；目标、成功指标、并行矩阵、关闭条件 |
| `operations/incidents/` · `operations/requests/` · `operations/runbooks/` | 事故、跨团队请求、运维手册 |
| `reports/` | 带日期的调查 / 评审 / 审计 / 基准结论 |

存量初始化：优先 `make scaffold PROFILE=minimal`（或默认 `detect`）。硬冲突时 scaffold 会 `BLOCK`；也可 `SDD_ROOT=docs/sdd`（或 `--root=docs/sdd`）把 SDD 挂到子树，并在 `AGENTS.md` 盖章 `SDD docs root`（见插件 `skills/vibe-coding/references/docs-root.md`）。

旧 wiki / README **只链接、不整页搬进** `product/`，避免双真源。

### 这份文档该放哪

先按「它回答什么」判断，不要默认放进某个宿主自有目录：

| 这份文档回答什么 | 放哪 |
|---|---|
| 要做什么、做到什么程度 | `product/`；落到版本后进 `specs/` |
| 这一轮要达成什么、含哪些 Spec、何时算关 | `iterations/<id>/` |
| 一个可验收切片怎么做、怎么验 | `specs/<id>/` |
| 活跃任务、PR、下一步（索引） | `reference/handoff.md` |
| 先做哪些、排期 | `planning/roadmap.md` |
| 找谁、要对方做什么、做没做 | `operations/requests/` |
| 出了什么事、怎么恢复 | `operations/incidents/` |
| 遇到某症状怎么办（可重复步骤） | `operations/runbooks/` |
| 某次调查 / 评审 / 审计 / 基准得出什么结论 | `reports/` |
| 系统现状、设计缘由（可选） | 宿主自有，如 `architecture/` |
| 不再维护但需可查 | Spec 进归档目录；其余进宿主 `_archive/` |

`reference/handoff.md` 是**会话与任务索引**，`operations/requests/` 是**跨团队请求单**，二者不是一回事，不要混用名字。

**宿主扩展必须声明。** 宿主增加的每个顶层目录，都要在本表里加一行写明「它回答什么」；没有对应一行的目录，`scripts/check-docs.sh` 会警告。

### 文档元数据与生命周期

除 `specs/<id>/` 的五件套外，本节所列类型的文档头部用同一组元数据：

```yaml
---
title: ...
type: iteration | request | runbook | report | reference
status: <该类型的状态词，见下>
owner: ...
updated: YYYY-MM-DD
---
```

| 类型 | 状态词 | 生命周期规则 |
|---|---|---|
| iteration | `draft → active → closed \| cancelled` | 状态只有一个真源：迭代文档只链接 Spec，不抄 Spec 状态 |
| request | `待认领 → 评估中 → 建设中 → 对账中 → 已交付 \| 不做` | 「不做」必附原因；关闭后保留 30 天再进归档 |
| incident | `investigating → mitigating → monitoring → restored → closed` | 沿用 `incidents/_template.md` 自带的字段表，不用上面的元数据块；只记事实、影响、根因（已证 / 未证分开）、处置 |
| runbook | `active \| deprecated` | 每份含触发症状、只读排查、处置、回滚、验证 |
| report | `active \| superseded` | **不可变**：只在顶部追加更正；结论过期就新写一份并指向它 |

`updated` 必填；有「基于某版本核对」含义的文档另写 `verified_against`。

### 宿主绑定

宿主用 `AGENTS.md` 里**固定格式的一行**声明与插件的绑定（值后面不要再跟注释，工具按整行读取）：

| 声明 | 默认 | 作用 |
|---|---|---|
| `- SDD docs root: <相对路径>` | `docs` | SDD 文档树的根 |
| `- SDD archive dir: <目录名>` | `archive` | `specs/` 下放已关版 Spec 的目录；`close-spec`、`check_spec` 读它 |
| `- SDD gap register: <相对宿主根的路径>` | `<root>/product/gap-register.md` | 宿主已有等价的缺口登记时声明；脚手架据此不再另建一份 |

### 真源优先级（冲突时）

```text
specs/<id>/（执行合同）+ 代码/运行环境
  ≫ reference/handoff.md
  ≫ product/modules/（产品蓝图）
  ≫ product/demand-pool.md（愿望）
```

状态词汇（Version / Delivery Target / Spec Run / 完成声明）以插件
`skills/vibe-coding/references/workflow-contract.md`「状态词汇」为**唯一真源**；
本目录不复述枚举。

## 工作轨

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         |
                      └ Repair ─┘

复杂/线上问题：Diagnose → Repair | Plan | Incident
生产事故：Incident → Production Verification → 长期执行合同
```

- Shape 澄清产品诉求；Plan 形成技术方案、**完整测试用例**和 Spec 执行合同；
- 每个工作轨在自身范围内连续完成；跨工作轨前先总结并等待用户批准；
- Verify 只验收、记录证据和分类 Fail（不改 `tests.md` Oracle）；
- Diagnose 只定位，Incident 只恢复生产。

## Spec 布局与读序

```text
docs/specs/<id>/              # 施工中
docs/specs/<archive dir>/<id>/  # 人验关版后搬入（默认 archive，可用 SDD archive dir 改名）；勿重开
├── VERSION.md
├── contract.md   # WHAT
├── tests.md      # TEST
├── plan.md       # HOW
└── run.md        # RUN
```

读序：`VERSION` → `contract` → `tests` → `plan` → `run`（Build 起）。

## 检查

从插件仓校验宿主 docs（只读；退出码 1 = 有警告以外的错误）：

```bash
bash <plugin>/scripts/check-docs.sh <host> [--max-broken N]
```

检查：宿主每个顶层目录是否在「这份文档该放哪」里有一行；本节所列类型的文档是否带元数据；相对链接的死链数（`--max-broken N` 超过则失败，用于「只增不减」的棘轮）。

脚手架只在用户明确要求时运行，不因缺少目录自动写入宿主仓库。
