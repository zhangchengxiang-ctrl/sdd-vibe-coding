# SDD Superpowers

面向略懂技术产品经理的 **Codex-only Spec-Driven Delivery 插件**。

用户只需要表达诉求、判断关键产品取舍、授权实施并体验真实成果。插件负责把复杂功能
澄清为产品蓝图，以完整 Spec 连续实施并用可追溯证据完成版本验收；只有独立并行、风险隔离
或恢复确有收益时才拆出技术 执行步骤。线上问题使用独立的 Diagnose / Incident 流程。

> 用户前台保持简单；`docs/`、Spec、执行合同、handoff 和 evidence 是 Agent
> 用于跨对话恢复和工程交付的内部记忆。

“略懂技术”表示用户可以判断产品范围、基础技术取舍、环境、执行步骤、Branch 和 PR，但不需要
手工维护 恢复指针、Claim、base SHA 或验收矩阵。安装、首次项目配置和生产入口由技术管理员
准备；PM 的日常入口始终是自然语言。

## 用户会看到什么

| 用户意图 | Codex 做什么 | 不会做什么 |
|---|---|---|
| “我希望……”／“优化这个体验” | **Shape**：调查现状、澄清目标、保存产品决策 | 不改业务代码 |
| “按这个方向拆解”／“准备实施” | **Plan**：形成整份 Spec 的执行合同和测试矩阵 | 不在规划对话编码 |
| “实施并验收这个 Spec” | **Build**：连续完成范围内实现与直接证据 | 不扩展已确认 Spec Scope |
| “完整验收这个版本” | **Verify**：按矩阵验证并分类问题 | 不边验边修 |
| “修复这些验收问题” | **Repair**：修复一组同根因问题 | 不顺手处理无关项 |
| “排查线上问题” | **Diagnose**：读取真实环境证据并定位根因 | 不自动修复或部署 |
| “立即恢复生产” | **Incident**：止血、最小修复、生产验证 | 不做大规模重构 |

用户侧默认只展示四类卡片：理解、决策、进度、交付；每次只给一个明确下一动作。执行步骤、
Branch、PR 等基础信息放在可选的“技术详情”，内部文件路径和状态术语只在用户要求查看时
展开。

## 主流程

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         │
                      └ Repair ─┘

Production issue → Diagnose → Incident / Repair / Plan / Blocked
```

每个阶段在自身范围内连续完成；任一箭头代表一次阶段交接，必须先向用户总结该阶段的内容、
证据和限制，并在获得明确批准后才可进入下一阶段（包括 Incident）。阶段闸门的完整规则以
`workflow-contract.md` 的“阶段闸门”一节为唯一真源。

一个对话只挂载一个工作轨和一个主目标。Build 默认连续完成整份 Spec；若 Spec 因独立边界
拆 执行步骤，则同一时刻只激活一个并自动串行推进。Verify 只能记录证据和分类 Fail。

## 安装与角色

技术管理员只需为每个工作环境安装一次插件，并在宿主仓补全 `AGENTS.md` 中的真实命令、
环境、验证和部署入口。PM 不需要运行以下命令；这些命令用于本地开发和管理员安装。

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
| Spec 执行合同 | `technical-plan.md` + `scenario-spec.md` + `validation.md` |
| Local / Worktree / Branch / PR | `workspace-contract.md` |
| Codex Worktree 的实际执行 | `codex-worktree-execution.md` |
| Diagnose / Incident | `incident-contract.md` |
| 验证、验收和交付证据 | `evidence-contract.md` |
| 长期产品决策 | 宿主 `docs/product/modules/` |
| 当前版本技术与范围合同 | 宿主 `docs/specs/<id>/` |
| Spec 执行合同 | 宿主 `docs/specs/<id>/technical-plan.md` + `scenario-spec.md` + `validation.md` |
| 活跃工作机器索引 | 宿主 `docs/reference/handoff.md` |
| 外部共享资源 Claim | 宿主 `docs/reference/claims.md` |
| 当前实现事实 | 代码和真实运行证据 |

五份跨 Skill 合同位于：

```text
skills/vibe-coding/references/
  workflow-contract.md
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
| `spec` | Plan；技术方案、Scenario、Spec 执行合同和 Workspace Strategy |
| `testing` | Build Validation、Version Acceptance、Production Verification |
| `debug` | Diagnose、Incident、生产证据和恢复路径 |

