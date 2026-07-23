# Task Contract

> 本文件是技术 Task、单对话 Work Order、原生执行绑定和跨对话恢复指针的唯一真源。

## 1. Task 定义

Task 必须形成一个可独立判断的用户或系统结果。数据库、API、前端和测试可以是同一
Task 的内部步骤，但不能默认拆成无法独立验收的分层半成品。

合格 Task 同时满足：

- 目标可用一句话判断；
- In / Out 清晰；
- 前置依赖明确；
- 写入区域可界定；
- 不变量明确；
- 验收步骤可执行；
- 结果可观察；
- 失败时知道回到哪个 Rail。

## 2. Spec 内结构

```text
docs/specs/<id>/
├── tasks.md
├── tasks/
│   ├── T-001.md
│   └── T-002.md
└── routes/
    ├── T-001.next-rail.md
    └── T-002.next-rail.md
```

`tasks.md` 只保存 Task Graph、索引、依赖、状态和推荐顺序；`tasks/T-xxx.md` 是该 Task
的唯一执行合同；`routes/T-xxx.next-rail.md` 是 Codex 的机器恢复指针，不是给 PM 复制
粘贴的操作口令。

## 3. Work Order 必填

```markdown
# T-xxx：<结果>

## 用户或系统结果
## 前置条件
## In
## Out
## 技术影响面
## 写入边界
## 不变量
## 实现步骤
## 验收条件
## 最低证据
## Workspace Strategy
## 风险与回滚
## 终态
```

`终态` 只使用：

```text
ready | in-progress | passed | failed | blocked | cancelled
```

## 4. 单对话执行

Build / Repair 对话开工时：

1. 读宿主 `AGENTS.md`；
2. 从当前 Build owner 的明确绑定恢复 Task；没有绑定时由 Codex 从项目 handoff 索引
   自动解析 `routes/T-xxx.next-rail.md`；
3. 只补读 Task 明示的 Spec、产品真源和代码入口；
4. 检查工作区、依赖、单一 owner、Workspace Strategy 和外部共享资源；
5. 领取所需外部资源 Claim，并将 Task 标记 `in-progress`；
6. 在 Task 范围内实现、定向验证和修正；
7. 写实际证据、设置终态并释放外部资源 Claim。

同一 Task 内测试失败后可继续修复；换 Task、改产品合同或改技术方向必须换 Rail。

### 原生执行映射

- **Plan**：多步骤工作且当前 surface 提供原生 Plan 时，同步当前 Rail 的步骤、状态和
  检查点；文件 Work Order 保存持久合同，原生 Plan 保存本次执行进度。
- **Goal**：只有用户或上层指令明确要求持续 Goal，且当前 surface 允许时，才将一个
  Work Order 的 objective 绑定到一个原生 Goal。Goal 不改变 Rail、权限或完成证据。
- **Subagent**：用户已授权实施后，独立 Task 可交给一个原生 Subagent；父任务传入
  objective、source 和 stop condition，并负责收集结果。Subagent thread 不是用户拥有的
  独立 Codex 任务，也不会自动获得 Worktree。
- **用户任务**：只有用户明确要求创建时，才代建新的用户可见 Codex 任务；否则由用户在
  新任务中用“开始第一步”等自然语言启动，Codex 自动解析项目 handoff 索引和 Route。
- **Worktree**：一个会修改文件的 owner 只使用一个 Local checkout 或一个 Worktree。
  托管 Worktree 通常由用户在新任务入口选择；不可用时使用明确路径的 CLI Git Worktree。
- **Handoff**：原生 Handoff 只移动同一 Codex 任务及其 Git 状态，在 Local 与该任务关联
  的 Worktree 间切换。跨任务恢复只使用项目 handoff 索引和 Route。

一个 Task 及其允许写入区域同一时刻只能由一个
`current-chat | user-thread | subagent` owner 与其 Workspace 拥有。文件或 Task 冲突
通过单 owner、依赖和串行顺序解决，不再创建 Task/file Claim。

## 5. Next Rail Route

每个 Task 使用独立的 `docs/specs/<id>/routes/T-xxx.next-rail.md`。禁止使用仓库根部单一
`.next-rail.md` 作为全局调度状态；它无法表达并行 Task。

Route 只保存机器恢复所需的稳定指针和可选原生绑定，不复制 Task 正文：

```yaml
route_version: 1
route_id: vYYYY.MM-example/T-003
rail: build
spec: vYYYY.MM-example
task: T-003
objective: 用户可以完成某件事
source: docs/specs/vYYYY.MM-example/tasks/T-003.md
workspace: local
owner: current-chat
thread_id: null
subagent_id: null
goal_id: null
claims: []
stop_when: Task 验收条件全部有证据
on_pass: verify
on_fail: blocked-or-replan
```

Plan 在 Task ready 时创建 Route，并在项目 handoff 索引的 `Route` 列登记路径。原生任务、
Subagent 或 Goal 创建后回填实际 ID；没有相应能力时字段保持 `null`。一个 Worktree / owner 只挂载
一个 Route；并行 Task 各自使用独立文件。Task 终态后 Route 保留为历史指针，handoff
将其移到最近关闭。Codex 负责解析和传递 Route，用户前台只展示目标、状态、证据和下一步。

## 6. Claim

Claim 只用于无法由 `current-chat | user-thread | subagent` owner + Workspace 所有权隔离的
外部共享资源，例如：

- 开发服务器、端口和串行运行时；
- 数据库、测试数据集和迁移执行窗口；
- 测试账号、浏览器/设备会话和第三方沙箱；
- 部署槽位、生产操作窗口和其他有容量或互斥约束的外部系统。

Task、文件、目录、公共合同和生成物不使用 Claim；它们必须在 Plan 中通过依赖、单 owner、
写入边界和串行合并顺序解决。无法给重叠文件确定唯一 owner 时禁止并行。

Claim 的权威账本是 `docs/reference/claims.md`：

- `active` Claim 必须记录唯一 ID、`resource` 类型、外部资源键、Spec、Task、Owner 和
  Workspace；
- 同一外部 `resource` 同时只能有一个 active Claim；
- handoff 的 `Claims` 列必须引用账本中的 active Claim ID；
- 使用外部资源前领取，结束、取消或阻塞交接时释放；
- 无外部共享资源冲突时写 `N/A`，不制造空 Claim。

Task Work Order 只列所需外部资源 Claim，不复制 Claim 当前状态。

## 7. 完成

Task `passed` 要求：

- In 全部交付；
- Out 未被静默纳入；
- 直接验收条件均有证据；
- 相关失败已解决；
- Workspace / Branch / PR 状态如实记录；
- 未覆盖项和限制已写明。

Task passed 只证明该 Task，不等于 Version Acceptance 通过。
