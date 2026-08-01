# Cursor alwaysApply 硬闸（随插件安装）

`make install-cursor` / `bash scripts/install.sh cursor` 会把本目录 `*.mdc` **符号链接**到 `~/.cursor/rules/`。

| 文件 | 作用 |
|------|------|
| `sdd-vibe-entry.mdc` | 先判 `project.kind`（`software`\|`plugin`\|`other`）；仅 `software` 强制 Read `vibe-coding` |
| `sdd-shape-no-code.mdc` | 仅 `software`：无 Build 授权不改业务码 |
| `sdd-deploy-p4.mdc` | Build ≠ Deploy；P4 前禁生产 |
| `sdd-codex-cli.mdc` | Codex 只走 CLI，禁 MCP |

类型合同：`skills/vibe-coding/references/project-kind.md`。  
工作流真源在 **skills**；项目级规则放宿主仓 `.cursor/rules/`，不要复制全文。
