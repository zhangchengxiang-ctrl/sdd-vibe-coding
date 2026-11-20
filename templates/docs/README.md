# SDD 文档地图

这些文档是 Agent 跨任务的交付记忆。用户只需确认产品方向、单向门和真实结果。

## 三类文档

每份文档只属于一类。类决定它放哪、怎么维护、要不要写状态。顶层目录按类划分，不按主题、不按读者场景划分。

| 类 | 是什么 | 怎么维护 | 状态 | 结束后 |
|---|---|---|---|---|
| **常青** | 现在是什么样 / 要做成什么样 | 原地改，永远是当前 | 不写状态，只链接在途文档 | 不归档；过时就改 |
| **在途** | 一件会结束的事 | 推进中可改，结束后冻结 | 有，**只写在它自己里面** | 原地改为关闭状态，不搬目录 |
| **记录** | 某个时刻的事实 | 写完不改，只追加 | 不写状态，日期就是身份 | 原地保留 |

判定顺序：这件事会结束吗？会 → 在途。不会，但内容会变吗？会 → 常青。都不会 → 记录。

术语：**版本** = `iterations/` 下的一次许愿（也叫迭代），它是在途文档；Spec 是从版本切出的工作包。Spec 目录里的 `VERSION.md` 是 Spec 的状态卡（名字沿用历史），不是「版本」本身。

## 权威来源

| 事实 | 唯一真源 |
|---|---|
| 项目命令、环境、架构、红线、就绪度 | `AGENTS.md` |
| 社区设计底线（系统架构 / UX / 视觉） | 插件 `design-standards/`（AGENTS 可覆盖） |
| 可选 as-built 边界与 ADR | 仓库 `docs/architecture/`（非 SDD 保留路径） |
| 产品愿望池与长期蓝图（不属于某一轮的） | `product/` |
| 某一次许愿的用户原话（逐字） | 该版本的 `iterations/<yyyy-mm>/<w>/<版本>/quote.md`（只追加） |
| 这一轮的需求判据、范围、待裁定 | 该版本的 `iterations/<yyyy-mm>/<w>/<版本>/requirements.md` |
| 用户裁定（对待裁定的回答）与版本级决策 | 该版本的 `iterations/<yyyy-mm>/<w>/<版本>/decisions.md` |
| 当前版本实施合同 | `iterations/<yyyy-mm>/<w>/<版本>/<id>/`（`contract` + `tests` + `plan` + `run`） |
| 活跃任务、Workspace、PR 和下一步 | `reference/handoff.md`（索引，不复制合同正文） |
| 并行互斥 Claim | `reference/claims.md` |
| 实际实现 | 代码、迁移和配置 |
| 验收证据 | `iterations/<yyyy-mm>/<w>/<版本>/<id>/run.md`（附件路径写在 Evidence 列） |
| 一个版本的目标、含哪些 Spec、并行矩阵、何时算关 | `iterations/<yyyy-mm>/<w>/<版本>/README.md`（只链接 Spec，不抄状态） |
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
| `specs/` | Spec 模板 `_template/`；版本层之前的历史 Spec（只读） |
| `reference/handoff.md` · `reference/claims.md` | 交付索引与 Claim |
| `planning/roadmap.md` | 排期（full scaffold；minimal 可后补） |
| `iterations/` | 版本层：`<yyyy-mm>/<w>/<版本>/`，一次许愿一个版本——原话、需求、用户裁定、目标与并行矩阵，以及从中切出的 Spec |
| `operations/incidents/` · `operations/requests/` · `operations/runbooks/` | 事故、跨团队请求、运维手册 |
| `reports/` | 带日期的调查 / 评审 / 审计 / 基准结论 |

存量初始化：优先 `make scaffold PROFILE=minimal`（或默认 `detect`）。硬冲突时 scaffold 会 `BLOCK`；也可 `SDD_ROOT=docs/sdd`（或 `--root=docs/sdd`）把 SDD 挂到子树，并在 `AGENTS.md` 盖章 `SDD docs root`（见插件 `skills/vibe-coding/references/docs-root.md`）。

旧 wiki / README **只链接、不整页搬进** `product/`，避免双真源。

### 这份文档该放哪

先按「它回答什么」判断，不要默认放进某个宿主自有目录：

