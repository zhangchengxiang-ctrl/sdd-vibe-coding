# 产品文档

本目录是**常青**文档：相对稳定的产品目标、能力蓝图和差距。这一轮做什么以版本目录 `docs/iterations/<yyyy-mm>/<w>/<版本>/` 为真源（原话、需求、裁定、Spec），
实际行为以代码和运行环境为真源。

## 读序

| 路径 | 回答什么 |
|---|---|
| `foundation/` | 使命、原则、角色旅程、系统边界 |
| `DESIGN.md` | 可选：默认 surface、锚点、品牌色/字体、反参考（插件 design-standards 底线之上） |
| `modules/<slug>/` | 成块能力的产品蓝图（章节合同见插件 skill `design` → `product-package`） |
| `demand-pool.md` | 尚未进入 Plan 的愿望和反馈 |
| `gap-register.md` | 蓝图与现状之间的差距 |
| `regression-register.md` | 维护态关键用户旅程（可选；合同见 skill `testing` → `product-regression`） |
| `roadmap.md` | 排期 |
| `../iterations/<yyyy-mm>/<w>/<版本>/` | 一次许愿：原话、需求、裁定，以及其中的 Spec（施工中与已关版都在这里） |

## 能力地图

| ID | 能力 | 蓝图包 | 版本 / Gap（链接） |
|---|---|---|---|
| C-001 | | `modules/<slug>/` | |

本表不写状态（文档标准「五条规则」第 2 条）：愿望的状态在 `demand-pool.md`，进行中的状态在版本与 Spec 里。

## 三池流转

```text
demand-pool（愿望）──Shape 确认方案──► design-ready
        │                                    │
        │                            用户批准进入 Plan
        │                                    ▼
        │                         docs/iterations/<yyyy-mm>/<w>/<版本>/（原话 → 需求 → 裁定 → Spec）
        │                                    │
        │                         关版 / 关闭：只改状态，原地不动
        │                                    │
gap-register（蓝图 vs 现状差距）──关闭──► gap-closed（审计）
```

| 池 | 何时写入 | 何时流出 |
|---|---|---|
| `demand-pool.md` | Shape：新愿望 / 故障 / 体验反馈 | 排进一轮 → 建版本，原话移入版本 `quote.md`，本条目链到该版本 |
| `gap-register.md` | 蓝图与代码/运行现状不一致 | 差距消除或明确不做 → `gap-closed.md` |
| `gap-closed.md` | 从 gap-register 关闭的条目 | 归档审计 |

新愿望进 demand-pool；排进一轮就建版本 `docs/iterations/<yyyy-mm>/<w>/<版本>/`，实施与验收以其中的 Spec 为真源。产品决定变化时更新蓝图，
技术实现变化时更新 Spec 或代码。
