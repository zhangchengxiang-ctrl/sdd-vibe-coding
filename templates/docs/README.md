# SDD 文档地图

这些文档主要是 Codex 跨任务的交付记忆。用户不需要维护内部编号，只需要确认产品方向、
单向门和真实结果。

## 权威来源

| 事实 | 唯一真源 |
|---|---|
| 项目命令、环境、架构、红线 | `AGENTS.md` |
| 产品愿望与长期蓝图 | `product/` |
| 当前版本实施合同 | `specs/<id>/` |
| 单 Task 执行合同 | `specs/<id>/tasks/T-xxx.md` |
| 下一对话路由 | `specs/<id>/routes/T-xxx.next-rail.md` |
| 活跃任务、Workspace、PR 和下一步 | `reference/handoff.md` |
| 并行互斥 Claim | `reference/claims.md` |
| 实际实现 | 代码、迁移和配置 |
| 验收证据 | `specs/<id>/validation.md` 与 `evidence/` |
| 生产事故 | `operations/incidents/` |

同一规则不要复制到多个层次；其他文档只链接权威来源。

## 工作轨

```text
Shape → Plan → Build(Task) → Verify
                    ↑          |
                    └─ Repair ←┘

复杂/线上问题：Diagnose → Repair | Plan | Incident
生产事故：Incident → Production Verification → 长期 Work Order
```

- Shape 澄清产品诉求；
- Plan 形成技术方案、Scenario 和 Task；
- Build / Repair 每次只执行一张 Work Order；
- Verify 只验收、记录证据和分类 Fail；
- Diagnose 只定位，Incident 只恢复生产。

## Spec 读序

1. `VERSION.md`
2. `context.md`
3. `requirements.md`
4. `technical-plan.md`
5. `scenario-spec.md`
6. `tasks.md`
7. 当前 `tasks/T-xxx.md`
8. 当前 `routes/T-xxx.next-rail.md`
9. `validation.md`

不要一次读取所有历史文档；只读取当前 Task 明示的真源和代码入口。

## 状态

- Version：`draft | ready | in-progress | verifying | blocked | done | archived | cancelled`
- Task：`ready | in-progress | passed | failed | blocked | cancelled`
- Delivery Target：
  `design-ready | code-ready | dev-effective | matrix-accounted | acceptance-passed |
  production-restored | production-delivered | user-accepted`

`matrix-accounted` 不等于 `acceptance-passed`；Task passed 不等于 Version 通过。

## 检查

```bash
bash scripts/check-docs.sh
# 本仓需要限制活跃 Spec 时：
WIP_CAP=<positive-number> bash scripts/check-docs.sh
```

脚手架只在用户明确要求时运行，不因缺少目录自动写入宿主仓库。
