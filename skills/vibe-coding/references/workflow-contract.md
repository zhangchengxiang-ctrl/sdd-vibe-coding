# Workflow Contract

> 一个确认的 Spec 是唯一交付单元；Rail 是同一交付目标内的动作模式。
> 纵向切片（见 Skill `spec`）是 Spec 内的可独立完成与验收单位；切片轴为真实用户入口，而非横向基础设施模块。
>
> **对人北极星（许愿 × 高质量）：** 见 [`wish-delivery.md`](./wish-delivery.md)。  
> 人：许愿 → 确认产品方案 → 按验收包自验关版 →（另批）上线。  
> AI：方案确认后自动研发编排至验收包；**禁止**自动上生产。质量内核不可省。

## 许愿式交付（对人语义 · 默认）

> 用户走愿望/方案话术时按本节；用户显式说 Rail 名（切 Spec / 开始做 / 验收）时仍可用下方「阶段闸门」经典逐步批准。

### 对人四步

1. **许愿** — 自然语言愿望；Agent 只追问改变产品结果的互斥点。  
2. **确认产品方案** — Agent 给出可确认方案（Job / 范围 / 非目标 / 主路径 / 风险）；人拍板。  
3. **AI 研发团队** — 方案确认后**自动** Plan → 按完成单元 Build → 单测 → 证伪/走查 → Repair，直至交出人类验收包。  
4. **人验收关版** — 人按验收包自验；通过后才 `acceptance-passed`；上线另走 Deploy。

### 人闸（质量两钉 + 生产另钉）

| 闸 | 人做什么 | 未过之前禁止 |
|----|----------|--------------|
| **方案闸** | 确认产品方案（「就按这个做 / 确认方案 / 按这个方案做」等） | 改业务代码、落实施 Spec（已有已确认 Spec 的 Repair、或 Polish (c) 除外） |
| **验收闸** | 按[人类验收包](../../testing/references/human-acceptance-pack.md)自验并明示通过/关版 | 宣称 `acceptance-passed` |
| **Deploy P4**（生产另钉） | 本轮明示「发布 / 上线 / 部署」并批准 P2+P3 后的执行 | 任何生产发布、reload、改 live 配置（关版通过也**不**自动授权） |

### 方案确认后的自动编排

取得方案确认后，Agent **不必再等人**说 Plan / Build / 验收，连续执行质量条至「待你验收」——**止于人类验收包，不含 Deploy**：

1. Plan 落盘（事实映射、纵向切片、强 Oracle、`check_spec`）— 可指挥侧自做或派 Codex Plan；  
   **许愿路径禁止中途「待批准」**；`codex-dispatch --unit plan --spec` 成功后须磁盘五件套（`assert_plan_artifacts`）  
2. **Build（Cursor/Claude 硬门）：** 每个纵向切片必须  
   `build_context_pack.py` → `codex-dispatch.sh --unit build`  
   （或 `wish-orchestrate.sh --spec …`）。**禁止**指挥侧同会话连做多片实现。  
   Pack 合同：[`context-pack.md`](../../dispatch-codex/references/context-pack.md)。  
3. 每片后指挥侧 ≥1 条**结构化证伪**（钉 3），见
   [`falsify-attestation.md`](../../dispatch-codex/references/falsify-attestation.md)
   （`COMMAND` + `EXIT_CODE: 0` + `VERDICT: … PASS`）；  
   `wish-orchestrate`（幂等 PASSED_SLICES + flock）/ `require-conductor-falsify` **机检**后方可下一片  
4. 全部切片工程侧收口后：Agent Verify（证伪 + 走查）→ 人类验收包  
5. Fail → 统一 Repair → 回验  

> **机检范围：** Pack→Build→结构化证伪→下一片。Plan / Verify / 验收包由指挥侧 Agent 调度；**止于验收包，不含 Deploy**。

无 `codex` CLI → 标 `blocked`（许愿 Build 编排不可用），不得假装已隔离上下文。

暂停仅限：产品互斥、不可逆、真实外部阻塞、Verified 事实与已确认方案冲突。  
**研发自动段不得**再插入「请批准 Plan/Build」类人闸（与方案闸、验收闸区分）。

