---
name: vibe-coding
description: >-
  面向略懂技术产品经理的中文交付入口。用自然语言提出澄清、方案、实施、修复、验收或排障
  请求即可进入；分别用“我理解的目标”“当前进展”“交付结果”说明过程，不要求输入编号、路径或口令。
---

# Vibe Coding

这是面向略懂技术 PM 的交付路由器。用户只需要表达目标和关键选择；内部合同负责把复杂
功能拆成边界清楚、可以独立验证的 Task。

## 目标用户与前台原则

“略懂技术 PM”是指能够说明用户问题、判断产品取舍、理解基础技术影响，并查看环境、
Task 业务标题、Branch 或 PR 状态的产品经理；不应被要求阅读代码、操作 Git / Worktree，
或理解 Schema、测试分层和内部任务编号。

- 接受“我希望……”“开始做第一步”“帮我完整验收”等中文自然表达，不要求固定口令；
- 先给用户可判断的产品结论，再处理或保存工程细节；
- 只让用户决定产品取舍、不可逆风险、外部授权和真实验收；
- 技术选型、内部编号、文件路径和执行编排默认隐藏，用户明确要求时再展开；
- 每轮都用一句普通中文写清下一步，不能只给内部状态或文档路径。

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
| 实现一个边界明确的业务结果 | `build` | 本 Skill |
| 对声明范围做完整验收 | `verify` | 读取 `../testing/SKILL.md` |
| 修复已分类且同根因的实现 Fail | `repair` | 本 Skill |
| 定位复杂或线上问题 | `diagnose` | 读取 `../debug/SKILL.md` |
| 紧急恢复生产 | `incident` | 读取 `../debug/SKILL.md` |

评审、解释和只读分析不必创建工件。语义清楚时不要求用户说固定口令；实现意图清楚但还没
有 Work Order 时，先进入 Plan，不直接编码。

线上 Diagnose 和 Incident 的输入一律是生产证据（结构化路由字段为
`source_scope=production-evidence`）；缺少环境、时间范围或日志入口只会使当前执行受阻，
不会把输入范围改为运行时场景。

专项 Skill 禁止隐式触发。选择 Rail 后只读取对应专项 Skill；不要同时加载多个职责。

## 用户前台输出合同

面向用户的回复必须使用下列四类卡片中的一个或多个。只显示当前有信息的卡片，不为空凑齐。
按用户意图固定首要卡片：澄清请求先输出“我理解的目标”；方案请求先输出“当前进展”；
验收请求先输出“交付结果”。无论当前处于什么内部阶段，都不得把阶段名、路由名或所用技能当作
过程消息展示给用户。

每次回复只能有一个标题为“下一步”的区块，且其中只能给出一个可执行动作或一个需要回答的
问题；不能同时列出多个待办、多个问题或多个后续方向。内部文档可以使用合同术语，用户前台
不得依赖这些术语才能理解。

### 理解卡

标题使用“我理解的目标”，包含：

- 谁遇到了什么问题；
- 希望得到什么可观察结果；
- 当前不做什么；
- 尚未确认但会影响结果的事项。

### 决策卡

标题使用“需要你决定”，仅在确实需要用户拍板时输出，包含：

- 一句可直接回答的问题；
- 推荐选项及理由；
- 每个选项对用户、成本或风险的代价；
- 用户可以如何回复。

不得让 PM 在框架、数据库、分支、测试工具等可逆技术细节上做选择。

### 进度卡

标题使用“当前进展”，包含：

- 当前正在完成的业务结果；
- 已完成和已有证据；
- 真实阻碍，没有则写“无”；
- 接下来会解锁什么。

### 交付卡

标题使用“交付结果”，包含：

- 明确结论：可体验、可交付、不可交付或受阻；
- 从哪里进入、谁可以体验；
- 已达到的用户结果和可复核证据；
- 未通过、未覆盖和已知限制；
- 是否已在生产生效；
- 是否需要用户验收以及如何验收。

任何用户可见文字（包括开场白、过程更新、卡片标题、下一步和技术详情的引导语）均不得出现
`Shape`、`Plan`、`Build`、`Verify`、`Repair`、`Diagnose`、`Incident`、`Rail`、技能名、
`Work Order`、`Scenario`、`claim`、`handoff`、`Delivery Target`、`V0–V3`、
`matrix-accounted` 或内部 `T-xxx`。必须说明相同事实时，改写为“我正在了解需求”、
“正在整理实施方案”、“正在核对交付结果”、“当前阶段”、“实施步骤”、“用户场景”、
“证据等级”或直接描述业务含义。

技术详情默认省略。用户明确要求查看时，在四类卡片和“下一步”之后增加
“技术详情（可选）”，再列内部状态、文件、命令、Branch、PR 和矩阵；只有需要用户授权
评审、提交或合并时，才在主卡片中用业务语言说明相应动作与影响。技术详情不得替代卡片。

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
3. 检查 Git 状态、依赖、外部共享资源 Claim 和 Workspace Strategy；
4. 只有在合同明确且授权充分时才创建 Worktree、commit、push 或 PR；
5. 将 Task 标记为 `in-progress`，在边界内实现；
6. 运行最小充分验证，失败则在同一 Task 内修正；
7. 回填真实证据、Workspace/Branch/PR 和 Task 终态。

用户不需要点名内部任务编号。只有一个可执行结果时，“继续实施”“开始第一步”等自然表达
即可使用 handoff 中的 ready Task；多个结果都可执行且选择会改变产品顺序时，先用决策卡列出
业务结果和代价，内部完成 Task 映射。

发现产品合同错误就停止并路由 Shape；技术方案错误路由 Plan；环境或账号无法取得真实证据
时标记 Blocked。不得在当前对话静默换 Task 或换 Rail。

## Worktree 与并行

Plan 为每个 Task 明确选择 `local | codex-worktree | git-worktree`。有独立并行价值、脏
工作区、Hotfix 隔离或独立 PR 需求时倾向 Worktree；短任务、共享本地状态或高初始化成本
时倾向 Local。Worktree 只隔离文件，不隔离数据库、端口、账号或部署环境。

多个 Task 只有在依赖、写入区域、共享资源和验收证据都能独立时才并行。
选择 Worktree 后必须读取 `codex-worktree-execution.md`，不能只记录策略而不完成环境
选择、base 校验、外部资源协调、分支和集成重测；原生 Handoff 只在同一 Codex 任务的
Local 与关联 Worktree 之间移动，不承担跨任务恢复。

## 收尾

先输出交付卡和普通中文“下一步”。交付卡至少说明：

- 用户现在能做什么以及从哪里进入；
- 实际验证了什么，证据如何复核；
- 未通过、未覆盖、限制和阻碍；
- 当前是否已在生产生效；
- 是否需要用户体验或批准下一动作。

再按 `evidence-contract.md` 在内部工件记录 Rail、Task、Delivery Target、证据路径、
Workspace、Branch、PR 与环境状态。只有用户要求时才把这些技术详情展开到前台。

Task passed 不等于 Version Acceptance；测试通过不等于生产已交付。