| 这份文档回答什么 | 类 | 放哪 |
|---|---|---|
| 要做什么、做到什么程度（长期） | 常青 | `product/`；排进一轮后建版本，再拆 Spec |
| 还没排期的愿望 | 在途 | `product/demand-pool.md`；排进一轮即建版本，原话移入该版本的 `quote.md` |
| 用户说的原话 | 记录 | `iterations/<yyyy-mm>/<w>/<版本>/quote.md`（没有版本就先建版本；逐字、只追加） |
| 这一轮要满足什么、待用户拍板什么 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/requirements.md` |
| 用户怎么拍板的 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/decisions.md`（待裁定在此有结论之前不切 Spec） |
| 这一轮要达成什么、含哪些 Spec、何时算关 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/README.md` |
| 一个可验收切片怎么做、怎么验 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/<id>/`（Spec 是版本拆出的工作包） |
| 新 Spec 从哪复制；版本层之前的历史 Spec | 模板 · 归档 | `specs/_template/`；`specs/<id>/`、`specs/<archive>/<id>/`（只读） |
| 谁正占着哪个文件 | 在途 | `reference/claims.md` |
| 会话流水：做了什么、下一步 | 记录 | `reference/handoff.md`（只追加；按月切到宿主归档） |
| 先做哪些、排期 | 常青 | `planning/roadmap.md`（只排优先级，不写进度） |
| 还没做的差距 | 常青 | `product/gap-register.md`（或宿主声明的 `SDD gap register`）；已关闭的进 `gap-closed.md`（记录） |
| 找谁、要对方做什么、做没做 | 在途 | `operations/requests/` |
| 出了什么事、怎么恢复 | 在途 | `operations/incidents/` |
| 遇到某症状怎么办（可重复步骤） | 常青 | `operations/runbooks/` |
| 某次调查 / 评审 / 审计 / 基准得出什么结论 | 记录 | `reports/` |
| 系统现状、设计缘由（可选） | 常青 | 宿主自有，如 `architecture/`；已拍板的技术决定是 ADR（记录，只追加） |
| 不再维护但需可查 | 归档 | 版本与其中的 Spec 关闭后原地不动（状态词标明 `archived`）；版本层之前的历史 Spec 在 `specs/<archive>/`；其余进宿主 `_archive/` |

`reference/handoff.md` 是**会话与任务索引**，`operations/requests/` 是**跨团队请求单**，二者不是一回事，不要混用名字。

**宿主扩展必须声明。** 宿主增加的每个顶层目录，都要在本表里加一行写明「它回答什么」；没有对应一行的目录，`scripts/check-docs.sh` 会警告。

## 五条规则

1. **主题不建目录，只建枢纽页。** 一个主题在产品侧（`product/modules/<slug>/README.md`，或宿主的能力页）、系统侧（宿主自有，如 `architecture/` 的模块页）各至多一页，链出它的版本、Spec、ADR、报告、请求单。不建把常青、在途、记录装在一起的主题目录。
2. **状态只写在在途文档里。** 版本 README 头部、Spec 的 `VERSION.md` / `run.md`、请求单、事故单写状态；枢纽页、各级 README 与索引、`roadmap.md` 只放链接。
3. **关闭必须晋升。** Spec 关版（`close-spec`）与版本关闭（`close-iteration`）之前，把仍然成立的结论写回常青文档（产品页、系统页），或新开 ADR。不晋升，结论就只留在一个已关闭的版本里。
4. **关闭不搬目录。** 版本与其中的 Spec 关闭只改状态词；归档目录只放版本层之前的历史 Spec（`specs/<archive>/`）与宿主其余已结束文件（宿主 `_archive/`）。子目录里不另建 `_archive/`。
5. **一处一份。** 同一内容只在一处维护，别处只链接；`AGENTS.md` 已写的规则不复制到文档开头；被代码、脚本或 `AGENTS.md` 引用的路径，移动时在同一提交里改引用。

## 文档元数据与生命周期

除 Spec 的五件套外，本节所列类型的文档头部用同一组元数据：

```yaml
---
title: ...
type: iteration | request | runbook | report | reference   # 版本目录里的 README / quote / requirements / decisions / baseline / release / retro 都是 iteration
status: <该类型的状态词，见下>
owner: ...
updated: YYYY-MM-DD
---
```

| 类型 | 状态词 | 生命周期规则 |
|---|---|---|
| iteration | `draft → active → archived \| cancelled` | 版本的状态写在版本 `README.md` 头部（`close-iteration` 写 `archived`）；版本文档只链接 Spec，不抄 Spec 状态；`quote.md` 逐字、只追加 |
| request | `待认领 → 评估中 → 建设中 → 对账中 → 已交付 \| 不做` | 「不做」必附原因；关闭后保留 30 天再进归档 |
| incident | `investigating → mitigating → monitoring → restored → closed` | 沿用 `incidents/_template.md` 自带的字段表，不用上面的元数据块；只记事实、影响、根因（已证 / 未证分开）、处置 |
| runbook | `active \| deprecated` | 每份含触发症状、只读排查、处置、回滚、验证 |
| report | `active \| superseded` | **不可变**：只在顶部追加更正；结论过期就新写一份并指向它 |

`updated` 必填；有「基于某版本核对」含义的文档另写 `verified_against`。

