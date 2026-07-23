# Workspace Contract

> 本文件是 Local、Worktree、Branch、PR、并行和共享资源的唯一真源。

## 1. 默认决策

Plan 为每个 Task 选择 `local | codex-worktree | git-worktree`。Worktree 不是奖励复杂度的
仪式，也不是禁用能力；选择依据是隔离收益、并行收益、冲突风险和环境成本。

## 2. 使用 Local

优先 Local：

- 单一短任务；
- trivial / small fix；
- 必须复用当前开发服务器或本地状态；
- Worktree 无法复现环境；
- 创建与同步成本高于任务本身。

## 3. 使用 Worktree

优先 Worktree：

- 两个以上无依赖 Task 并行；
- 当前 Local 有不相关 WIP；
- Hotfix 要与功能开发隔离；
- 长时或后台任务；
- 独立分支和 PR；
- 高风险实验需要隔离。

Codex 托管 Worktree 可用时优先使用产品内 Handoff；其他 Codex 表面可在计划明确且目标
路径安全时使用 Git worktree。基础分支或本地状态不清时先停止并确认。

具体执行步骤见 [`codex-worktree-execution.md`](./codex-worktree-execution.md)。

## 4. 禁止并行

任一成立就串行：

- Task 有依赖；
- 修改同一文件或代码区域；
- 同时修改数据库迁移、公共 API、权限模型或生成物；
- 竞争同一数据库、端口、账号、浏览器或部署环境；
- 不能独立取得验收证据；
- 合并顺序未知。

Worktree 只隔离文件，不隔离外部状态。

## 5. Workspace Strategy

每个 Task 必须填写：

```yaml
workspace:
  mode: local | codex-worktree | git-worktree
  base_ref: "<host-default-branch>"
  base_sha: "<confirmed-sha>"
  branch: codex/<spec>-<task>
  setup: "<host-defined>"
  shared_resources: []
  claims: []

delivery:
  target: local-diff | commit | push | draft-pr | ready-pr
  pr_base: "<host-default-branch>"
  merge_after: []
  merge_before: []
  integration_retest: required | n/a
```

宿主默认分支、初始化命令和分支保护只读 `AGENTS.md`。

## 6. 授权

- 创建可恢复的本地 Worktree 可以由已确认 Workspace Strategy 授权；
- 工作区脏状态、base 不明或路径冲突时必须停止；
- Worktree 创建前必须领取 Task / contract / resource Claim；
- commit、push、创建或更新 PR 只在用户请求或 Work Order 明示时执行；
- merge、deploy、数据操作不由 PR 授权自动推出。

## 7. PR

- 一个独立可评审价值切片可以对应一个 PR；
- 紧耦合且必须同时生效的 Task 可以共用一个 PR；
- 可独立合并的并行 Task 使用独立 Worktree、分支和 PR；
- 公共合同先合并，依赖分支 rebase 后重新验证；
- 分别绿灯不等于集成验收通过。

分支默认使用 `codex/<spec>-<task>`，宿主另有规则时服从宿主。

## 8. Handoff 与清理

handoff 记录 Spec、Task、Rail、Workspace、Branch、PR、依赖、共享资源、状态和下一动作。
任务结束后：

- 在证据与 handoff 回填后释放 Claim；
- 保留或清理 Worktree 按 Codex/宿主策略；
- 不删除含未合并改动的 Worktree；
- PR 合并后安排 integration retest；
- 不长期累积无主 Worktree。
