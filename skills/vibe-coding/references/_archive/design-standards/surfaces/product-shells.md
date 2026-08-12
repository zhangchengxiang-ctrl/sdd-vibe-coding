# Product shells（B 端四壳 · 蒸馏）

> 来源意图：taste-saas structural archetypes。新建/大改应用壳时 **必选其一**；禁止默认成「好看 Linear」。  
> `shell` 字段：`floating-card` | `flush-pane` | `doc-workspace` | `data-table`。

## 怎么选

| shell | 产品重心 | 锚点产品 |
|-------|----------|----------|
| `floating-card` | 长时间盯密行（工单、队列、日志） | Linear / Height |
| `flush-pane` | 大块可读运营面、少嵌套 | Vercel / GitHub / Sentry |
| `doc-workspace` | 内容/文档/知识为主 | Notion / Coda |
| `data-table` | 数据即产品、极高密度 | Stripe / Retool / Plaid |

用户未指定 → **追问**，勿默认 `floating-card`。

## 共性几何（所有壳）

蒸馏自 alignment-invariants：

1. **Viewport lock**：`html, body, #root { height:100%; overflow:hidden }` — 只让 `<main>` 滚。  
2. **顶三行共基线**：侧栏品牌行、顶栏、工具首行共用 `--top-row-h`；偏差 ≥2px 视为失败。  
3. **左右垫同源**：`--page-pl/pr` 同时约束工具条、表、空态，防错缝。  
4. **图标槽**：`--slot-size` 对齐，不是每个图标自定外宽。  
5. **测量即规格**：`getBoundingClientRect` 验证，禁止用负 margin 糊弄。

## 跨态对齐不变量

侧栏 collapse、loading→loaded、空态↔有数据等 **成对测量**：

| 不变量 | 要求 |
|--------|------|
| 稳定锚点 | 顶栏/侧栏品牌行/`--page-pl` 首列 centerY（或 left）两态一致；偏差 ≥2px → Fail |
| 顶三行 | 开合侧栏后仍共 `--top-row-h` 基线 |
| 工具条 | 空态时工具条仍在；表体替换不影响 `--page-pl` |
| 禁糊弄 | 禁止用负 margin / 绝对定位漂移「看起来齐」 |

回归步骤 → [../debug-playbook.md](../debug-playbook.md)。

## A · `floating-card`

- 视口有 stage 底；主区为 **圆角浮卡** + 弱阴影；面包屑常在卡 **上方** stage 行。  
- 侧栏可透明贴 stage，常无重 `border-r`。  
- 表行：**pill 行**（行底微面 + 圆角），非斑马主风格。  
- STOP：勿把主区做成齐平无卡；勿省略 stage 与卡的 inset。

## B · `flush-pane`

- 侧栏 **贴视口边**；与主区用 **1px 分割线 + 微背景差**。  
- 主区 **无圆角、无阴影**；顶栏 sticky + `border-b`。  
- 表行：**发丝分割**，整行 hover 底，无 pill。  
- 卡：厚描边、无阴影。主按钮可为近黑底（极简号）。  
- STOP：禁止主区 `rounded-xl shadow`；禁止 pill 行；勿省略侧栏/主区分割线。

## C · `doc-workspace`

- 页面即文档；大留白；`--detail-px` 更大；常 `max-w` 阅读宽。  
- 标题编辑感强；面包屑弱或由标题承担。  
- 表是 **文档内块**，发丝网格，无 pill。圆角近 0–4。  
- STOP：禁止浮卡舞台；禁止密级运营顶栏堆砌。

## D · `data-table`

- 表占满主区；侧栏瘦、功利。顶栏常 **两行**（标题行 + 筛选行）。  
- 行：发丝或斑马；**禁 pill**；sticky thead；宽表可冻首列。  
- 数字列强制 `tabular-nums`；底部分页（勿默认无限滚）。  
- STOP：禁止 stage 灰框；禁止表外包阴影卡；勿藏分页。

## 与 primitives

壳定拓扑；控件尺寸仍走 [../tokens/scale.md](../tokens/scale.md) 与 [product-primitives.md](../components/product-primitives.md)。  
表机制 → [../components/product-datatable.md](../components/product-datatable.md)。
