# 安装与验证（SDD Superpowers）

仓库目录：`~/code/sdd-vibe-coding`（插件名 **sdd-superpowers**）。  
给 PM 的白话说明 → [`README.md`](./README.md)。

## 安装

```bash
# 三端（缺 CLI 的自动 SKIP）
bash ~/code/sdd-vibe-coding/scripts/install.sh

# 单端
bash ~/code/sdd-vibe-coding/scripts/install.sh cursor
bash ~/code/sdd-vibe-coding/scripts/install.sh claude
bash ~/code/sdd-vibe-coding/scripts/install.sh codex
```

可选：`INSTALL_USER_HOOKS=0` 跳过写入 `~/.cursor/hooks.json`。

| Harness | 安装后 |
|---------|--------|
| Cursor | Reload Window → Plugins 见 sdd-superpowers |
| Claude Code | `/reload-plugins`；或 `claude plugin list` |
| Codex | Plugins Directory → **SDD Superpowers (local)** → Install |

## 空仓骨架

```bash
bash ~/code/sdd-vibe-coding/scripts/scaffold.sh /path/to/empty-repo
```

会生成：`AGENTS.md` · `docs/` · `.cursor/rules` · `.claude/rules` · hooks ·  
`.cursor/sdd-enabled` · `.claude/sdd-enabled`（硬写闸标记）。

## 硬闸标记（重要）

| 行为 | 何时生效 |
|------|----------|
| SessionStart **上下文注入**（判轨提醒） | 插件已装 → **默认生效**（三端） |
| PreToolUse **硬 deny**（Intake 禁写业务代码） | 宿主有 `.cursor/sdd-enabled` 或 `.claude/sdd-enabled`（或对应 rules 文件） |

无标记时硬闸 **fail-open**（不拦），避免误伤非 SDD 存量仓。要用硬闸 → 跑 scaffold，或手动 `touch .cursor/sdd-enabled`。

Codex：插件 hooks 可能需 `plugin_hooks` 特性开关 + 信任审查；未开时靠 skill 触发与上下文。

## 验证

```bash
cd ~/code/sdd-vibe-coding
bash scripts/verify.sh
node scripts/verify-hooks.mjs
claude plugin validate ~/code/sdd-vibe-coding   # 若已装 Claude CLI
```

## 布局速查

见 [`SYSTEM.md` §4](./SYSTEM.md#4-插件结构)。
