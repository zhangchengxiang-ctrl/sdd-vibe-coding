# SDD Superpowers

面向懂一点技术的产品经理的 **Codex-only Spec-Driven Delivery 插件**。

用户只需要表达诉求、判断关键产品取舍、授权实施并体验真实成果。插件负责把复杂功能
澄清为产品蓝图，拆成有明确边界的技术 Task，在独立对话中逐项实现，并用可追溯证据完成
版本验收。线上问题使用独立的 Diagnose / Incident 流程。

> 用户前台保持简单；`docs/`、Spec、Task Work Order、handoff 和 evidence 是 Agent
> 用于跨对话恢复和工程交付的内部记忆。

## 用户会看到什么

| 用户意图 | Codex 做什么 | 不会做什么 |
|---|---|---|
| “我希望……”／“优化这个体验” | **Shape**：调查现状、澄清目标、保存产品决策 | 不改业务代码 |
| “按这个方向拆解”／“准备实施” | **Plan**：形成技术方案、Task Graph 和测试矩阵 | 不在规划对话编码 |
| “执行 T-003” | **Build**：只完成该 Task 并取得直接证据 | 不扩展 Scope |
| “完整验收这个版本” | **Verify**：按矩阵验证并分类问题 | 不边验边修 |
| “修复这些验收问题” | **Repair**：修复一组同根因问题 | 不顺手处理无关项 |
| “排查线上问题” | **Diagnose**：读取真实环境证据并定位根因 | 不自动修复或部署 |
| “立即恢复生产” | **Incident**：止血、最小修复、生产验证 | 不做大规模重构 |

用户侧默认只展示四类卡片：理解、决策、进度、交付。内部文件名和状态术语只在用户要求
查看时展开。

## 主流程

```text
Shape → Plan → Build(T-001…T-n) → Verify
                         ↑             │
                         └── Repair ←───┘

Production issue → Diagnose → Incident / Repair / Plan / Blocked
```

一个对话只挂载一个工作轨和一个主目标。Build 可以在同一 Task 内反复实现和定向复验，
但不能换到另一个 Task；Verify 只能记录证据和分类 Fail。

## 安装

```bash
git clone <repo-url> sdd-vibe-coding
cd sdd-vibe-coding
bash scripts/install.sh
```

安装脚本会把当前仓库注册为本地 Codex marketplace，并安装
`sdd-superpowers@sdd-superpowers-local`。也可以手动执行：

```bash
codex plugin marketplace add /absolute/path/to/sdd-vibe-coding
codex plugin add sdd-superpowers@sdd-superpowers-local
```

安装或更新后，重启 Codex 或开始一个新任务。

## 给宿主仓生成内部交付骨架

只有用户明确要求初始化时才运行：

```bash
bash /path/to/sdd-vibe-coding/scripts/scaffold.sh /path/to/host-repo
```

脚手架以“缺失才创建”的方式生成：

```text
AGENTS.md
docs/
  product/
  planning/
  reference/handoff.md
  operations/incidents/
  specs/_template/
scripts/check-docs.sh
```

脚手架不会自动修改业务代码，也不会把“已初始化”当成实施许可。

## 权威信息分层

| 信息 | 权威真源 |
|---|---|
| 宿主环境、命令、部署、单向门 | 宿主 `AGENTS.md` |
| 工作轨、权限和转换 | `workflow-contract.md` |
| 单 Task 执行合同 | `task-contract.md` |
| Local / Worktree / Branch / PR | `workspace-contract.md` |
| Codex Worktree 的实际执行 | `codex-worktree-execution.md` |
| Diagnose / Incident | `incident-contract.md` |
| 验证、验收和交付证据 | `evidence-contract.md` |
| 长期产品决策 | 宿主 `docs/product/modules/` |
| 当前版本技术与范围合同 | 宿主 `docs/specs/<id>/` |
| 当前 Task | 宿主 `docs/specs/<id>/tasks/T-xxx.md` |
| 下一对话 Route | 宿主 `docs/specs/<id>/routes/T-xxx.next-rail.md` |
| 多线索引 | 宿主 `docs/reference/handoff.md` |
| 并行 Claim | 宿主 `docs/reference/claims.md` |
| 当前实现事实 | 代码和真实运行证据 |

五份跨 Skill 合同位于：

```text
skills/vibe-coding/references/
  workflow-contract.md
  task-contract.md
  workspace-contract.md
  codex-worktree-execution.md
  incident-contract.md
  evidence-contract.md
```

