# Workflow Contract

> 一个确认的 Spec 是唯一交付单元；Rail 是同一交付目标内的动作模式。
> 纵向切片（见 Skill `spec`）是 Spec 内的可独立完成与验收单位；不得用横向基础设施模块冒充切片。

## 交付语义

1. 先确认 Spec 的范围、验收条件、风险边界与当前代码事实（含已验证的入口事实映射）。
2. `Build` 按宿主能力完成实现：见下方「Harness 适配」。不得在局部代码、局部检查或进度汇报处结束。
3. 实现完成后才运行一次完整的**单元测试批次**。该批次开始到结果收齐期间，禁止修改代码。
4. `Verify` 再统一运行适用的集成、场景、端到端及真实环境探针，收齐所有失败。
5. 有实现失败时先写一份按根因分组的统一 Repair 方案；随后 `Repair` 集中修改，完成后从完整
   验收批次重新验证。禁止“测一个点、改一个点”。
6. 只有达到当前完成单元的验收、所有剩余工作被真实外部条件阻塞、或下一步需要不可逆授权时才结束。
   Rail 转换、测试层切换、局部通过、普通 WIP、缺少新对话/子代理、盘点结论、typecheck 旧债都不是结束理由。

## Harness 适配（完成单元）

> 产品语义不变：Spec 仍是合同边界。变的是「一次 agent 回合允许承诺并交付到哪」。

| 宿主 | Build 完成单元 | 长程整份 Spec |
|---|---|---|
| Cursor / Claude Code | 默认可连续完成 **整份 Spec** In Scope | 阶段内连续，直到交付 / 真实外部阻塞 / 不可逆授权 |
| **Codex** | 普通任务默认只承诺并交付 **一个纵向切片**（含该切片行为验收） | 用户要求「完整实施 / 连续做完 / 不要中途停止」整份 Spec 时，视为**明确授权创建持久 Goal**（`/goal` 或 `create_goal`）；禁止把整份 Spec 塞进普通单轮并假装能一口气做完 |

### Codex 强制规则

1. **Goal 桥接**：出现「完整实施已确认 Spec」「持续完成」「不要中途停止」「按任务依赖连续推进到完整 Spec」等意图时，必须立即创建或请求创建持久 Goal，而不是作为普通任务硬扛。
2. **无 Goal 时**：前台只声明当前纵向切片的完成条件；切片完成后总结并请求批准进入下一切片或 Verify，不得静默扩到整包后半段再发 final。
3. **禁止假 final**：进度汇报、T1.0 盘点、部分入口迁移、既有仓库 typecheck 失败，一律不得作为结束回复；未达完成单元则继续工具循环。
4. **禁止假阻塞**：见下方「证据分级」；不得把「现状代码用了绝对路径」「文档尚未编号」当成外部阻塞。

### 指挥施工 Harness（可选 · Cursor / Claude → Codex）

> **定位：** 指挥侧（Cursor / Claude Code，含 Auto）做人机交互、产品拍板与验收；
> 施工侧 Codex 用 **`gpt-5.6-sol` × medium/high** 跑有界完成单元。这是**可选**模式，
> 不是「便宜模型外包一切」，也不是纯 Codex 单宿主的替代终局。
> 执行细则与模型硬表见 Skill `dispatch-codex`。产品语义（Spec / 纵向切片 / Oracle）不变。

**触发（指挥侧用户明示其一即可）：**

- 派 Codex / 用 Codex 做 / 让 Codex 施工 / 省成本用 Codex 跑

**未触发时：** 当前宿主按上表自行完成，**不自动外包**。复杂 Plan 默认指挥侧自做。

**规则：**

