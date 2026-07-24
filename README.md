# Vibe Coding

面向略懂技术产品经理的 **Codex-only Spec-Driven Delivery 插件**。

用户只需要表达诉求、判断关键产品取舍、授权实施并体验真实成果。插件负责把复杂功能
澄清为产品蓝图，以完整 Spec 连续实施并用可追溯证据完成版本验收。线上问题使用独立的
Diagnose / Incident 流程。

> 用户前台保持简单；`docs/`、Spec、执行合同、handoff 和 evidence 是 Agent
> 用于跨对话恢复和工程交付的内部记忆。

“略懂技术”表示用户可以判断产品范围、基础技术取舍、环境、Branch 和 PR，但不需要
手工维护恢复指针、Claim、base SHA 或验收矩阵。

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

用户侧默认只展示四类卡片：理解、决策、进度、交付；每次只给一个明确下一动作。

## 主流程

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         │
                      └ Repair ─┘

Production issue → Diagnose → Incident / Repair / Plan / Blocked
```

每个阶段在自身范围内连续完成；跨阶段须先总结并取得明确批准（见 `workflow-contract.md`）。
一个对话只挂载一个工作轨和一个主目标。Build 默认连续完成整份 Spec。Verify 只记录证据和分类 Fail。

## 安装与角色

```bash
git clone <repo-url> sdd-vibe-coding
cd sdd-vibe-coding
bash scripts/install.sh
```

安装脚本会把当前仓库注册为本地 Codex marketplace，并安装
`sdd-vibe-coding@sdd-vibe-coding-local`。安装或更新后，重启 Codex 或开始一个新任务。

## 给宿主仓生成内部交付骨架

只有用户明确要求初始化时才运行：

```bash
bash /path/to/sdd-vibe-coding/scripts/scaffold.sh /path/to/host-repo
```

脚手架以“缺失才创建”的方式生成 `AGENTS.md`、`docs/`、`scripts/check-docs.sh`。
脚手架不会自动修改业务代码，也不会把“已初始化”当成实施许可。

## 权威信息分层

| 信息 | 权威真源 |
|---|---|
| 宿主环境、命令、部署、单向门 | 宿主 `AGENTS.md` |
| 工作轨、权限和转换 | `workflow-contract.md` |
| Local / Worktree / Branch / PR（含 Codex 执行） | `workspace-contract.md` |
| 验证、验收和交付证据 | `evidence-contract.md` |
| Diagnose / Incident | Skill `debug` |
| 长期产品决策 | 宿主 `docs/product/modules/` |
| 当前版本实施合同 | 宿主 `docs/specs/<id>/` |
| 活跃工作机器索引 | 宿主 `docs/reference/handoff.md` |
| 外部共享资源 Claim | 宿主 `docs/reference/claims.md` |
| 当前实现事实 | 代码和真实运行证据 |

跨 Skill 合同：

```text
skills/vibe-coding/references/
  workflow-contract.md
  workspace-contract.md
  evidence-contract.md
```

同一个规范性事实只在一份合同中维护。其他 Skill 使用相对链接引用，不复制正文。

## Skill 结构

| Skill | 职责 |
|---|---|
| `vibe-coding` | 唯一宽入口；识别意图并选择工作轨 |
| `design` | Shape；产品澄清和分层产品蓝图 |
| `spec` | Plan；技术方案、Scenario、Spec 执行合同和 Workspace Strategy |
| `testing` | Build Validation、Version Acceptance、Production Verification |
| `debug` | Diagnose、Incident、生产证据和恢复路径 |

只有 `vibe-coding` 允许隐式触发。专项 Skill 由主入口定向读取，或由用户显式调用。

## Spec 执行合同

整份 Spec 的执行合同必须描述：用户结果、前置依赖、In / Out、写入边界、不变量、
验收条件、最低证据、Workspace / Branch / PR、外部共享资源 Claim、风险与回滚。

## Worktree 与 PR

Plan 为整份 Spec 给出 Workspace Strategy：

- 单任务、短修改、共享验证环境 → Local；
- 无重叠写入面并行、隔离现有 WIP、Hotfix 或独立 PR → Worktree 候选；
- 修改同一合同、迁移、生成物或竞争共享运行时 → 串行。

Worktree 只隔离文件。分支使用 `codex/<spec>`。commit / push / PR 由执行合同或用户授权，
不从“使用 Worktree”自动推导。细则见 `workspace-contract.md`。

## 线上问题

Diagnose 默认只读。只有生产不可用、活跃数据风险、安全事件或核心旅程严重故障才进入
Incident。流程与授权见 Skill `debug`。

## 验证

```bash
bash scripts/verify.sh
```

真实路由评估：

```bash
npm run verify-contracts
npm run eval-live -- --case shape-vague-wish
npm run eval-live -- --all
```

证据分三层：`Build Validation → Version Acceptance → Production Verification`。
`matrix-accounted` 只表示所有 Scenario 已有 Pass、Fail 或 Blocked；
只有满足关版条件时才能声明 `acceptance-passed`。

## 项目边界

插件只提供跨仓工作流。环境、命令、部署、WIP、账号等事实永远由宿主 `AGENTS.md` 定义。

## License

MIT
