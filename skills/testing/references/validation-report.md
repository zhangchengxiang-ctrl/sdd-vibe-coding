# Validation Report

> 正式验收、发布或事故恢复使用；普通 Task 可直接在 Work Order 中记录证据。

```markdown
# Validation Report · <scope>

## PM 验收摘要

### 结论

- 是否可以交付：`可交付 | 不可交付 | 受阻`
- 一句话原因：
- 本次验收覆盖：
- 验收时间：

### 如何体验

- 环境 / 入口：
- 适用角色：
- 代表性数据：
- 成功时应看到：

### 已验证的用户结果

| 用户要完成的事 | 实际观察 | 证据 | 结论 |
|---|---|---|---|
| | | | 已通过 / 未通过 / 无法验证 |

### 未通过或无法验证

| 问题 | 对用户的影响 | 严重度 | 原因或缺少什么 | 建议动作 |
|---|---|---|---|---|
| | | 阻断 / 严重 / 一般 / 轻微 | | |

### 限制与上线状态

- 未覆盖内容：
- 已知限制：
- 是否已上线：`未上线 | 已上线 | 未知 | 不适用`
- 上线后的观察：

### 需要用户做什么

- 用户验收动作：
- 下一步：

## 工程验证明细（按需查看）

### 声明

- Rail：verify | incident
- 验收层次：Task Validation | Version Acceptance | Production Verification
- Spec / Task：
- 声明范围：
- 目标 Delivery Target：
- 实际 Delivery Target：
- 时间：

### 执行上下文

- Environment / URL：
- Version / commit：
- Workspace：
- Branch：
- PR：
- Role / account：
- Test data：

### 追踪矩阵

| Requirement | Scenario | Task | Oracle | Evidence | Result |
|---|---|---|---|---|---|
| | | | | | Pass / Fail / Blocked |

### 实际验证

| 层 | 命令或步骤 | 结果 | 证据 |
|---|---|---|---|
| V0 | | | |
| V1 | | | |
| V2 | | | |
| V3 | | | |

### Fail / Blocked

| Scenario | 表象 | 分类 | 根因或未知 | 下一 Rail / Work Order |
|---|---|---|---|---|
| | | implementation / product-ux / technical-plan / test-oracle / environment / new-request / unknown-root-cause | | |

### 生产验证（适用时）

- Deploy / rollback：
- Health：
- 原始故障信号：
- 核心用户路径：
- 数据一致性：
- 监控观察窗口：
- 回滚点：

### 工程结论

- Matrix：matrix-accounted | incomplete
- Acceptance：acceptance-passed | not-passed | n/a
- 未覆盖项与限制：
- 下一步：
```

PM 验收摘要必须位于工程明细之前，并能让未参与实现的人回答“能否交付、为什么、从哪里体验、
还有什么风险、下一步是什么”。不得省略失败、Blocked 或未执行项。未运行的命令不能写成
通过；证据不足时降低声明。聊天默认只展示 PM 摘要，工程明细在用户要求时展开。
