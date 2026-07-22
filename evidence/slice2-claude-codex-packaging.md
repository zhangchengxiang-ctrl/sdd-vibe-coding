# Slice 2–3 · Claude Code / Codex 打包 · 2026-07-22

## 交付
| Harness | 工件 |
|---------|------|
| Claude Code | `.claude-plugin/plugin.json` · marketplace（source `..`）· `hooks/hooks.json` · harness adapters |
| Codex | `.codex-plugin/plugin.json` · `.agents/plugins/marketplace.json` · 共用 hooks/skills |
| 共享 | `skills/` · `scripts/scaffold.sh`（同步 `.claude/rules` + `sdd-enabled`）· `install-local.sh [all\|cursor\|claude\|codex]` |

## 验证
```text
bash scripts/verify-slice1.sh
→ RESULT: PASS — Slice 2–3 / 0.3.0 Claude+Codex packaging green
claude plugin validate → ✔
claude plugin list → sdd-superpowers@… ✔ enabled
codex plugin list → sdd-superpowers@sdd-superpowers-local installed, enabled
```

## 安装
```bash
bash scripts/install-local.sh          # 三端
bash scripts/install-local.sh claude
bash scripts/install-local.sh codex
```

注意：`hooks/hooks.json` 为 Claude/Codex **默认自动加载**路径；manifest **不要**再写 `hooks` 字段（否则 Duplicate hooks）。

AgentDeck 仍无 `.cursor/sdd-enabled`（用户 hooks fail-open）。
