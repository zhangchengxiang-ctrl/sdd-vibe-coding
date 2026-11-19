---
title: 运维手册（Runbooks）
type: reference
status: active
owner: <谁>
updated: YYYY-MM-DD
---

# 运维手册（Runbooks）

按「症状 → 判断 → 动作 → 回滚」组织的可重复步骤。**这里是索引**；已有的部署手册等不在此复制，只链接。

## 索引

| 场景 | 位置 |
|---|---|
| | |

## 每份 runbook 必含

触发症状、先查什么（只读）、处置步骤、回滚、验证、升级给谁。文件名 `<场景>.md`，头部用元数据（`type: runbook`，状态 `active | deprecated`），并在上表登记。事故里沉淀出的通用步骤，从 `incidents/` 提炼到这里。
