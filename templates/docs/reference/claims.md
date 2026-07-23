# Active Claims

Claim 只保护无法由单 `current-chat | user-thread | subagent` owner + Workspace
所有权隔离的外部共享资源。
Task、文件、目录和代码合同不创建 Claim；它们由单 owner、写入边界和串行顺序保护。
无外部资源冲突时不创建 Claim。

| Claim | Type | Resource | Spec | Task | Owner | Workspace | Status | Acquired | Released |
|---|---|---|---|---|---|---|---|---|---|
| | resource | | | | | | active / released | | |

规则：

- `Type` 只使用 `resource`；
- Resource 使用稳定的外部资源键，例如 `test-db`、`dev-server:3000`、`account:qa-admin`、
  `browser:shared` 或 `deploy-slot:production`；
- 同一 `Resource` 同时只能有一个 `active` Claim；
- Claim 必须关联真实 Spec 和 Task；
- active handoff 的 `Claims` 列引用 Claim ID；
- 外部资源不再使用、Task passed/failed/cancelled 或交接完成后释放；
- 不用 Task、文件、目录、代码合同或整份 Spec 作为 Resource。