## 宿主绑定

宿主用 `AGENTS.md` 里**固定格式的一行**声明与插件的绑定（值后面不要再跟注释，工具按整行读取）：

| 声明 | 默认 | 作用 |
|---|---|---|
| `- SDD docs root: <相对路径>` | `docs` | SDD 文档树的根 |
| `- SDD archive dir: <目录名>` | `archive` | `specs/` 下放版本层之前的已关版 Spec 的目录（版本内的 Spec 关版不搬动）；`close-spec`、`check_spec` 读它 |
| `- SDD gap register: <相对宿主根的路径>` | `<root>/product/gap-register.md` | 宿主已有等价的缺口登记时声明；脚手架据此不再另建一份 |

## 真源优先级（冲突时）

需求冲突（用户要什么）：

```text
版本 quote.md（用户原话）
  ≫ 版本 decisions.md（用户裁定）
  ≫ 版本 requirements.md（推出的需求）
  ≫ Spec contract.md
```

原话与下游冲突时以原话为准，并回用户裁决，不得静默改写任何一方。

现状冲突（做成了什么）：

```text
Spec 五件套（执行合同）+ 代码/运行环境
  ≫ reference/handoff.md
  ≫ product/modules/（产品蓝图）
  ≫ product/demand-pool.md（愿望池）
```

状态词汇（Spec 的 `VERSION.md` / Delivery Target / Spec Run / 完成声明）以插件
`skills/vibe-coding/references/states.md` 为准；本目录不复述枚举。版本（迭代）与请求单、事故单等文档的状态词见上文「文档元数据与生命周期」。

## 工作轨

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         |
                      └ Repair ─┘

复杂/线上问题：Diagnose → Repair | Plan | Incident
生产事故：Incident → Production Verification → 长期执行合同
```

- Shape 澄清产品诉求：**Shape 产出一个版本** `iterations/<yyyy-mm>/<w>/<版本>/`——原话进 `quote.md`、需求与待裁定进 `requirements.md`、用户拍板进 `decisions.md`；长期有效的产品定义写回 `product/`；
- Plan 在该版本目录下切 Spec，形成技术方案、**完整测试用例**和 Spec 执行合同；待裁定未清空不切；
- 每个工作轨在自身范围内连续完成；跨工作轨前先总结并等待用户批准；
- Verify 只验收、记录证据和分类 Fail（不改 `tests.md` Oracle）；
- Diagnose 只定位，Incident 只恢复生产。

## 版本布局与读序

```text
docs/iterations/<yyyy-mm>/<w>/<版本>/
├── README.md        # 头部 type: iteration；目标、成功指标、Spec 清单与并行矩阵、关闭条件
├── quote.md         # 用户原话（逐字、只追加）
├── requirements.md  # 需求判据（标出处）、范围、待裁定
├── decisions.md     # 用户裁定与版本级决策（含 Spec 移入移出）
├── baseline.md · release.md · retro.md
└── <spec-id>/       # 从本版本切出的 Spec
```

- `<yyyy-mm>` 是版本开始的月份；`<w>` 按开始日期：1～7 日 `w1`、8～14 日 `w2`、15～21 日 `w3`、22～28 日 `w4`、29 日起 `w5`。路径从开始就固定，跨周跨月不搬。
- 工具不解析这两层：`iterations/` 下 README 头部为 `type: iteration` 的目录就是版本，其下含 `VERSION.md` 的子目录就是 Spec（见插件 `skills/spec/scripts/spec_paths.py`）。版本 id 与 Spec id 各自全局唯一。
- 只有一个 Spec 的小改动也建版本。
- 读序：README → quote → requirements → decisions → 要做的 Spec。
- 关闭：每个 Spec 关版用 `close-spec`（状态改 `archived`，原地不动）；`retro.md` 写完后用 `close-iteration`（核对成员全关、复盘已写，版本 README 状态改 `archived`）。都不搬目录，链接不会断。

## Spec 布局与读序

```text
docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/   # 施工中；关版后状态改 archived，原地不动（close-spec）；勿重开
docs/specs/_template/                        # 模板；docs/specs/<id>/ 只剩版本层之前的历史 Spec
<Spec 目录>
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

检查：宿主每个顶层目录是否在「这份文档该放哪」里有一行；本节所列类型的文档是否带元数据（版本目录里的 Spec 五件套除外）；相对链接的死链数（`--max-broken N` 超过则失败，用于「只增不减」的棘轮）。

Spec 的位置由 `check_spec` 检查：在途 Spec 还在历史位置 `specs/<id>/`、或 `VERSION.md` 的 `iteration:` 字段与所在版本不一致时给出警告。

脚手架只在用户明确要求时运行，不因缺少目录自动写入宿主仓库。
