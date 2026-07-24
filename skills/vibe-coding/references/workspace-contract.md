# Workspace Contract

> 本文件是 Local、Worktree、Branch、PR、并行和共享资源的唯一真源。

## 1. 默认决策

Plan 为每个 Spec Build 选择 `local | codex-worktree | git-worktree`。Worktree 不是奖励复杂度的
仪式，也不是禁用能力；选择依据是隔离收益、并行收益、冲突风险和环境成本。

先探测当前 Codex surface：有 Subagent、托管 Worktree 或 Handoff 时按其真实语义使用；
能力不存在、不可调用或不适合当前授权时，保留 Local 与 CLI Git Worktree。Subagent 是
内部委派，用户任务是用户拥有的独立对话；二者不能互换。原生运行时负责执行上下文，文件
恢复指针 / 项目 handoff 索引负责跨任务、跨 surface 的持久恢复。

## 2. 使用 Local

优先 Local：

- 单一短任务；
- trivial / small fix；
- 必须复用当前开发服务器或本地状态；
- Worktree 无法复现环境；
- 创建与同步成本高于任务本身。

## 3. 使用 Worktree

优先 Worktree：

- 同一 Spec 内两个无重叠写入面的执行步骤可并行；
- 当前 Local 有不相关 WIP；
- Hotfix 要与功能开发隔离；
- 长时或后台任务；
- 独立分支和 PR；
- 高风险实验需要隔离。

Codex 托管 Worktree 可用时，用户可在新任务入口为该用户任务选择 Worktree；已有任务需要
在 Local 与其关联 Worktree 间移动时使用原生 Handoff。Subagent 不自动获得独立 Worktree。
其他 Codex 表面可在计划明确且目标路径安全时使用 Git worktree。基础分支或本地状态不清
时先停止并确认。

具体执行步骤见 [`codex-worktree-execution.md`](./codex-worktree-execution.md)。

## 4. Owner 与并行

一个会修改文件的执行步骤同一时刻只有一个 owner：
`current-chat | user-thread | subagent`。该
owner 只写一个 Local checkout 或一个 Worktree 中的已声明写入边界。执行步骤/file 所有权不写入
Claim 账本；由原生执行上下文、Workspace、依赖和 handoff 共同表达。

有原生 Subagent 时，只有执行步骤能独立实现、验证和交接才分派。没有这些能力时，在当前
Build owner 串行执行；不得要求用户用新任务或 恢复指针 恢复正常步骤推进。

### 禁止并行

任一成立就串行：

- 执行步骤有依赖；
- 修改同一文件或代码区域；
- 同时修改数据库迁移、公共 API、权限模型或生成物；
- 竞争同一数据库、端口、账号、浏览器或部署环境；
- 不能独立取得验收证据；
- 合并顺序未知。

Worktree 只隔离文件，不隔离外部状态。

## 5. Workspace Strategy

每个 Spec 执行合同必须填写：

```yaml
owner:
  kind: current-chat | user-thread | subagent
  id: "<native-id-or-local>"

workspace:
  mode: local | codex-worktree | git-worktree
  base_ref: "<host-default-branch>"
  base_sha: "<confirmed-sha>"
  branch: codex/<spec>
  setup: "<host-defined>"
  shared_resources: []
  claims: []

native:
  plan_item: null
  goal_id: null

delivery:
  target: local-diff | commit | push | draft-pr | ready-pr
  pr_base: "<host-default-branch>"
  merge_after: []
  merge_before: []
  integration_retest: required | n/a
```

宿主默认分支、初始化命令和分支保护只读 `AGENTS.md`。
`claims` 只列数据库、端口、账号、浏览器、部署槽位等外部共享资源；不得为 执行步骤、文件、
目录或代码合同创建 Claim。

## 6. 授权

- 创建可恢复的本地 Worktree 可以由已确认 Workspace Strategy 授权；
- 工作区脏状态、base 不明或路径冲突时先做只读发现并选择安全隔离；只有无法安全隔离的实际冲突才暂停；
- 使用受控外部共享资源前必须领取 resource Claim；创建 Worktree 本身不需要 执行步骤/file
  Claim；
- commit、push、创建或更新 PR 只在用户请求或 执行合同 明示时执行；
- merge、deploy、数据操作不由 PR 授权自动推出。

## 7. PR

- 一个完整 Spec 可以对应一个 PR；
- 同一 Spec 内需要隔离的并行步骤可以使用独立 Worktree，但不改变一个 Spec 的交付边界；
- 公共合同先合并，依赖分支 rebase 后重新验证；
- 分别绿灯不等于集成验收通过。

分支默认使用 `codex/<spec>`，宿主另有规则时服从宿主。

## 8. Handoff 与清理

原生 Handoff 可用时，只用它在 Local 与同一用户任务关联的 Worktree 之间移动该任务及 Git
状态；跨任务恢复通过机器 恢复指针 和项目 handoff 索引完成。项目 handoff 记录 Spec、执行步骤、
Rail、原生 owner ID、Workspace、Branch、
PR、依赖、外部共享资源、状态和下一动作，但不复制聊天记录。PM 不需要输入 恢复指针 路径、
线程 ID 或 Worktree 目录。

任务结束后：

- 在证据与 handoff 回填后释放外部资源 Claim；
- 保留或清理 Worktree 按 Codex/宿主策略；
- 不删除含未合并改动的 Worktree；
- PR 合并后安排 integration retest；
- 不长期累积无主 Worktree。
