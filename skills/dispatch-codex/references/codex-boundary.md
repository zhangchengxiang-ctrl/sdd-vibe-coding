# Codex 能力边界（越界禁派）

> 唯一允许/禁止表。摘要见 [`gates.md`](../../vibe-coding/references/gates.md)。机检：`assert_codex_eligible.py`。

越界 **exit 2**；口头「派 Codex」无豁免。维护者：`SKIP_CODEX_BOUNDARY=1`。

## 允许（须同时）

Build/Repair **单切片**（A==D）；全部 T-xxx 为 **machine** Oracle；allowlist 非空、**文件级**（禁 `src/`）、≤8 路径；无 UI/`page_kind`/视觉/`user_visible_gap`；备注非 `oracle:human|lab`、非架构差量；非 `executor:conductor`。

## 禁止

Plan/Spec/Oracle/拆片（`--unit plan`）、Shape、Verify、UI/产品判断、弱/人工 Oracle、宽 allowlist、多片一 exec、compact 续跑、Desktop 长会话、无 Spec 许愿实现。

## 谁动手

eligible → `codex-dispatch --unit build` / wish；否则指挥侧 + `run.md` 写 `executor: conductor`。eligible 片仅可用 `override: 用户要求自写` 逃派，不可用 conductor。

`MAX_ALLOWLIST_PATHS=8`（与 `assert_codex_eligible.py` 同源）。
