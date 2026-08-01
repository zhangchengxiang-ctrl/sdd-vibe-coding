---
name: vibe-coding
description: >-
  Spec-Driven Delivery 跨端主入口（Cursor / Claude / Codex）。触发即须先 Read 本 SKILL.md，
  再读宿主 AGENTS.md。触发：我希望 / 优化体验 / 讨论产品 / 聊聊方向 / 拆解 /
  学习这个 repo / 排期 / 准备实施 / 切 Spec / 开始做 / 实现 / 构建 / 验收 /
  UX走查 / 发布 / 上线 / 部署 / 修复 / 排障 / vibe / 派 Codex / 用 Codex 做。
  未明示开始做且无已确认 Spec → 只写 docs/product/，不改业务代码。质量条默认执行。
  Codex：整份 Spec 须 Goal；普通回合只承诺一个纵向切片。Cursor/Claude 明示派 Codex
  时走指挥施工（Skill dispatch-codex）。
---

# Vibe Coding

用户只需表达**意图**和关键选择；质量条、调查顺序、切片方式与验收标准由插件默认执行。
内部步骤只用于推进工作，不能成为最终回复、要求用户重新发起或中止当前交付的理由。
薄提示词对照见 [`workflow-contract.md`](./references/workflow-contract.md)「薄提示词原则」。
可选指挥施工见同文件「指挥施工 Harness」与 Skill [`dispatch-codex`](../dispatch-codex/SKILL.md)
（`gpt-5.6-sol` × medium/high）。
Cursor 会话硬闸另见 install 投影的 `~/.cursor/rules/sdd-*.mdc`。

## FIRST ACTION（硬门）

命中本 Skill 任一触发语时：

1. **第一个工具调用** = Read 本文件（`vibe-coding/SKILL.md`）；
2. 再读宿主 `AGENTS.md`（含 SDD docs root）；
3. 判轨后再读下方合同。未完成 1–2 → 禁止改业务代码 / 禁止可交付 / 禁止生产部署。

## 10 行操作卡（日常）

1. **FIRST ACTION**：Read 本 Skill → 宿主 `AGENTS.md`。
2. 判轨：Shape / Plan / Build / Verify / Deploy / Diagnose / Incident（或「派 Codex」）。
3. Shape：只写 `product/`；有 UI 先读 design-standards **LOAD-MAP**（字段门控唯一真源）。
4. Plan：落盘五件套；跑 `check_spec`；通过才请求 Build。
5. Build：只做当前完成单元；测前冻结改码；改存量 UI 先 change-control（见 LOAD-MAP）。  
   **硬门：** 只可报「实现完成」；禁「可交付」；**禁 P5/P6 生产动作**（须 Deploy 轨 + P4）。
6. Verify：先证伪再写 Pass；`kind=` Evidence；不改 Oracle；先交付卡；有界轮次 + Visual QA。  
   **硬门：** 未跑证伪 → 禁止对用户说可交付。
7. Deploy：P1 证据 → P2+P3 方案 → 批准 → 执行 → P6 目标环境冒烟关版（禁仅 health）。
8. Fail → 统一 Repair，再回验整批。
9. 派 Codex：先 `check_spec`；经 CLI `codex-dispatch.sh`；sol×medium|high + approval never。  
   **硬门：** 不经 `user-codex` / `CallMcpTool`；指挥侧重跑 ≥1 条证伪。
10. 仅 Verified 进 P0/Lock；代码事实优先于文档自洽。深合同按需再读下方「必读」。

## 必读

在完成 **FIRST ACTION** 后，按当前问题读取（**SDD docs root** 见 [docs-root.md](./references/docs-root.md)）：

- [Workflow Contract](./references/workflow-contract.md)：目标、授权、**薄提示词**、**Harness 适配**（含可选指挥施工）、证据分级、推进和完成语义；
- [Workspace Contract](./references/workspace-contract.md)：Local、Worktree、分支和 PR（含托管 / CLI Worktree）；
- [Evidence Contract](./references/evidence-contract.md)：验证层次、**Evidence Kind**、行为优先、Deliver Gate 和完成声明；
- [Design Standards](./references/design-standards/README.md)：入口 **[LOAD-MAP](./references/design-standards/LOAD-MAP.md)**（字段门控 / 豁免 / 场景必读）；AGENTS/PRODUCT+DESIGN.md 可覆盖；
- 发布 / 上线 → Skill [`deploy`](../deploy/SKILL.md)（P0–P6）；
- Diagnose / Incident → Skill `debug`。

