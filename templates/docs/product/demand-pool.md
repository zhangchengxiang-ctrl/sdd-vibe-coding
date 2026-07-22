# 需求池（Demand Pool）

> **用户愿望 / 故障 / 体验吐槽的排期入口。**  
> 与 [gap-register.md](./gap-register.md)（蓝图−现状）分工：口述进本池；能力账本进 gap。  
> 角色合同 → skill `vibe-coding` → `references/role-rails.md`。

## 字段说明

| 字段 | 说明 |
|------|------|
| ID | `DEM-NNN`（本文件内递增） |
| 类型 | `wish` / `fault` / `ux` / `other` |
| 来源 | 谁提出 / 哪次会话 |
| 摘要 | 一句话 |
| 现状痛点 | 现在怎样 |
| 期望 | 办成什么算够 |
| 非目标 | 明确不做 |
| 建议优先级 | Intake 建议：`P0`/`P1`/`P2`/`park`（**非**排期承诺） |
| Owner 优先级 | Owner 判决后填写；未审则 `—` |
| 状态 | 见下表 |
| 链接 | modules / Spec / GAP / handoff 筹备行 |

### 状态语义

| 状态 | 含义 | 谁改 |
|------|------|------|
| `draft` | Intake 已记；信息可能不全 | Intake |
| `ready` | 可排期 | Intake；Owner 可退回 `needs-intake` |
| `scheduled` | Owner 已排入近期 | Owner |
| `in-spec` | 已有 `docs/specs/<id>/` | Owner 升格后 |
| `done` | 已交付或关闭 | Owner / Build 关版回写 |
| `wontfix` | 明确不做（必写理由） | Owner |
| `needs-intake` | 退回补澄清 | Owner |

## 条目

| ID | 日期 | 类型 | 摘要 | 建议优先级 | Owner | 状态 | 链接 |
|----|------|------|------|------------|-------|------|------|
| | | | | | — | | |

## 已关闭

（短链即可）
