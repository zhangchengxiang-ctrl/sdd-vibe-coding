---
name: testing
description: >-
  Codex 的 Verify 专项 Skill：执行 Task、Version 或 Production 验证，维护证据链，
  分类 Fail 并给出下一 Rail。仅在 vibe-coding 已路由到 Verify，或用户显式调用本 Skill
  时使用；不隐式接管普通测试请求，不修改实现。
---

# Testing：Verify 与证据

本 Skill 只运行在已确认的 Verify Rail，不修改业务代码。先读宿主 `AGENTS.md`、当前声明范围、
[`evidence-contract.md`](../vibe-coding/references/evidence-contract.md) 和适用 Scenario。
用户体验场景再读 [UX Standards](./references/ux-standards.md)。

## 先声明验收层次

| 层次 | 要回答的问题 |
|---|---|
| Task Validation | 当前 T-xxx 是否按合同完成？ |
| Version Acceptance | 多个 Task 集成后，当前版本是否满足产品结果？ |
| Production Verification | 目标版本是否在生产真实生效且健康？ |

不得用 Task 证据替代 Version Acceptance，也不得用本地/预览证据声明生产交付。

## 执行

1. 固定环境、版本、角色、数据和声明范围；
2. 建立 Requirement → Scenario → Task → Evidence 追踪；
3. 从宿主 `AGENTS.md` 取得真实命令、URL、账号和工具；
4. 按风险选择 V0–V3 的最小充分组合；
5. 实际执行每个适用 Scenario，记录 `Pass | Fail | Blocked`；
6. 记录命令、时间、环境、版本、观察值和证据路径；
7. 对 Fail 做归因，不在 Verify 中顺手修代码；
8. 给出实际 Delivery Target 和下一 Rail。

UI/人工 Scenario 至少需要一次真实通道 V2。API 成功、DOM 存在、Toast 出现或脚本旁路
都不能单独证明用户 Job 通过。

## Fail 路由

| 分类 | 下一步 |
|---|---|
| implementation | `repair` Work Order |
| product / ux | `shape` |
| technical-plan | `plan` |
| test-oracle | 修订测试合同 |
| environment / account / data | `blocked` |
| new-request | demand pool / `shape` |
| unknown-root-cause | `diagnose` |

只有同根因的 implementation Fail 可以合为一个 Repair Task。

## 声明

所有 Scenario 有终态，只能说明 `matrix-accounted`；关版条件全部满足才是
`acceptance-passed`。正式结果按
[Validation Report](./references/validation-report.md) 输出，必须同时写通过证据、失败、
Blocked、未覆盖项和限制。
