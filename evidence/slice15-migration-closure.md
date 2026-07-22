# Slice 1.5 / v0.2.0 迁移闭环 · 2026-07-22

## 范围
把完整 SDD 实践目录迁入插件（仍只改 `~/code/sdd-superpowers`）：产品回归合同、foundation 六件套、DEM/蓝图生命周期、Mode D、testing/VALIDATION-REPORT、便携 `check-docs-sdd`、对话卫生规则、spec 工具箱加深。

## 验证
```text
bash scripts/verify-slice1.sh
→ RESULT: PASS — Slice 1.5 / 0.2.0 gates green
```
含：hooks Intake 硬闸 · 结构文件齐全 · 去 AgentDeck 硬编码 · scaffold（含 CLAUDE.md / check-docs / regression）· `check-docs-sdd` errors=0 WIP_CAP=8

## 安装
- `install-local.sh` → `~/.cursor/plugins/local/sdd-superpowers` @ 0.2.0
- 用户 hooks fail-open；**AgentDeck 无** `.cursor/sdd-enabled`
- sandbox `~/code/sdd-sandbox-empty` 已刷新骨架

## 相对 Slice 1 新增（摘要）
| 类 | 工件 |
|----|------|
| rules | `05-conversation-hygiene.mdc` |
| skills | `testing` · VALIDATION-REPORT · spec Ready Gate / Mode D |
| foundation | mission · principles · personas · package-contract · product-regression · system-map |
| regression | `regression-register.md` · `surfaces.json` |
| Mode D | `experience-design.md` · `problem-map.md` |
| CI | 便携 `scripts/check-docs-sdd.sh`（scaffold 复制到宿主） |
| 其它 | gap-closed · roadmap · BORROW 模板 · host `guides/vibe-coding.md` |

## 仍属后续（有意未做）
Claude Code / Codex 打包 · `/intake` commands · Marketplace · 英文化 · harness 自动冒烟（S2+）
