---
name: vibe-coding
description: >-
  Spec-Driven Delivery（SDD）跨端主入口。仅在用户显式进入 SDD 交付轨时使用：
  /vibe-coding 或 @vibe-coding、许愿、确认方案、就按这个做、切 Spec、关版、
  polish/抛光/按 refinement 修、初始化项目或接入存量（SDD 冷启动）、
  派 Codex/用 Codex 做、显式人类验收或生产发布/上线/部署。
  触发后须先 Read 本 SKILL.md，再读宿主 AGENTS.md；先判 project.kind。
  禁止因普通调研、读文档、SSH、取数、看 session、修 bug、实现功能、排障、
  优化体验、我想要/聊聊/拆解等日常请求而加载。子轨由本入口路由；
  Codex 指挥见 dispatch-codex。
---

# Vibe Coding

**北极星：** [许愿式高质量交付](./references/wish-delivery.md) — 人定方案；无 UI 机器关版 / 有 UI 人点验；AI 跑质量内核。  
用户表达**意图**与关键选择即可；拆分、实现、单测、走查由插件默认编排。  
薄提示词与闸门见 [`workflow-contract.md`](./references/workflow-contract.md)。  
可选指挥施工见同文件「指挥施工 Harness」与 Skill [`dispatch-codex`](../dispatch-codex/SKILL.md)
（`gpt-5.6-sol` × medium/high）。  
Cursor 会话硬闸另见 install 投影的 `~/.cursor/rules/sdd-*.mdc`。

## FIRST ACTION（硬门）

### 0. 项目类型（先于一切轨）

**禁止默认 `project.kind=software`。** 仅三档：`software` | `plugin` | `other`。  
先读 `AGENTS.md` / 可选 `PROJECT.md`，否则探测。见 [`project-kind.md`](./references/project-kind.md)。

| 有效 kind | 本 Skill |
|---|---|
| `software` | 下方「software 宿主」 |
| `plugin` | 维护本插件：读 ARCHITECTURE；改 skills/templates/scripts；笔记 plans/ |
| `other` | **放手**（停用编码硬闸，不接管） |

### software 宿主

**仅当**本轮为显式 SDD 意图（见上方 description / `sdd-vibe-entry` 高信号列表）时加载本 Skill：

1. **第一个工具调用** = Read 本文件（`vibe-coding/SKILL.md`）；
2. 再读宿主 `AGENTS.md`（含 SDD docs root 与 `project.kind`）；
3. 判轨后再读下方合同。未完成 1–2 → 禁止改业务代码 / 禁止可交付 / 禁止生产部署。

非显式 SDD（调研、运维、取数、探索问答等）→ **不要**加载本 Skill；用域内 skill / 普通工具。

## 10 行操作卡（日常）

1. **FIRST ACTION**：判 `project.kind` → 仅 software 才走宿主轨 → `AGENTS.md`。
2. **判轨**：基线未齐 → 冷启动；愿望/讨论 → Shape 出产品方案；**确认方案** → 许愿自动编排；经典 Rail 名 → 逐步闸门；Deploy / Diagnose / 派 Codex 各走专轨。
3. **Shape**：只写 `product/`；LOAD-MAP → product-judgment；产出**产品方案**并请人确认（见 wish-delivery）。
4. **方案确认后（许愿半自动）**：Plan + `check_spec` → **打包 D → edit-wave Codex**（`wish-orchestrate` 波次+锁）→ **verify-wave 证伪** → Verify → **证据卡或验收包**（不含 Deploy）。
5. **Build**：一次一个 D（272K）；测前冻结；禁「可交付」；禁生产 Deploy；钉 2 Oracle 冻结 + 红绿证据。
6. **Polish**：明示 polish/走查抛光 → 非 material 直改；material → Shape。
7. **Verify**：证伪；无 UI → 证据卡+机器关版；有 UI → 验收包 + `awaiting-human-acceptance`；钉 1/3。
8. **关版**：`acceptance-passed` + verify-deliver + 搬入 `docs/specs/archive/<id>/`；再问是否 Deploy。
9. **Deploy**：P1→P2+P3→P4→P5→P6；禁仅 health；须人验已过（或明文豁免）。
10. **派 Codex**：CLI `codex-dispatch.sh`；一次一个 D；禁 Codex 主验收；改文档不派。

