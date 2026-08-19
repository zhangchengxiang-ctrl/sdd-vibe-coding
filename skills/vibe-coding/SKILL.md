---
name: vibe-coding
description: >-
  Spec-Driven Delivery（SDD）跨端主入口。仅在用户显式进入 SDD 交付轨时使用：
  /vibe-coding 或 @vibe-coding、许愿、确认方案、就按这个做、切 Spec、关版、
  polish/抛光/按 refinement 修、初始化项目或接入存量（SDD 冷启动）、
  派 Codex/用 Codex 做、显式人类验收或生产发布/上线/部署。
  触发后须先 Read 本 SKILL.md，再读宿主 AGENTS.md；先判 project.kind。
  禁止因普通调研、读文档、SSH、取数、看 session、修 bug、实现功能、排障、
  优化体验、我想要/聊聊/拆解等日常请求而加载。子轨由本入口路由；
  Codex 指挥见 dispatch-codex。
---

# Vibe Coding

**北极星：** 先满足用户本轮意图 → **仅 Deliver 时**启用形式安全网 → 关版（无 UI 机器 / 有 UI 人点验）→（另批）Deploy。  
Explore / Deliver 合同 → [`explore-deliver.md`](./references/explore-deliver.md)。  
指挥侧 Build = 先判 Codex eligible（[`codex-boundary.md`](../dispatch-codex/references/codex-boundary.md)）；合格片走 [`dispatch-codex`](../dispatch-codex/SKILL.md)。

## FIRST ACTION

1. 判 `project.kind`（`software` | `plugin` | `other`）——见 [`project-kind.md`](./references/project-kind.md)；禁止默认 software。  
2. 仅 software 宿主 + 显式 SDD 意图时：第一个工具调用 = Read 本文件 → 再读 [`explore-deliver.md`](./references/explore-deliver.md) + 宿主 `AGENTS.md`。  
3. **判 Explore / Deliver**（未说落盘/确认/切 Spec/开始做/关版/发布 → 默认 **Explore**）。  
4. **常驻只读** [`gates.md`](./references/gates.md) 摘要；**勿**首轮加载全套 design-standards / spec / testing——进对应 Rail 再读（见 explore-deliver §懒加载）。

| kind | 动作 |
|---|---|
| `software` | 下方路由 |
| `plugin` | 读 ARCHITECTURE；改 skills/templates/scripts |
| `other` | 放手 |

## 路由

| 用户意图 | 模式 |
|---|---|
| 帮我想想 / 聊聊 / 怎么设计 / 调研 / 读代码 / 对比方案（未要求落盘） | **Explore** → 直接答；Shape 用 `design`+debate/grounding；infra 机制可 Explore+读码后入 Plan |
| 用户说「先别走 SDD / 不要卡片 / 直接给方案 / 这轮 Explore」 | **Explore**（强制；见 explore-deliver） |
| 机制/平台（kill/timeout/取消传播/RG/capacity/cancel/query gateway/中止 等）且要 **落盘/实施** | Deliver → Plan → Skill `spec` |
| 初始化 / 接入存量 / 基线空 | 冷启动 → Skill `design` → `project-init` |
| 我希望 / 我想要（基线已齐） | 默认 **Explore** → `design`；用户要「产品方案/给 PM」→ Deliver Shape 卡片 |
| 就按这个做 / 确认方案 | **Deliver** → Plan → eligible 派 Codex → Verify |
| 派 Codex / 用 Codex 做 | 仅 eligible；越界仍指挥侧 |
| 切 Spec / Plan | **Deliver** → Plan → Skill `spec` |
| Spec 批准 / 开始做 / 实现 | **Deliver** → Build |
| polish / 抛光 / 前端小改 / 按 refinement 修 | **Polish**（非 material；material → Shape） |
| 验收 / UX 走查 | **Deliver** → Verify → Skill `testing` |
| 通过了 / 关版 / 归档 | **Deliver** → `make close-spec`；再问是否 Deploy |
| 发布 / 上线 / 部署 | **Deliver** → Skill `deploy`（P0–P6） |
| 只定位复杂/线上问题 | Diagnose → Skill `debug` |

## 高质量内核（Deliver 时不可省）

| 层 | 义务 |
|----|------|
| 产品正确 | 方案闸：Job / In-Out / 主路径；**Explore 不要求卡片** |
| 合同正确 | 事实映射 → 纵向切片 → Spec 五件套 → 强 Oracle |
| 实现正确 | 一 D 一次 exec（272K）；eligible → Context Pack→Codex；否则指挥侧；Oracle 冻结 |
| 验证正确 | 先证伪；maker ≠ grader |
| 发布正确 | 关版后另批 Deploy P4；自动段禁生产 |

## 按需

- Explore / Deliver：[`explore-deliver.md`](./references/explore-deliver.md)  
- Polish / material：[`change-control.md`](./references/design-standards/change-control.md) + LOAD-MAP  
- UI 施工索引：[`design-standards/LOAD-MAP.md`](./references/design-standards/LOAD-MAP.md)  
- Workspace：[`workspace-contract.md`](./references/workspace-contract.md)  
- Evidence：[`evidence-contract.md`](./references/evidence-contract.md)  
- 三钉：[`verification-loop.md`](./references/verification-loop.md)  
- SDD docs root：[`docs-root.md`](./references/docs-root.md)  
- Build 自动化通则：[`automated-tests.md`](./references/automated-tests.md)  
- 索引（兼容旧链）：[`workflow-contract.md`](./references/workflow-contract.md)
