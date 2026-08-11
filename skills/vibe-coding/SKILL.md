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

**北极星：** 人定方案 → AI 按质量条交付 → 关版（无 UI 机器 / 有 UI 人点验）→（另批）Deploy。  
指挥侧 Build = 派发（Skill [`dispatch-codex`](../dispatch-codex/SKILL.md)）。

## FIRST ACTION

1. 判 `project.kind`（`software` | `plugin` | `other`）——见 [`project-kind.md`](./references/project-kind.md)；禁止默认 software。  
2. 仅 software 宿主 + 显式 SDD 意图时：第一个工具调用 = Read 本文件 → 再读宿主 `AGENTS.md`。  
3. 本轨只读 1 份常驻合同：[`gates.md`](./references/gates.md)。关版读 [`states.md`](./references/states.md)；进 Build/Verify 读 [`rails.md`](./references/rails.md)。

| kind | 动作 |
|---|---|
| `software` | 下方路由 |
| `plugin` | 读 ARCHITECTURE；改 skills/templates/scripts |
| `other` | 放手 |

## 路由

| 用户意图 | 模式 |
|---|---|
| 初始化 / 接入存量 / 基线空 | 冷启动 → Skill `design` → `project-init` |
| 我希望 / 我想要（基线已齐） | Shape → Skill `design`（产品方案） |
| 就按这个做 / 确认方案 | 许愿编排：Plan→打包 D→edit-wave Codex→Verify→证据卡或验收包 |
| 派 Codex / 用 Codex 做 | 同 Build（派发是默认通道） |
| 切 Spec / Plan | Plan → Skill `spec` |
| Spec 批准 / 开始做 / 实现 | Build：打包 D → 派发 |
| polish / 抛光 / 前端小改 / 按 refinement 修 | **Polish**（非 material；material → Shape） |
| 验收 / UX 走查 | Verify → Skill `testing` |
| 通过了 / 关版 / 归档 | 关版授权 → `make close-spec`；再问是否 Deploy |
| 发布 / 上线 / 部署 | Deploy → Skill `deploy`（P0–P6） |
| 只定位复杂/线上问题 | Diagnose → Skill `debug` |

## 高质量内核（不可省）

| 层 | 义务 |
|----|------|
| 产品正确 | 方案闸：Job / In-Out / 主路径；人确认前不施工 |
| 合同正确 | 事实映射 → 纵向切片 → Spec 五件套 → 强 Oracle |
| 实现正确 | 一 D 一次 exec（272K）；Context Pack→Codex；Oracle 冻结 |
| 验证正确 | 先证伪；maker ≠ grader |
| 发布正确 | 关版后另批 Deploy P4；自动段禁生产 |

## 按需

- Polish / material：[`change-control.md`](./references/design-standards/change-control.md) + LOAD-MAP  
- UI 施工索引：[`design-standards/LOAD-MAP.md`](./references/design-standards/LOAD-MAP.md)  
- Workspace：[`workspace-contract.md`](./references/workspace-contract.md)  
- Evidence：[`evidence-contract.md`](./references/evidence-contract.md)  
- 三钉：[`verification-loop.md`](./references/verification-loop.md)  
- SDD docs root：[`docs-root.md`](./references/docs-root.md)  
- 运行时 hooks：[`runtime-hooks.md`](./references/runtime-hooks.md)  
- Build 自动化通则：[`automated-tests.md`](./references/automated-tests.md)  
- 索引（兼容旧链）：[`workflow-contract.md`](./references/workflow-contract.md)
