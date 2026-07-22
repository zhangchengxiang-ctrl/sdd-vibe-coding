# AGENTS.md — 工程宪法（SDD scaffold）

> 由 **sdd-superpowers** `scripts/scaffold.sh` 生成。按本仓事实改写；Agent 以本文件为项目真源。

## Plan Approval

架构变更、新产品能力、破坏性操作、单向门 → 聊天给出计划，用户明确批准（「可以开始」/「批准」/ `go ahead`）后再执行。

## 文档分层

| 层 | 路径 | 用途 |
|----|------|------|
| 宪法 | 本文件 | 技术栈、命令、红线、部署 |
| 规格 | `docs/` | 产品门面 + `docs/specs/` 版本包 |

编码主入口 skill：**vibe-coding**（插件提供）。验证 skill：**testing**。

## Environments

| 用途 | 值（请填写） |
|------|----------------|
| 本地 / 预览 URL | |
| 生产 URL | |
| 应用监听 | |

## Architecture

（简述进程 / 部署单元边界。若有多进程故意双份代码，在此写明，禁止 Agent「DRY 合并」。）

## Makefile / 常用命令

```bash
# 按本仓填写，例如：
# make check
# make test
# make build
# bash scripts/check-docs-sdd.sh
```

## Verification

| 变更类型 | 命令 / 义务 |
|----------|-------------|
| 后端 | 定向 typecheck + 相关测试 |
| 前端用户可见 | 定向检查 + **浏览器验收**（方式见下） |
| 产品回归 | 见 `docs/product/foundation/product-regression.md`；选型命令自填 |
| 发版 | 本仓部署流程 |

浏览器验收：按本仓约定（Browser MCP / Playwright / 其它）。**禁止**用纯 API 冒充 UI 验收（若产品有 UI）。

## 单向门（须人审 + 定向加验）

默认：DB migration · 对外 API 契约 · 权限/安全边界 · 进程边界 · 数据删除 · 生产配置。按本仓增删。

## Git

- 主线：`main`（或本仓默认分支）
- commit / push：仅用户明示或 Spec 约定边界
- **禁止** Agent 擅自创建 git worktree，除非用户本轮明确要求

## WIP

活跃 Spec 上限与 `scripts/check-docs-sdd.sh` 的 `WIP_CAP` **同一数字**（默认 **8**）。

## SDD

见 `docs/README.md`。插件：判轨 · 产品记忆 · 完成门禁 · 回填 · 对话卫生。  
检查：`bash scripts/check-docs-sdd.sh`
