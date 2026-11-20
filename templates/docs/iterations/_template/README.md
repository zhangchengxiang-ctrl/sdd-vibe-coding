---
title: <迭代名>
type: iteration
status: draft
owner: <谁>
updated: YYYY-MM-DD
---

# <迭代名>

> 复制本目录为 `iterations/<yyyy-mm>/<w>/<版本>/`（开始月份 / 当月第几周 / 版本名），并在 [索引](../README.md) 加一行。Spec 建在本目录下。**不要在本文件抄各 Spec 的状态**，只放链接。

## 来源

- 用户原话：[quote.md](./quote.md) · 需求：[requirements.md](./requirements.md) · 裁定：[decisions.md](./decisions.md)
- 顺序：原话 → 需求 → 用户裁定 → 切 Spec。待裁定未清空前不切 Spec。

## 目标与成功指标

- 要解决的问题：
- 成功指标（可度量）：基线 → 目标；口径见 `baseline.md`
- 不做什么：

## Spec 清单与并行矩阵

| Spec | 触及路径（`文件` 或 `文件::符号`；注明实测 / 预估） | 依赖 | 车道 | 可否并行 |
|---|---|---|---|---|
| `<id>/`（写成指向 `./<id>/VERSION.md` 的链接） | | | | |

车道：同一热点文件上的 Spec 排在同一车道，车道内串行。

## 跨 Spec 事项

| 事项 | 找谁 | 链接 | 状态在哪 |
|---|---|---|---|
| | | `operations/requests/…` | 该请求单 |

## 关闭条件

- [ ] 本目录下所有 Spec 为 `archived`（`close-spec`）或 `cancelled`（理由写入 `decisions.md`）
- [ ] 基线复测完成，或 owner 明示豁免并写入 `decisions.md`
- [ ] 关联缺口已更新状态
- [ ] `retro.md` 已写
- [ ] 运行 `close-iteration`（README 状态改为 `archived`，不搬目录）

## 当前阻塞

（只写事实与等谁，不复制 Spec 状态）
