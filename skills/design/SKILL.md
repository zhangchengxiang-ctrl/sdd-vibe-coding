---
name: design
description: >-
  SDD Shape / 冷启动专项：Init/Onboard 与可确认产品方案、产品包分层。
  仅在 vibe-coding 已路由到 Shape/冷启动，或用户显式 @design /
  「初始化项目接入 SDD」时使用。禁止因帮我想想、聊聊、拆解、辩论、
  优化体验等日常话术自动加载；不写业务代码。
disable-model-invocation: true
---

# Design：Shape 产品诉求

本 Skill 只负责已确认的 Shape Rail（含冷启动子流程）。先读宿主 `AGENTS.md`、
[`explore-deliver.md`](../vibe-coding/references/explore-deliver.md)、
[`project-kind.md`](../vibe-coding/references/project-kind.md)、产品真源和
[`gates.md`](../vibe-coding/references/gates.md)。

## 默认：Explore（不是卡片）

**未**要求「产品方案 / 落盘 / 给 PM / 确认方案 / 准备实施」时：

- 走 [探索对话](./references/debate-style.md) 或 [代码库 grounding](./references/codebase-grounding.md)；
- **直接回答用户 Job**，满足 explore-deliver **实质闸**（代码锚点 / 可证伪断言 / 机制权衡 / 可观察场景）；
- **禁止**默认输出「我理解的目标」理解卡、禁止请「确认方案」、禁止只对齐 `docs/product/`。

用户说「先别走 SDD / 不要卡片」→ 整轮 Explore。

## Deliver Shape（卡片 · opt-in）

仅当用户 **明确** 要产品交付物时启用前台卡片（理解卡 → 决策卡 → 请确认方案）：

- 「出产品方案 / 给 PM / 落盘 / 准备实施 / 确认方案 / 就按这个做」
- 或 Explore 收敛后用户 **主动** 要求锁切片

有体验或 UI 诉求且 **进入 Deliver Shape** 时：**再读**
[`design-standards/LOAD-MAP.md`](../vibe-coding/references/design-standards/LOAD-MAP.md) +
[`product-judgment.md`](../vibe-coding/references/design-standards/product-judgment.md)。
Explore 讨论 UI 时可口头对齐 Job，**不必**先填 Design Read / anchor。

## 排除（infra/平台机制设计 · Deliver）

当用户要 **落盘/实施** infra/平台机制（kill/timeout/取消传播/RG/capacity/cancel/query gateway/中止 等）时，本 Skill 不负责；路由 Plan→`spec` + [`infra-mechanism-brief.md`](../spec/references/infra-mechanism-brief.md)。  
Explore 下讨论机制 → 读码 + 实质闸即可，不必 Shape 卡片。

改存量 UI 见 [change-control.md](../vibe-coding/references/design-standards/change-control.md)。  
评审用 [ui-page-gate.md](../vibe-coding/references/design-standards/ui-page-gate.md) /
[critique-format.md](./references/critique-format.md)。

## 冷启动（优先于普通 Shape）

基线未齐或用户在做项目初始化 / 存量接入时：**先读并执行**
[`project-init.md`](./references/project-init.md)（Init / Onboard）。

- 前台：推断 → 基线草案 → 确认；整轮拍板 **≤5**；禁止长表填写。  
- `project.kind` 仅 `software`\|`plugin`\|`other`；只有 `software` 走编码表单全量。
- 确认投影后才进入下方「普通 Shape」；冷启动完成 **≠** Build 授权。

## 目标（Deliver Shape 结束时）

把模糊愿望塑造成**可确认的产品方案**（再交给 Plan / 编排）：

- 谁在什么情境下遇到什么问题；
- Job 和可观察结果；In / Out；
- 关键体验、权限和失败路径；
- 首个可交付价值切片；
- 只需用户决定的互斥或不可逆事项。

Shape 产出（**Deliver 且用户确认后**）：这一次许愿落成一个版本目录 `docs/iterations/<yyyy-mm>/<w>/<版本>/`——原话进 `quote.md`、需求与待裁定进 `requirements.md`、用户拍板进 `decisions.md`；长期有效的产品定义（能力、IA、产品模型）写回 `docs/product/`。  
**硬门：** 本轨不创建实施 Spec、不改业务代码、不部署。  
写码授权：见 [`gates.md`](../vibe-coding/references/gates.md)。

## 工作方式

| 意图 | 做法 |
|------|------|
| 初始化 / 接入存量 / 基线空 | [项目冷启动](./references/project-init.md) |
| 聊方向 / 帮我想想 / 怎么设计（默认） | **[debate-style](./references/debate-style.md)** + 实质闸 |
| 拆解 / 学习 repo | [codebase-grounding](./references/codebase-grounding.md) |
| 要产品方案 / 给 PM / 落盘 | **Deliver Shape** → 下方「前台卡片」 |
| 成块能力蓝图（Deliver） | 「产品包」；简单诉求只写 demand pool / 单页 |

Deliver Shape 结构化路径：

1. 读代码、文档、真实界面（as-built）；
2. 理解卡 → 必要决策卡（1–3 个，有推荐与代价）；
3. 用户确认后写该版本的 `requirements.md` / `decisions.md`（原话先落 `quote.md`），长期产品定义写回 `docs/product/`；
4. 内部 `design-ready`；前台请「确认方案」。

Explore 路径：**跳过 2–4**，除非用户转 Deliver。  
外部事实影响设计时才联网，并记录来源与日期。

## Shape 前台合同（仅 Deliver · opt-in）

探索对话期间 → [debate-style](./references/debate-style.md)。  
**仅 Deliver Shape** 使用下列卡片：

**「我理解的目标」**（简短）：

- 目标用户与情境；问题与期望结果；价值切片；明确不做；待验证事实。

**「需要你决定」**（仅当选择会改变产品结果；每轮 ≤3，带推荐与代价）

**「当前进展」**（方案就绪时）：

- 建议的**产品方案**（非实施细节）；首个可交付价值；**请确认方案**（「就按这个做」）。

默认不展示 `design-ready`、Rail、Oracle 等；用户要求时放「技术详情（可选）」。

## 产品包

成块能力：`docs/product/modules/<slug>/`（01–04，常青；分期与系列验收写在版本目录）。  
**默认剪枝**：简单诉求单页；**禁止**齐套空层（antipattern #7）。  
[`product-package.md`](./references/product-package.md) · [`perceptible-path.md`](./references/perceptible-path.md) · [`scheme-antipatterns.md`](./references/scheme-antipatterns.md)。

## 交付给 Plan

**Deliver Shape 确认后** 内部保存：切片、In/Out、失败路径、不变量、未决项、产品真源路径。  
下一动作：方案确认 → `plan`（许愿自动编排）或等人说切 Spec。
