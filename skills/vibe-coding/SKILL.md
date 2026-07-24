---
name: vibe-coding
description: >-
  Spec-Driven Delivery 跨端主入口（Cursor / Claude / Codex）。触发：我希望 / 优化体验 /
  排期 / 准备实施 / 开始做 / 实现 / 构建 / 验收 / 修复 / 排障 / vibe。先读宿主 AGENTS.md；
  未明示开始做且无已确认 Spec → 只写 docs/product/，不改业务代码。一个已确认 Spec 是持续
  完成的 Build，直到完整交付、真实阻塞或必须授权。
---

# Vibe Coding

用户表达目标和关键选择；体系负责连续实施与验收。内部步骤只用于推进工作，不能成为最终回复、
要求用户重新发起或中止当前交付的理由。

## 必读

先读宿主 `AGENTS.md`，再按当前问题读取：

- [Workflow Contract](./references/workflow-contract.md)：目标、授权、推进和完成语义；
- [Workspace Contract](./references/workspace-contract.md)：Local、Worktree、分支和 PR（含托管 / CLI Worktree）；
- [Evidence Contract](./references/evidence-contract.md)：验证层次和完成声明；
- Diagnose / Incident → Skill `debug`。

## 路由

| 用户目标 | 当前模式 |
|---|---|
| 澄清愿望、体验和产品方向 | Shape |
| 形成技术方案和完整执行合同 | Plan |
| 实施、修复并验收一个已确认 Spec | Build |
| 只验收既有实现 | Verify |
| 只定位复杂或线上问题 | Diagnose |
| 紧急恢复生产 | Incident |

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
取得用户明确批准。闸门规则见 [`workflow-contract.md`](./references/workflow-contract.md)。

## 持续交付规则

1. 建立一个用户可判断的交付目标、范围和完成条件；
2. 读取当前事实并执行下一可执行步骤；
3. Build 完成全部实现后，只运行完整的单元测试批次；测试开始后禁止修改代码；
4. Verify 统一运行集成、场景与真实通道测试，完整收集 Fail；
5. 所有测试结束后先形成一份统一修复方案，再进入 Repair 集中修改并回验；
6. 每个阶段完成后记录目标、完成内容、证据与限制，先向用户总结并取得明确批准，再进入下一
   阶段（见 `workflow-contract.md`）；阶段内只在整个目标完成、剩余步骤真实外部阻塞，
   或下一动作需要不可逆授权时才暂停。

Spec 范围以 `VERSION.md`、`context.md`、`requirements.md`、`technical-plan.md`、
`scenario-spec.md`、`validation.md`、`spec-run.md` 与代码共同确定；先读这些文件，按需再读其他材料。

不得把局部证据、未部署、普通 WIP、检查点、内部编号、缺少新对话/子代理或“需要汇报进度”
作为暂停理由。生产授权只限制生产动作，不限制当前阶段内其余实现和测试。

## 用户前台

只用“我理解的目标”“当前进展”“交付结果”“需要你决定”说明事实。每次可有一句“下一步”，
仅作进度说明。仅在确实需要用户做决定、授予授权或处理真实 Blocker 时向用户提问。

禁止“测一个点、改一个点”。最终交付必须说明：用户目标是否完成、真实验证、未通过/受阻项、
环境状态和后续授权（如有）。局部通过不能声明完成。
