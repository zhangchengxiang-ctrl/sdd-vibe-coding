# SDD Superpowers

把 **Spec-Driven Delivery** 打包成可分享插件，支持 **Cursor · Claude Code · Codex**：

- **判轨先行** · **产品记忆先行** · **门禁优先级**
- **Intake → Owner → Build** · spec 工具箱 · 验收→修复闭环
- **产品回归合同** · **docs CI** · **空仓 scaffold**

项目细节只读宿主 `AGENTS.md` / `docs/`。

## 当前版本 0.3.0

| 项 | 状态 |
|----|------|
| Cursor 插件 + rules 00–05 + hooks | ✅ |
| Claude Code（`.claude-plugin` + marketplace + harness hooks） | ✅ |
| Codex（`.codex-plugin` + `.agents/plugins` marketplace） | ✅ |
| vibe-coding / product-design-package / spec / testing | ✅ |
| 产品回归 · Mode D · check-docs-sdd | ✅ |
| `/intake` commands · Marketplace 公开发布 · 英文化 | ⏳ S4–S5 |

## 安装

```bash
# 三端（缺 CLI 的自动 SKIP）
bash ~/code/sdd-superpowers/scripts/install-local.sh

# 或单端
bash ~/code/sdd-superpowers/scripts/install-local.sh cursor
bash ~/code/sdd-superpowers/scripts/install-local.sh claude
bash ~/code/sdd-superpowers/scripts/install-local.sh codex
```

空宿主仓：

```bash
bash ~/code/sdd-superpowers/scripts/scaffold.sh /path/to/empty-repo
```

| Harness | 安装后 |
|---------|--------|
| Cursor | Reload Window → Plugins 见 sdd-superpowers |
| Claude Code | `/reload-plugins` → `/plugin` 确认；或 `claude plugin list` |
| Codex | Plugins Directory → **SDD Superpowers (local)** → Install |

## 验证

```bash
cd ~/code/sdd-superpowers && bash scripts/verify-slice1.sh
claude plugin validate ~/code/sdd-superpowers   # 若已装 Claude CLI
```

## 布局

```text
.cursor-plugin/     Cursor manifest
.claude-plugin/     Claude Code manifest + marketplace
.codex-plugin/      Codex manifest
.agents/plugins/    Codex/ChatGPT local marketplace
hooks.json          Cursor user/plugin hooks
hooks/hooks.json    Claude Code / Codex lifecycle hooks
rules/              always-apply（Cursor .mdc；scaffold 同步到 .claude/rules）
skills/             共享技能（三端共用）
scripts/            scaffold · install-local · check-docs-sdd · hooks
templates/          AGENTS + docs 骨架
```

## License

MIT