## 交付语义

1. 先确认产品方案（许愿路径）或 Spec 范围（经典路径），以及验收条件、风险边界与代码事实（含入口事实映射）。
2. `Build` 按宿主能力完成实现：见下方「Harness 适配」。结束条件是当前完成单元的行为验收。
3. 实现完成后才运行一次完整的**单元测试批次**。该批次开始到结果收齐期间，冻结改码。
4. `Verify` 再统一运行适用的集成、场景、端到端及真实环境探针，收齐所有失败，并产出**人类验收包**。
5. 有实现失败时先写一份按根因分组的统一 Repair 方案；随后 `Repair` 集中修改，完成后从完整
   验收批次重新验证。
6. 只有达到当前完成单元的验收、所有剩余工作被真实外部条件阻塞、或下一步需要不可逆授权
  （含**请人按包验收**）时才结束。

## Harness 适配（完成单元）

> 产品语义不变：Spec 仍是合同边界。变的是「一次 agent 回合允许承诺并交付到哪」。  
> **默认（全宿主）：** 一次只承诺 **一个纵向切片**（含该片行为验收），以稳住质量。  
> 长程整份 Spec：用户明示「完整实施 / 连续做完 / 不要中途停」或 Codex Goal。

| 宿主 | Build 完成单元（默认） | 长程整份 Spec |
|---|---|---|
| Cursor / Claude Code | **一个纵向切片** | 用户明示整份连续，或许愿自动编排下按切片顺序推进（每片仍按完成单元收口） |
| **Codex** | **一个纵向切片** | 用户要求「完整实施 / 连续做完 / 不要中途停止」时创建持久 Goal（`/goal` 或 `create_goal`） |

### Codex 强制规则

1. **Goal 桥接**：出现「完整实施已确认 Spec」「持续完成」「不要中途停止」「按任务依赖连续推进到完整 Spec」等意图时，立即创建或请求创建持久 Goal。
2. **无 Goal 时**：只承诺当前纵向切片；切片完成后可在许愿自动编排下直接进入下一片，或向用户短报进展（经典路径可请求批准）。
3. **收口条件**：结束回复须对应完成单元的行为证据；未达则继续工具循环。
4. **阻塞判定**：仅真实外部条件可标 Blocked；见下方「证据分级」。

### 指挥施工 Harness（可选 · Cursor / Claude → Codex）

> **定位：** 指挥侧（Cursor / Claude Code）做人机交互、产品拍板与验收；
> 施工侧 Codex 用 **`gpt-5.6-sol` × medium/high** 跑有界完成单元。
> 执行细则见 Skill `dispatch-codex`。产品语义（Spec / 纵向切片 / Oracle）不变。

**触发（指挥侧用户明示其一即可）：**

- 派 Codex / 用 Codex 做 / 让 Codex 施工 / 省成本用 Codex 跑

**未触发时：** 当前宿主按上表自行完成。复杂 Plan 默认指挥侧自做。

**规则：**

1. **一次一个完成单元**：Plan（整份 Spec 落盘）或 Build **一个**纵向切片。
2. **薄派单**：只含 cwd、单元类型、输入路径、完成定义指针（如 `S1 → T-001/T-002`）、**model/effort**、**approval-policy**、**sandbox**。质量条由施工侧已装插件默认执行。
3. **模型**：Plan / Build / Goal 用 `gpt-5.6-sol`，effort 为 `medium`（默认）或 `high`（加码）。
4. **审批**：CLI 派单用 `approval_policy=never`（`codex-dispatch.sh` 写死）。
5. **沙箱**：Plan 用 `workspace-write`；Build/Goal 默认 `danger-full-access`。
6. **Oracle 齐才派 Build**：该片须有可观察的 success + failure/permission（`tests.md`）；否则先补 Plan。
7. **maker ≠ grader**：指挥侧对照仓库产物验收，并**亲自跑 ≥1 条证伪命令**（或复核其输出），不只读施工侧 `run.md`。Plan 通过条件见 `dispatch-codex` 验收清单（须有 `contract.md` 五件套）。超时后按仓库结案。  
   **禁止**派 Codex 做 Verify 主验收 / 「验到可交付」（见 [verification-loop](./verification-loop.md) 钉 3）。