## 必读

在完成 **FIRST ACTION** 后，按当前问题读取（**SDD docs root** 见 [docs-root.md](./references/docs-root.md)）：

- [Wish Delivery](./references/wish-delivery.md)：许愿四步与质量内核；
- [Runtime Hooks](./references/runtime-hooks.md)：可选 Cursor/Claude 写码/Deploy 硬闸 + 旅程状态机；
- [Project Kind](./references/project-kind.md)：`project.kind` 枚举、探测、非 software 停用编码轨；
- 冷启动 → Skill `design` → [`project-init.md`](../design/references/project-init.md)（Init/Onboard；推断确认 ≤5 问）；
- [Workflow Contract](./references/workflow-contract.md)：许愿闸门、授权、薄提示词、Harness、完成语义；
- [Workspace Contract](./references/workspace-contract.md)：Local、Worktree、分支和 PR（含托管 / CLI Worktree）；
- [Evidence Contract](./references/evidence-contract.md)：验证层次、**Evidence Kind**、行为优先、Deliver Gate 和完成声明；
- [Verification Loop](./references/verification-loop.md)：三钉（关版戳 / Oracle 冻结 / maker≠grader）、结束信号、反放水；
- [Human Acceptance Pack](../testing/references/human-acceptance-pack.md)：无 UI 证据卡 / 有 UI 人点验包；
- [Design Standards](./references/design-standards/README.md)：入口 **[LOAD-MAP](./references/design-standards/LOAD-MAP.md)**；
- 发布 / 上线 → Skill [`deploy`](../deploy/SKILL.md)（P0–P6）；
- Diagnose / Incident → Skill `debug`。

文中 `docs/product`、`docs/specs` 等路径均相对 `AGENTS.md` 的 SDD docs root（默认 `docs`）。

## 路由

| 用户意图（自然语言即可） | 当前模式 |
|---|---|
| 初始化项目 / 新开 / 立项 / 接入存量 / 基线空或刚 scaffold | **冷启动** → Skill `design` → `project-init`（Init 或 Onboard） |
| 我希望 / 我想要 / 澄清愿望与产品方向（基线已齐） | Shape → Skill `design`（出**产品方案**） |
| **就按这个做 / 确认方案 / 按这个方案做** | **许愿研发编排**：Plan→**打包 D→edit-wave Codex**→Verify→证据卡或验收包 |
| **派 Codex / 用 Codex 做 / 让 Codex 施工**（且当前在 Cursor/Claude） | **指挥施工** → Skill `dispatch-codex`（一次一个 D；sol×medium/high） |
| 切 Spec / Plan / 按产品包拆到能编码 | Plan → Skill `spec`（**直接落盘**） |
| Spec 批准了 / 开始做 / 实现 | Build（默认首个未完成 D） |
| polish / 抛光 / 前端小改 / 交互微调 / 按 refinement 修 / 修本批走查 | **Polish**（写码硬闸 (c)；非 material；见下） |
| 验收 / UX 走查 | Verify → Skill `testing`（证据卡或验收包 + 证伪；禁派 Codex 主验收） |
| 通过了 / 没问题 / 可以关版 | 有 UI 验收闸 → `acceptance-passed` + 归档（须 verify-deliver） |
| 发布 / 上线 / 部署 / 发版 / 生产部署 | Deploy → Skill `deploy`（P0–P6；先方案后执行） |
| 只定位复杂或线上问题 | Diagnose |
| 紧急恢复生产 | Incident |

