# Evidence Contract

> 本文件是 Build Validation、Version Acceptance、Production Verification 和完成声明的唯一真源。

## 1. 证据层

| 层 | 证明 | 常见证据 |
|---|---|---|
| V0 | 静态合同成立 | diff、lint、类型、确定性检查 |
| V1 | 实现逻辑正确 | 单元、集成、API、migration 测试 |
| V2 | Test 在真实通道有效 | 浏览器、运行时 Job、目标环境、**跨用户越权拒绝** |
| V3 | 全局消费者或发布稳定 | 全量回归、CI、生产检查 |

按当前风险选择最小充分组合。

### 行为优先于文档自洽

1. 权限正确、用户 Job 成功、`code-ready` 须有行为/通道证据；编号对齐、manifest 计数、checklist 只证明文档自洽。
2. 权限 / 隔离类 Spec：每个 In-scope 入口具备可观察的成功路径 + 越权失败路径证据（测试、探针或真实通道），再宣称该入口完成。
3. 代码或 Schema 与 Spec 冲突时：先修 Spec 或标缺陷，再继续。

## 2. 三个验证层次

### Build Validation

Build 先证明整个 Spec 的实现状态；完成实现后运行完整单元测试批次，测试期间冻结改码。
Repair 只在 Verify 汇总全部 Fail 并形成统一方案后开始：

- 直接相关检查；
- Spec `tests.md` 用例；
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

证明目标版本在**目标环境**真实生效：版本、deploy、health（过程信号）、**产品冒烟**、数据一致性、监控和回滚点。

发布全过程（证据 → 并列设计「怎么发 / 怎么证伪」→ 批准 → 执行 → 关版）见 Skill
[`deploy`](../../deploy/SKILL.md) 与 [`release-lifecycle.md`](../../deploy/references/release-lifecycle.md)
（P0–P6）。本节只钉 **关版硬门**；执行步骤以 deploy Skill 为准。

#### Delivery Target 闸门

| Target | 含义 | 部署含义 |
|---|---|---|
| `code-ready` | 代码与合同就绪 | 不自动部署 |
| `dev-effective` | 在开发/预览环境生效 | 默认只交付该环境；上生产须写清风险接受 + 加长版目标环境冒烟 |
| `production-delivered` | 生产真实生效 | 正常生产发布入口；须 P6 目标环境冒烟通过 |

完成标签对齐已声明 Target。`matrix-accounted` / `acceptance-passed` / `design-ready` / `production-restored`
不是 Delivery Target；分层见 [`workflow-contract.md`](./workflow-contract.md)「状态词汇」。

#### 交付条件

1. **产品冒烟（P6）**：有产品影响的发布在**目标环境**按事先写好的验证方案跑用户路径冒烟；完成声明带冒烟态（通过 / 未过 / Blocked+原因）。  
   **硬门：** `/health`、进程 active、首页 HTTP 200 单独不构成「部署成功」或生产交付（仅 P5 过程检查）。
2. **环境对齐**：生产 Target 的证据取自目标生产环境（数据、env、权限、预置）。  
   **硬门：** 开发/预览 E2E 或开发 URL 回归单独不构成生产验收（最多作 P1 旁证）。
3. **定级有理由**：发布风险定级（L0/L1/L2）与冒烟范围由 Agent/人写明理由；脚本（路径变更、reload、环境清单）只作信号，不定级。
4. **P2 + P3 先于执行**：生产发布须先贴 **发布方案（怎么发）** 与 **验证方案（怎么证伪）**，再经批准（P4）后才执行（P5）。  
   **硬门：** L1/L2 缺任一则禁止 deploy；L0 可极简但仍须触及面最小冒烟。  
   **硬门：** P6 未过禁止宣称 `production-delivered`；标签只能是 `prod-smoke 未过/Blocked`。
5. **非代码面**：触及 migrate / 主机依赖 / 反向代理·进程模板 / 新 env 合同等时，方案须含采纳或明确延期（理由+跟踪）；配置类 MUST 含「模板↔live 同步」再 reload，禁止只写 reload。

#### Deliver Gate 回写（`run.md`）

生产或目标环境交付后，至少回写：

```markdown
声明目标：
实际达到：
环境 / 版本：
定级 + 理由（若适用）：
P2 发布方案（执行序 / sidecar 采纳或延期）：
P3 验证方案（冒烟层勾选）：
reload / deploy（P5）：
migration / health（过程）：
环境门禁 / 侧车检查：
产品冒烟（目标环境 · P6）：通过 | 未过 | Blocked+原因
完成标签：[部署·L#·prod-smoke …]
Open MUST（延期 sidecar，挂下次 P1）：
回滚点：
Observe 结果：
```

目标环境产品冒烟通过后，再推进生产 Observe。

宿主具体命令、URL、检查清单以 `AGENTS.md`（及产品仓 deploy 适配器，若有）为准。

## 3. 追踪链

```text
Requirement
→ Test（tests.md）
→ Implementation
→ Build Evidence
→ Version Evidence
→ Production Evidence
```

适用节点齐备后再提高对应 Delivery Target。

## 4. Test 终态

- `Pass`：实际执行并达到 Oracle；
- `Fail`：实际执行但未达到；
- `Blocked`：无法执行，必须写原因。

所有适用 Test 有终态 → 可声明 `matrix-accounted`。关版条件满足 → 可声明 `acceptance-passed`。

## 5. Fail 分类

| 类型 | 下一 Rail |
|---|---|
| implementation | 汇总全部实现 Fail，形成统一 Repair 方案后集中修复并回验 |
| product / ux | Shape（回写 `docs/product/`，不另建 Spec 体验文件） |
| plan | Plan |
| test-oracle | 修订 `tests.md` 测试合同 |
| environment / account / data | Blocked |
| new-request | demand pool / Shape |
| unknown-root-cause | Diagnose |

全部适用测试结果齐备后，再创建统一 Repair 方案。

## 6. UI 与用户体验

用户 Job 通过须有真实通道证据（至少一次 V2）。截图应能让读者判断场景和结果。  
**硬门：** API 成功、控件存在、Toast、`/health` 或脚本旁路单独不构成 Job 通过。

浏览器通道选型、证据落盘与身份切换细则见 testing Skill 的
[`browser-verify.md`](../../testing/references/browser-verify.md)。
UX 判定标准见 [`ux-standards.md`](../../testing/references/ux-standards.md)。

生产/测试环境需要登录时：宿主 `AGENTS.md` 或项目约定中**已有可复用测试凭据**的，Agent
自行切换账号继续验收。仅当需要**用户个人账号**、OAuth 本人授权、或生产密钥时，记为
`Blocked` / `needs-authorization`。

## 7. 完成声明

完成报告须写：

- Rail；
- Spec / Test / 声明范围；
- 实际 Delivery Target；
- 真实运行的命令和步骤；
- 证据路径；
- 未覆盖项、Blocked 和限制；
- Workspace / Branch / PR / 环境状态。

测试绿证明对应 Correctness；用户价值、目标环境或生产交付另按本文件 Delivery Target 条件声明。
