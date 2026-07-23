# Scenario Spec · <version-id>

## 场景矩阵

| ID | Requirement | Role | Journey | Type | EFFECTIVE_CHANNEL | Preconditions | Steps | ORACLE | FAILURE_ROUTE |
|---|---|---|---|---|---|---|---|---|---|
| SC-001 | R-001 | | | success | | | | | |
| SC-002 | R-001 | | | failure / permission | | | | | |

`Type` 至少覆盖成功路径和适用的失败、权限、降级路径。

## 执行约束

- Scenario 必须能在声明环境和通道实际执行；
- API、mock、fixture 或 DOM 存在不能替代用户通道 Oracle；
- 无法执行时结果为 Blocked，并记录缺少的环境、账号或数据；
- Scenario 结果只在 `validation.md` 记录，不回写预期为实际。
