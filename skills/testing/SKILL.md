---
name: testing
description: >-
  面向略懂技术产品经理的 Verify 专项 Skill：按真实用户旅程执行 Spec / Version
  或 Production 验证；亦覆盖 UX 走查 / 体验审计。先用交付卡给出可否交付的中文结论、
  证据和限制，再维护工程证据链。仅在 vibe-coding 已路由到 Verify，或用户显式调用
  本 Skill 时使用；不修改实现。
---

# Testing：Verify 与证据

本 Skill 只运行在已确认的 Verify Rail，不修改业务代码。先读宿主 `AGENTS.md`、当前声明范围、
[`evidence-contract.md`](../vibe-coding/references/evidence-contract.md) 和适用
`tests.md` 用例。
用户体验场景再读 [UX Standards](./references/ux-standards.md)（真源
[design-standards/ux.md](../vibe-coding/references/design-standards/ux.md)）；有界面时对照
[visual.md](../vibe-coding/references/design-standards/visual.md)；UI / 浏览器真实通道再读
[浏览器验证](./references/browser-verify.md)；用户要 **UX 走查 / 体验审计** 或需分级启发式
发现时，加读 [UX 走查](./references/ux-walkthrough.md)。

## 先声明验收层次

| 层次 | 要回答的问题 | 证据来源 |
|---|---|---|
| Build Validation | 当前 Spec 的实现与集成是否按合同完成？ | 本 Spec 实现与集成证据 |
| Version Acceptance | 当前版本是否满足产品结果？ | 整版产品结果证据 |
| Production Verification | 目标版本是否在**目标环境**真实生效（含产品冒烟）？ | 目标环境冒烟与观察 |

层次与证据对齐后再提高声明；细则见 `evidence-contract.md` 交付条件。

## 执行

1. 固定环境、版本、角色、数据和声明范围；
2. 建立 Requirement → Test → Implementation → Evidence 追踪；
3. 从宿主 `AGENTS.md` 取得真实命令、URL、账号和工具；有可复用测试凭据时自行切换角色/账号
   继续跑矩阵（个人账号 / OAuth / 生产密钥 → `Blocked` / `needs-authorization`）；
4. 按风险选择 V0–V3 的最小充分组合；走查变体按 [ux-walkthrough](./references/ux-walkthrough.md)
   扩检查面，仍记录 `Pass | Fail | Blocked`；
5. 按 `tests.md` 实际执行每个适用用例（Given/When/Then），记录结果；
6. 记录命令、时间、环境、版本、观察值和证据路径；
7. 对全部 Fail 统一归因、聚类并形成一份 Repair 方案；Verify 只读实现；
8. 给出实际 Delivery Target、下一 Rail 建议和阶段总结，并等待用户批准后才转换。

UI/人工 Test 至少需要一次真实通道 V2（见 [browser-verify](./references/browser-verify.md)）。  
**硬门：** Oracle 保持在 `tests.md`；观察结果只写 `run.md`。API/DOM/Toast/`/health`/脚本旁路单独不构成 Job 通过。

## 用户前台输出

验收结果先输出“交付结果”，再按需展开工程矩阵。交付卡包含：

- **结论**：可交付、不可交付或受阻，并用一句话说明原因；
- **如何体验**：环境、入口、适用角色和代表性数据；
- **已验证的用户结果**：每项写实际观察和可复核证据；
- **未通过或无法验证**：写用户影响、严重度和原因，不能只写内部分类；
- **已知限制**：包括未覆盖内容；
- **上线状态**：未上线、已上线、未知或不适用；
- **需要用户做什么**：体验确认、批准下一动作或无需动作；

聊天前台默认不显示 Requirement、Test、Oracle、V0–V3、Rail、Delivery Target、
Matrix、commit、Workspace 等工程术语。正式报告仍保存完整工程证据；用户明确要求或走查变体
需要分级发现时，在交付卡之后展开“技术详情（可选）”或 P0/P1/P2 列表。交付卡之后单列且只列
一个“下一步”，用普通中文给出最小可执行动作。

## Fail 路由

分类与下一 Rail 以 [`evidence-contract.md`](../vibe-coding/references/evidence-contract.md)
§5 为唯一真源；本 Skill 不另维护表。

全部适用 Test 有结果后，再设计并执行统一 Repair。

## 声明

所有适用 Test 有终态 → `matrix-accounted`；关版条件全部满足 → `acceptance-passed`
（二者都不是 Delivery Target，见 workflow-contract「状态词汇」）。
正式结果写入当前 Spec 的 `run.md`（结构见 scaffold 模板；说明见
[Validation Report](./references/validation-report.md)），同时写通过证据、失败、
Blocked、未覆盖项和限制。报告先写 PM 验收摘要（关版结论），再写工程矩阵。

长期产品回归（可选）合同见
[product-regression](./references/product-regression.md)；启用后维护
`docs/product/regression-register.md`。