8. **墙钟上限**：Plan ~15min / Build 单片 ~20min（脚本默认）；超时 exit 124 → 验收仓库。
9. **失败打回**：经 CLI 再派（可升 high）或指挥侧自做。
10. **多片长程**：可派「对该 Spec 开 Goal，完成条件=剩余切片+验证命令」；effort=**high**；指挥盯里程碑与证据。
11. **工具路径**：`skills/dispatch-codex/scripts/codex-dispatch.sh`（或 `make codex-dispatch`）。包装缺失时裸 `codex exec`（自带 timeout + never）。皆失败 → 对人说明 Blocked。  
    **硬门：** 派发只经该 CLI；不经 `user-codex` / `CallMcpTool`。模型仅 `gpt-5.6-sol` × medium|high。

**对人前台：** 只说目标、进展、证据、要你决定；可简说「复杂活用 Codex Sol」。不暴露 dispatch 内部词，除非用户追问。

## 证据分级

技术判断标为以下之一，并写入 Spec / 对话结论：

| 级别 | 含义 | 用途 |
|---|---|---|
| `Verified` | 有当前代码、Schema/约束、配置或运行证据 | Requirement、Test、Lock、Blocker、DDL 条件、宣称可实施 |
| `Unverified` / `Assumption` | 尚未证明 | 仅写在「待验证」 |

冲突时：以代码与数据库事实为准，先修 Spec 或标缺陷，再继续 Build。

## 写代码前的硬闸

在改业务代码（应用源码、配置契约、运行时行为）之前，须满足至少一项：

| # | 条件 |
|---|---|
| **(a)** | 已存在**已确认**的实施 Spec：`docs/specs/<id>/`（含 Verify 后转入的 Repair） |
| **(b)** | 用户本轮**明示**「开始做 / 实现 / 按这个来 / 构建」**或**「就按这个做 / 确认方案 / 按这个方案做 / 按这个产品方案做」，且产品方案/切片已确认 |
| **(c)** | 用户本轮**明示**轻量 UI 授权（见下「Polish 档」），且变更判定为 **非 material** |

demand pool 条目、`modules/` 设计稿、聊天清单或截图不算 (a)/(b)/(c)。  
**(b) 中「确认方案」** = 方案闸通过，授权进入上方「方案确认后的自动编排」（含 Plan 落盘与后续 Build）；**不等于** Deploy / 上线。

**(a)/(b)/(c) 皆无时，本轮只做：**

1. 写 `docs/product/`（demand pool / modules 草稿 / 理解卡 / **产品方案**沉淀）；
2. 只读调查宿主代码与 `AGENTS.md`。

经典路径：Spec 由用户批准进入 Plan 后创建。  
许愿路径：方案确认后 Agent 直接落盘 Spec 并编排，无需再等人说「切 Spec」。  
空仓或未 scaffold 的宿主：先跑 `scripts/scaffold.sh`（见 [docs-root.md](./docs-root.md)）。scaffold 不算 (a)/(b)/(c)。

### Polish 档（(c) · 可不新开 Spec）

> 功能已可用、只动前端交互/抛光时用。细则与 material 门见
> [`change-control.md`](./design-standards/change-control.md)；缩读义务见
> [`LOAD-MAP.md`](./design-standards/LOAD-MAP.md) 豁免表。

**明示授权话术（命中其一即可，须本轮）：**

- polish / 抛光 / 前端小改 / 交互微调  
- 按 refinement 修 / 按走查修 P0–P1 / 修本批走查  

**仍不算 (c)：**「优化体验」「应该更好看」「走查一下」「讨论产品」「设计方案」
→ 停留 Shape 或 Verify，见 Skill `design` / `testing`。

**Agent 义务（走 (c) 时）：**

