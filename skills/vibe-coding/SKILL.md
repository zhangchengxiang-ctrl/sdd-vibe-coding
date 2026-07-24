---
name: vibe-coding
description: >-
  面向略懂技术产品经理的中文交付入口。用自然语言提出澄清、方案、实施、修复、验收或排障
  请求即可进入；一个已确认 Spec 是一个持续完成的 Build，直到完整交付、真实阻塞或必须授权。
---

# Vibe Coding

用户表达目标和关键选择；体系负责连续实施与验收。内部步骤只用于推进工作，不能成为最终回复、
要求用户重新发起或中止当前交付的理由。

## 必读

先读宿主 `AGENTS.md`，再按当前问题读取：

- [Workflow Contract](./references/workflow-contract.md)：目标、授权、推进和完成语义；
- [Workspace Contract](./references/workspace-contract.md)：Local、Worktree、分支和 PR；
- [Codex Worktree Execution](./references/codex-worktree-execution.md)：Worktree 被选中后读取；
- [Evidence Contract](./references/evidence-contract.md)：验证层次和完成声明；
- [Incident Contract](./references/incident-contract.md)：线上诊断与事故恢复。

## 路由

| 用户目标 | 当前模式 |
|---|---|
| 澄清愿望、体验和产品方向 | Shape |
| 形成技术方案和完整执行合同 | Plan |
| 实施、修复并验收一个已确认 Spec | Build |
| 只验收既有实现 | Verify |
| 只定位复杂或线上问题 | Diagnose |
| 紧急恢复生产 | Incident |

Rail 是同一交付目标内的动作模式，不是要求用户重新发起任务的借口。每个阶段在自身范围内
连续完成、中途不甩锅给用户；`Shape → Plan → Build → Verify → Repair` 的每次跨阶段切换都是
交接点，须先总结并取得用户明确批准才推进。完整闸门规则见
[`workflow-contract.md`](./references/workflow-contract.md) 的“阶段闸门”一节。

## 持续交付规则

1. 建立一个用户可判断的交付目标、范围和完成条件；
2. 读取当前事实并执行下一可执行步骤；
3. Build 完成全部实现后，只运行完整的单元测试批次；测试开始后禁止修改代码；
4. Verify 统一运行集成、场景与真实通道测试，完整收集 Fail；
5. 所有测试结束后先形成一份统一修复方案，再进入 Repair 集中修改并回验；
6. 每个阶段完成后记录目标、完成内容、证据与限制，先向用户总结并取得明确批准，再进入下一
   阶段（阶段闸门见 `workflow-contract.md`）；阶段内只在整个目标完成、剩余步骤真实外部阻塞，
   或下一动作需要不可逆授权时才暂停。

### 旧 Spec 兼容

历史遗留的分步控制面文件只是背景资料，**不具有控制权**：不得逐项执行、不得把其状态当完成
条件、不得为它们创建新文件，也不得为读取它们中断连续 Build。以 `VERSION.md`、`context.md`、
`requirements.md`、`technical-plan.md`、`scenario-spec.md`、`validation.md` 与实际代码共同确定整个
Spec 范围；先读这些必要文件，按需读取其他材料，避免一次性倾倒所有文档占满执行上下文。

不得把局部证据、未部署、普通 WIP、检查点、内部编号、缺少新任务、缺少子代理或“需要汇报
进度”作为暂停理由。生产授权只限制生产动作，不限制当前阶段内其余实现和测试。

## 用户前台

只用“我理解的目标”“当前进展”“交付结果”“需要你决定”说明事实。每次可有一句“下一步”，
但它只是进度说明，不是交还控制权或停止执行的指令。仅在确实需要用户做决定、授予授权或处理
真实 Blocker 时向用户提问。

禁止“测一个点、改一个点”。最终交付必须说明：用户目标是否完成、真实验证、未通过/受阻项、环境状态和后续授权（如有）。
局部通过不能声明完成。
