# Surfaces — 判定与加载

有 UI 时先定 **`surface`**，再加载对应册 + tokens + 组件处方。

## 枚举

| 值 | 含义 |
|----|------|
| `product` | **B 端**：企业客户或企业内部的管理 / 分析 / 运营 / 配置（神策、GA、运营台、B2B Console） |
| `consumer` | **C 端**：个人消费者产品（微信、淘宝等）；含营销落地（`motif:growth`）特例 |
| `n/a` | 无 UI |

## 判定口诀

```text
主要用户是「用系统干活的人」→ product
主要用户是「消费/社交/购物等个人」→ consumer
```

| 信号 | 倾向 |
|------|------|
| 看板、漏斗、权限、租户、配置、工单、CRM、密表 | `product` |
| 浏览、下单、会话、feed、C 端「我的」 | `consumer` |
| 品牌活动 / 官网获客落地 | `consumer` + `motif:growth` |
| 同仓 C 端 App + 商家后台 | **按本版切片主交付面** |

说不清时追问一句：「主要用户是企业里用系统干活的人，还是普通消费者？」

## 旋钮（非第二 surface）

**product：** `shell`（见 product.md）、`buyer`（internal\|external-b2b）  
**consumer：** `device`、`motif`（feed\|chat\|commerce\|media\|utility\|growth\|unset）、`context`（in-product\|growth-web）

**正交（两 surface 共用）** → [../craft-knobs.md](../craft-knobs.md)（`density` 只认 **1–10**；`compact`/`comfortable` 为别名）：

- Design Read 一行  
- `variance` / `motion` / `density`（1–10，有默认）  
- `visitor_mode`：`persuade` \| `operate` \| `read` \| `experience`

字段强度 → [../LOAD-MAP.md](../LOAD-MAP.md)。

## 加载

| surface | 必读 |
|---------|------|
| `product` | [product.md](./product.md) → 按任务加 [product-shells.md](./product-shells.md)、datatable、forms-states、primitives、[../audit/ai-tells.md](../audit/ai-tells.md) |
| `consumer` | [consumer.md](./consumer.md) + consumer-primitives + ai-tells |

未声明 surface → **不得定视觉方向、不得写新页业务 UI**（与 ui-page-gate 同等硬门）。
