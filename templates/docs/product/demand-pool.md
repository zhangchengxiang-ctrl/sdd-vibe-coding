# 需求池

用户愿望、普通故障和体验反馈先记录在这里；生产事故另见
`docs/operations/incidents/`。入池 → Shape；实施以 `docs/specs/<id>/` 为准。

## 状态（条目态）

| 状态 | 含义 |
|---|---|
| `draft` | 信息可能不完整 |
| `shaping` | 正在澄清产品切片 |
| `design-ready` | **产品方案已确认**（方案闸通过），可进入研发自动编排 / Plan |
| `planned` | 已有 Spec |
| `delivered` | 已交付 |
| `parked` | 暂不处理，附理由 |

与能力地图态区分：本表跟踪单条愿望；`product/README` 能力地图跟踪成块能力。  
`design-ready` 语义见插件 `workflow-contract.md`「状态词汇」。

## 条目

| ID | 日期 | 类型 | 用户问题 / 目标 | 优先级建议 | 状态 | 产品真源 / Spec |
|---|---|---|---|---|---|---|
| DEM-001 | | wish / fault / ux / other | | P0 / P1 / P2 / park | draft | |

优先级建议供 Roadmap / 产品决定参考。
