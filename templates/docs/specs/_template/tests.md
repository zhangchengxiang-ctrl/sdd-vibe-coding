# Tests · <version-id>

> TDD 测试合同：Plan 完成时本文件必须含完整可判定用例。
> Build 先对红，再改实现。Verify 只把 Result 写入 `run.md`，**禁止**把 Oracle 改成实际观察。

## 索引

| ID | R | Type | 层 | Channel | 标题 |
|---|---|---|---|---|---|
| T-001 | R-001 | success | V2 | | |
| T-002 | R-001 | failure / permission | V2 | | |

`Type` 至少覆盖成功路径和适用的失败、权限、降级路径。每个 P0 Requirement 至少映射
1 条 success + 1 条 failure/permission。

## 执行约束

- 用例必须能在声明环境和通道实际执行；
- API、mock、fixture 或 DOM 存在不能替代用户通道 Oracle；
- 无法执行时结果为 Blocked，并记录缺少的环境、账号或数据；
- 结果只在 `run.md` 记录，不回写预期为实际。

---

## T-001 · <短标题>

- Requirement: R-001
- Type: success
- 层: V0 | V1 | V2 | V3
- Channel:

### Given

- 角色 / 账号：
- 数据 / 夹具：
- 环境 / URL：

### When

1.
2.

### Then（Oracle）

- 用户可见：
- 副作用（DB / API / 事件）：
- 不得出现：

### 自动化

- 命令或测试路径：`…` | `manual-only` + 原因
- 红灯条件：

---

## T-002 · <短标题 · 失败或越权>

- Requirement: R-001
- Type: failure / permission
- 层: V0 | V1 | V2 | V3
- Channel:

### Given

- 角色 / 账号：
- 数据 / 夹具：
- 环境 / URL：

### When

1.
2.

### Then（Oracle）

- 用户可见：
- 副作用（DB / API / 事件）：
- 不得出现：

### 自动化

- 命令或测试路径：`…` | `manual-only` + 原因
- 红灯条件：
