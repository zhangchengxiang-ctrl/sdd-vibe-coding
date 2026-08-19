# Infra 机制合同骨架（Plan 专用）

> 用于 infra/平台机制设计（kill/timeout/cancel/RG/resource group/capacity/query-gateway 中止语义等）。
> 目标是把“可执行失败语义”写进 `tests.md`（T-xxx success + failure/permission），而不是写 UI/交互描述。

## 适用触发

- 用户明确要“机制设计”：超时层、取消传播、资源组配额/隔离、gateway 中止等。
- 机制的正确性可以通过机跑断言证伪（返回码、状态迁移、失败映射、资源释放/回收、幂等性）。

## 关键原则（避免又变成 UI 表演）

1. 禁止把“用户可见页面 / 前端行为 / 点验流程”当作机制正确性来源。
2. 必须把 success 与 failure 都写成可机检两态（并映射到对应 T-xxx）。
3. 必须在 contract/plan/tests 任一处包含 `ux: n/a` 或 `无 UI`（避免 `check_spec.py` 误判 has_ui，进而要求 UI 字段门控）。
4. P0 Oracle 默认走 `unit` / `machine` 这类 agent 可执行脚本；不要把“请人再跑/请你自验”写进验收内容。

## 建议在 contract/plan 中落的 Required 字段（供写 tests.md 复用）

你可以直接把下面内容当作“机制需求清单”，写进 `contract.md` 的对应段落（或在 `Non-functional 与约束` 里用编号写清）。

### A. 触发与入口（Entry / Actor / Trigger）
- 谁发起：用户侧（gateway/API/端点）或内部调度器。
- 触发：`kill` / `cancel` / `timeout` / `resource group` 超配 / `query gateway` 中止。
- 作用域：只取消当前 query，还是带出任务树/依赖子任务；是否按租户/角色隔离。

### B. 成功定义（Success semantics）
- 返回码/错误类型（若机制规范要求）。
- 查询状态迁移（例如 running → cancelling → cancelled / terminated）。
- 资源回收语义（例如释放 RG 配额、释放线程/worker、清理中间态）。
- 幂等性：重复 kill/cancel 的观测结果应一致（不应二次扣费/重复释放导致异常）。

### C. 失败定义（Failure/permission semantics）
至少要覆盖两类失败（写进 Required 的“对应 T-xxx success/failure/permission”）：
- 无权限失败：应拒绝并留下可观察的“失败原因”（不触发资源回收或按规范触发回滚）。
- 资源/容量失败：RG/队列超配、配额耗尽、墙钟到点等；应有明确失败映射且不会泄漏资源。

### D. 传播与边界（Propagation & Boundaries）
- 取消/中止信号如何在分层中传播：gateway → 调度层 → 执行层 → 子任务。
- 失败传播：父任务 kill 后子任务是否也必须终止；对子任务可观测状态如何定义。
- 不变量：哪些行为绝对禁止（例如“kill 只返回成功但实际未终止”）。

## tests.md 的写作建议（直接用于 T-xxx）

对每个 P0 requirement，至少需要：

1. `T-xxx success`：两态可观察断言（kill/cancel 成功后状态迁移与资源释放两点至少一对）。
2. `T-xxx failure/permission`：同入口下无权限/无资源/超配/无法中止等失败映射断言。

如果存在“取消需要先进入某状态才能有效”的机制阶段（例如从 running 到 cancelling），Then 必须覆盖这一状态机边界，避免“宣称终止但仍在执行”这种假沙箱。