1. **一次只派一个完成单元**：Plan（整份 Spec 落盘）或 Build **一个**纵向切片；禁止把整包多片塞进一次普通 Codex 派单。
2. **派单必须薄**：只含 cwd、单元类型、输入路径、完成定义指针（如 `S1 → T-001/T-002`）、**model/effort**、**approval-policy**、**sandbox**；**禁止**把本合同大段粘进派单。质量条由施工侧已装插件默认执行。
3. **模型硬约束**：Plan / Build / Goal 仅允许 `gpt-5.6-sol`，effort 仅 `medium`（默认）或 `high`（加码）。**禁止** `gpt-5.6-terra` / `gpt-5.6-luna` / sol×`low`（评测：旧骨架或无产物）。
4. **审批硬约束**：MCP/CLI 派单必须 `approval-policy=never`。**禁止** `on-request` / `untrusted`（MCP 同步通道弹不出批准 UI → 工具无限挂死）。漏传等同非法派单。
5. **沙箱**：Plan 可用 `workspace-write`；Build/Goal 默认 `danger-full-access`（避免 listen/port 集成测卡 escalation）。
6. **无 Oracle 不准派 Build**：该片缺少可观察的 success + failure/permission（`tests.md`）→ 指挥侧先补 Plan 或打回，不得派编码。
7. **maker ≠ grader**：Codex 施工自评不算通过；指挥侧必须对照仓库产物（Spec 文件 / `run.md` / diff / 测试）验收后再向用户交付。Plan 若落成旧骨架（`context`/`requirements`/`tasks`/`validation` 等而无 `contract.md`）→ **否决打回**，不得改派 Terra/Luna。**MCP 是否 return 不是验收条件**；挂死后仍按仓库结案。
8. **挂死上限**：Plan ~15min / Build 单片 ~20min 仍 pending → 中断工具，验收仓库；可改 CLI 重派。禁止干等。
9. **失败打回同一 thread**（`codex-reply`，可升 high）或新开派单修正；不得用催促词掩盖坏 Spec。
10. **多片长程**：可派「对该 Spec 开 Goal，完成条件=剩余切片+验证命令」；effort=**high**；指挥只盯里程碑与证据，不逐工具盯梢。
11. **工具降级**：优先 Codex MCP（`codex` / `codex-reply`，须带 never）；不可用或曾挂死则走 `skills/dispatch-codex/scripts/codex-dispatch.sh`（强制 never + 墙钟 timeout + JSONL）；再不行才裸 `codex exec`；皆失败 → 对人说明 Blocked，禁止谎报已派单成功。

**对人前台：** 只说目标、进展、证据、要你决定；可简说「复杂活用 Codex Sol」。不暴露 threadId、MCP、Goal 内部词，除非用户追问。

## 证据分级（Unverified 禁入硬闸）

技术判断必须标为以下之一，并写入 Spec / 对话结论：

| 级别 | 含义 | 允许用途 |
|---|---|---|
| `Verified` | 有当前代码、Schema/约束、配置或运行证据 | Requirement、Test、Lock、Blocker、DDL 条件、宣称可实施 |
| `Unverified` / `Assumption` | 尚未证明 | 仅可写在「待验证」；**禁止**进入 P0 Requirement、Requirements Lock、实施阻断、DDL 默认条件 |

冲突规则：代码与数据库事实与 Spec 冲突时，先判定为 **Spec 缺陷**；不得为维护 Spec 权威而臆造新表、扩大阻塞或停止整个 Build。

## 写代码前的硬闸

在改业务代码（应用源码、配置契约、运行时行为）之前，必须满足至少一项：

| # | 条件 |
|---|---|
| **(a)** | 已存在**已确认**的实施 Spec：`docs/specs/<id>/`（含 Verify 后转入的 Repair） |
| **(b)** | 用户本轮**明示**「开始做 / 实现 / 按这个来 / 构建」，且产品切片已确认 |

demand pool 条目、`modules/` 设计稿、聊天清单或截图 **都不算** (a)/(b)。

**(a)/(b) 皆无时，本轮只能：**

1. 写 `docs/product/`（demand pool / modules 草稿 / 理解卡沉淀）；
2. 只读调查宿主代码与 `AGENTS.md`；
3. **禁止**改业务代码；
4. **禁止**新建 `docs/specs/`（Spec 只在用户批准进入 Plan 后由 Plan 创建）。

空仓或未 scaffold 的宿主：先跑 `scripts/scaffold.sh`（默认 `detect`：空 SDD root → full，已有文件 → minimal；保留路径语义冲突 → 拒绝）。存量推荐 `PROFILE=minimal`；宿主已占用默认 `docs/product` 时用 `--root=docs/sdd`（见 [docs-root.md](./docs-root.md)）。scaffold **不算** (a)/(b)。

trivial 豁免（跳过完整 Shape→Plan）见 [`vibe-coding/SKILL.md`](../SKILL.md)。

常见 Shape 话术（「优化 X」「编号清单 + 截图」「应该/不要有…」「很明确直接改」）一律按上表处理：
停留 Shape、沉淀切片，见 Skill `design`。

## 模式与权限

