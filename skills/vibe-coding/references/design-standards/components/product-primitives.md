# Product primitives（B 端组件处方）

> 无宿主组件库时按此实现；有 antd/shadcn 等则用其 API，并对齐下列**角色与尺度**。  
> 尺度真源 → [../tokens/scale.md](../tokens/scale.md)。

## Button

| 变体 | 高度 | 水平垫 | 圆角 | 字 |
|------|------|--------|------|-----|
| primary | 32 (`control-sm`) | ≈15 | 6 | 14 / 500；字色白或 on-accent |
| default | 32 | ≈15 | 6 | 14；底 `surface`，边 `border-strong` |
| text/link | — | — | — | `accent`；非第二主按钮 |

- 一屏一个 primary。  
- 禁习惯性「左 filled + 右 ghost」双主 CTA。  
- 危险：明确 danger 样式；确认框内危险钮不默认 focus。

## Input / Select

| 项 | 值 |
|----|-----|
| 高度 | 32（舒适表单可用 36） |
| 垫 | ≈4×11 |
| 圆角 | 6 |
| 字 | 14 |
| focus | 可见 ring（`accent`）；禁无替代的 `outline: none` |
| label | 可见 label 或 `aria-label`；可点击 |

**禁止原生 `<select>`**（产品面默认）：用宿主/设计系统的 **popover picker / combobox**（可搜索、键盘可达、与 chip 筛选一致）。  
仅当无障碍强制原生且宿主无等价组件时例外，并在 Spec 注明。

交互五态 → [interaction-states.md](./interaction-states.md)。

## Table

- 语义 `<table>` + 表头；密表用 `table-layout` 稳定列宽。  
- 表头：14 / 600；底 `surface-muted`。  
- 单元格：文本左、数字右 + `tabular-nums`；单位/精度同行一致。  
- 行高走 `--row-h`（常 28–36 档）。  
- 筛选/排序状态进 URL（有前端路由时）。  
- **禁止**用等大卡片墙代替可扫读表。

## Tag / Status

- 形状 + 文案的 pill；垫 ≈0×7；字 12。  
- **禁止**发光/脉冲圆点作状态。

## Modal / Dialog

- 内容垫 ≈20–24；圆角 ≤8。  
- 页头/页脚用留白分层，勿靠重描边堆盒子。  
- 破坏性操作：确认；写清影响范围。

## App chrome（有壳时）

- 顶栏高 `--top-row-h`（常 44）。  
- 侧栏图标进固定 `--slot-size` 槽。  
- 内容左右垫 `--page-pl/pr` 与表/工具条同源，防错缝。

## 表单

- 提交钮在请求开始前保持可点；错误贴字段；提交失败 focus 首错。  
- 不禁粘贴；手机端主输入字号避免触发缩放异常（≥16 若以 mobile 为主）。
