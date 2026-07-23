---
name: vibe-coding
description: >-
  Codex 的 Spec-Driven Delivery 主入口。把产品诉求路由为 Shape、Plan、Build、
  Verify、Repair、Diagnose 或 Incident，并用单 Task Work Order 跨对话交付。
  适用于需求澄清、技术拆解、实现、修复、验收、线上排障和生产事故。
---

# Vibe Coding

这是面向略懂技术 PM 的交付路由器。用户只需要表达目标和关键选择；内部合同负责把复杂
功能拆成边界清楚、可以独立验证的 Task。

## 必读

先读宿主 `AGENTS.md`，再按当前问题读取：

- [Workflow Contract](./references/workflow-contract.md)：Rail、授权、转换和完成语义；
- [Task Contract](./references/task-contract.md)：单 Task Work Order；
- [Workspace Contract](./references/workspace-contract.md)：Local、Worktree、分支和 PR；
- [Codex Worktree Execution](./references/codex-worktree-execution.md)：Worktree 被选中后读取；
- [Evidence Contract](./references/evidence-contract.md)：验证层次和完成声明；
- [Incident Contract](./references/incident-contract.md)：线上诊断与事故恢复。

这些合同是权威来源；本文件只负责路由。

## 第一步：判定 Rail

| 用户真正要完成的事 | Rail | 路由 |
|---|---|---|
| 澄清愿望、体验和产品方向 | `shape` | 读取 `../design/SKILL.md` |
| 将确认的产品切片拆成技术方案和 Task | `plan` | 读取 `../spec/SKILL.md` |
| 实现一个明确的 T-xxx | `build` | 本 Skill |
| 对声明范围做完整验收 | `verify` | 读取 `../testing/SKILL.md` |
| 修复已分类且同根因的实现 Fail | `repair` | 本 Skill |
| 定位复杂或线上问题 | `diagnose` | 读取 `../debug/SKILL.md` |
| 紧急恢复生产 | `incident` | 读取 `../debug/SKILL.md` |

评审、解释和只读分析不必创建工件。语义清楚时不要求用户说固定口令；实现意图清楚但还没
有 Work Order 时，先进入 Plan，不直接编码。

专项 Skill 禁止隐式触发。选择 Rail 后只读取对应专项 Skill；不要同时加载多个职责。

## 第二步：控制复杂度

按 `workflow-contract.md` 分别评估规模与风险：

- trivial / small fix 可以不建 Spec，但必须有明确目标和验证；
- non-trivial 必须有 Spec、Scenario 和 Task Work Order；
- major 或触发宿主单向门，先让用户批准技术计划；
- 文件数不决定复杂度，产品边界、依赖和不可逆性才决定。

只在用户明确要求初始化宿主时运行：

```bash
bash <plugin-root>/scripts/scaffold.sh <host-repo>
```

不要因为目录为空或缺文档就自行初始化。

## Build / Repair 开工

一次对话只执行一个 Task：

1. 读取 handoff 指定的 `routes/T-xxx.next-rail.md` 或用户点名的 Work Order；
2. 确认目标、In、Out、写入边界、不变量和验收条件；
3. 检查 Git 状态、依赖、Claim、共享资源和 Workspace Strategy；
4. 只有在合同明确且授权充分时才创建 Worktree、commit、push 或 PR；
5. 将 Task 标记为 `in-progress`，在边界内实现；
6. 运行最小充分验证，失败则在同一 Task 内修正；
7. 回填真实证据、Workspace/Branch/PR 和 Task 终态。

发现产品合同错误就停止并路由 Shape；技术方案错误路由 Plan；环境或账号无法取得真实证据
时标记 Blocked。不得在当前对话静默换 Task 或换 Rail。

## Worktree 与并行

Plan 为每个 Task 明确选择 `local | codex-worktree | git-worktree`。有独立并行价值、脏
工作区、Hotfix 隔离或独立 PR 需求时倾向 Worktree；短任务、共享本地状态或高初始化成本
时倾向 Local。Worktree 只隔离文件，不隔离数据库、端口、账号或部署环境。

多个 Task 只有在依赖、写入区域、共享资源和验收证据都能独立时才并行。
选择 Worktree 后必须读取 `codex-worktree-execution.md`，不能只记录策略而不完成 Handoff、
base 校验、Claim、分支和集成重测。

## 收尾

完成声明遵循 `evidence-contract.md`，至少包含：

- 当前 Rail、Task 和声明范围；
- 实际 Delivery Target；
- 做了什么与真实运行的验证；
- 证据路径；
- 未覆盖项、限制和 Blocker；
- Workspace、Branch、PR 与环境状态。

Task passed 不等于 Version Acceptance；测试通过不等于生产已交付。
