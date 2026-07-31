# Design Standards Pack

插件默认可执行设计底线。有 UI 时**先读 [LOAD-MAP.md](./LOAD-MAP.md)**（字段门控、豁免、场景必读的**唯一真源**）。  
宿主品牌写在 `AGENTS.md` / 可选 `docs/product/DESIGN.md` + `PRODUCT.md`。

## 册

| 路径 | 内容 |
|------|------|
| **[LOAD-MAP.md](./LOAD-MAP.md)** | **任务→必读（入口）** |
| [craft-knobs.md](./craft-knobs.md) | Design Read · variance/motion/density · visitor_mode |
| [change-control.md](./change-control.md) | refinement/redesign · material 门 |
| [debug-playbook.md](./debug-playbook.md) | UI 回归 / 错缝 |
| [anchor.md](./anchor.md) | 参考锚点（Build 前硬门；Shape 可后置） |
| [copy.md](./copy.md) | UX Writing |
| [tokens/](./tokens/) | 封闭尺度与色角色 |
| [surfaces/](./surfaces/) | product / consumer / 四壳 |
| [pages/](./pages/) | list/detail/settings/dashboard/form/consumer |
| [components/](./components/) | primitives、表、表单、五态、overlays、Cmd+K、批量 |
| [audit/](./audit/) | ai-tells、web-interface |
| [exemplars/](./exemplars/README.md) | 正反例 |
| [ui-page-gate.md](./ui-page-gate.md) | 写页面前**评审输出模板**（加载义务见 LOAD-MAP） |
| [visual.md](./visual.md) | 原则索引（非施工入口） |
| [ux.md](./ux.md) | 体验启发式（非施工入口） |
| [system-architecture.md](./system-architecture.md) | 架构通则 |

## 覆盖顺序

```text
Spec ≫ AGENTS.md / docs/product/{PRODUCT,DESIGN}.md ≫ docs/architecture/ ≫ 本包默认
```

## Surface + page_kind

```text
未声明 surface → 不定视觉、不写新页
未写 Design Read → 不定视觉（craft-knobs）
product → surfaces/product +（改壳）product-shells + pages/<kind> + components…
consumer → surfaces/consumer + pages/consumer + consumer-primitives
page_kind 与 motif 等价；Build 前 anchor 必填；改存量先 change-control
```

场景表、Rail 强度、豁免 → **[LOAD-MAP](./LOAD-MAP.md)**（勿在本 README 复述强度表）。

## 机读

[ui-surface.checklist.json](./ui-surface.checklist.json) · [plan-architecture.checklist.json](./plan-architecture.checklist.json)  
`check_spec.py`：有 UI 缺 surface → fail；缺 Design Read / page_kind|motif / anchor → warn。

## 明确不做

- 不新建 Design Rail；不在 templates 复制本包长文  
- 不搬宿主组件库 API 全文 / Vercel 品牌 CSS  
