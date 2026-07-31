# Bounded Verify（有界验收轮次）

> 蒸馏：Impeccable Core principles、visual-qa-testing。防止 open-ended 自扫烧钱。

## 轮次硬停

1. **一批** 证据：按 `tests.md` 适用用例跑完（含约定 desktop + 关键 mobile 截图）。  
2. **一批** 修复：只修本批 Fail / P0–P1（Verify **不改码**；Repair 回 Build）。  
3. **最多再一轮** confirm 扫描。  
4. **停止** — 剩余 P2 记限制；禁止无期限「再扫一轮」。

## Visual QA 三态报告（有 UI 的浏览器通道）

在 [browser-verify.md](./browser-verify.md) V2 之上，UI 变更须记录：

| 态 | 查什么 | 写入 |
|----|--------|------|
| **视觉** | 主 Job 屏截图；对照 page_kind 自检 + ai-tells 抽检 | `run.md` Evidence |
| **控制台** | 无 fatal / 未处理 rejection（与 Job 相关） | 有则 Fail 或限制 |
| **网络** | 主路径无意外 4xx/5xx（预期错误除外） | 有则归因 |

不必每轮全站爬虫；覆盖**本切片声明的 page_kind 主 Job**即可。

## 与走查

UX 走查变体仍用 [ux-walkthrough.md](./ux-walkthrough.md)；发现分级用 [critique-format](../../design/references/critique-format.md) 或 O→I→S。  
严重度 4 → Job Fail（ux.md）。
