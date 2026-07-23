# Task Contract

> 本文件是技术 Task、单对话 Work Order 和跨对话路由的唯一真源。

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
的唯一执行合同；`routes/T-xxx.next-rail.md` 是进入下一次对话的指针。

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
2. 读 handoff 指定的 `routes/T-xxx.next-rail.md`；
3. 只补读 Task 明示的 Spec、产品真源和代码入口；
4. 检查工作区、依赖、Workspace Strategy、Claim 和共享资源；
5. 领取所需 Claim，并将 Task 标记 `in-progress`；
6. 在 Task 范围内实现、定向验证和修正；
7. 写实际证据、设置终态并释放 Claim。

同一 Task 内测试失败后可继续修复；换 Task、改产品合同或改技术方向必须换 Rail。

## 5. Next Rail Route

每个 Task 使用独立的 `docs/specs/<id>/routes/T-xxx.next-rail.md`。禁止使用仓库根部单一
`.next-rail.md` 作为全局调度状态；它无法表达并行 Task。

Route 只做路由，不复制 Task 正文：

```yaml
rail: build
spec: vYYYY.MM-example
task: T-003
objective: 用户可以完成某件事
source: docs/specs/vYYYY.MM-example/tasks/T-003.md
workspace: local
stop_when: Task 验收条件全部有证据
on_pass: verify
on_fail: blocked-or-replan
```

Plan 在 Task ready 时创建 Route，并在 handoff 的 `Route` 列登记路径。一个 Worktree /
对话只挂载一个 Route；并行 Task 各自使用独立文件。Task 终态后 Route 保留为历史指针，
handoff 将其移到最近关闭。

## 6. Claim

Claim 使用 Task 或共享资源粒度，不锁整个 Spec：

- Task claim：防止两个对话写同一 Task；
- contract claim：迁移、公共 API、生成物等共享合同；
- resource claim：开发服务器、数据库、测试账号、浏览器环境。

Claim 的权威账本是 `docs/reference/claims.md`：

- `active` Claim 必须记录唯一 ID、类型、资源键、Spec、Task、Owner 和 Workspace；
- 同一 `type + resource` 同时只能有一个 active Claim；
- handoff 的 `Claims` 列必须引用账本中的 active Claim ID；
- Task 开工前领取，结束、取消或阻塞交接时释放；
- 无并行写风险时写 `N/A`，不制造空 Claim。

Task Work Order 只列所需 Claim，不复制 Claim 当前状态。

## 7. 完成

Task `passed` 要求：

- In 全部交付；
- Out 未被静默纳入；
- 直接验收条件均有证据；
- 相关失败已解决；
- Workspace / Branch / PR 状态如实记录；
- 未覆盖项和限制已写明。

Task passed 只证明该 Task，不等于 Version Acceptance 通过。
