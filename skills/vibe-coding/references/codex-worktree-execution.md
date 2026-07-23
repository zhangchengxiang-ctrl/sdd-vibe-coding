# Codex Worktree Execution

> 仅当 Task 的 Workspace Strategy 选择 `codex-worktree` 或 `git-worktree` 时读取。

## 1. 共同前置

创建工作区前确认：

- 宿主是 Git 仓库；
- `base_ref` 与 `base_sha` 已解析；
- 当前脏改动是否属于 Task；
- Route、Task 和所需 Claim 已存在；
- setup、依赖、忽略文件和共享资源已明确；
- Delivery 是否授权 branch、commit、push 或 PR。

未满足时保持 Local 或标记 Blocked，不猜 base、不搬运未知改动。

## 2. Codex 托管 Worktree

Codex 桌面端可为新对话选择 Worktree，也可用 **Hand off** 在 Local 与该对话关联的
Worktree 之间移动。执行顺序：

1. 为 Task 建立独立 Route，并在 handoff 登记；
2. 领取 Claim；
3. 新对话选择 **Worktree**，选择 Work Order 的起始分支；
4. 在提示中明确 `$vibe-coding` 和 Route 路径；
5. 确认实际 checkout 与计划的 `base_sha` 一致；
6. 运行宿主定义的 Worktree setup；
7. 执行一个 Task，并在该 Worktree 内取得 Task Evidence；
8. Delivery 需要分支时，使用 **Create branch here** 创建唯一分支；
9. 需要复用 Local 环境时，使用 **Hand off**，不要在两个 Worktree 同时 checkout 同一分支；
10. 回填 handoff、PR、证据并释放 Claim。

Codex 托管 Worktree 初始通常是 detached HEAD。不要把“已经有 Worktree”误认为“已经有
分支”。被 `.gitignore` 忽略的本地文件不会自动随 Handoff 移动；宿主确有需要时才配置
`.worktreeinclude`，不得借此传播不必要的密钥。

## 3. CLI Git Worktree

只有 Workspace Strategy 明示 `git-worktree` 时才执行：

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

- 一个并行 Task 对应一个 Route、Workspace、Claim 集合和证据集合；
- Worktree 不隔离数据库、端口、测试账号、浏览器或生产环境；
- 公共合同先行时，依赖 Task 在同步新 base 后重新执行直接验证；
- 各 PR 分别绿灯不等于 Version Acceptance；
- 合并顺序完成后执行 `integration_retest` 声明的 Scenario。

## 5. 收尾状态

handoff 必须记录真实 Workspace、base SHA、Branch、PR、Claims、Task Status 和下一动作。
Codex 托管 Worktree 的清理由产品管理；永久或 CLI Worktree 按宿主规则清理，永不删除
仍含未交付改动的工作区。