1. 开改前声明 `change: refinement`（默认）并做 material 判定；  
2. **material**（主路径/默认 CTA/导航/权限可见性/shell 等）→ **停**，升格 Shape 或补 Spec，不得假装 polish；  
3. 非 material → 不新开 Spec、不写完整产品包；按 LOAD-MAP 豁免缩读 + 改动面最小验证；  
4. 完成单元 = 本轮点名的控件/走查条目（默认含 P0–P1；P2 仅用户点名才做）。

trivial 豁免（笔误 / 单点 CSS / 已知单控件 bug）见 [`vibe-coding/SKILL.md`](../SKILL.md)，可并入 (c) 或单独最小修复。

## 模式与权限

| 模式 | 职责 | 代码写入 |
|---|---|---|
| Shape | 澄清产品结果与范围 | 否 |
| Plan | 形成 Spec、场景与验收策略 | 否 |
| Build | 实现确认 Spec 的全部内容 | 是 |
| **Polish** | 非 material 前端小改 / 走查抛光（硬闸 (c)；不新开 Spec） | 是（仅豁免范围） |
| Verify | 只运行批量验收、记录结果并归类失败 | 否 |
| Repair | 按统一方案集中修复已收齐的失败 | 是 |
| Deploy | 目标环境发布：P0–P6（证据 → 发布+验证方案 → 批准 → 执行 → 冒烟关版） | 仅经批准的发布动作；不写新功能 |
| Diagnose | 定位原因和证据 | 否，除非用户明确要求修复 |
| Incident | 经授权恢复生产 | 仅最小止血 |

## 薄提示词原则（质量条在插件）

> 用户用自然语言表达**意图**与**关键选择**。下列质量条由插件默认执行。  
> 许愿路径细节见 [`wish-delivery.md`](./wish-delivery.md)。

| 用户只需说 | 插件默认做到 |
|---|---|
| 「我希望…」「我想要…」（愿望） | Shape：出**产品方案**卡；不改业务代码；请人确认方案 |
| 「就按这个做 / 确认方案 / 按这个方案做」 | **方案闸通过** → Plan→**每片 Context Pack→Codex Build**→证伪→Verify→**人类验收包**；请人自验 |
| 「按这个产品包切 Spec / Plan / 拆到能编码」 | Plan：事实映射 → 纵向切片 → 完整 `tests.md`；落盘；齐套后进入 Build（许愿下自动；经典路径给批准卡） |
| 「批准了，开始做 / 实现」（或粘贴 Build 提示词） | Build：默认**一个**纵向切片（含行为验收）；明示整份连续才连做 |
| 「polish / 按 refinement 修 / 修本批走查 P0–P1」 | **Polish 档**：非 material 直接改；不新开 Spec；material 升格 Shape |
| 「派 Codex / 用 Codex 做」 | Cursor/Claude：指挥施工（Skill `dispatch-codex`）；一次一单元；sol×medium/high |
| 「完整实施 / 不要中途停 / 把整份 Spec 做完」 | 按切片顺序连续推进；Codex：立即创建持久 Goal |
| 「验收一下」 | Agent Verify + **人类验收包**；先证伪；禁纯 smoke；**不**替人关版 |
| 「通过了 / 没问题 / 可以关版」 | 人验收闸通过 → `acceptance-passed`；`VERSION=archived`；**搬到** `docs/specs/archive/<id>/`；更新索引 / gap-closed 指针；询问是否 Deploy |
| 「发布 / 上线 / 部署」 | Deploy：P2+P3 先于执行；须人验已过（或明文豁免）；P6 目标环境冒烟；health ≠ 交付 |

插件已默认覆盖：产品方案、事实映射、纵向切片、Verified 才进 Lock、Given/When/Then、证伪与走查、
人类验收包、真实阻塞判定、短交付卡、发布 P0–P6 门禁（见 Skill `deploy`）。

### Plan 落盘授权

下列任一表述 = **已批准进入 Plan 并创建/写入 `docs/specs/<id>/`**：

- 切 Spec / 走 Plan / 拆解实施 / 做到可以编码 / 按产品设计切版 / 重切 Spec  
- **就按这个做 / 确认方案 / 按这个方案做**（许愿路径：方案确认后直接落盘并继续编排）

