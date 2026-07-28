# UX Validation Standards

> **规范真源**：[design-standards/ux.md](../../vibe-coding/references/design-standards/ux.md)  
> （ISO 9241、检查维度、Nielsen H1–H10、反模式、Shape 自检。）  
> 视觉底线 → [design-standards/visual.md](../../vibe-coding/references/design-standards/visual.md)。  
> 加载合同 → [design-standards/README.md](../../vibe-coding/references/design-standards/README.md)。  
> 专家走查步骤 → [ux-walkthrough.md](./ux-walkthrough.md)（Verify 变体，非独立 Skill）。

本文只保留 **Verify 接线**：如何把上述规范用于验收证据。启发式正文真源在 design-standards。

## Verify 判定

**Pass = 指定用户在真实情境下能有效、高效、满意地完成目标**（定义见 ux.md）。  
有控件 / Toast / API 200 / 空态文案 **单独均不算 Pass。**

- 使用目标角色、真实入口和代表性数据；
- 观察系统反馈、错误恢复和最终状态；
- 截图或录像必须让未参与实现的人判断场景与结果；
- 不能执行时标记 Blocked；真实通道证据优先于 mock / API / 口头推演。

严重度与 Nielsen 评分规则以 **ux.md** 为准；**4 → 阻断核心 Job → Job Fail**。

## Spec 工件（有 UI / 手动验收时）

| 工件 | 角色 |
|------|------|
| design-standards `ux` / `visual`（插件） | 定义 · ISO · Nielsen · 视觉底线 · 反模式 |
| `docs/specs/<id>/tests.md` | 本版 Jobs / Then Oracle + 通道；声明服从上述规范 |
| `run.md`（Evidence 列 / 附件路径） | 实测账本（Jobs + H# findings） |

不适用：纯后端无 UI、纯文档、纯 CI（`run.md` 写 `UX: N/A` + 理由）。

## 证据

每个关键 Job 至少记录入口、步骤、期望、实际结果、环境/版本和一份可复核证据。  
核心 Job 阻断（严重度 4）→ Version Acceptance 不通过。
