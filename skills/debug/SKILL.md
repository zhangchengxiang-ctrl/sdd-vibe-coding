---
name: debug
description: >-
  Codex 的 Diagnose 与 Incident 专项 Skill。用于复杂 bug、线上排障、生产故障、
  日志/监控定位、止血和 Hotfix。仅在 vibe-coding 已路由到 Diagnose/Incident，
  或用户显式调用本 Skill 时使用；不隐式接管普通 bug 请求，诊断不自动授权修改或部署。
---

# Debug：Diagnose / Incident

只处理已确认的 Diagnose / Incident Rail。先读宿主 `AGENTS.md` 和
[`incident-contract.md`](../vibe-coding/references/incident-contract.md)。需要改代码时同时读取
[`workspace-contract.md`](../vibe-coding/references/workspace-contract.md) 和
[`evidence-contract.md`](../vibe-coding/references/evidence-contract.md)。

## 环境门

先确认目标环境、URL、版本/commit、时间范围、用户/请求标识，以及宿主定义的日志、监控、
SSH、数据库、部署与回滚入口。不确定时只做安全的只读调查或问最小问题；禁止用本机状态
代表生产。

所有日志和证据脱敏，不输出密钥、令牌和敏感用户数据。

## Diagnose

“排查、看看原因、线上有错”默认只授权诊断：

1. 有原生 Plan 时，把诊断步骤和假设检查点同步到 Plan；
2. 固定表象、影响范围和时间线；
3. 区分已确认事实与推测；
4. 建立 2–3 个可证伪假设；
5. 从真实环境取得证据逐个排除；
6. 定位根因层并给出置信度；
7. 输出最小 Repair / Plan 执行合同。

Diagnose 不写业务代码、不改配置/数据、不部署。根因不明时不得用试错修改生产状态。
只读证据源彼此独立且当前 surface 提供 Subagent 时，可以并行委派有边界的证据调查；
每个证据源仍只有一个 owner，父对话负责合并结论。没有 Subagent 时在当前对话串行调查。

## Incident

核心服务不可用、活跃数据损坏/丢失风险、活跃安全事件或核心旅程严重故障时进入
Incident。目标只有恢复生产：

```text
确认影响 → 选择止血 → 最小变更 → 最低验证
→ 部署授权 → 生产 health/关键路径 → 观察 → 后续 执行合同
```

止血优先回滚、功能开关、隔离依赖和配置修正，最后才是最小 Hotfix。Incident 不承载
大规模重构。任何变更前先在事故记录中固定最小 Incident 执行合同；生产部署、数据
操作、迁移和安全边界变化仍需明确授权。

Incident 始终只有一个恢复目标和一个变更 owner。只有用户或上层指令明确要求持续 Goal，
且当前 surface 支持时，才把恢复目标绑定到原生 Goal；原生 Goal 不替代 Incident Work
Order、生产授权或证据。Subagent 只并行只读调查或彼此独立的验证，不并行修改同一事故
范围。

## Workspace 与结果

Local 有无关 WIP、需要稳定分支或独立紧急 PR 时优先 Worktree；干净工作区中的唯一事故、
回滚或配置止血不强制 Worktree。原生 Worktree / Handoff 可用且已获授权时优先使用；
否则按 `workspace-contract.md` 回退到当前 Local 或 CLI Git Worktree。恢复指针由 Codex
写入 handoff / 恢复指针，不要求 PM 输入文件路径。

`production-restored` 只表示服务恢复。长期根因、回归、产品债和技术债必须形成独立
Repair / Plan / Verify 执行合同。

Incident 阶段完成后，先向用户总结恢复结果、生产证据、残余风险和建议的后续阶段；只有获得
明确批准，才能进入 Repair、Plan 或 Verify。
