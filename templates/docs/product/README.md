# 产品文档（门面）

> 读序：本页 → `foundation/` → `modules/<slug>/` → 切版后以 `specs/<id>/` 为实施真源。  
> 怎么跑 → **读代码** + [system-map](./foundation/system-map.md)。

## 读序

| 顺序 | 路径 | 回答什么 |
|------|------|----------|
| 1 | 本 README | 能力地图 + 模块状态 |
| 2 | [foundation/](./foundation/) | 使命、原则、旅程、system-map、包合同、产品回归 |
| 3 | [`modules/<slug>/`](./modules/) | 蓝图五层 |
| 4 | [demand-pool.md](./demand-pool.md) | 用户愿望 / 故障（Intake→Owner） |
| 5 | [gap-register.md](./gap-register.md) · [gap-closed.md](./gap-closed.md) | 蓝图−现状 · 已关 |
| 6 | [regression-register.md](./regression-register.md) | 产品回归活索引 |
| 7 | [`../specs/`](../specs/) | 本版实施 |
| 8 | [`../planning/roadmap.md`](../planning/roadmap.md) | 排期 |

## 能力地图（可增删）

| ID | 能力 | 蓝图包 |
|----|------|--------|
| C1 | （填写） | `modules/…` |

## 状态枚举

| 状态 | 含义 | Agent 怎么对待 |
|------|------|----------------|
| `调研` | 尚未成产品约束 | 勿当 Must |
| `设计稿` | 蓝图可用；未切版 | 可引用；未实施 |
| `已切版` | 有活跃 `specs/<id>/` | 以 Spec 为实施真源 |
| `部分落地` | 主路径已合；余量在 gap/tasks | 对照 gap/tasks |
| `已验收` | validation-complete · **进入维护** | **不重开全文**；产品回归 / 小修；大改再切版或新包 |
| `归档` | 合并/废弃 | 只读历史 |

> **维护标识真源：** 本页模块表「状态」列。`已验收` = 维护态；正文仍留 `modules/<slug>/`。

## 模块蓝图索引（状态真源）

| 模块包 | 能力 | 状态 | Spec / Gap |
|--------|------|------|------------|
| （尚无） | | | |