Plan 阶段内：调查 → **直接落盘** `VERSION`/`contract`/`tests`/`plan`/`run`。

**许愿路径：** Plan 齐套且 `check_spec` 通过后**直接进入 Build 编排**，不必再等人粘贴 Build 提示词；
前台只短报「开始实现」与当前切片。  
**经典路径：** 结束时出进入 Build 的批准卡；**可**附「新对话 Build 提示词」（便于人手动开短聊），
同对话「批准 Build / 开始做」仍有效。

经典提示词模板（仅经典路径需要时给出）：

```text
批准 Build。Spec：<SDD docs root>/specs/<id>/
按 plan.md 切片 <S1→S2→… 或 整份> 实现；本对话只做 Build（完成后只报实现完成）。
```

**跨阶段仍须人批准的：** 方案闸（Shape→研发）、验收闸（→`acceptance-passed`）、
**Deploy P4** 与其他生产动作。  
许愿路径下 Plan→Build→Agent Verify→验收包 **不**再逐步拦人。

## 阶段闸门

> 本节是"何时连续、何时暂停、跨阶段如何总结与批准"的唯一真源。其他 Skill 只引用本节。

### A. 许愿路径（默认优先识别）

1. Shape 出产品方案 → **等人确认方案**。  
2. 方案确认后 → 自动 Plan → Build（按完成单元）→ Agent Verify → 人类验收包 → **等人验收**（**不含** Deploy）。  
3. 人验收通过 → `acceptance-passed`；**询问**是否上线；须本轮明示「发布/上线」+ Deploy P4 才执行。  
4. 阶段内暂停条件同下「阶段内暂停」。

### B. 经典路径（用户说了 Rail 名）

1. **阶段内连续**：每个阶段由当前 agent 一次性连续完成自身职责。
2. **跨阶段闸门**：`Shape → Plan → Build → Verify → Deploy → Repair` 每一次阶段切换前，先向用户总结本阶段
   的目标、完成内容、证据、限制与建议的下一阶段，取得**明确批准**后才进入下一阶段。
   Deploy 另遵 P0–P6：L1/L2 须先批准 P2+P3 再执行。
3. **阶段内暂停**：仅在产品选择互斥、破坏性/不可逆动作、用户本人才能完成的外部操作、或**已 Verified**
   的事实与已确认需求冲突且将改变交付结果时询问用户。
4. **纠错后续**：用户指出错误或要求继续时，先纠正并继续执行下一可执行步骤。需要暂停开发时，用户须明确说停。

### 阶段内默认动作

| 场景 | 正确动作 |
|---|---|
| X 属本阶段 / 本 Spec | 直接做完 X（commit / push / 部署除外，须明示授权） |
| 还差若干项 | 本阶段范围内 → 做到齐；经典跨阶段 → 按闸门总结并请求批准；许愿研发段 → 连续做 |
| In Scope 未完成项 | 做完或记为真实 Blocked |
| Shape 下清单已清楚 | 沉淀产品方案 / demand pool；走方案闸后再改码 |
| 用户已确认方案 | **直接** Plan 落盘并编排 Build→…→人类验收包 |
| 路径字段是绝对路径 | 先按业务 ID / owner 关系验证能否派生根；仅 Verified 无法派生才可阻断 |
| 未达完成单元 | 继续做，不以进度汇报收口 |
| 用户已说切 Spec/Plan（经典） | **直接落盘**；齐后出批准卡（可附 Build 提示词） |
| 无产品互斥 | 按默认质量条执行；理解偏差在交付卡里说明 |

### 建议开新对话 / 干净工人的信号

> 目的是稳住**质量**（避免上下文腐烂）。许愿 Build 的 Codex 派发是**硬门**，不是建议。

0. **许愿 Build 切片**：必须 Context Pack + `codex-dispatch` / `wish-orchestrate`（见上）。  
1. **经典 Plan 齐套 → Build**：可开新对话；或同样走 Pack+Codex。  
2. **同区二次修复仍失败**：停补丁，开新对话 Diagnose 或重开 Plan。  
3. **会话混入第二个不相关产品目标**：先收束或 Blocked；新目标新开 Shape。  
4. **Verify / 走查**：指挥侧执行，勿派 Codex 主验收。  
5. **人验收**：把验收包交给人。

