# Workflow Contract

> 本文件是工作轨、写权限、转换条件和完成语义的唯一真源。

## 1. 总原则

1. 一个执行上下文（当前 Codex 任务或一个 Subagent thread）只挂载一个 Rail 和一个主目标；
   父任务可以编排多个独立 Subagent，但不得在同一 owner 内混合 Rail 写入权限。
2. 用户意图按语义判断；关键词是例子，不是唯一许可证。
3. Shape、Plan、Verify、Diagnose 禁止写业务代码。
4. Build / Repair 只执行一个 Task Work Order。
5. Incident 只为恢复生产服务，不承载长期重构。
6. 内部文档可以复杂，但用户只处理产品决策、单向门、外部授权和真实结果。
7. 没有直接证据不得提高 Delivery Target。
8. 初始化宿主骨架必须由用户明确要求；空仓本身不是写入许可。
9. Rail、Work Status 和 Delivery Target 是内部控制语义，不要求用户用这些词发起工作。
10. 每次用户侧响应只给一个明确的下一动作；没有可执行下一步时说明真实 Blocker。

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

跨 Rail 时写下一 Work Order；当前执行 owner 不得换身份继续写。用户已授权实施且当前
surface 有 Subagent 时，可把 ready Work Order 交给新的单 Rail Subagent；用户拥有的
新 Codex 任务只有在用户明确要求创建时才可代建，否则 Plan 停止并给出一个自然语言启动
动作，不在当前 Plan 上下文静默进入 Build。

### Work Order 就绪语义

判断“是否需要 Work Order”时禁止只用布尔值，必须区分：

| 状态 | 含义 | 当前可否执行实现 |
|---|---|---:|
| `not-needed` | 当前 Rail 不创建也不消费执行 Work Order | 按该 Rail 权限 |
| `to-create` | 当前 Rail 的产出之一是后续执行所需 Work Order | 否 |
| `ready` | 适用 Work Order 已存在、可定位且边界完整 | 按 Work Order 权限 |
| `missing` | 用户要求执行，但所需 Work Order 不存在或不可定位 | 否，Workspace=`blocked` |

Plan 通常为 `to-create`；Build / Repair 必须为 `ready` 才能修改实现；Incident 仅在适用
Work Order 为 `ready` 且生产动作另有授权时执行变更。不得把“需要创建”与“已经存在”
压成同一个 `requires_work_order=true`。

## 7. 状态与完成

只使用三个正交概念：

- **Rail**：当前对话允许做什么；
- **Work Status**：`ready | in-progress | passed | failed | blocked | cancelled`；
- **Delivery Target**：
  `design-ready | code-ready | dev-effective | matrix-accounted |
  acceptance-passed | production-restored | production-delivered | user-accepted`。

`matrix-accounted` 不等于 `acceptance-passed`；`production-restored` 不等于长期问题已解决。

## 8. 用户前台

用户侧主内容只输出当前最有用的一张或多张卡片：

- 理解卡：问题、目标、当前范围、暂不包含、关键未知；
- 决策卡：必须拍板的方向、推荐、理由、代价和最短回复方式；
- 进度卡：当前用户结果、已完成、正在验证、后续会解锁的结果、Blocker；
- 交付卡：结论、体验入口、已验证结果、失败或限制、需要用户验收的事项。

略懂技术 PM 可以看到 Task 的业务标题、环境和关键技术取舍。Task ID、Workspace、
Branch、PR、commit 和证据路径默认只放在卡片末尾的“技术详情（可选）”；只有需要用户
授权评审、提交或合并时，主卡片才用业务语言说明动作与影响。默认不要求用户理解
DEM、Scenario ID、Oracle、V0–V3、claim、Work Order、Route、handoff、base SHA 或
detached HEAD，也不得要求用户复制这些内部路径来推进正常流程。

