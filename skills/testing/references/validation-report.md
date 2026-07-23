# Validation Report

> 正式验收、发布或事故恢复使用；普通 Task 可直接在 Work Order 中记录证据。

```markdown
# Validation Report · <scope>

## 声明

- Rail：verify | incident
- 验收层次：Task Validation | Version Acceptance | Production Verification
- Spec / Task：
- 声明范围：
- 目标 Delivery Target：
- 实际 Delivery Target：
- 时间：

## 执行上下文

- Environment / URL：
- Version / commit：
- Workspace：
- Branch：
- PR：
- Role / account：
- Test data：

## 追踪矩阵

| Requirement | Scenario | Task | Oracle | Evidence | Result |
|---|---|---|---|---|---|
| | | | | | Pass / Fail / Blocked |

## 实际验证

| 层 | 命令或步骤 | 结果 | 证据 |
|---|---|---|---|
| V0 | | | |
| V1 | | | |
| V2 | | | |
| V3 | | | |

## Fail / Blocked

| Scenario | 表象 | 分类 | 根因或未知 | 下一 Rail / Work Order |
|---|---|---|---|---|
| | | implementation / product-ux / technical-plan / test-oracle / environment / new-request / unknown-root-cause | | |

## 生产验证（适用时）

- Deploy / rollback：
- Health：
- 原始故障信号：
- 核心用户路径：
- 数据一致性：
- 监控观察窗口：
- 回滚点：

## 结论

- Matrix：matrix-accounted | incomplete
- Acceptance：acceptance-passed | not-passed | n/a
- 未覆盖项与限制：
- 下一步：
```

不得省略失败、Blocked 或未执行项。未运行的命令不能写成通过；证据不足时降低声明。
