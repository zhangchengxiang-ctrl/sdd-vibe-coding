# AGENTS.md — live-relay fixture (isolated test host)

## SDD

- SDD docs root: docs
- Codex harness baseline tokens: 40000
- **Codex：** `codex-dispatch.sh` / `wish-orchestrate.sh`。一次一个 D。Build ≠ Deploy。

## 项目

- project.kind: software
- 产品/服务：live-relay token+ingest fixture（仅插件编排实跑，非产品仓）
- 主要技术栈：Python 3
- 代码入口：svc/
- 默认分支：main

## 常用命令

```bash
PYTHONPATH=. python3 -m pytest tests -q
```

## 架构与写入边界

- 分层：svc/auth → svc/ingest → svc/gateway
- Default UI surface: n/a
- 写入边界：仅 spec allowlist；禁止改 docs/specs/*/tests.md