| 模式 | 职责 | 代码写入 |
|---|---|---|
| Shape | 澄清产品结果与范围 | 否 |
| Plan | 形成 Spec、场景与验收策略 | 否 |
| Build | 实现确认 Spec 的全部内容 | 是 |
| Verify | 只运行批量验收、记录结果并归类失败 | 否 |
| Repair | 按统一方案集中修复已收齐的失败 | 是 |
| Diagnose | 定位原因和证据 | 否，除非用户明确要求修复 |
| Incident | 经授权恢复生产 | 仅最小止血 |

## 薄提示词原则（质量条在插件，不在用户嘴里）

> 用户只需用自然语言表达**意图**与**关键选择**。下列质量条由本插件默认执行；
> **不得**要求用户在提示词里复述，也不得因用户没写这些条款而降级执行。

| 用户只需说 | 插件默认必须做到 |
|---|---|
| 「按这个产品包切 Spec / Plan / 拆到能编码」 | Plan：先事实映射 → 纵向切片 → 完整 `tests.md` G/W/T → 落盘整份 Spec；不改业务代码 |
| 「批准了，开始做 / 实现」 | Build：Codex 默认只做**第一个**纵向切片（含行为验收）；Cursor/Claude 可连续整份 Spec |
| 「派 Codex / 用 Codex 做」 | Cursor/Claude：走可选**指挥施工**（Skill `dispatch-codex`）；一次一单元；**仅 sol×medium/high** |
| 「完整实施 / 不要中途停 / 把整份 Spec 做完」 | Codex：立即 Goal；禁止普通单轮硬扛整包 |
| 「验收一下」 | Verify：行为/权限 Oracle 优先于文档自洽 |

用户**不必**写出：先查库、禁止 ManagedRoot、禁止横向拆、Unverified 不进 Lock、Given/When/Then、
禁止假阻塞、禁止长篇自辩——这些已是合同默认。

### Plan 落盘授权（内化 · 修假闸）

下列任一表述 = **已批准进入 Plan 并创建/写入 `docs/specs/<id>/`**，无需再问「批准落盘 Spec」：

- 切 Spec / 走 Plan / 拆解实施 / 做到可以编码 / 按产品设计切版 / 重切 Spec

Plan 阶段内：调查 → **直接落盘** `VERSION`/`contract`/`tests`/`plan`/`run` → 结束时只出
**进入 Build** 的批准卡。禁止在落盘前用「拟按此计划创建 Spec，请批准」交还控制权。

仍须跨阶段批准的只有：`Shape → Plan`、`Plan → Build`、`Build/Verify →` 下一阶段或生产动作。

## 阶段闸门

> 本节是"何时连续、何时暂停、跨阶段如何总结与批准"的唯一真源。其他 Skill 只引用本节。

1. **阶段内连续**：每个阶段由当前 agent 一次性连续完成自身职责，中途不向用户交还控制权。
2. **跨阶段闸门**：`Shape → Plan → Build → Verify → Repair` 每一次阶段切换前，先向用户总结本阶段
   的目标、完成内容、证据、限制与建议的下一阶段，取得**明确批准**后才进入下一阶段。
3. **阶段内暂停**：仅在产品选择互斥、破坏性/不可逆动作、用户本人才能完成的外部操作、或**已 Verified**
   的事实与已确认需求冲突且将改变交付结果时询问用户。
4. **禁止解释循环**：用户指出错误或要求继续时，先纠正并继续执行；不得用长篇根因自辩、推责或
   「系统性解释」替代下一可执行步骤。需要暂停开发时，用户须明确说停。

### 禁止的提问（阶段内应直接做完）

| ❌ Agent 常说的话 | ✅ 正确应对 |
|---|---|
| 「要不要继续做 X？」且 X 属本阶段 / 本 Spec | 直接做完 X（commit / push / 部署除外，须明示授权） |
| 「还差这些，要我继续吗？」 | 本阶段范围内 → 做到齐；跨阶段 → 按闸门总结并请求批准 |
| 「核心已经写好了，剩下的要不要做？」 | 未完成项不得标可选；属于 In Scope 的必须做完或记为真实 Blocked |
| Shape 下「清单已经很清楚，我直接改代码？」 | **不改码**；沉淀 demand pool / 理解卡，走硬闸 |
| 「路径字段是绝对路径，所以没有真源，重开 Lock」 | 先按业务 ID / owner 关系验证能否派生根；仅 Verified 无法派生才可阻断 |
| 「先汇报进度，下一轮再继续」 | 未达完成单元 → 不发结束式回复，继续做 |
| 「请批准按此计划落盘 Spec」（用户已说切 Spec/Plan） | **直接落盘**；只在 Spec 齐后请求批准进入 Build |
| 「请先确认这 5 条硬要求 / 我是否理解对了再开始」且无产品互斥 | 按默认质量条执行；理解偏差在交付卡里说明 |

