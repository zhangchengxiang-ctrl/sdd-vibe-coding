# SDD 文档地图

这些文档是 Agent 跨任务的交付记忆。用户只需确认产品方向、单向门和真实结果。

## 权威来源

| 事实 | 唯一真源 |
|---|---|
| 项目命令、环境、架构、红线、就绪度 | `AGENTS.md` |
| 产品愿望与长期蓝图 | `product/` |
| 当前版本实施合同 | `specs/<id>/`（`contract` + `tests` + `plan` + `run`） |
| 活跃任务、Workspace、PR 和下一步 | `reference/handoff.md`（索引，不复制合同正文） |
| 并行互斥 Claim | `reference/claims.md` |
| 实际实现 | 代码、迁移和配置 |
| 验收证据 | `specs/<id>/run.md`（附件路径写在 Evidence 列） |
| 生产事故 | `operations/incidents/` |

同一规则不要复制到多个层次；其他文档只链接权威来源。

### 真源优先级（冲突时）

```text
specs/<id>/（执行合同）+ 代码/运行环境
  ≫ reference/handoff.md
  ≫ product/modules/（产品蓝图）
  ≫ product/demand-pool.md（愿望）
```

状态词汇（Version / Delivery Target / Spec Run / 完成声明）以插件
`skills/vibe-coding/references/workflow-contract.md`「状态词汇」为**唯一真源**；
本目录不复述枚举。

## 工作轨

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         |
                      └ Repair ─┘

复杂/线上问题：Diagnose → Repair | Plan | Incident
生产事故：Incident → Production Verification → 长期执行合同
```

- Shape 澄清产品诉求；Plan 形成技术方案、**完整测试用例**和 Spec 执行合同；
- 每个工作轨在自身范围内连续完成；跨工作轨前先总结并等待用户批准；
- Verify 只验收、记录证据和分类 Fail（不改 `tests.md` Oracle）；
- Diagnose 只定位，Incident 只恢复生产。

## Spec 布局与读序

```text
docs/specs/<id>/
├── VERSION.md
├── contract.md   # WHAT
├── tests.md      # TEST
├── plan.md       # HOW
└── run.md        # RUN
```

读序：`VERSION` → `contract` → `tests` → `plan` → `run`（Build 起）。

## 检查

可选：从插件仓维护者工具校验宿主 docs：

```bash
bash <plugin>/evals/tools/check_docs.sh .
```

脚手架只在用户明确要求时运行，不因缺少目录自动写入宿主仓库。
