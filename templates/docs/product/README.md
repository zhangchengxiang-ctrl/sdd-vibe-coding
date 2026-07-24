# 产品文档

本目录保存相对稳定的产品目标、能力蓝图和差距；版本实施以 `docs/specs/<id>/` 为真源，
实际行为以代码和运行环境为真源。

## 读序

| 路径 | 回答什么 |
|---|---|
| `foundation/` | 使命、原则、角色旅程、系统边界 |
| `modules/<slug>/` | 成块能力的产品蓝图 |
| `demand-pool.md` | 尚未进入 Plan 的愿望和反馈 |
| `gap-register.md` | 蓝图与现状之间的差距 |
| `regression-register.md` | 维护态关键用户旅程 |
| `../planning/roadmap.md` | 排期 |
| `../specs/<id>/` | 当前版本实施合同 |

## 能力地图

| ID | 能力 | 蓝图包 | 状态 | Spec / Gap |
|---|---|---|---|---|
| C-001 | | `modules/<slug>/` | shaping | |

## 状态枚举

| 状态 | 含义 |
|---|---|
| `shaping` | 产品方向仍在澄清 |
| `design-ready` | 产品切片已确认，未进入技术 Plan |
| `planned` | 已有 Spec 与 执行步骤 |
| `partially-delivered` | 部分价值切片已交付 |
| `accepted` | 当前声明范围已通过 Version Acceptance |
| `archived` | 历史或废弃 |

不要在 modules 和 Spec 双写同一实施合同；产品决定变化时更新蓝图，技术实现变化时更新
Spec 或代码。