已在 **Codex** 会话中时：忽略「派 Codex」，按纯 Codex Harness 自行 Plan/Build。

### 轻量 UI 三档（可跳过完整 Shape→Plan）

> 写码授权细节真源：[`workflow-contract.md`](./references/workflow-contract.md)（a/b/c）。  
> material / refinement 真源：[`change-control.md`](./references/design-standards/change-control.md)。  
> 缩读义务：[`LOAD-MAP.md`](./references/design-standards/LOAD-MAP.md) 豁免表。

| 档 | 何时 | 授权 | 做法 |
|---|---|---|---|
| **trivial** | 纯笔误 / 单点 CSS / 已知单控件 bug | 可并入 (c)，或用户点名即修 | 最小 diff + 对应验证；跳过产品包与 Spec |
| **Polish** | 非 material 交互/抛光（五态、错缝、文案微调、a11y label、走查 P0–P1 抛光项） | 本轮明示 (c) 话术 | 声明 `change: refinement`；LOAD-MAP 豁免缩读；**不**新开 Spec / 完整产品包 |
| **升格** | material：主任务路径、默认 CTA/筛选、导航、跨面入口、权限可见性、shell、发布模型 | 无 (c) 捷径 | Shape 或更新既有 Spec 后再 Build |

触及导航结构、跨表面入口、发布模型或角色可见性 → **升格**，不得用 polish 绕过。  
`workspace-contract.md` 的「trivial / small fix」只决定选 Local，不单独跳过 Shape。  
「优化体验」「应该支持…」无 (c) 话术 → 仍停留 Shape。

**闸门摘要：** 许愿路径 = 方案闸 + 验收闸（中间自动编排）。经典路径 = 逐步跨阶段批准。  
Deploy P4 与生产动作不可跳过。详见 [`workflow-contract.md`](./references/workflow-contract.md)。

## 持续交付规则

1. 建立一个用户可判断的交付目标、范围和**当前 D（派发单元）**；
2. 读取当前事实并执行下一可执行步骤；许愿路径在方案确认后连续编排至关版分叉；
   指挥模式下由 `dispatch-codex` 按 272K 打包派单；一聊一个 edit-wave；
3. Build 完成当前完成单元后只跑完整单元测试批次；冻结改码；**不宣称可交付**；
4. Verify **先证伪**再跑集成/场景/真实通道；产出**证据卡或人类验收包**；Evidence 写 `kind=`；
5. 所有测试结束后先形成一份统一修复方案，再进入 Repair 集中修改并回验；
6. 许愿路径：无 UI → 机器关版 `acceptance-passed`；有 UI → `awaiting-human-acceptance` 后人确认。  
   经典路径：每阶段总结并取得批准再进入下一阶段。

Spec 范围以 `VERSION.md`、`contract.md`（含事实映射）、`tests.md`（完整用例）、`plan.md`、
`run.md` 与代码共同确定；先读这些文件，按需再读其他材料。

暂停理由仅限：完成单元达成、真实外部阻塞、不可逆授权、**方案闸 / 验收闸**。生产授权只限制生产动作。

用户纠错或要求继续时：先改行为，再给下一可执行步骤。

## 用户前台

只用“我理解的目标”“当前进展”“交付结果”“需要你决定”说明事实。  
许愿路径优先：产品方案确认、研发进展、**证据卡或请按包点验**、关版/上线。  
仅在确实需要用户做决定、授予授权或处理真实 Blocker 时向用户提问。  
**硬门：** 不得把 Agent 可自跑的打开/硬刷/确认是否正常写成「下一步」；有 UI 人验除外（验收包内步骤）。无 UI 禁止请人再跑同一脚本。

最终交付说明：用户目标是否完成、真实验证、未通过/受阻项、环境状态和后续授权（如有）。
完成声明须对应当前 Delivery Target 的全量证据；结束信号见 [verification-loop](./references/verification-loop.md)。
