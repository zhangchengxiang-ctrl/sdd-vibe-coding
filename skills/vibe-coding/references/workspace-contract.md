# Workspace Contract

> Local、Worktree、Branch、PR、并行和共享资源的唯一真源。托管 / CLI Worktree 细则见文末。

## 1. 默认决策

Plan 为每个 Spec Build 选择 `local | managed-worktree | git-worktree`。选择依据是隔离收益、
并行收益、冲突风险和环境成本。

先探测当前 agent surface：有 Subagent、托管 Worktree 或 Handoff 时按其真实语义使用；
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

- 同一 Spec 内两个无重叠写入面可并行；
- 当前 Local 有不相关 WIP；
- Hotfix 要与功能开发隔离；
- 长时或后台任务；
- 独立分支和 PR；
- 高风险实验需要隔离。

托管 Worktree 可用时，用户可在新任务入口为该用户任务选择 Worktree；已有任务需要
在 Local 与其关联 Worktree 间移动时使用原生 Handoff。Subagent 不自动获得独立 Worktree。
托管能力不可用时，可在计划明确且目标路径安全时使用 Git worktree。基础分支或本地状态不清
时先停止并确认。

## 4. Owner 与并行

一个会修改文件的写入面同一时刻只有一个 owner：`current-chat | user-thread | subagent`。
该 owner 只写一个 Local checkout 或一个 Worktree 中的已声明写入边界。文件所有权不写入
Claim 账本；由原生执行上下文、Workspace、依赖和 handoff 共同表达。

有原生 Subagent 时，只有可独立实现、验证和交接的写入面才分派。没有这些能力时，在当前
Build owner 串行执行；不得要求用户用新任务恢复正常推进。

### 禁止并行

任一成立就串行：

- 写入面有依赖；
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
  mode: local | managed-worktree | git-worktree
  base_ref: "<host-default-branch>"
  base_sha: "<confirmed-sha>"
  branch: sdd/<spec>
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
`claims` 只列数据库、端口、账号、浏览器、部署槽位等外部共享资源；不得为文件、目录或
代码合同创建 Claim。

## 6. 授权

- 创建可恢复的本地 Worktree 可以由已确认 Workspace Strategy 授权；
- 工作区脏状态、base 不明或路径冲突时先做只读发现并选择安全隔离；只有无法安全隔离的实际冲突才暂停；
- 使用受控外部共享资源前必须领取 resource Claim；创建 Worktree 本身不需要 file Claim；
- commit、push、创建或更新 PR 只在用户请求或执行合同明示时执行；
- merge、deploy、数据操作不由 PR 授权自动推出。

## 7. PR

- 一个完整 Spec 可以对应一个 PR；
- 同一 Spec 内需要隔离的并行步骤可以使用独立 Worktree，但不改变一个 Spec 的交付边界；
- 公共合同先合并，依赖分支 rebase 后重新验证；
- 分别绿灯不等于集成验收通过。

分支默认使用 `sdd/<spec>`，宿主另有规则时服从宿主。

## 8. Handoff 与清理

原生 Handoff 可用时，只用它在 Local 与同一用户任务关联的 Worktree 之间移动该任务及 Git
状态；跨任务恢复通过机器恢复指针和项目 handoff 索引完成。项目 handoff 记录 Spec、Rail、
原生 owner ID、Workspace、Branch、PR、依赖、外部共享资源、状态和下一动作，但不复制聊天记录。
PM 不需要输入恢复指针路径、线程 ID 或 Worktree 目录。

任务结束后：

- 在证据与 handoff 回填后释放外部资源 Claim；
- 保留或清理 Worktree 按当前 surface / 宿主策略；
- 不删除含未合并改动的 Worktree；
- PR 合并后安排 integration retest；
- 不长期累积无主 Worktree。

## 9. 托管 / CLI Worktree 执行

> 仅当 Workspace Strategy 选择 `managed-worktree` 或 `git-worktree` 时读取本节。

### 9.1 共同前置

创建工作区前确认：

