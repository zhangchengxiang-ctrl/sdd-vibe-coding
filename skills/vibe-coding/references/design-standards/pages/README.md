# Page patterns（页面类型）

> 与 `surface` **正交**。先 surface，再 `page_kind`，再按 [../LOAD-MAP.md](../LOAD-MAP.md) 加读。

## product `page_kind`

| 值 | 合同 |
|----|------|
| `list` | [list.md](./list.md) |
| `detail` | [detail.md](./detail.md) |
| `settings` | [settings.md](./settings.md) |
| `dashboard` | [dashboard.md](./dashboard.md) |
| `form` | [form.md](./form.md) |
| 其他 | 写理由；仍 tokens + ai-tells + overlays |

## consumer

按 motif 用 [consumer.md](./consumer.md)；motif 寄存器在 [../surfaces/consumer.md](../surfaces/consumer.md)。  
`motif:` 与 `page_kind:` 等价（见 [../LOAD-MAP.md](../LOAD-MAP.md)）。

## 落盘

```text
UI surface: product
page_kind: list
anchor: Stripe Payments
diverge: 无多币种列
```

```text
UI surface: consumer
motif: growth
anchor: 某品牌落地
diverge: 首屏无证言条
```

混主任务 → 拆页或 Tab。

## Redundancy hunt（标签只出现一次）

同一信息 **只在一处** 担任标签角色，优先级：

`breadcrumb` → `PageHeader/标题` → `正文/表列`

| 反例 | 改法 |
|------|------|
| 面包屑「订单」+ 页标题「订单」+ 卡头再「订单」 | 留标题；面包屑用父级或省略末级 |
| Status pill 已写「已发布」+ 旁再「状态：已发布」 | 删重复 label |
| 表列头与筛选 chip 同文案堆叠无增量 | 合并或弱化其一 |

自检：扫页头区，每个名词是否只承担一次导航或标题职责。

