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
| 活跃任务、Workspace、PR 和下一步 | `handoff.md`（索引，不复制合同正文） |
| 并行互斥 Claim | `claims.md` |
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
| `product/` | 愿望、蓝图、gap、排期 `roadmap.md`（含 `modules/`、`foundation/`；roadmap full scaffold，minimal 可后补） |
| `specs/` | Spec 模板 `_template/`；版本层之前的历史 Spec（只读） |
| `handoff.md` · `claims.md` | 交付索引与 Claim |
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
| 还没排期的愿望；可能做、也可能不做的功能灵感 | 在途 | `product/demand-pool.md` 加一行，调研结论写 `reports/` 并在该行链接；**不建版本、不登记 gap、不进 roadmap**；排进一轮才建版本，原话移入该版本的 `quote.md`。开新话题前先查池，避免重复调研 |
| 用户说的原话 | 记录 | `iterations/<yyyy-mm>/<w>/<版本>/quote.md`（没有版本就先建版本；逐字、只追加） |
| 这一轮要满足什么、待用户拍板什么 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/requirements.md` |
| 用户怎么拍板的 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/decisions.md`（待裁定在此有结论之前不切 Spec） |
| 这一轮要达成什么、含哪些 Spec、何时算关 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/README.md` |
| 一个可验收切片怎么做、怎么验 | 在途 | `iterations/<yyyy-mm>/<w>/<版本>/<id>/`（Spec 是版本拆出的工作包） |
| 新 Spec 从哪复制；版本层之前的历史 Spec | 模板 · 归档 | `specs/_template/`；`specs/<id>/`、`specs/<archive>/<id>/`（只读） |
| 外部共享资源（数据库、端口、测试账号、浏览器、部署槽）现在由谁占用 | 在途 | `claims.md`（文件不建 Claim：文件互斥由单 owner + Workspace 保证，见 vibe-coding `references/workspace-contract.md`） |
| 会话流水：做了什么、下一步 | 记录 | `handoff.md`（只追加；按月切到宿主归档） |
| 先做哪些、排期 | 常青 | `product/roadmap.md`（只排优先级，不写进度） |
| 还没做的差距（附证据） | 在途 | 一条一个文件 `product/gaps/GAP-NNN.md`（或宿主声明的 `SDD gap dir`）；总表 `product/gap-register.md`（或 `SDD gap register`）由工具生成 |
| 找谁、要对方做什么、做没做 | 在途 | `operations/requests/` |
| 出了什么事、怎么恢复 | 在途 | `operations/incidents/` |
| 遇到某症状怎么办（可重复步骤） | 常青 | `operations/runbooks/` |
| 某次调查 / 评审 / 审计 / 基准得出什么结论 | 记录 | `reports/` |
| 系统现状、设计缘由（可选） | 常青 | 宿主自有，如 `architecture/`；已拍板的技术决定是 ADR（记录，只追加） |
| 不再维护但需可查 | 归档 | 版本与其中的 Spec 关闭后原地不动（状态词标明 `archived`）；版本层之前的历史 Spec 在 `specs/<archive>/`；其余进宿主 `_archive/` |

`handoff.md` 是**会话与任务索引**，`operations/requests/` 是**跨团队请求单**，二者不是一回事，不要混用名字。

**宿主扩展必须声明。** 宿主增加的每个顶层目录，都要在本表里加一行写明「它回答什么」；没有对应一行的目录，`scripts/check-docs.sh` 会警告。

## 六条规则

1. **主题不建目录，只建枢纽页。** 一个主题在产品侧（`product/modules/<slug>/README.md`，或宿主的能力页）、系统侧（宿主自有，如 `architecture/` 的模块页）各至多一页，链出它的版本、Spec、ADR、报告、请求单。不建把常青、在途、记录装在一起的主题目录。
2. **状态只写在在途文档里。** 版本 README 头部、Spec 的 `VERSION.md` / `run.md`、请求单、事故单写状态；枢纽页、各级 README 与索引、`roadmap.md` 只放链接。
3. **关闭必须晋升。** Spec 关版（`close-spec`）与版本关闭（`close-iteration`）之前，把仍然成立的结论写回常青文档（产品页、系统页），或新开 ADR。不晋升，结论就只留在一个已关闭的版本里。
4. **关闭不搬目录。** 在途文档（版本、Spec、需求池条目、gap、请求单、事故单）关闭只改状态词，原地不动；只有整个机制退役的目录才进归档（宿主 `_archive/`，保留原相对路径），并需 ADR。子目录里不另建 `_archive/`。
5. **汇总表生成，不手写。** 版本索引、报告索引、事故索引、gap 总表、handoff 在途段写在 `<!-- sdd:gen NAME -->` 标记段里，由 `scripts/sdd_docs.py gen` 生成；手改会被检查器报 C4。
6. **一处一份。** 同一内容只在一处维护，别处只链接；`AGENTS.md` 已写的规则不复制到文档开头；被代码、脚本或 `AGENTS.md` 引用的路径，移动时在同一提交里改引用。

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
| iteration | `draft → active → archived \| cancelled`，**由其中的 Spec 推导**（`gen` 写入） | 只有版本 `README.md` 头部有状态；版本内其他文档不写 `status`；`quote.md` 逐字、只追加 |
| request | 工作项词表（`states.md` §5）：`open → shaping → planned → done \| dropped` | `dropped` 必写 `reason:`；对方进度写在 `note:` 或回复记录；关闭后原地保留 |
| incident | 头部 `status` 用工作项词表（`open` / `done`）；处置阶段 `investigating → mitigating → monitoring → restored → closed` 写在正文字段表的「阶段」行 | 只记事实、影响、根因（已证 / 未证分开）、处置 |
| runbook | `active \| deprecated` | 每份含触发症状、只读排查、处置、回滚、验证 |
| report | 不写 `status`；必填 `topic:`（生成索引按它分组）；被推翻时加 `superseded-by:` | **不可变**：只在顶部追加更正；结论过期就新写一份并指向它 |

`updated` 必填；有「基于某版本核对」含义的文档另写 `verified_against`。

## 宿主绑定

宿主用 `AGENTS.md` 里**固定格式的一行**声明与插件的绑定（值后面不要再跟注释，工具按整行读取）：

| 声明 | 默认 | 作用 |
|---|---|---|
| `- SDD docs root: <相对路径>` | `docs` | SDD 文档树的根 |
| `- SDD archive dir: <目录名>` | `archive` | `specs/` 下放版本层之前的已关版 Spec 的目录（版本内的 Spec 关版不搬动）；`close-spec`、`check_spec` 读它 |
| `- SDD gap register: <相对宿主根的路径>` | `<root>/product/gap-register.md` | 生成的 gap 总表位置；脚手架据此不再另建一份 |
| `- SDD gap dir: <相对宿主根的路径>` | `<root>/product/gaps` | gap 一条一文件的目录 |
| `- SDD legacy paths: a, b, …` | — | 已退役的路径；在 `AGENTS.md`、规则、技能、目录 README 中出现即报 C6 |
| `- SDD size exempt: glob, …` | — | 不受体积预算约束的路径（如业务口径大表） |
| `- SDD strict since: YYYY-MM-DD` | — | 此日期之后新增的文档缺头部字段报 ERROR，之前的只报 WARN |
| `- SDD workspace: <模式>` | 按 Spec 选 `local \| managed-worktree \| git-worktree` | 宿主强制多个会话共用一个 checkout 时写 `shared-local`：开工声明写入面、提交前 `commit-guard`（vibe-coding `references/workspace-contract.md` §10） |

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
  ≫ handoff.md
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

检查、生成、移动都用 `scripts/sdd_docs.py`（只用标准库）：

```bash
python3 <plugin>/scripts/sdd_docs.py check <host> [--files F …]   # C1～C10；有 ERROR 退出 1
python3 <plugin>/scripts/sdd_docs.py gen   <host> [--check]       # 写入或核对生成段
python3 <plugin>/scripts/sdd_docs.py mv    <host> OLD NEW …        # git mv + 全仓改引用
```

| 规则 | 检查什么 |
|---|---|
| C1 | 带类型文档的头部字段（`strict since` 之后新增的为 ERROR） |
| C2 | 状态词与必填项（工作项词表、Spec 词表、需求池表头） |
| C3 | 禁写状态：报告、能力页、版本内非 README 文档；版本 README 与推导结果一致 |
| C4 | 生成段最新、未被手改 |
| C5 | 现行文档相对链接断链为 0；归档与报告只报总数 |
| C6 | 规则类文件不出现已退役路径 |
| C7 | 体积：`AGENTS.md` ≤ 24KB、常青单文件 ≤ 40KB、handoff ≤ 15KB、能力页 ≤ 12KB |
| C8 | 期限（WARN）：复审日已过、版本超 42 天未关 |
| C9 | 放置：顶层目录已声明、无单文件目录、无插件模板的本地副本、报告名带日期 |
| C10 | 编号唯一：DEM、GAP、ADR |

**改动分级**（决定要不要建版本）：T0 错字、纯文档 → 只写提交信息；T1 缺陷修复、单模块小改 → 在对应 gap 或需求池行记一笔并写 handoff；T2 新功能、行为变化、新表、≥5 个文件或跨模块 → 建版本与 Spec。

旧脚本 `check-docs.sh` 保留兼容（放置、元数据、断链三项）。

检查：宿主每个顶层目录是否在「这份文档该放哪」里有一行；本节所列类型的文档是否带元数据（版本目录里的 Spec 五件套除外）；相对链接的死链数（`--max-broken N` 超过则失败，用于「只增不减」的棘轮）。

Spec 的位置由 `check_spec` 检查：在途 Spec 还在历史位置 `specs/<id>/`、或 `VERSION.md` 的 `iteration:` 字段与所在版本不一致时给出警告。

脚手架只在用户明确要求时运行，不因缺少目录自动写入宿主仓库。
