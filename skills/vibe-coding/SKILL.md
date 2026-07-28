---
name: vibe-coding
description: >-
  Spec-Driven Delivery 跨端主入口（Cursor / Claude / Codex）。触发：我希望 / 优化体验 /
  讨论产品 / 聊聊方向 / 拆解 / 学习这个 repo / 排期 / 准备实施 / 切 Spec / 开始做 /
  实现 / 构建 / 验收 / UX走查 / 修复 / 排障 / vibe / 派 Codex / 用 Codex 做。先读宿主
  AGENTS.md；未明示开始做且无已确认 Spec → 只写 docs/product/，不改业务代码。质量条在
  插件默认执行。Codex：整份 Spec 须 Goal；普通回合只承诺一个纵向切片。Cursor/Claude 上
  用户明示派 Codex 时走指挥施工（Skill dispatch-codex）。
---

# Vibe Coding

用户只需表达**意图**和关键选择；质量条、调查顺序、切片方式与验收标准由插件默认执行。
内部步骤只用于推进工作，不能成为最终回复、要求用户重新发起或中止当前交付的理由。
薄提示词对照见 [`workflow-contract.md`](./references/workflow-contract.md)「薄提示词原则」。
可选指挥施工见同文件「指挥施工 Harness」与 Skill [`dispatch-codex`](../dispatch-codex/SKILL.md)
（`gpt-5.6-sol` × medium/high）。

## 10 行操作卡（日常）

1. 读宿主 `AGENTS.md`（含 SDD docs root）。
2. 判轨：Shape / Plan / Build / Verify / Diagnose / Incident（或「派 Codex」）。
3. Shape：只写 `product/`；有 UI 对照 design-standards ux/visual。
4. Plan：落盘五件套；跑 `check_spec`；通过才请求 Build。
5. Build：只做当前完成单元；测前冻结改码。
6. Verify：收齐结果写 `run.md`；不改 Oracle；先交付卡。
7. Fail → 统一 Repair，再回验整批。
8. 派 Codex：先 `check_spec`；经 CLI `codex-dispatch.sh`；sol×medium|high + approval never。  
   **硬门：** 不经 `user-codex` / `CallMcpTool`。
9. 仅 Verified 进 P0/Lock；代码事实优先于文档自洽。
10. 深合同按需再读下方「必读」链接。

## 必读

先读宿主 `AGENTS.md`（含 **SDD docs root**，见 [docs-root.md](./references/docs-root.md)），再按当前问题读取：

- [Workflow Contract](./references/workflow-contract.md)：目标、授权、**薄提示词**、**Harness 适配**（含可选指挥施工）、证据分级、推进和完成语义；
- [Workspace Contract](./references/workspace-contract.md)：Local、Worktree、分支和 PR（含托管 / CLI Worktree）；
- [Evidence Contract](./references/evidence-contract.md)：验证层次、行为优先、Deliver Gate 和完成声明；
- [Design Standards](./references/design-standards/README.md)：系统架构 / UX / 视觉社区底线（按 Rail 默认加载；AGENTS 可覆盖）；
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

每个阶段在自身范围内连续完成；`Shape → Plan → Build → Verify → Repair` 的跨阶段切换须先总结并
取得用户明确批准。闸门与宿主完成单元见 [`workflow-contract.md`](./references/workflow-contract.md)。

## 持续交付规则

1. 建立一个用户可判断的交付目标、范围和**当前完成单元**（整份 Spec 或一个纵向切片）；
2. 读取当前事实并执行下一可执行步骤；Codex 上整份 Spec 长程交付须先 Goal（见合同 Harness 节）；
   指挥模式下由 `dispatch-codex` 派单，指挥侧验收后再向用户结案；
3. Build 完成当前完成单元的实现后，只运行完整的单元测试批次；测试开始后冻结改码；
4. Verify 统一运行集成、场景与真实通道测试，完整收集 Fail；**行为/权限 Oracle 优先于文档自洽**；
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
