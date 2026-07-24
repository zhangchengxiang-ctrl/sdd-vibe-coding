---
name: testing
description: >-
  面向略懂技术产品经理的 Codex Verify 专项 Skill：按真实用户旅程执行 Spec / Version
  或 Production 验证，先用交付卡给出可否交付的中文结论、证据和限制，再维护工程证据链。
  仅在 vibe-coding 已路由到 Verify，或用户显式调用本 Skill 时使用；不修改实现。
---

# Testing：Verify 与证据

本 Skill 只运行在已确认的 Verify Rail，不修改业务代码。先读宿主 `AGENTS.md`、当前声明范围、
[`evidence-contract.md`](../vibe-coding/references/evidence-contract.md) 和适用 Scenario。
用户体验场景再读 [UX Standards](./references/ux-standards.md)。

## 先声明验收层次

| 层次 | 要回答的问题 |
|---|---|
| Build Validation | 当前 Spec 的实现与集成是否按合同完成？ |
| Version Acceptance | 当前版本是否满足产品结果？ |
| Production Verification | 目标版本是否在生产真实生效且健康？ |

不得用局部实现证据替代 Version Acceptance，也不得用本地/预览证据声明生产交付。

## 执行

1. 固定环境、版本、角色、数据和声明范围；
2. 建立 Requirement → Scenario → Implementation → Evidence 追踪；
3. 从宿主 `AGENTS.md` 取得真实命令、URL、账号和工具；有可复用测试凭据时自行切换角色/账号
   继续跑矩阵，勿默认停等人工登录（个人账号 / OAuth / 生产密钥才算外部阻塞，见
   `evidence-contract.md`）；
4. 按风险选择 V0–V3 的最小充分组合；
5. 实际执行每个适用 Scenario，记录 `Pass | Fail | Blocked`；
6. 记录命令、时间、环境、版本、观察值和证据路径；
7. 对全部 Fail 统一归因、聚类并形成一份 Repair 方案；Verify 中禁止修改代码；
8. 给出实际 Delivery Target、下一 Rail 建议和阶段总结，并等待用户批准后才转换。

UI/人工 Scenario 至少需要一次真实通道 V2。API 成功、DOM 存在、Toast 出现或脚本旁路
都不能单独证明用户 Job 通过。

## 用户前台输出

验收结果必须先输出“交付结果”，不得先展示工程矩阵。交付卡包含：

- **结论**：可交付、不可交付或受阻，并用一句话说明原因；
- **如何体验**：环境、入口、适用角色和代表性数据；
- **已验证的用户结果**：每项写实际观察和可复核证据；
- **未通过或无法验证**：写用户影响、严重度和原因，不能只写内部分类；
- **已知限制**：包括未覆盖内容；
- **上线状态**：未上线、已上线、未知或不适用；
- **需要用户做什么**：体验确认、批准下一动作或无需动作；

聊天前台默认不显示 Requirement、Scenario、Oracle、V0–V3、Rail、Delivery Target、
Matrix、commit、Workspace 等工程术语。正式报告仍保存完整工程证据；用户明确要求时，在
交付卡之后展开“技术详情（可选）”。交付卡之后单列且只列一个“下一步”，用普通中文
给出最小可执行动作。

## Fail 路由

| 分类 | 下一步 |
|---|---|
| implementation | 纳入统一 Repair 方案，集中修复后重新统一验收 |
| product / ux | `shape` |
| technical-plan | `plan` |
| test-oracle | 修订测试合同 |
| environment / account / data | `blocked` |
| new-request | demand pool / `shape` |
| unknown-root-cause | `diagnose` |

不得在单个 Scenario 失败后立即修代码；所有适用 Scenario 都有结果后，才设计并执行统一 Repair。

## 声明

所有 Scenario 有终态，只能说明 `matrix-accounted`；关版条件全部满足才是
`acceptance-passed`。正式结果按
[Validation Report](./references/validation-report.md) 输出，必须同时写通过证据、失败、
Blocked、未覆盖项和限制。报告必须先写 PM 验收摘要，再写工程矩阵；内部状态不能替代
“可交付 / 不可交付 / 受阻”的前台结论。
