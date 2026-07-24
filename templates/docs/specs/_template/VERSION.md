# Version · <version-id>

| 字段 | 值 |
|---|---|
| **ID** | `vYYYY.MM-<slug>` |
| **标题** | |
| **状态** | `draft` |
| **Delivery Target** | `code-ready` |
| **Requirements Lock** | `open` |
| **产品决定依据** | |
| **创建日期** | YYYY-MM-DD |
| **目标环境** | |

状态只使用：
`draft | ready | in-progress | verifying | blocked | done | archived | cancelled`。

Rail 属于对话，不属于 Version；当前 Rail 只在 `reference/handoff.md` 记录。

## Manifest

| # | 文件 | 作用 |
|---|---|---|
| 1 | [context.md](./context.md) | 目标、范围和环境 |
| 2 | [requirements.md](./requirements.md) | Requirement 与 AC |
| 3 | [technical-plan.md](./technical-plan.md) | 技术方案与单向门 |
| 4 | [scenario-spec.md](./scenario-spec.md) | 可执行用户结果 |
| 5 | [validation.md](./validation.md) | 实现、集成与版本验收 |
| 6 | [spec-run.md](./spec-run.md) | 连续 Build、批量测试与统一 Repair 状态 |
| 7 | [evidence/](./evidence/) | 可复核证据 |

按风险添加 `clarify.md`、`migration-design.md`、`threat-model.md`、`test-plan.md` 等。不要为
凑齐模板生成空文档。

## 变更记录

| 日期 | 变更 | 依据 |
|---|---|---|
| | 初版 | |
