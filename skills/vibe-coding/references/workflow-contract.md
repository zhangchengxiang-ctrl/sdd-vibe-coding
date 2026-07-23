# Workflow Contract

> 本文件是工作轨、写权限、转换条件和完成语义的唯一真源。

## 1. 总原则

1. 一个对话只挂载一个 Rail 和一个主目标。
2. 用户意图按语义判断；关键词是例子，不是唯一许可证。
3. Shape、Plan、Verify、Diagnose 禁止写业务代码。
4. Build / Repair 只执行一个 Task Work Order。
5. Incident 只为恢复生产服务，不承载长期重构。
6. 内部文档可以复杂，但用户只处理产品决策、单向门、外部授权和真实结果。
7. 没有直接证据不得提高 Delivery Target。
8. 初始化宿主骨架必须由用户明确要求；空仓本身不是写入许可。

## 2. Rails

| Rail | 唯一职责 | 可写 | 禁止 |
|---|---|---|---|
| `shape` | 澄清诉求和产品目标 | demand、产品蓝图、决策 | Spec、业务代码、部署 |
| `plan` | 技术方案和 Task 拆解 | Spec、Task、Scenario、Workspace Strategy | 业务代码 |
| `build` | 完成一个 Task | Task 范围内代码、测试和证据 | 扩 Scope、换 Task |
| `verify` | 完整验收声明范围 | validation、evidence、Fail 分类、后续 Work Order | 修改实现和产品合同 |
| `repair` | 修复一组同根因 Fail | Repair Task 范围内代码和证据 | 无关问题 |
| `diagnose` | 定位复杂或线上问题 | 诊断记录和建议 Work Order | 未授权修改、部署 |
| `incident` | 紧急恢复生产 | 止血、最小修复、生产证据 | 大规模重构 |

Read-only 的回答、解释和评审不强制建立 Rail 工件。

## 3. 意图路由

| 语义意图 | Rail |
|---|---|
| 新愿望、体验问题、产品方向 | `shape` |
| 已确认方向，需要技术拆解 | `plan` |
| 要求实施新功能但尚无 Work Order | `plan`，生成后续 `build` |
| 执行明确 T-xxx | `build` |
| 不改变产品合同的已知缺陷 | `build` 或 `repair` |
| 完整验收、走查、总评 | `verify` |
| 修复已分类的实现 Fail | `repair` |
| 排查线上或复杂问题 | `diagnose` |
| 生产不可用、活跃数据或安全风险 | `incident` |

“开始做、实现、落地、处理掉、fix、执行该 Task”可以表达实施意图；是否能进入
Build 仍取决于 Task 边界是否明确。清单、截图和描述详细度不等于实施授权。

## 4. 规模与风险

规模决定文档义务：

| 规模 | 文档 |
|---|---|
| Trivial | 无 Spec；直接验收条件 |
| Small fix | 可无 Spec；诊断 + 最小验证 |
| Non-trivial | Spec + Task Work Order + Scenario |
| Major | Non-trivial 全部义务 + 用户批准技术计划 |

风险决定审查与验证，不由文件数量决定。单向门清单只读宿主 `AGENTS.md`。通用默认包括：
数据库迁移、对外契约、权限/安全边界、数据删除、生产配置和部署单元边界。

## 5. 授权

只为以下事项中断用户：

- 互斥或不可逆的产品选择；
- 技术单向门或破坏性操作；
- 用户本人才能完成的外部动作；
- commit、push、PR、deploy 等宿主明确要求授权的动作；
- 真实证据与已确认合同冲突且会改变用户结果。

普通可逆技术细节由体系决定。Worktree 的选择见 `workspace-contract.md`。

## 6. 转换

| 当前 | 条件 | 下一 Rail |
|---|---|---|
| Shape | 产品切片已确认 | Plan |
| Plan | Task Work Order 已 ready | Build |
| Build | 当前 Task passed | 下一个 Build 或 Verify |
| Build | 发现产品/技术合同错误 | Shape 或 Plan |
| Verify | 实现偏差 | Repair |
| Verify | 产品问题 | Shape |
| Verify | 技术方案错误 | Plan |
| Verify | 环境/数据/账号问题 | Blocked |
| Diagnose | 普通实现缺陷 | Repair |
| Diagnose | 产品/技术合同问题 | Shape / Plan |
| Diagnose | 紧急生产事故 | Incident |
| Incident | 生产恢复 | Verify 或长期 Repair |

跨 Rail 时写下一 Work Order；当前对话不得换身份继续执行。

## 7. 状态与完成

只使用三个正交概念：

- **Rail**：当前对话允许做什么；
- **Work Status**：`ready | in-progress | passed | failed | blocked | cancelled`；
- **Delivery Target**：
  `design-ready | code-ready | dev-effective | matrix-accounted |
  acceptance-passed | production-restored | production-delivered | user-accepted`。

`matrix-accounted` 不等于 `acceptance-passed`；`production-restored` 不等于长期问题已解决。

## 8. 用户前台

用户侧只输出：

- 理解卡：问题、目标、非目标、未知；
- 决策卡：必须拍板的方向、推荐和代价；
- 进度卡：当前目标、证据、下一步、Blocker；
- 交付卡：入口、实际达到、证据、限制。

默认不要求用户理解 DEM、Scenario ID、claim、Work Order 或 handoff。
