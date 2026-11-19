---
title: <迭代名>
type: iteration
status: draft
owner: <谁>
updated: YYYY-MM-DD
---

# <迭代名>

> 复制本目录为 `iterations/<slug>-<YYYY.MM>/`，并在 [索引](../README.md) 加一行。**不要在本文件抄各 Spec 的状态**，只放链接。

## 目标与成功指标

- 要解决的问题：
- 成功指标（可度量）：基线 → 目标；口径见 `baseline.md`
- 不做什么：

## Spec 清单与并行矩阵

| Spec | 触及路径（`文件` 或 `文件::符号`；注明实测 / 预估） | 依赖 | 车道 | 可否并行 |
|---|---|---|---|---|
| `specs/<id>/`（链接到其 VERSION.md） | | | | |

车道：同一热点文件上的 Spec 排在同一车道，车道内串行。

## 跨 Spec 事项

| 事项 | 找谁 | 链接 | 状态在哪 |
|---|---|---|---|
| | | `operations/requests/…` | 该请求单 |

## 关闭条件

- [ ] 所有成员 Spec 为 `acceptance-passed` 或已放弃（放弃须写入 `decisions.md`）
- [ ] 基线复测完成，或 owner 明示豁免并写入 `decisions.md`
- [ ] 关联缺口已更新状态
- [ ] `retro.md` 已写

## 当前阻塞

（只写事实与等谁，不复制 Spec 状态）