### 建议开新对话的信号

下列情况才建议用户开新对话（或明确换目标）：

1. **同区二次修复仍失败**：同一根因面已按统一 Repair 方案修过一轮并回验仍 Fail → 停补丁，开新对话做 Diagnose 或重开 Plan。
2. **会话混入第二个不相关产品目标**：当前 Spec / 阶段尚未收束 → 先收束或 Blocked；新目标开新对话走 Shape。
3. **Verify 不通过且统一 Repair 面过大**：先交付 Verify 总结与 Repair 方案，建议新对话专跑 Repair（或先回 Plan 修订合同）。

## 实施与验收清单

### Build

- 覆盖当前完成单元（整份 Spec 或一个纵向切片）的入口、数据流、错误语义；先按事实映射核对再修改。
- 用户只说「开始做」且未点名切片时：Codex = `plan.md` **第一个**纵向切片；Cursor/Claude = 默认可连续整份 Spec（仍可按切片推进）。
- 可以在实现期间做编译、格式化、静态分析等非验收性检查；不得把局部测试结果称为完成。
- 完成实现后冻结代码，列出并运行完整单元测试命令；记录全部失败而不边测边改。
- 禁止用「符合文档编号 / manifest 数量」代替行为验收（越权拒绝、成功路径）。
- 切片/完成单元收口：短报告「做成了什么 / 证据在哪 / 下一个切片」；禁止长篇自辩。

### Verify

- 在不修改实现的前提下，运行完整集成/场景/端到端/真实环境探针。
- 报告每个失败的命令、结果、影响范围和初步根因；环境、账号、主机或外部依赖失败须有原始证据。
- 若存在可修实现问题，输出一份 Repair 方案：根因分组、修改面、风险、回归矩阵，然后进入 Repair。

### Repair

- 只按已记录的统一 Repair 方案修改；若发现新根因，补入同一方案。
- 修复完成后重跑完整的单元与 Verify 批次；不得以定向绿灯代替全量回验。

## 完成声明

最终只能声明以下之一（枚举见下方「状态词汇」第 4 层）。

不能用“已完成某一步”“等待用户批准”“需要新任务”“未部署”或单个测试绿灯代替结论。

## 状态词汇（唯一真源）

> 下列四层不得混写。其它文档只引用本节；`matrix-accounted` / `design-ready` /
> `production-restored` **不是** Delivery Target。

### 1. Version 状态（`VERSION.md`）

`draft | ready | in-progress | verifying | blocked | done | archived | cancelled`

### 2. Delivery Target（`VERSION.md` / `run.md` 声明目标）

| Target | 含义 |
|---|---|
| `code-ready` | 代码与合同就绪；**不**自动部署 |
| `dev-effective` | 在开发/预览环境真实生效 |
| `production-delivered` | 生产真实生效 |

细则与铁律见 [`evidence-contract.md`](./evidence-contract.md) Deliver Gate。

### 3. Spec Run 持久态（`run.md` / `handoff.md`）

`ready | building | unit-testing | verifying | repairing | blocked | acceptance-passed`

### 4. 完成声明（阶段结束时只能选其一）

- `acceptance-passed`：每项适用验收条件都有直接证据
- `blocked`：未完成项与外部阻塞可复现
- `needs-authorization`：下一步是不可逆授权

### 相邻但不同层（禁止塞进 Delivery Target）

| 词 | 落盘 | 含义 |
|---|---|---|
| `matrix-accounted` | `run.md` → 终态 Matrix | 所有适用 Test 已有终态 |
| `design-ready` | 产品包 / demand-pool | Shape 切片已确认，尚未 Plan |
| `production-restored` | Incident 记录 | 生产已止血恢复，≠ 长期根因已修 |
| 产品能力态 | `product/README` 能力地图 | `shaping \| design-ready \| planned \| partially-delivered \| accepted \| archived` |
| demand 条目态 | `demand-pool.md` | `draft \| shaping \| design-ready \| planned \| delivered \| parked` |

能力态与 demand 条目态分表维护，禁止混写同一行；勿使用已废弃的 `ready-for-plan`。

### 仅评测（不写入交付工件）

`evals/` 路由字段 `spec_run_state`：
`not-started | continuous-build | batch-unit-test | batch-verify | unified-repair | completed | blocked | needs-authorization`
