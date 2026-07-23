# 会话交接

最后更新：YYYY-MM-DD

本文件是跨 surface 的机器恢复索引，不替代用户任务、Subagent 或 Worktree 的运行状态。
原生能力可用时，`Owner` 写 `user-thread:<id>` 或 `subagent:<id>`，`Workspace` 写实际
工作区；不可用时写稳定的本地 owner。原生 Handoff 只移动同一用户任务的 Local /
Worktree 状态，不在本索引中伪造 Handoff ID。`Route` 始终指向机器恢复文件，`Claims`
只列外部共享资源。Codex 自动解析这些字段，不要求 PM 输入路径、ID 或目录。

## 活跃工作

| Spec | Task | Rail | Status | Owner | Workspace | Branch | PR | Route | Claims | Dependencies | Shared Resource | Next | Blocker |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | | |

## 筹备中

| 主题 | 产品真源 | 下一 Rail | 待决事项 |
|---|---|---|---|
| | | | |

## 等待外部动作

| 事项 | Spec / Task | 所需动作 | Owner | 登记日期 |
|---|---|---|---|---|
| | | | | |

## 最近关闭

| Spec / Task | 结果 | Delivery Target | Workspace / PR | 关闭日 |
|---|---|---|---|---|
| | | | | |
