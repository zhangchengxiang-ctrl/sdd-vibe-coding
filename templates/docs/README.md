# SDD — 文档地图（通用脚手架）

> Spec-Driven Delivery：产品专家表达愿望与关键判断；体系维护记忆与交付合同。  
> **非目标：** 方法论博物馆、双真源 as-built。

## 真源分层

| 层 | 路径 | 作用 |
|----|------|------|
| **路由** | [`reference/handoff.md`](reference/handoff.md) | 活跃 Spec / 等人 / 关闭 |
| **执行** | [`specs/<id>/`](specs/) | 本版工单 |
| **蓝图** | [`product/`](product/) | 能力地图 · modules · [system-map](product/foundation/system-map.md) · [包合同](product/foundation/product-package-contract.md) · [产品回归](product/foundation/product-regression.md) |
| **差距** | [`product/gap-register.md`](product/gap-register.md) · [`gap-closed.md`](product/gap-closed.md) | 蓝图 − 现状 |
| **排期** | [`planning/roadmap.md`](planning/roadmap.md) | Gap/DEM → 版本 |
| **现状** | 代码 + `AGENTS.md` + system-map（薄） | 怎么跑 |

## 热温冷

| 热度 | 目录 |
|------|------|
| 热 | handoff · specs/ |
| 温 | product/ · guides/ · planning/ |
| 冷 | product/decisions/ · gap-closed |

## Agent 开工（≤3 分钟）

1. Wish 且无 Spec → skill `vibe-coding` Intake / Shape  
2. 已有任务 → handoff → 挂 `<id>`  
3. 读 `VERSION.md` + `context.md` + 当前 Slice  
4. 实现细节 → **读代码**

主流程：插件 **`vibe-coding`**。宿主特有项写 [`guides/vibe-coding.md`](guides/vibe-coding.md)。

## 回填矩阵（合并时）

| 若改动涉及 | 必须更新 |
|----------|--------|
| 任何非 trivial 合并 | `specs/<id>/` · handoff 行 |
| 进程边界 / 部署单元 | system-map · 必要时 ADR |
| 产品能力 / 旅程 | product/README · modules |
| 维护态关键旅程 | regression-register · surfaces.json · regression-map |
| 对外 API 契约 | 宿主约定路径 |
| 已拍板技术决策 | product/decisions/ |
| 新差距 | gap-register + roadmap 一行 |
| 会话结束且状态变化 | handoff **对应行** |

**禁止**：非 trivial 不建 version 却报告完成。关版 `done` → 当日 `_archive/`。

## Spec 状态枚举

`draft` · `in-progress` · `review` · `done` · `archived` · `cancelled`

## 检查

```bash
bash <plugin>/scripts/check-docs-sdd.sh   # 或复制到宿主 scripts/
# WIP_CAP=8 bash scripts/check-docs-sdd.sh
```

## 可搬运最小包

```
AGENTS.md
docs/reference/handoff.md
docs/specs/_template/
docs/planning/roadmap.md
docs/product/   # README · foundation · modules · demand-pool · gap · regression
SDD Superpowers 插件 skills/rules
```