- 宿主是 Git 仓库；
- `base_ref` 与 `base_sha` 已解析；
- 当前脏改动是否属于本 Spec；
- 恢复指针、单一 owner 和所需外部资源 Claim 已存在；
- setup、依赖、忽略文件和共享资源已明确；
- Delivery 是否授权 branch、commit、push 或 PR。

未满足时保持 Local 或标记 Blocked，不猜 base、不搬运未知改动。

### 9.2 托管 Worktree

当前 agent surface 暴露 Subagent、托管 Worktree 或 **Handoff** 时，只按实际语义使用，
不根据文档名称猜测工具存在。用户任务与 Subagent 是不同 owner；一个写入面绑定一个 owner
和一个 Workspace。执行顺序：

1. 建立机器恢复指针，在 handoff 登记 objective、source、stop condition 和推荐 Workspace；
2. 用户已授权实施且任务可独立时，可分派一个 Subagent；用户拥有的新任务仅在用户
   明确要求时创建，否则用户可在新任务中用自然语言启动；
3. 托管 Worktree 由用户在新任务入口选择。Subagent 默认使用父任务当前 Workspace；
4. 父任务把 `$vibe-coding`、objective 和 source 直接传给 Subagent；PM 不输入恢复指针路径；
5. 回填实际 user-thread / subagent / goal ID；相应能力不可用时保留 `null`；
6. 确认实际 checkout 与计划的 `base_sha` 一致；
7. 领取所需外部资源 Claim，运行宿主定义的 Worktree setup；
8. 在该 Worktree 内完成声明范围内的实现与证据；
9. Delivery 需要分支时，按当前 surface 或 Git 能力创建唯一分支；
10. 同一用户任务需要在 Local 与其关联 Worktree 间移动且原生 Handoff 可用时使用 Handoff；
    跨任务或 Handoff 不可用时停止该 owner，由项目 handoff 索引和恢复指针在目标 Workspace
    恢复，禁止两个 Worktree 同时 checkout 同一分支；
11. 回填 handoff、PR、证据并释放外部资源 Claim。

托管 Worktree 初始通常是 detached HEAD。“已有 Worktree”不等于“已有分支”。被
`.gitignore` 忽略的本地文件不会自动随 Handoff 移动；宿主确有需要时才配置
`.worktreeinclude`，不得借此传播密钥。

### 9.3 CLI Git Worktree

托管 Worktree / Handoff 不可用，且 Workspace Strategy 明示 `git-worktree` 时才执行：

1. 只读检查 `git status --short`、`git branch --show-current` 和
   `git worktree list --porcelain`；
2. 将 `base_ref` 解析为确定的 `base_sha`；
3. 使用明确、专用且不存在的目标目录创建 detached Worktree；
4. Delivery 需要分支时，在该 Worktree 创建 `sdd/<spec>`（或宿主 `AGENTS.md` 规定的前缀）；
5. 执行宿主 setup 与本 Spec 工作；
6. push / PR 只按单独授权执行；
7. 未合并改动、活跃 PR 或未保存证据存在时不得删除 Worktree。

命令中不使用宽泛路径、未验证变量或同一分支的重复 checkout。

### 9.4 并行与集成

- 一个并行写入面对应一个 owner、恢复指针、Workspace、外部资源 Claim 集合和证据集合；
- 文件互斥由单 owner 与 Worktree 承担，不创建 file Claim；
- Worktree 不隔离数据库、端口、测试账号、浏览器或生产环境；
- 公共合同先行时，依赖面在同步新 base 后重新执行直接验证；
- 各 PR 分别绿灯不等于 Version Acceptance；
- 合并顺序完成后执行 `integration_retest` 声明的 Scenario。

### 9.5 收尾

handoff 必须记录真实 owner / 原生 ID、Workspace、base SHA、Branch、PR、外部资源 Claims、
状态和下一动作。恢复指针是机器恢复指针，不作为 PM 操作说明。托管 Worktree 的清理
由当前 surface / 产品策略管理；永久或 CLI Worktree 按宿主规则清理，永不删除仍含未交付改动的工作区。
