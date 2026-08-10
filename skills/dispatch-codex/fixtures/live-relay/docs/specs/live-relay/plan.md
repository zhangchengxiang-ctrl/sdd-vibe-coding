# Plan · live-relay-1

## 方案差量

- 核心机制：把故意写红的 stub 补成 token/rate/ingest/gateway 合同实现
- 组件 / 模块影响：`svc/auth/*`、`svc/ingest/collect.py`、`svc/gateway.py`
- 数据与 API：无 DB；内存 rate store
- 权限与安全：mac 签名 + 过期；不回传原始 token
- 可观测性：函数返回 status/code

## 架构与设计边界

- 边界：沿用现有三层目录 `svc/auth` → `svc/ingest` → `svc/gateway`，无新部署单元
- C4 影响：L3 库内函数组合，N/A 到 L1/L2
- ADR：否
- UX / 视觉约束：N/A · 无 UI · pure backend
- Unverified：无；夹具 SECRET 与窗口参数已在 contract Verified

## 纵向切片（默认执行轴）

| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
|---|---|---|---|---|---|
| S1 | validate(token) | T-001, T-002 | svc/auth/token.py | | oracle:unit |
| S2 | rate.check(token) | T-003, T-004 | svc/auth/token.py, svc/auth/rate.py | S1 | oracle:unit |
| S3 | ingest(event) | T-005, T-006 | svc/ingest/collect.py | | oracle:unit |
| S4 | gateway.handle | T-007, T-008 | svc/gateway.py | S1, S3 | oracle:unit |

> S1+S2 同写 `svc/auth/token.py` → 应打成一个 D。S3 写集不相交 → 可与 auth D 并行。S4 依赖 S1+S3 → 第二 edit-wave。

## 备选与取舍

| 方案 | 收益 | 代价 / 风险 | 结论 |
|---|---|---|---|
| 内存 store dict | 无外部依赖，可并行测 | 非多进程 | 采用 |
| Redis | 更像生产 | 夹具过重 | 不用 |

## 单向门

| 项 | 是否触发 | 审批 | 附加验证 |
|---|---|---|---|
| 数据库迁移 | no | N/A | |
| 对外契约 | no | N/A | |
| 权限 / 安全 | no | N/A | fixture only |
| 数据删除 | no | N/A | |
| 生产配置 / 部署单元 | no | N/A | |

## 迁移与回滚

- 兼容策略：夹具一次性实现
- 发布顺序：D(auth) ∥ D(ingest) → D(gateway)
- 回滚点：丢弃 /tmp host
- 数据恢复：N/A

## Workspace Strategy

```yaml
owner:
  kind: current-chat
  id: live-relay-scenario
workspace:
  mode: local
  branch: sdd/live-relay
  shared_resources: []
```
