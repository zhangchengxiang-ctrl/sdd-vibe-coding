# Product DataTable（B 端列表 · 蒸馏）

> 来源意图：taste-saas datatable-mechanics。列表页是 B 端多数路由；下列为 **壳无关** 硬合同。  
> 行外观（pill / 发丝 / 斑马）由 [../surfaces/product-shells.md](../surfaces/product-shells.md) 决定。

## 解剖

```text
[ 筛选 chips … ]     [ search ]   [ Display ]
──────── sticky thead ─────────────────────
行 …
```

工具条与 thead 可 sticky；**唯一纵向滚动**在表所在 `<main>`（或约定滚动容器）。

## 三定律（违反即列漂移 / 右垫不可达）

### 1. 真 `<table>` + `<colgroup>` + `table-layout: fixed`

列宽写在 `<col>`；禁手搓 `div+flex` 伪表（表头与表体 leftover 分配不同 → 列漂）。

### 2. 右垫可达：`min-w-fit`（或等价）

带 `padding-right: var(--page-pr)` 的内层在横向溢出时，必须让 padding 计入 `scrollWidth`；否则右垫永远滚不到。

### 3. 尾列吞剩余

`<colgroup>` 末尾加空 `<col />`，对应空 `<th>`/`<td>`，吸收横向剩余，避免最后一列被拉变形。

## 列与对齐

| 内容 | 对齐 |
|------|------|
| 文本 / ID 可读名 | 左；表头同向 |
| 数字 / 金额 / 占比 | 右 + `tabular-nums`；表头同向 |
| 状态 | pill + 文案；**禁发光点** |

单位与精度同行一致；勿假精度。

## 筛选与 URL

- 服务端筛选参数约定清晰（如 `status` / `q` / `sort=field:dir`）。  
- 错误按 **code** 分发，禁 `message.includes`。  
- 有路由时：筛选/分页/排序进 URL。

## 空 / 载 / 错（与 forms-states 分工）

| 态 | 要求 |
|----|------|
| Loading | 骨架行高 ≈ 真行高（防 CLS） |
| First-run 空 | **邀请型**英雄块（见 product-forms-states）；工具条仍在 |
| 筛选为零 | **短文案 + 清筛选**；勿同一套大英雄 |
| Error | 具体原因 + 重试；禁「出了点问题」 |

## 壳差量（行）

| shell | 行 |
|-------|-----|
| floating-card | pill 行 |
| flush-pane / doc-workspace | 发丝 `border-b` |
| data-table | 发丝或斑马；可冻列；底部分页 |

## 自检

- [ ] 真 table + colgroup + fixed  
- [ ] `--page-pl/pr` 与工具条同源  
- [ ] 数字右齐 + tabular-nums  
- [ ] 空态区分 first-run vs 筛选零  
- [ ] 行风格匹配已选 shell  
