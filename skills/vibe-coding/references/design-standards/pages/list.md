# Page: list（B 端列表）

> 核心任务：在集合中**找到**目标并执行操作。  
> [../components/product-datatable.md](../components/product-datatable.md) · [../components/bulk-actions.md](../components/bulk-actions.md) · [../components/overlays.md](../components/overlays.md) · [../copy.md](../copy.md)

## 必有结构

```text
[筛选 chips…]     [search]   [Display]
──────── sticky thead ───────────────
行…
[分页或滚动止点]
```

1. 工具条：`--row-h`；空态时**仍显示**。  
2. 真 table + colgroup + `table-layout:fixed`；左右垫 `--page-pl/pr`。  
3. 行外观 = 当前 shell（pill / 发丝 / 斑马）。  
4. 进详情：点主列或整行（全表一致）；可 Sheet 预览（overlays）+ 展开全页。

## 硬约束

| 项 | 要求 |
|----|------|
| 禁止 | 卡片墙替密表；div+flex 伪表 |
| 对齐 | 文本左、数字右 + tabular-nums |
| URL | `q` / 筛选 / `sort` / 页码 |
| 空态 | first-run ≠ 筛选零（文案不同） |
| 批量 | 见 bulk-actions |
| 主键 | 可读名主显；复制 ID 次要 |
| 错误 | code 分发；人话 + 重试 |

## 密度与壳

- `density:compact` + `shell:data-table` → 底部分页优先。  
- 无限滚须有明确加载态与尽头。

## 自检

- [ ] page_kind=list；DataTable 三定律  
- [ ] 空态两分；URL 同步  
- [ ] 批量/预览容器选对  
