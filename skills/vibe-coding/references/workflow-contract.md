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

## 证据分级（Unverified 禁入硬闸）

技术判断必须标为以下之一，并写入 Spec / 对话结论：

| 级别 | 含义 | 允许用途 |
|---|---|---|
| `Verified` | 有当前代码、Schema/约束、配置或运行证据 | Requirement、Scenario、Lock、Blocker、DDL 条件、宣称可实施 |
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

空仓无 `AGENTS.md` / `docs/` → 先跑 `scripts/scaffold.sh`（或等价）生成骨架；scaffold **不算** (a)/(b)。

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

### 建议开新对话的信号

下列情况才建议用户开新对话（或明确换目标）：

1. **同区二次修复仍失败**：同一根因面已按统一 Repair 方案修过一轮并回验仍 Fail → 停补丁，开新对话做 Diagnose 或重开 Plan。
2. **会话混入第二个不相关产品目标**：当前 Spec / 阶段尚未收束 → 先收束或 Blocked；新目标开新对话走 Shape。
3. **Verify 不通过且统一 Repair 面过大**：先交付 Verify 总结与 Repair 方案，建议新对话专跑 Repair（或先回 Plan 修订合同）。

## 实施与验收清单

### Build

- 覆盖当前完成单元（整份 Spec 或一个纵向切片）的入口、数据流、错误语义；先按事实映射核对再修改。
- 可以在实现期间做编译、格式化、静态分析等非验收性检查；不得把局部测试结果称为完成。
- 完成实现后冻结代码，列出并运行完整单元测试命令；记录全部失败而不边测边改。
- 禁止用「符合文档编号 / manifest 数量」代替行为验收（越权拒绝、成功路径）。

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

### 2. Delivery Target（`VERSION.md` / `validation.md` 声明目标）

| Target | 含义 |
|---|---|
| `code-ready` | 代码与合同就绪；**不**自动部署 |
| `dev-effective` | 在开发/预览环境真实生效 |
| `production-delivered` | 生产真实生效 |

细则与铁律见 [`evidence-contract.md`](./evidence-contract.md) Deliver Gate。

### 3. Spec Run 持久态（`spec-run.md` / `handoff.md`）

`ready | building | unit-testing | verifying | repairing | blocked | acceptance-passed`

### 4. 完成声明（阶段结束时只能选其一）

- `acceptance-passed`：每项适用验收条件都有直接证据
- `blocked`：未完成项与外部阻塞可复现
- `needs-authorization`：下一步是不可逆授权

### 相邻但不同层（禁止塞进 Delivery Target）

| 词 | 落盘 | 含义 |
|---|---|---|
| `matrix-accounted` | `validation.md` → Matrix | 所有适用 Scenario 已有终态 |
| `design-ready` | 产品包 / demand-pool | Shape 切片已确认，尚未 Plan |
| `production-restored` | Incident 记录 | 生产已止血恢复，≠ 长期根因已修 |
| 产品能力态 | `product/README` | `shaping \| design-ready \| planned \| …` |

### 仅评测（不写入交付工件）

`evals/` 路由字段 `spec_run_state`：
`not-started | continuous-build | batch-unit-test | batch-verify | unified-repair | completed | blocked | needs-authorization`