## 实施与验收清单

### Build

- 覆盖当前完成单元（**默认一个纵向切片**）的入口、数据流、错误语义；先按事实映射核对再修改。
- 用户只说「开始做」或方案确认后自动编排且未点名切片时：取 `plan.md` **第一个未完成**纵向切片；明示「整份 Spec」才按序连做（每片仍收口）。
- **新建 / 大改用户可见页面**：先读 [LOAD-MAP.md](./design-standards/LOAD-MAP.md)（字段门控 + 场景必读）与 [product-judgment.md](./design-standards/product-judgment.md)（Job Brief 先于视觉）；需要时用 [ui-page-gate.md](./design-standards/ui-page-gate.md) 评审模板；输出前扫 ai-tells。
- 实现期间可做编译、格式化、静态分析等非验收性检查；完成以行为验收为准。
- 按需编写/更新自动化测试（分层与用语见 [automated-tests.md](./automated-tests.md)）；完成实现后冻结代码，列出并运行完整单元测试命令；记录全部失败后统一 Repair。
- **有自动化 → 先红后绿**：红/绿命令与退出码写入 `run.md`「红绿证据」；Polish/trivial/无自动化写 `N/A · …`。
- 行为验收优先：越权拒绝、成功路径等可观察断言。
- 切片/完成单元收口：短报告「做成了什么 / 证据在哪 / 下一个切片」。
- **硬门：** Build 轨只可报「实现完成」；禁止宣称「可交付」/ `acceptance-passed`（属验收闸）。
- **硬门：** Build 轨禁止执行 Deploy P5/P6 或读写生产 deploy/reload；须路由 Skill `deploy` 并完成本轮 P4。
- **硬门（钉 2 · Oracle 冻结）：** Build/Repair **禁止**修改 Spec `tests.md` 与产品包验收矩阵（`06-acceptance-matrix` 等）。改 Oracle 只能回 Plan + 用户批准。宣称实现完成时 `run.md` 须有 `oracle-freeze: intact`（`check_spec` 机检）；指挥侧 diff 不得含上述 Oracle 文件。

### Verify

- 在不修改实现的前提下，**先按** testing [`falsify-checklist`](../../testing/references/falsify-checklist.md) **证伪**，再跑完整集成/场景/端到端/真实环境探针。
- **必须**产出 [`human-acceptance-pack`](../../testing/references/human-acceptance-pack.md)（怎么验 + 验什么 + AI 旁证 + 限制）。
- Evidence 写 `kind=`（见 evidence-contract §1.1）；工程 Pass 禁止仅 window-smoke / health。
- 同会话不得把 Build 冒烟原样誊为 Verify Pass。
- 结束信号与三钉：[`verification-loop.md`](./verification-loop.md)。
- **硬门：** Agent 工程证伪通过后，状态为 `awaiting-human-acceptance`；前台请人按包自验。  
  **禁止**在无人明示「通过 / 没问题 / 关版」前写 `acceptance-passed` 或对用户说「可关版 / 可交付」。
- **硬门（钉 1）：** 人验收通过、宣称 `acceptance-passed` / 可交付前须 `make verify-deliver` exit 0，`run.md` 有 `verify-deliver: ok · <时间>`。
- **硬门（钉 3）：** Verify 默认指挥侧执行；禁止派 Codex 做主验收。
- 整体/系列/多角色 material 验收：[`version-acceptance-matrix.md`](../../testing/references/version-acceptance-matrix.md)；禁 Build Pass 冒充系列 Pass。
- 报告每个失败的命令、结果、影响范围和初步根因；环境、账号、主机或外部依赖失败须有原始证据。
- 若存在可修实现问题，输出一份 Repair 方案：根因分组、修改面、风险、回归矩阵，然后进入 Repair。

### Repair

- 只按已记录的统一 Repair 方案修改；若发现新根因，补入同一方案。
- 修复完成后重跑完整的单元与 Verify 批次。
- **同钉 2：** Repair 禁改 `tests.md` / 验收矩阵 Oracle。

