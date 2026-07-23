# Evidence Contract

> 本文件是 Task Validation、Version Acceptance、Production Verification 和完成声明的唯一真源。

## 1. 证据层

| 层 | 证明 | 常见证据 |
|---|---|---|
| V0 | 静态合同成立 | diff、lint、类型、确定性检查 |
| V1 | 实现逻辑正确 | 单元、集成、API、migration 测试 |
| V2 | Scenario 在真实通道有效 | 浏览器、运行时 Job、目标环境 |
| V3 | 全局消费者或发布稳定 | 全量回归、CI、生产检查 |

按当前风险选择最小充分组合，不把 V0–V3 当固定工具清单。

## 2. 三个验证层次

### Task Validation

Build / Repair 只证明当前 Task：

- 直接相关检查；
- Task Scenario；
- 用户可见变化的真实通道；
- 单向门附加验证；
- diff 与 Task In / Out 自检。

### Version Acceptance

Verify 证明多个 Task 集成后：

- 核心成功路径；
- 关键失败和降级；
- 角色与权限；
- 跨 Task 集成；
- 用户真实通道；
- 适用回归和 UX Job。

### Production Verification

证明目标版本在生产真实生效：版本、deploy、health、关键路径、数据一致性、监控和回滚点。

## 3. 追踪链

```text
Requirement
→ Scenario
→ Task
→ Implementation
→ Task Evidence
→ Version Evidence
→ Production Evidence
```

任一适用节点断链时，不得提高对应 Delivery Target。

## 4. Scenario 终态

- `Pass`：实际执行并达到 Oracle；
- `Fail`：实际执行但未达到；
- `Blocked`：无法执行，必须写原因。

所有 Scenario 有终态时只能声明 `matrix-accounted`。只有关版条件满足时才能声明
`acceptance-passed`。

## 5. Fail 分类

| 类型 | 下一 Rail |
|---|---|
| implementation | Repair |
| product / ux | Shape |
| technical-plan | Plan |
| test-oracle | 测试合同修订 |
| environment / account / data | Blocked |
| new-request | demand pool / Shape |
| unknown-root-cause | Diagnose |

分类前不得自动创建 Repair。只有产品或体验问题才要求 `experience-design.md`。

## 6. UI 与用户体验

API 成功、控件存在、Toast 出现或脚本旁路均不能单独证明用户 Job 通过。UI/人工 Scenario
至少需要一次 V2；截图应能让读者判断场景和结果。

UX 详细标准见 testing Skill 的 `references/ux-standards.md`。

## 7. 完成声明

完成报告必须写：

- Rail；
- Task / Scenario / 声明范围；
- 实际 Delivery Target；
- 真实运行的命令和步骤；
- 证据路径；
- 未覆盖项、Blocked 和限制；
- Workspace / Branch / PR / 环境状态。

测试绿只证明对应 Correctness，不自动推出用户价值、目标环境或生产交付。
