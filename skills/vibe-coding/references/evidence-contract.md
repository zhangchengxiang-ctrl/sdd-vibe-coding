# Evidence Contract

> 本文件是 Build Validation、Version Acceptance、Production Verification 和完成声明的唯一真源。

## 1. 证据层

| 层 | 证明 | 常见证据 |
|---|---|---|
| V0 | 静态合同成立 | diff、lint、类型、确定性检查 |
| V1 | 实现逻辑正确 | 单元、集成、API、migration 测试 |
| V2 | Scenario 在真实通道有效 | 浏览器、运行时 Job、目标环境 |
| V3 | 全局消费者或发布稳定 | 全量回归、CI、生产检查 |

按当前风险选择最小充分组合，不把 V0–V3 当固定工具清单。

## 2. 三个验证层次

### Build Validation

Build 先证明整个 Spec 的实现状态；完成实现后运行完整单元测试批次，测试期间不得改代码。
Repair 只在 Verify 汇总全部 Fail 并形成统一方案后开始：

- 直接相关检查；
- Spec Scenario；
- 用户可见变化的真实通道；
- 单向门附加验证；
- diff 与 Spec In / Out 自检。

### Version Acceptance

Verify 证明整份 Spec 集成后：

- 核心成功路径；
- 关键失败和降级；
- 角色与权限；
- 跨入口 / 跨模块集成；
- 用户真实通道；
- 适用回归和 UX Job。

### Production Verification

证明目标版本在**目标环境**真实生效：版本、deploy、health（仅过程信号）、**产品冒烟**、数据一致性、监控和回滚点。

#### Delivery Target 闸门

| Target | 含义 | 部署含义 |
|---|---|---|
| `code-ready` | 代码与合同就绪 | **不**自动部署 |
| `dev-effective` | 在开发/预览环境生效 | 默认只交付该环境；若强行上生产须写清风险接受 + 加长版目标环境冒烟 |
| `production-delivered` | 生产真实生效 | 才是正常生产发布入口 |

未达声明 Target，不得把完成标签写成更高一层。
`matrix-accounted` / `acceptance-passed` / `design-ready` / `production-restored`
不是 Delivery Target；分层见 [`workflow-contract.md`](./workflow-contract.md)「状态词汇」。

#### 铁律（违反即不得报交付）

1. **`/health`、进程 active、首页 HTTP 200 ≠ 部署成功。** 有产品影响的发布必须在**目标环境**跑产品冒烟；未过或未跑 → 只能写冒烟未过 / Blocked，禁止单独写「部署成功」。
2. **开发环境证据 ≠ 生产验收。** 禁止用开发/预览 E2E 或开发 URL 回归冒充生产交付；同 commit 也不行（数据、env、权限、预置通常不同）。
3. **脚本证据 ≠ 判断。** 路径变更、reload 单元、环境检查清单只提供信号；发布风险定级与冒烟范围由 Agent/人声明理由，禁止把脚本输出当成已定级。
4. **方案缺产品冒烟 → 禁止执行生产 deploy。** 仅有运维侧动作、没有目标环境用户路径核对 = 方案不合格。

完成声明须带冒烟态（通过 / 未过 / Blocked+原因），不得用「已上线」单独收束。

#### Deliver Gate 回写（`validation.md`）

生产或目标环境交付后，至少回写：

```markdown
声明目标：
实际达到：
环境 / 版本：
定级 + 理由（若适用）：
reload / deploy：
migration / health：
环境门禁 / 侧车检查：
产品冒烟（目标环境）：通过 | 未过 | Blocked+原因
回滚点：
Observe 结果：
```

只有**目标环境**产品冒烟通过，才能把交付推进到生产 Observe；不得用「代码已合并 / health ok」冒充已交付。

宿主具体命令、URL、检查清单以 `AGENTS.md`（及产品仓 deploy 适配器，若有）为准。

## 3. 追踪链

```text
Requirement
→ Scenario
→ Implementation
→ Build Evidence
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
| implementation | 汇总全部实现 Fail，形成统一 Repair 方案后集中修复并回验 |
| product / ux | Shape |
| technical-plan | Plan |
| test-oracle | 测试合同修订 |
| environment / account / data | Blocked |
| new-request | demand pool / Shape |
| unknown-root-cause | Diagnose |

单个 Fail 不得触发立即修复。所有适用测试结果齐备后才能创建 Repair 方案；只有产品或体验问题才要求 `experience-design.md`。

## 6. UI 与用户体验

API 成功、控件存在、Toast 出现或脚本旁路均不能单独证明用户 Job 通过。UI/人工 Scenario
至少需要一次 V2；截图应能让读者判断场景和结果。

浏览器通道选型、证据落盘与身份切换细则见 testing Skill 的
[`browser-verify.md`](../../testing/references/browser-verify.md)。
UX 判定标准见 [`ux-standards.md`](../../testing/references/ux-standards.md)。

生产/测试环境需要登录时：宿主 `AGENTS.md` 或项目约定中**已有可复用测试凭据**的，Agent
应自行切换账号继续验收，不得默认停下来等人工登录。只有需要**用户个人账号**、OAuth 本人授权、
或生产密钥时，才记为真实外部阻塞（`Blocked` / `needs-authorization`）。

## 7. 完成声明

完成报告必须写：

- Rail；
- Spec / Scenario / 声明范围；
- 实际 Delivery Target；
- 真实运行的命令和步骤；
- 证据路径；
- 未覆盖项、Blocked 和限制；
- Workspace / Branch / PR / 环境状态。

测试绿只证明对应 Correctness，不自动推出用户价值、目标环境或生产交付。