## 完成声明

最终只能声明以下之一（枚举见下方「状态词汇」第 4 层）。

完成声明须对应当前 Delivery Target 的全量证据。

## 状态词汇（唯一真源）

> 四层分表维护。其它文档只引用本节；`matrix-accounted` / `design-ready` /
> `production-restored` 不是 Delivery Target。

### 1. Version 状态（`VERSION.md`）

`draft | ready | in-progress | verifying | blocked | done | archived | cancelled`

| 状态 | 目录 | 含义 |
|---|---|---|
| 施工态（`draft`…`done`） | `docs/specs/<id>/` | 施工队列；`check_spec --all` 只扫这里 |
| `archived` | `docs/specs/archive/<id>/` | 人验关版后**必须搬入**；勿只改状态位留在原地；勿重开 |
| `cancelled` | `docs/specs/archive/<id>/` 或删除（宿主自定） | 明确不做 |

**关版归档（人明示通过/关版后，同回合必做）：**

1. `make verify-deliver` + `run.md` → `acceptance-passed`
2. `VERSION.md` → `archived`（变更记录写搬迁）
3. `git mv docs/specs/<id> docs/specs/archive/<id>`（无 git 时普通 `mv`）
4. 更新 `specs/README`（若有）、gap-closed / demand-pool 指针
5. 询问是否 Deploy（**不**自动上生产）

`done` 仅作同回合瞬态（人验过、尚未搬出）；不得隔会话留在 `docs/specs/<id>/`。

### 2. Delivery Target（`VERSION.md` / `run.md` 声明目标）

| Target | 含义 |
|---|---|
| `code-ready` | 代码与合同就绪；**不**自动部署 |
| `dev-effective` | 在开发/预览环境真实生效 |
| `production-delivered` | 生产真实生效（须目标环境 P6 冒烟通过；见 Deliver Gate） |

细则见 [`evidence-contract.md`](./evidence-contract.md) Deliver Gate。

### 3. Spec Run 持久态（`run.md` / `handoff.md`）

`ready | building | unit-testing | verifying | repairing | blocked | awaiting-human-acceptance | acceptance-passed`

> `awaiting-human-acceptance`：Agent 工程证伪与人类验收包已就绪，**待人按包自验**。  
> 人明示通过/关版后才可写 `acceptance-passed`。

### 4. 完成声明（阶段结束时只能选其一）

- `awaiting-human-acceptance`：工程侧已证伪并交出验收包，待人验收（许愿路径常态收口）
- `acceptance-passed`：人已按包确认通过，且适用关版条件有直接证据
- `blocked`：未完成项与外部阻塞可复现
- `needs-authorization`：下一步是不可逆授权

### 相邻但不同层（不写入 Delivery Target）

| 词 | 落盘 | 含义 |
|---|---|---|
| `matrix-accounted` | `run.md` → 终态 Matrix | 所有适用 Test 已有终态 |
| `design-ready` | 产品包 / demand-pool | **产品方案已确认**（方案闸通过），可进入研发自动编排 / Plan |
| `production-restored` | Incident 记录 | 生产已止血恢复，≠ 长期根因已修 |
| 产品能力态 | `product/README` 能力地图 | `shaping \| design-ready \| planned \| partially-delivered \| accepted \| archived` |
| demand 条目态 | `demand-pool.md` | `draft \| shaping \| design-ready \| planned \| delivered \| parked` |

能力态与 demand 条目态分表维护；能力态用 `design-ready`（不用已废弃的 `ready-for-plan`）。

## 对人前台

只用「我理解的目标 / 当前进展 / 交付结果 / 需要你决定」。  
许愿路径优先说：产品方案、研发进展、**请你按验收包自验**、关版/上线是否批准。  
内部步骤、Harness 细节、dispatch / Subagent 参数默认不展示；用户追问再放技术详情。

### 仅评测（不写入交付工件）

`evals/` 路由字段 `spec_run_state`：
`not-started | continuous-build | batch-unit-test | batch-verify | unified-repair | completed | blocked | needs-authorization`
