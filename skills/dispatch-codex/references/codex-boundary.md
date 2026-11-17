# Codex 能力边界（越界禁派）

> 唯一允许/禁止表。摘要见 [`gates.md`](../../vibe-coding/references/gates.md)。机检：`assert_codex_eligible.py`。

越界 **exit 2**；口头「派 Codex」无豁免。维护者：`SKIP_CODEX_BOUNDARY=1`。

## 允许（须同时）

Build/Repair **单切片**（A==D）；全部 T-xxx 为 **machine** Oracle；allowlist 非空、**文件级**（禁 `src/`）、≤8 路径；无 UI/`page_kind`/视觉/`user_visible_gap`；备注非 `oracle:human|lab`、非架构差量；非 `executor:conductor`。

## 禁止

Plan/Spec/Oracle/拆片（`--unit plan`）、Shape、Verify、UI/产品判断、弱/人工 Oracle、宽 allowlist、多片一 exec、compact 续跑、Desktop 长会话、无 Spec 许愿实现。

## 负控 / 保留项 Oracle

`ship.sh` 要求每条 Oracle 在基线上为红（基线即绿 = `nondiscriminating`，什么都没量）。这是设计，不是缺陷。
所以「保留项仍存在」这类负控**必须与本切片的变更合取**（`保留项仍在 && 目标已删`），让它在基线上红、改后绿；
单独的保留检查基线必绿，会让下一波被 replay 门拦下。

## Oracle 写法的两条约定（回放实测踩出来的）

- **路径写仓库根相对路径。** `ship.sh` 的 maker≠grader 检查按仓库根解析命令里的测试路径；若命令经运行器切换目录
  （如在 `backend/` 下跑 pytest），相对子目录的路径会被误判为「评判者基线不存在」。写 `backend/tests/...`，由运行器去掉前缀。
- **冻结测试依赖的注入点，Spec 必须点名。** 测试若 `monkeypatch.setattr(module, "_utc_now", …)`，实施者只能从测试文件猜出
  这个符号；Spec 只写「`now` 注入」会让实施者实现不出该接缝（fix-11 首轮 5 例红即因此）。把符号名写进 contract 的接口段。

## 谁动手

eligible → `codex-dispatch --unit build` / wish；否则指挥侧 + `run.md` 写 `executor: conductor`。eligible 片仅可用 `override: 用户要求自写` 逃派，不可用 conductor。

`MAX_ALLOWLIST_PATHS=8`（与 `assert_codex_eligible.py` 同源）。
