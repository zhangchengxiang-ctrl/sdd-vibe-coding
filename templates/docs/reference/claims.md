# Active Claims

Claim 防止并行 Task 修改同一 Task、合同或外部资源。无并行冲突风险时不创建 Claim。

| Claim | Type | Resource | Spec | Task | Owner | Workspace | Status | Acquired | Released |
|---|---|---|---|---|---|---|---|---|---|
| | task / contract / resource | | | | | | active / released | | |

规则：

- 同一 `Type + Resource` 同时只能有一个 `active` Claim；
- Claim 必须关联真实 Spec 和 Task；
- active handoff 的 `Claims` 列引用 Claim ID；
- Task passed、failed、cancelled 或交接完成后释放；
- 不用整份 Spec 作为 Resource。
