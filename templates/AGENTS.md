# AGENTS.md — 项目工程约定

> 由 SDD Superpowers 显式初始化。请用本仓真实事实补全；Codex 以本文件为项目约定真源。

## 项目

- 产品/服务：
- 主要技术栈：
- 代码入口：
- 默认分支：

## 环境与入口

| 环境 | URL / 访问方式 | 版本识别 | 日志 / 监控 |
|---|---|---|---|
| Local | | | |
| Preview / Staging | | | |
| Production | | | |

生产 SSH、数据库、部署和回滚入口只写安全的定位方法，不写密钥。

## 常用命令

```bash
# 安装：
# 启动：
# 定向测试：
# 全量测试：
# lint / typecheck：
# build：
# docs check：bash scripts/check-docs.sh
```

## 架构与写入边界

- 进程 / 部署单元：
- 公共 API / schema 真源：
- 生成物及生成命令：
- 不得修改的区域：

## 验证

| 变更 | 最低验证 |
|---|---|
| 后端逻辑 | 相关静态检查 + 单元/集成 |
| 用户可见前端 | 相关检查 + 真实浏览器 Scenario |
| 全栈 | 相关前后端检查 + 当前用户 Job |
| 数据库 / 单向门 | 迁移、兼容、health、回滚或本仓等价 |
| 发布 | 版本、deploy、health、核心路径、监控、回滚点 |

- 浏览器工具 / 账号：
- CI / 发布门：

## 单向门

以下事项在执行前需要用户批准计划和风险；按本仓增删：

- 数据库迁移、数据删除或不可逆修复；
- 对外 API / schema 兼容性；
- 权限、安全和隐私边界；
- 生产配置、部署单元和发布；
- 大规模依赖或架构迁移。

## Git、Worktree 与 PR

- 分支前缀默认 `codex/`，除非本仓另有约定。
- 短任务或必须共享当前本地状态时可用 Local。
- 并行独立 Task、无关 WIP、Hotfix 隔离、独立 PR 或高风险实验可用 Worktree。
- 同文件、迁移、公共合同或共享数据库/端口/账号冲突时不得并行。
- Worktree 只隔离文件，不隔离外部资源。
- commit、push、PR、merge、deploy 分别授权，不相互推出。
- 工作区脏状态、base 或目标路径不清时先停止。

## SDD 工作方式

- 主入口 Skill：`vibe-coding`；专项：`design`、`spec`、`testing`、`debug`。
- 一个对话只做一个 Rail 和一个主目标。
- Build / Repair 一次只执行一张 `tasks/T-xxx.md` Work Order。
- 每个 Task 使用独立的 `routes/T-xxx.next-rail.md`，禁止仓库根单一指针承担并行调度。
- 并行 Claim 的权威账本是 `docs/reference/claims.md`。
- 活跃工作上限若需要，由本仓设置 `WIP_CAP`；插件不提供通用固定值。
- 文档地图见 `docs/README.md`；检查运行 `bash scripts/check-docs.sh`。
