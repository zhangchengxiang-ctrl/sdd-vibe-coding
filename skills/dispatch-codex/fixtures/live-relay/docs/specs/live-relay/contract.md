# Contract · live-relay-1

## 一句话目标

调用方用签名 token 经 gateway 投递事件：合法 204，坏 token 401，限流 429，坏事件 400。无 UI。

UX: n/a · 无 UI · pure backend

## 入口事实映射（Plan 硬前置）

| 入口 | actor | 业务实体 / 表关系 | 可信路径如何派生 | 代码调用点 | 越权反例 | 证据级 |
|---|---|---|---|---|---|---|
| validate(token) | ingest-worker | token 字符串 `{project}.{kid}.{exp}.{mac}`；mac=sha256(project.kid.exp.SECRET)[:16] | 本地函数 + pytest | `svc/auth/token.py:validate` | 伪造 mac / 过期 exp 必须 invalid/expired | Verified |
| rate.check(token) | ingest-worker | 每 token 10s 窗口最多 3 次 | 内存 store dict | `svc/auth/rate.py:check` | 第 4 次 limited=true；不同 token 互不影响 | Verified |
| ingest(event) | ingest-worker | event.type 非空 str + payload dict + json≤8192 | 本地函数 + pytest | `svc/ingest/collect.py:ingest` | 缺 type / payload 非 dict / 超大 → 400 | Verified |
| gateway.handle(token,event) | cli-caller | 组合 validate→rate→ingest | 本地函数 + pytest | `svc/gateway.py:handle` | 坏 token 401；限流 429；坏事件 400 | Verified |

## 用户 Job

作为 ingest-worker，在本地单测环境里，我要用签名 token 投递事件并得到稳定状态码，从而在无 UI 下机跑验收。

## Requirements

| ID | 需求 | 优先级 | 证据级 | AC 摘要（行为） | Tests |
|---|---|---|---|---|---|
| R-001 | 签名 token：合法 ok；缺/假/过期分别 missing/invalid/expired | P0 | Verified | validate 返回 ok+project 或 code | T-001, T-002 |
| R-002 | 每 token 10s 窗口最多 3 次，第 4 次 limited | P0 | Verified | remaining 递减；窗口过期重置 | T-003, T-004 |
| R-003 | ingest 只收合法 event，否则 400 | P0 | Verified | 204 vs 400+code | T-005, T-006 |
| R-004 | gateway 串起 token+rate+ingest，映射 204/401/429/400 | P0 | Verified | handle 状态码 | T-007, T-008 |

## 非功能与约束

| ID | 约束 | 可观察判据 | Tests |
|---|---|---|---|
| NF-001 | 不写原始 token 到返回值 | 返回 dict 不含完整 token 字符串 | T-001 |

## In / Out

- In：token 校验、限流、事件形状、gateway 组合
- Out：HTTP 服务、持久化 DB、UI
- 非目标：生产部署、K8s、Nginx
- 用户入口：Python 函数 / pytest
- Target Environment：本地 PYTHONPATH=. pytest

## 产品不变量

- SECRET 仅 fixture 常量 `live-relay-fixture-secret`
- 限流 store 由调用方传入 dict，进程内有效

## 外部依赖与限制

| 项 | 状态 | Owner | Blocker 条件（须 Verified） |
|---|---|---|---|
| 无外部服务 | Verified | fixture | 无 |

## 产品真源

- 本夹具 `skills/dispatch-codex/fixtures/live-relay/`
- 相关现状代码：`svc/` 下故意写红的 stub
