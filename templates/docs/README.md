# SDD 文档地图

这些文档主要是 Codex 跨任务的交付记忆。用户不需要维护内部编号，只需要确认产品方向、
单向门和真实结果。

## 权威来源

| 事实 | 唯一真源 |
|---|---|
| 项目命令、环境、架构、红线 | `AGENTS.md` |
| 产品愿望与长期蓝图 | `product/` |
| 当前版本实施合同 | `specs/<id>/` |
| Spec 执行合同 | `specs/<id>/technical-plan.md` + `scenario-spec.md` + `validation.md` + `spec-run.md` |
| 活跃任务、Workspace、PR 和下一步 | `reference/handoff.md` |
| 并行互斥 Claim | `reference/claims.md` |
| 实际实现 | 代码、迁移和配置 |
| 验收证据 | `specs/<id>/validation.md` 与 `evidence/` |
| 生产事故 | `operations/incidents/` |

同一规则不要复制到多个层次；其他文档只链接权威来源。

### 真源优先级（冲突时）

```text
specs/<id>/（执行合同）+ 代码/运行环境
  ≫ reference/handoff.md（索引，不复制合同正文）
  ≫ product/modules/（产品蓝图）
  ≫ product/demand-pool.md（愿望）
```

命名约定：`docs/specs/<id>/`；产品包 `docs/product/modules/<slug>/`；
池文件 `demand-pool.md` / `gap-register.md` / `gap-closed.md`。

## 工作轨

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         |
                      └ Repair ─┘

复杂/线上问题：Diagnose → Repair | Plan | Incident
生产事故：Incident → Production Verification → 长期执行合同
```

- Shape 澄清产品诉求；
- Plan 形成技术方案、Scenario 和整份 Spec 执行合同；
- 每个工作轨在自身范围内连续完成；跨工作轨前先总结阶段结果并等待用户批准；
- Verify 只验收、记录证据和分类 Fail；
- Diagnose 只定位，Incident 只恢复生产。

## Spec 读序

1. `VERSION.md`
2. `context.md`
3. `requirements.md`
4. `technical-plan.md`
5. `scenario-spec.md`
6. `validation.md`
7. `spec-run.md`（Build 起）

优先读取当前 Spec 的执行合同、场景和代码入口。

## 状态

- Version：`draft | ready | in-progress | verifying | blocked | done | archived | cancelled`
- Delivery Target：
  `design-ready | code-ready | dev-effective | matrix-accounted | acceptance-passed |
  production-restored | production-delivered | user-accepted`

`matrix-accounted` 不等于 `acceptance-passed`；局部检查通过不等于 Version 通过。

## 检查

可选：从插件仓维护者工具校验宿主 docs（非 scaffold 默认拷贝）：

```bash
bash <plugin>/evals/tools/check_docs.sh .
# 限制活跃 Spec：
WIP_CAP=<positive-number> bash <plugin>/evals/tools/check_docs.sh .
```

脚手架只在用户明确要求时运行，不因缺少目录自动写入宿主仓库。
