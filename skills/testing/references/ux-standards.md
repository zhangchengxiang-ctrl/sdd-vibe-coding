# UX Validation Standards

> **入口**：[design-standards/LOAD-MAP.md](../../vibe-coding/references/design-standards/LOAD-MAP.md)  
> **启发式真源**：[design-standards/ux.md](../../vibe-coding/references/design-standards/ux.md)  
> 视觉/尺度/页面/文案/审计 → visual · tokens · pages · copy · audit · exemplars（均经 LOAD-MAP 加载）  
> 专家走查 → [ux-walkthrough.md](./ux-walkthrough.md)。

本文只保留 **Verify 接线**。

## Verify 判定

**Pass = 指定用户在真实情境下能有效、高效、满意地完成目标**（ux.md）。  
有控件 / Toast / API 200 / 空态文案 **单独均不算 Pass。**

走查时按 Spec 的 `page_kind`/`motif` 打开对应 `pages/*.md` 自检，并抽：

- [audit/ai-tells.md](../../vibe-coding/references/design-standards/audit/ai-tells.md)  
- [audit/web-interface.md](../../vibe-coding/references/design-standards/audit/web-interface.md)  
- [copy.md](../../vibe-coding/references/design-standards/copy.md)  
- [exemplars/](../../vibe-coding/references/design-standards/exemplars/README.md) 同类型正反例  

轮次与 Visual QA → [bounded-verify.md](./bounded-verify.md)。  
严重度：Nielsen **0–4**（ux.md）；走查用语 **P0/P1/P2** 映射见 [change-control.md](../../vibe-coding/references/design-standards/change-control.md)（**4↔P0，3↔P1，1–2↔P2**）。**4 / P0 → Job Fail**。

## Spec 工件

| 工件 | 角色 |
|------|------|
| design-standards（LOAD-MAP 所点册） | 定义与页面/交互/文案合同 |
| `tests.md` | Jobs / Oracle；声明服从上述 |
| `run.md` | 实测账本 |

不适用：纯后端无 UI（`UX: N/A`）。

## 证据

每关键 Job：入口、步骤、期望、实际、环境、可复核证据。核心 Job 阻断 → Acceptance 不通过。
