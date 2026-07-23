---
name: design
description: >-
  Codex 的 Shape 专项 Skill：澄清用户 Job、体验边界与首个价值切片并沉淀产品蓝图。
  仅在 vibe-coding 已路由到 Shape，或用户显式调用本 Skill 时使用；不隐式接管普通产品诉求，
  不写业务代码。
---

# Design：Shape 产品诉求

本 Skill 只负责已确认的 Shape Rail。先读宿主 `AGENTS.md`、产品真源和
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)。

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

## 工作方式

1. 读取代码、现有产品文档和真实界面，建立当前状态；
2. 用一张理解卡复述问题、目标、非目标和未知；
3. 只追问会改变产品结果的 1–3 个问题；
4. 提出有明确代价的推荐，不把可逆技术细节抛给 PM；
5. 保存经确认的产品切片；
6. 输出 `design-ready`，并为下一次 Plan 提供入口。

外部事实、竞品、法规或平台能力会影响设计时才联网，并记录来源与日期。

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

只创建当前问题需要的层，不为空目录凑文档。宿主存在
`docs/product/foundation/product-package-contract.md` 时服从其章节合同。

| 层 | 负责 | 不负责 |
|---|---|---|
| Experience | 角色、旅程、操控面、失败体验 | 表结构、算法 |
| Product model | 能力、对象、状态、权限、冻结决策 | UI 配置、实现代码 |
| Presentation | IA、入口、文案和视觉语义 | 数据库和 API 细节 |
| Runtime intent | 运行边界和关键路径意图 | 完整技术设计 |
| Delivery | 首切片、后续切片、风险和指标 | Task 拆解 |

简单诉求可以只写 demand pool 或单页设计，不强制五层产品包。

## 交付给 Plan

Shape 结束时给出：

- 一句话问题与目标用户；
- 已确认的首个价值切片；
- In / Out；
- 成功、关键失败与权限场景；
- 不可破坏的产品不变量；
- 未决项及负责人；
- 产品真源路径；
- 下一 Rail：`plan`。

不要在同一对话继续技术拆解或编码。
