# Codex Worktree Execution

> 仅当 Task 的 Workspace Strategy 选择 `codex-worktree` 或 `git-worktree` 时读取。

## 1. 共同前置

创建工作区前确认：

- 宿主是 Git 仓库；
- `base_ref` 与 `base_sha` 已解析；
- 当前脏改动是否属于 Task；
- Route、Task、单一 owner 和所需外部资源 Claim 已存在；
- setup、依赖、忽略文件和共享资源已明确；
- Delivery 是否授权 branch、commit、push 或 PR。

未满足时保持 Local 或标记 Blocked，不猜 base、不搬运未知改动。

## 2. Codex 托管 Worktree

当前 Codex surface 暴露 Subagent、托管 Worktree 或 **Hand off** 时，只按实际语义使用，
不根据文档名称猜测工具存在。用户任务与 Subagent 是不同 owner；一个 Task 绑定一个 owner
和一个 Workspace。执行顺序：

1. 为 Task 建立机器 Route，在 handoff 登记 objective、source、stop condition 和推荐
   Workspace；
2. 用户已授权实施且任务可独立时，可分派一个 Subagent；用户拥有的新 Codex 任务仅在用户
   明确要求时创建，否则用户可在新任务中用自然语言启动；
3. 托管 Worktree 由用户在新任务入口选择。Subagent 默认使用父任务当前 Workspace，不把
   Subagent 当成自动隔离的 Worktree；
4. 父任务把 `$vibe-coding`、objective 和 source 直接传给 Subagent；PM 不输入 Route 路径；
5. 回填实际 user-thread / subagent / goal ID；相应能力不可用时保留 `null`；
6. 确认实际 checkout 与计划的 `base_sha` 一致；
7. 领取数据库、端口、账号、浏览器等所需外部资源 Claim，运行宿主定义的 Worktree setup；
8. 执行一个 Task，并在该 Worktree 内取得 Task Evidence；
9. Delivery 需要分支时，按当前 surface 或 Git 能力创建唯一分支；
10. 同一用户任务需要在 Local 与其关联 Worktree 间移动且原生 Handoff 可用时使用
    Handoff；跨任务或 Handoff 不可用时停止该 owner，由项目 handoff 索引和 Route 在目标
    Workspace 恢复，禁止两个 Worktree 同时 checkout 同一分支；
11. 回填 handoff、PR、证据并释放外部资源 Claim。

Codex 托管 Worktree 初始通常是 detached HEAD。不要把“已经有 Worktree”误认为“已经有
分支”。被 `.gitignore` 忽略的本地文件不会自动随 Handoff 移动；宿主确有需要时才配置
`.worktreeinclude`，不得借此传播不必要的密钥。

## 3. CLI Git Worktree

托管 Worktree / Handoff 不可用，且 Workspace Strategy 明示 `git-worktree` 时才执行：

1. 只读检查 `git status --short`、`git branch --show-current` 和
   `git worktree list --porcelain`；
2. 将 `base_ref` 解析为确定的 `base_sha`；
3. 使用明确、专用且不存在的目标目录创建 detached Worktree；
4. Delivery 需要分支时，在该 Worktree 创建 `codex/<spec>-<task>`；
5. 执行宿主 setup 与 Task；
6. push / PR 只按单独授权执行；
7. 未合并改动、活跃 PR 或未保存证据存在时不得删除 Worktree。

不要在命令中使用宽泛路径、未验证变量或同一分支的重复 checkout。

## 4. 并行与集成

- 一个并行 Task 对应一个 owner、Route、Workspace、外部资源 Claim 集合和证据集合；
- Task/file 互斥由单 owner 与 Worktree 承担，不创建 Task/file Claim；
- Worktree 不隔离数据库、端口、测试账号、浏览器或生产环境；
- 公共合同先行时，依赖 Task 在同步新 base 后重新执行直接验证；
- 各 PR 分别绿灯不等于 Version Acceptance；
- 合并顺序完成后执行 `integration_retest` 声明的 Scenario。

## 5. 收尾状态

handoff 必须记录真实 owner / 原生 ID、Workspace、base SHA、Branch、PR、外部资源
Claims、Task Status 和下一动作。Route 是机器恢复指针，不作为 PM 操作说明。
Codex 托管 Worktree 的清理由产品管理；永久或 CLI Worktree 按宿主规则清理，永不删除
仍含未交付改动的工作区。
