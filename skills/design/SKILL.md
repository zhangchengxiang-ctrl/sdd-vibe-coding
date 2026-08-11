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
[`project-kind.md`](../vibe-coding/references/project-kind.md)、产品真源和
[`gates.md`](../vibe-coding/references/gates.md)。
有体验或 UI 诉求时：**先打开**
[`design-standards/LOAD-MAP.md`](../vibe-coding/references/design-standards/LOAD-MAP.md)，
并立刻读 [`product-judgment.md`](../vibe-coding/references/design-standards/product-judgment.md)
（Job Brief 先于控件）。改存量 UI 见 [change-control.md](../vibe-coding/references/design-standards/change-control.md)。
评审用 [`ui-page-gate.md`](../vibe-coding/references/design-standards/ui-page-gate.md) /
[critique-format.md](./references/critique-format.md)。

## 冷启动（优先于普通 Shape）

基线未齐或用户在做项目初始化 / 存量接入时：**先读并执行**
[`project-init.md`](./references/project-init.md)（Init / Onboard）。

- 前台：推断 → 基线草案 → 确认；整轮拍板 **≤5**；禁止长表填写。  
- `project.kind` 仅 `software`\|`plugin`\|`other`；只有 `software` 走编码表单全量。
- 确认投影后才进入下方「普通 Shape」；冷启动完成 **≠** Build 授权。

## 目标

把模糊愿望塑造成**可确认的产品方案**（再交给研发自动编排或经典 Plan）：

- 谁在什么情境下遇到什么问题；
- 用户要完成的 Job 和可观察结果；
- In / Out 与非目标；
- 关键体验、权限和失败路径；
- 已知事实、假设与未知；
- 首个可交付价值切片；
- 只需要用户决定的互斥或不可逆事项。

Shape 产出：`docs/product/` 产品方案 / 切片与理解卡。  
**硬门：** 本轨不创建实施 Spec、不改业务代码、不部署。  
写码授权 / 许愿编排：见 [`gates.md`](../vibe-coding/references/gates.md)。  
明示 polish → 结束 Shape，交回 vibe-coding Polish 档（[`change-control.md`](../vibe-coding/references/design-standards/change-control.md)）；material 仍留 Shape。

## 工作方式

按用户意图选择入口，最终仍要落到可确认的产品切片：

| 意图 | 做法 |
|------|------|
| 初始化项目 / 新开 / 立项 / 接入存量 / 基线空 | **先** [项目冷启动](./references/project-init.md)（Init 或 Onboard） |
| 聊方向 / 辩论 / 帮我想想（未要求锁切片） | 先走 [探索对话](./references/debate-style.md)，收敛后再出理解卡 |
| 拆解 / 学习 repo / 产品文档落后于代码 | [代码库 grounding](./references/codebase-grounding.md)；若属首次接入则走 Onboard |
| 成块能力蓝图 | 下方「产品包」；简单诉求可只写 demand pool / 单页 |

默认结构化路径：

1. 读取代码、现有产品文档和真实界面，建立当前状态；
2. 用一张理解卡复述问题、目标、非目标和未知；
3. 只追问会改变产品结果的 1–3 个问题；
4. 提出有明确代价的推荐，不把可逆技术细节抛给 PM；
5. 保存经确认的产品方案/切片；
6. 内部记录 `design-ready`，前台说明「产品方案已清楚」并**明确请求确认方案**（可回复：就按这个做 / 确认方案）。

外部事实、竞品、法规或平台能力会影响设计时才联网，并记录来源与日期。

## Shape 前台合同

**探索对话**期间服从 [debate-style](./references/debate-style.md)（口语、少结构）。
一旦收敛或用户要落盘 / 准备实施，改用下列卡片：

每次 Shape 回复先输出“我理解的目标”：

- 目标用户与使用情境；
- 当前问题和期望结果；
- 当前价值切片；
- 明确不做的内容；
- 仍需验证的事实。

只有产品结果会因选择而改变时，才追加“需要你决定”。每个问题必须给出推荐、理由、选项
代价和可直接回复的方式，每轮最多 1–3 个。没有需要拍板的事项时，不输出空决策卡。

产品方案就绪后，追加“当前进展”，用普通中文说明：

- 这是建议的**产品方案**（不是实施细节）；
- 首个可交付价值是什么；
- 确认后 AI 将按质量条自动拆解、实现、自测与走查，最后给你一份验收用例；
- **请确认方案**（例如回复「就按这个做」）。

默认不展示 `design-ready`、Rail、In / Out、Oracle、产品真源路径或内部编号。用户要求查看
时，将其放在卡片之后的“技术详情（可选）”中。

## 产品包

成块能力可存放在 `docs/product/modules/<slug>/`（01–05）。  
**默认剪枝：** 简单诉求只写 demand pool 或单页；**禁止**为齐套建空层。  
章节合同：[`product-package.md`](./references/product-package.md)。  
方案脊：[`perceptible-path.md`](./references/perceptible-path.md) + [`scheme-antipatterns.md`](./references/scheme-antipatterns.md)。

## 交付给 Plan / 研发编排

Shape 结束时在内部工件保存：

- 一句话问题与目标用户；
- 已确认的首个价值切片 / 产品方案；
- In / Out；
- 成功、关键失败与权限场景；
- 不可破坏的产品不变量；
- 未决项及负责人；
- 产品真源路径；
- 下一动作：许愿路径 = 方案确认后自动 `plan`→编排；经典路径 = 等人说切 Spec。

用户前台只给理解卡、必要决策卡、**产品方案确认请求**。确认后由 vibe-coding 按 [`gates.md`](../vibe-coding/references/gates.md) 自动编排。