同一个规范性事实只在一份合同中维护。其他 Skill 使用相对链接引用，不复制正文。

## Skill 结构

| Skill | 职责 |
|---|---|
| `vibe-coding` | 唯一宽入口；识别意图、规模和风险并选择工作轨 |
| `design` | Shape；产品澄清和分层产品蓝图 |
| `spec` | Plan；技术方案、Task Graph、Scenario 和 Workspace Strategy |
| `testing` | Task Validation、Version Acceptance、Production Verification |
| `debug` | Diagnose、Incident、生产证据和恢复路径 |

只有 `vibe-coding` 允许隐式触发。专项 Skill 设置
`allow_implicit_invocation: false`，由主入口确定 Rail 后定向读取，或由用户显式调用。

## Task Work Order

一个 Build 对话挂载一个 `tasks/T-xxx.md`。Task 必须描述：

- 用户或系统结果；
- 前置依赖；
- In / Out；
- 技术影响面和允许写入区域；
- 不变量；
- 可执行验收条件；
- 最低证据；
- Workspace / Branch / PR；
- 独立 Route 与所需 Claim；
- 风险、回滚和终态。

Task 应是可独立验收的垂直切片，而不是“先建表、再写 API、再做前端”这种分层半成品。

## Worktree 与 PR

Plan 必须为每个 Task 给出 Workspace Strategy：

- 单任务、短修改、共享验证环境 → Local；
- 独立 Task 并行、隔离现有 WIP、Hotfix 或独立 PR → Worktree 候选；
- 修改同一合同、迁移、生成物或竞争共享运行时 → 串行。

Worktree 只隔离文件，不自动隔离数据库、端口、账号和浏览器环境。分支使用
`codex/<spec>-<task>`。是否 commit、push、创建 Draft/Ready PR 由 Work Order 或用户授权，
不从“使用 Worktree”自动推导。

Codex 桌面端使用一个 Task 对应一个托管 Worktree/对话；初始通常是 detached HEAD，需要
PR 时再创建独立分支。CLI 使用显式 Git Worktree。两种路径都必须校验 base SHA、领取 Claim、
完成 setup、回填证据，并在合并顺序完成后进行 integration retest。

## 线上问题

Diagnose 默认只读。它必须先从宿主 `AGENTS.md` 判断环境，再使用宿主提供的日志、监控、
SSH、数据库或运行时入口。不得用本地日志冒充生产证据，也不得从“排查”推导修复或部署权限。

只有生产不可用、活跃数据风险、安全事件或核心旅程严重故障才进入 Incident：

```text
确认影响 → 止血 → 最小变更 → 发布前最低验证
→ 部署授权 → 生产健康检查 → 核心路径验证 → 长期 Repair / Verify
```

Incident 优先回滚、功能开关、隔离依赖或配置修正；大范围重构留给后续 Work Order。

## 验证

```bash
bash scripts/verify.sh
```

验证包括：

- Codex manifest 和 marketplace；
- Skill frontmatter 与权威合同引用；
- 非目标平台残留；
- 新鲜宿主 scaffold；
- Task、Scenario、Incident、Workspace 合同；
- `check-docs.sh`；
- 路由合同 Fixture 的结构和覆盖；
- live Codex eval runner 的可执行性。

确定性验证不会冒充模型行为。真实路由评估必须显式运行，会调用 `codex exec`：

```bash
npm run verify-contracts
npm run eval-live -- --case shape-vague-wish
# 全量真实评估：
npm run eval-live -- --all
```

Live eval 在临时只读宿主中挂载本仓 Skills，使用 JSON Schema 约束输出，并将真实
Rail、代码/部署授权、Work Order 和 Workspace 与合同期望逐项比较。

证据分三层：

```text
Task Validation → Version Acceptance → Production Verification
```

`matrix-accounted` 只表示所有 Scenario 已有 Pass、Fail 或 Blocked；
只有满足关版条件时才能声明 `acceptance-passed`。

## 项目边界

插件只提供跨仓工作流。以下事实永远由宿主 `AGENTS.md` 或宿主文档定义：

- 环境和 URL；
- 代码根和进程边界；
- 日志、SSH、数据库与监控入口；
- 验证和浏览器命令；
- 分支保护和 PR 规则；
- 部署、回滚和生产授权；
- WIP 上限；
- 外部服务和账号策略。

## License

MIT