文中 `docs/product`、`docs/specs` 等路径均相对 `AGENTS.md` 的 SDD docs root（默认 `docs`）。

## 路由

| 用户意图（自然语言即可） | 当前模式 |
|---|---|
| 澄清愿望、体验和产品方向（含聊聊/辩论、拆解 repo） | Shape → Skill `design` |
| **派 Codex / 用 Codex 做 / 让 Codex 施工**（且当前在 Cursor/Claude） | **指挥施工** → Skill `dispatch-codex`（一次一单元；sol×medium/high） |
| 切 Spec / Plan / 按产品包拆到能编码 | Plan → Skill `spec`（**直接落盘**） |
| Spec 批准了 / 开始做 / 实现 | Build（Codex 默认首个纵向切片；指挥模式下改派 Codex） |
| 验收 / UX 走查 | Verify → Skill `testing`（指挥模式下建议指挥侧验收，maker ≠ grader） |
| 发布 / 上线 / 部署 / 发版 / 生产部署 | Deploy → Skill `deploy`（P0–P6；先方案后执行） |
| 只定位复杂或线上问题 | Diagnose |
| 紧急恢复生产 | Incident |

已在 **Codex** 会话中时：忽略「派 Codex」，按纯 Codex Harness 自行 Plan/Build。

### trivial 豁免（可跳过完整 Shape→Plan）

同时满足下列条件时，可不走完整 `Shape → Plan`，直接最小修复并做对应验证：

1. 纯笔误；或
2. 单点 CSS；或
3. 已知 bug；
4. **且**不改产品合同、导航结构、跨表面入口、发布模型、角色可见性。

触及导航结构、跨表面入口、发布模型或角色可见性 → 走 Shape（或已有 Spec 的 Plan/Build）。
`workspace-contract.md` 的「trivial / small fix」只决定选 Local，不跳过 Shape。写代码前硬闸见
[`workflow-contract.md`](./references/workflow-contract.md)。

每个阶段在自身范围内连续完成；`Shape → Plan → Build → Verify → Deploy → Repair` 的跨阶段切换须先总结并
取得用户明确批准。闸门与宿主完成单元见 [`workflow-contract.md`](./references/workflow-contract.md)。
（Deploy 可紧接 Verify 后生产交付，或用户单独要求「上线」时进入；P4 批准不可跳过。）

## 持续交付规则

1. 建立一个用户可判断的交付目标、范围和**当前完成单元**（整份 Spec 或一个纵向切片）；
2. 读取当前事实并执行下一可执行步骤；Codex 上整份 Spec 长程交付须先 Goal（见合同 Harness 节）；
   指挥模式下由 `dispatch-codex` 派单，指挥侧验收后再向用户结案；
3. Build 完成当前完成单元的实现后，只运行完整的单元测试批次；测试开始后冻结改码；**不宣称可交付**；
4. Verify **先证伪**再跑集成/场景/真实通道；完整收集 Fail；Evidence 写 `kind=`；**行为/权限 Oracle 优先于文档自洽**；
5. 所有测试结束后先形成一份统一修复方案，再进入 Repair 集中修改并回验；
6. 每个阶段完成后记录目标、完成内容、证据与限制，先向用户总结并取得明确批准，再进入下一
   阶段；阶段内只在完成单元达成、剩余步骤真实外部阻塞，或下一动作需要不可逆授权时才暂停。

Spec 范围以 `VERSION.md`、`contract.md`（含事实映射）、`tests.md`（完整用例）、`plan.md`、
`run.md` 与代码共同确定；先读这些文件，按需再读其他材料。

暂停理由仅限：完成单元达成、真实外部阻塞、不可逆授权。生产授权只限制生产动作。

用户纠错或要求继续时：先改行为，再给下一可执行步骤。

## 用户前台

只用“我理解的目标”“当前进展”“交付结果”“需要你决定”说明事实。每次可有一句“下一步”，
仅作进度说明。仅在确实需要用户做决定、授予授权或处理真实 Blocker 时向用户提问。

最终交付说明：用户目标是否完成、真实验证、未通过/受阻项、环境状态和后续授权（如有）。
完成声明须对应当前 Delivery Target 的全量证据。
