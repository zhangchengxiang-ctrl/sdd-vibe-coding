---
name: debug
description: >-
  Diagnose 与 Incident 专项 Skill。用于复杂 bug、线上排障、生产故障、
  日志/监控定位、止血和 Hotfix。仅在 vibe-coding 已路由到 Diagnose/Incident，
  或用户显式调用本 Skill 时使用；不隐式接管普通 bug 请求，诊断不自动授权修改或部署。
---

# Debug：Diagnose / Incident

只处理已确认的 Diagnose / Incident。先读宿主 `AGENTS.md`。需要改代码时同时读取
[`workspace-contract.md`](../vibe-coding/references/workspace-contract.md) 和
[`evidence-contract.md`](../vibe-coding/references/evidence-contract.md)。

## 环境门

任何线上判断前，先从用户描述和宿主 `AGENTS.md` 确认：

- 环境与 URL；
- 当前版本 / commit；
- 日志、监控、SSH、数据库和运行时入口；
- 部署与回滚命令；
- 生产操作授权。

不确定环境时只做安全的只读调查或询问。线上结论用目标环境证据。  
**硬门：** 本地日志、数据库或配置单独不代表生产状态。所有日志和证据脱敏。

## Diagnose

“排查、看看原因、线上有错”默认只授权诊断：

1. 固定时间范围、影响用户和关键标识；
2. 记录表象与已确认事实；
3. 建立 2–3 个可证伪假设；
4. 读取真实环境证据并排除假设；
5. 定位根因层，给出置信度、风险和下一执行合同。

Diagnose 默认只读。写代码、改配置、改数据或部署须另有明确授权。  
根因不明时保持只读调查；生产状态变更走下方授权边界。  
**硬门：** 未看日志 / 堆栈 / 失败响应前，不猜测改码。

### 证据源清单（按宿主 `AGENTS.md` 探测）

| 面 | 先取什么 |
|----|----------|
| 前端 | Browser：Console 报错、Network 失败请求的 request/response |
| 后端 / Agent | 终端日志（IDE `terminals/`）、容器/进程日志、Traceback、SQL 报错 |
| 定位 | 用堆栈或关键错误串 Grep / 搜索到具体行，再向上追调用链与入参 |
| 证伪 | 临时日志或调试只为验证假设；确认根因后再最小修复 |

修复获授权后：最小改动；检查同模式是否在别处复现；边界条件补自动化测试（命令读 `AGENTS.md`）。  
非 trivial / 非 Polish 行为变更走 Plan / Repair 合同，不靠口头「修一下」。UI 抛光明示话术见 workflow-contract (c)。

只读证据源彼此独立且当前 surface 提供 Subagent 时，可以并行委派有边界的证据调查；
每个证据源仍只有一个 owner，父对话负责合并结论。没有 Subagent 时在当前对话串行调查。

## Incident

满足任一才进入 Incident：

- 核心服务不可用；
- 活跃数据损坏或丢失风险；
- 活跃安全事件；
- 核心用户旅程严重故障且无合理绕过。

其余问题回到普通 Repair / Plan。目标只有恢复生产：

```text
确认影响 → 选择止血 → 最小变更 → 最低验证
→ 部署授权 → 生产 health/关键路径 → 观察 → 后续执行合同
```

止血优先：回滚 → 功能开关 → 隔离依赖 → 配置修正 → 最小 Hotfix。变更面保持在恢复所需最小集。

任何代码、配置或功能开关变更前，在事故记录中固定最小 Incident 执行合同：

- 恢复目标与当前影响；
- In / Out 和写入边界；
- 生产动作授权；
- Workspace / Branch / PR；
- 发布前最低验证、生产 Oracle 和回滚点。

事故记录可以承载这张紧急合同，无需为止血创建完整版本包。

### 授权边界

以下动作仍需宿主预授权或用户明确授权：

- 数据删除、恢复或不可逆修复；
- 数据库迁移；
- 权限和安全边界；
- 生产部署；
- 关闭关键保护机制。

“排查”不包含这些授权。

### Workspace

Local 有无关 WIP、需要稳定分支或独立紧急 PR 时优先 Worktree；干净工作区中的唯一事故、
回滚或配置止血不强制 Worktree。选择服从 `workspace-contract.md`。

Incident 始终只有一个恢复目标和一个变更 owner。Subagent 只并行只读调查或彼此独立的验证，
不并行修改同一事故范围。

### 生产验证

至少记录：目标环境与版本、deploy/rollback 结果、health、原始故障信号是否消失、核心用户路径、
数据一致性、监控观察窗口、未覆盖项和回滚点。

`production-restored` 只表示服务恢复；长期根因、回归、产品债形成独立 Repair / Plan / Verify 执行合同。

Incident 阶段完成后，先向用户总结恢复结果、生产证据、残余风险和建议的后续阶段；取得
明确批准后再进入 Repair、Plan 或 Verify。

### 安全与复盘

- 验证猜想用只读证据；生产状态变更走授权边界；
- 重大事故在宿主定义的事故目录记录时间线、根因、止血、恢复和后续工作；
- 暴露系统性问题时回填产品/技术 Gap。
