---
name: testing
description: >-
  跨项目定向测试与证据分层（V0–V3）。矩阵验收 / 禁热修 / remediation →
  vibe-coding acceptance-to-remediation（本 skill 不复述）。
  触发：测试 / test / E2E / 验证报告 / 回归 / 定向验证。
---

# 测试与验收

**先读**：宿主 `AGENTS.md` + 当前任务直接验收条件。已挂 Spec → `scenario-spec` / `validation`；体验 → [`ux-standards`](../vibe-coding/references/ux-standards.md)。  
**Accept 矩阵 / 3 硬钉 / 轨工单** → [`acceptance-to-remediation`](../vibe-coding/references/acceptance-to-remediation.md)（禁止本文件复述）。

## 原则

- 主代理做最小定向验证；全量仅发布/CI/全局合同或用户明示。  
- 已通过且代码未变 → 不重跑。只修本次 diff 引入或直接阻断项。

## 证据分层（V0–V3）

| 层 | 证明 | 例 |
|----|------|-----|
| V0 | 静态合同 | lint / 类型 |
| V1 | 逻辑 | 定向单测 / API |
| V2 | 真实通道 SC | Browser / 运行时 Job |
| V3 | 全局 | 全量 / CI / 发布 |

UI Demo Gate ≥ 一次 V2。命令从宿主 `AGENTS.md` / Makefile 读（禁止写死）。

## 改动 → 最低验收

| 改动 | 原则 |
|------|------|
| 后端 | 相关静态 + 后端测 |
| 前端 | 相关前端测 + **宿主浏览器验收** |
| 全栈 | 相关前后端 + 当前 In scenario |
| DB / 单向门 | migrate/health 或宿主等价；单向门 + 人眼 diff |

新产品 / Major：`scenario-spec` 覆盖角色 × 旅程 × 失败/权限。  
有 UI：`ux-test-results` + Jobs；核心 Job Fail / 严重度 4 → 不得关版。

证据目录：`docs/specs/<id>/evidence/`（截图 · README · `user-review`）。  
正式报告 → [`validation-report`](./references/validation-report.md)。Ordinary fix → Docs: N/A。