卡片必须使用用户结果命名，不用 `T-003` 代替“运营可以提交退款并看到处理结果”。卡片
末尾只能有一个 `下一步`；需要用户决定时给推荐和可以直接回复的短句。

## 9. Rail 输入、写入与停止合同

| Rail | 必读范围 | 可写范围 | 预期工件 | 停止条件 |
|---|---|---|---|---|
| Shape | 产品与当前系统 | 产品文档 | 已确认产品切片 | `design-ready` |
| Plan | 已确认产品切片与代码 | Spec 与 Work Orders | 技术计划和 Work Orders | `code-ready` |
| Build / Repair | Task Route、Work Order 与代码 | Task 边界 | Task Evidence | `task-passed` |
| Verify（Version Acceptance） | Scenario、集成实现与真实运行时 | validation / evidence | Validation Report | `matrix-accounted` 后给总评 |
| Verify（Production Verification） | 生产版本、health、核心路径与监控 | validation / evidence | Production Verification | 声明范围全部有终态 |
| Diagnose | 真实目标环境证据 | 诊断记录 | Diagnosis | 根因已定位或诚实 Blocked |
| Incident（未授权变更） | 真实生产证据 | Incident 记录 | Incident Work Order | 止血计划可执行 |
| Incident（已授权恢复） | 生产证据与 ready Work Order | Incident 边界 | Production Verification | `production-restored` 或诚实失败 |

行为评测中的枚举映射为：

- `product-and-current-system` / `approved-product-and-code` /
  `task-route-and-code` / `scenarios-and-runtime` / `production-evidence`；
- `product-docs` / `spec-and-work-orders` / `task-boundary` /
  `validation-evidence` / `diagnosis-record` / `incident-record`。

其中 `scenarios-and-runtime` 只用于 Version Acceptance；Diagnose（包括因缺少环境信息而
Blocked）和 Incident 一律使用 `production-evidence`。

## 10. Codex 原生执行映射

内部合同决定允许做什么；Codex 原生能力决定在当前表面如何执行。能力可用时优先使用，
不可用时保持同一合同并使用文件或 CLI fallback，不得假装调用了不存在的能力。

| 内部职责 | 优先原生能力 | Fallback |
|---|---|---|
| Shape / Plan 澄清 | Plan mode；只追问改变结果的问题 | 当前对话内的只读澄清 |
| Build / Repair 单 Task | 当前 Build owner + ready Work Order；仅在用户或上层明确要求持续 Goal 时绑定原生 Goal | 用户开启的新任务或当前 Build owner |
| 并行调查、审查、验收 | 独立 Subagents，父任务汇总结论 | 顺序执行并保持同一声明范围 |
| 独立实现 | 用户创建的 Codex Worktree 任务；或边界互不重叠的 Subagent | Local 或已授权的显式 Git Worktree |
| 同一任务在 Local 与 Worktree 间切换 | 原生 Handoff | 停止当前 owner，按项目 handoff 索引与 Route 在目标 Workspace 恢复 |
| 跨任务恢复 | 用户明确创建的新 Codex 任务 + 项目 handoff 索引 | Route + Work Order |
| UI 体验验证 | Codex Browser / Computer Use（可用且已授权时） | 宿主定义的浏览器命令或诚实 Blocked |

Plan mode 不等于 `plan` Rail：前者是产品交互能力，后者是本合同的写入边界。Goal 也不
替代 Work Order：只有用户或上层明确要求持续 Goal 时才创建 Goal；Goal 保存当前任务的
可验证结果，Work Order 保存跨任务、跨客户端可恢复的范围与证据合同。

Subagent 只用于能独立并行的调查、审查、验证或实现。并行写入仍必须经过依赖、文件区域和
外部共享资源检查；Subagent 不等于用户拥有的独立 Codex 任务，也不会自动获得独立
Worktree。不能用 Subagent、Goal 或 Worktree 绕过用户授权、sandbox 或 approval。
