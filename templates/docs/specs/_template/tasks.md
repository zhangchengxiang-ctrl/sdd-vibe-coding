# Task Graph · <version-id>

> 本文件只保存索引、依赖和顺序；执行合同在 `tasks/T-xxx.md`。

## Graph

```text
T-001 → T-002
      ↘ T-003
T-002 + T-003 → Version Acceptance
```

## Task Index

| Task | 可独立判断的结果 | Depends On | Status | Workspace | Branch / PR | Work Order | Route |
|---|---|---|---|---|---|---|---|
| T-001 | | none | ready | local | N/A | [T-001](./tasks/T-001.md) | [next rail](./routes/T-001.next-rail.md) |

## 并行判断

| Task 组合 | 写入是否重叠 | 共享资源 | 证据能否独立 | 决策 |
|---|---|---|---|---|
| | | | | serial / parallel |

## 集成重测

- 触发点：
- 需要重跑的 Scenario：
- Owner / Work Order：