只有 `vibe-coding` 允许隐式触发。专项 Skill 设置
`allow_implicit_invocation: false`，由主入口确定 Rail 后定向读取，或由用户显式调用。

## 可选 执行合同

默认以整份 Spec 连续执行；只有独立并行、风险隔离、单独交付或跨对话恢复有明确收益时，才创建
整份 Spec 的执行合同必须描述：

- 用户或系统结果；
- 前置依赖；
- In / Out；
- 技术影响面和允许写入区域；
- 不变量；
- 可执行验收条件；
- 最低证据；
- Workspace / Branch / PR；
- 跨客户端恢复 恢复指针（适用时）与外部共享资源 Claim；
- 风险、回滚和终态。

执行步骤 应是可独立验收的垂直切片，而不是“先建表、再写 API、再做前端”这种分层半成品。

## Worktree 与 PR

Plan 必须为每个 执行步骤 给出 Workspace Strategy：

- 单任务、短修改、共享验证环境 → Local；
- 独立 执行步骤 并行、隔离现有 WIP、Hotfix 或独立 PR → Worktree 候选；
- 修改同一合同、迁移、生成物或竞争共享运行时 → 串行。

Worktree 只隔离文件，不自动隔离数据库、端口、账号和浏览器环境。分支使用
`codex/<spec>`。是否 commit、push、创建 Draft/Ready PR 由执行合同或用户授权，
不从“使用 Worktree”自动推导。

普通 执行步骤 使用当前 Build owner 和 执行合同；只有用户或上层明确要求持续 Goal 时才创建
原生 Goal。Codex 桌面端可让用户在新任务入口选择托管 Worktree；原生 Handoff 只移动同一
任务及其 Git 状态，在 Local 与该任务关联的 Worktree 间切换。Subagent 是当前任务的内部
委派，不等同于用户拥有的新任务，也不会自动获得独立 Worktree。CLI 使用显式 Git Worktree
和 恢复指针 fallback。所有路径都必须校验 base、协调外部共享资源、完成 setup、回填证据，并
在合并顺序完成后进行 integration retest。

## 线上问题

Diagnose 默认只读。它必须先从宿主 `AGENTS.md` 判断环境，再使用宿主提供的日志、监控、
SSH、数据库或运行时入口。不得用本地日志冒充生产证据，也不得从“排查”推导修复或部署权限。

只有生产不可用、活跃数据风险、安全事件或核心旅程严重故障才进入 Incident：

```text
确认影响 → 止血 → 最小变更 → 发布前最低验证
→ 部署授权 → 生产健康检查 → 核心路径验证 → 长期 Repair / Verify
```

Incident 优先回滚、功能开关、隔离依赖或配置修正；大范围重构留给后续 执行合同。

## 验证

```bash
bash scripts/verify.sh
```

默认验证只执行确定性检查，包括：

- Codex manifest 和 marketplace；
- Skill frontmatter 与权威合同引用；
- 非目标平台残留；
- 新鲜宿主 scaffold；
- 执行步骤、Scenario、Incident、Workspace 合同；
- `check-docs.sh`；
- 路由合同 Fixture 的结构和覆盖；
- live Codex eval runner 的可执行性，但不冒充真实行为通过。

确定性验证不会冒充模型行为。真实路由评估必须显式运行，会调用 `codex exec`：

```bash
npm run verify-contracts
npm run eval-live -- --case shape-vague-wish
# 全量真实评估：
npm run eval-live -- --all
```

Live routing eval 在临时只读宿主中挂载本仓 Skills，使用 JSON Schema 约束输出，并将真实
Rail、代码/部署授权、执行合同 和 Workspace 与合同期望逐项比较。

证据分三层：

```text
Build Validation → Version Acceptance → Production Verification
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
