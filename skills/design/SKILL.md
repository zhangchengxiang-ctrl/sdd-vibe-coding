---
name: design
description: >-
  面向略懂技术产品经理的 Shape 专项 Skill：澄清问题与首个价值切片；支持探索对话、
  代码库 grounding（拆解/学习 repo）与产品包分层。触发亦含：讨论产品、辩论、
  帮我想想、聊聊方向、拆解、deconstruct。仅在 vibe-coding 已路由到 Shape，或用户
  显式调用时使用；不隐式接管普通产品诉求，不写业务代码。
---

# Design：Shape 产品诉求

本 Skill 只负责已确认的 Shape Rail。先读宿主 `AGENTS.md`、产品真源和
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)。
用户只需能描述产品问题、判断取舍和确认结果；不得要求其理解实现结构或内部交付术语。

## 目标

把模糊愿望塑造成可以交给 Plan 的产品切片：

- 谁在什么情境下遇到什么问题；
- 用户要完成的 Job 和可观察结果；
- In / Out 与非目标；
- 关键体验、权限和失败路径；
- 已知事实、假设与未知；
- 首个可交付价值切片；
- 只需要用户决定的互斥或不可逆事项。

Shape 禁止创建实施 Spec、修改业务代码、部署或把技术偏好冒充产品决定。
写代码前硬闸与常见误判话术 → [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)。
权限 / 数据边界类诉求进入 Plan 前，应先有可读的代码与 Schema 事实（见 Plan「事实映射门」）；
不得在未查关系时发明平台级抽象。

## 工作方式

按用户意图选择入口，最终仍要落到可确认的产品切片：

| 意图 | 做法 |
|------|------|
| 聊方向 / 辩论 / 帮我想想（未要求锁切片） | 先走 [探索对话](./references/debate-style.md)，收敛后再出理解卡 |
| 拆解 / 学习 repo / 产品文档落后于代码 / 存量首次接入 | 先走 [代码库 grounding](./references/codebase-grounding.md)（含 Brownfield bootstrap），再 Shape |
| 成块能力蓝图 | 下方「产品包」；简单诉求可只写 demand pool / 单页 |

默认结构化路径：

1. 读取代码、现有产品文档和真实界面，建立当前状态；
2. 用一张理解卡复述问题、目标、非目标和未知；
3. 只追问会改变产品结果的 1–3 个问题；
4. 提出有明确代价的推荐，不把可逆技术细节抛给 PM；
5. 保存经确认的产品切片；
6. 内部记录 `design-ready`，前台说明“产品方向已清楚，可以进入实施拆解”及启动方式。

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

产品切片确认后，追加“当前进展”，用普通中文说明：

- 产品方向已经确认；
- 首个可交付价值是什么；
- 下一步是拆解实施顺序和风险；
- 请求用户评审本阶段结论，并批准进入实施拆解。

默认不展示 `design-ready`、Rail、In / Out、Oracle、产品真源路径或内部编号。用户要求查看
时，将其放在卡片之后的“技术详情（可选）”中。

## 产品包

成块能力可存放在：

```text
docs/product/modules/<slug>/
├── README.md
├── 01-experience.md
├── 02-product-model.md
├── 03-presentation.md
├── 04-runtime.md
└── 05-delivery.md
```

只创建当前问题需要的层，不为空目录凑文档。章节合同与剪枝以
[`product-package.md`](./references/product-package.md) 为唯一真源。

| 层 | 负责 | 不负责 |
|---|---|---|
| Experience | 角色、旅程、操控面、失败体验 | 表结构、算法 |
| Product model | 能力、对象、状态、权限、冻结决策 | UI 配置、实现代码 |
| Presentation | IA、入口、文案和视觉语义 | 数据库和 API 细节 |
| Runtime intent | 运行边界和关键路径意图 | 完整技术设计 |
| Delivery | 首切片、后续切片、风险和指标 | Spec 切片 / Plan |

简单诉求可以只写 demand pool 或单页设计，不强制五层产品包。

## 交付给 Plan

Shape 结束时在内部工件保存：

- 一句话问题与目标用户；
- 已确认的首个价值切片；
- In / Out；
- 成功、关键失败与权限场景；
- 不可破坏的产品不变量；
- 未决项及负责人；
- 产品真源路径；
- 下一 Rail：`plan`。

用户前台只给理解卡、必要的决策卡、确认后的进度卡和一句明确下一步；阶段结束时必须请求
用户批准进入 Plan（阶段闸门规则见 `workflow-contract.md` 的“阶段闸门”一节）。不要在同一
对话继续技术拆解或编码。
