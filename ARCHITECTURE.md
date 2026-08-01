# Plugin Architecture

本文件给维护者说明「哪里是唯一真源、改动应落在哪一层、如何避免双写」。

## 项目类型门（硬边界）

入口先判 `project.kind`，**仅三档**（合同：[`project-kind.md`](./skills/vibe-coding/references/project-kind.md)）：

| kind | 谁 | 怎么工作 |
|---|---|---|
| `plugin`（**本仓库**） | 插件源码仓 | 笔记 `plans/`；改 `skills/`·`templates/`·`scripts/`；禁止宿主式 `docs/product/` |
| `software` | 用户产品/服务仓 | vibe-coding 全轨 + 冷启动 |
| `other` | 其余 | 放手（只停用编码硬闸） |

在本仓讨论「加能力 / 改流程」→ 直接改插件真源（或先写 `plans/`）。

## 分层模型

```text
入口层
  README.md
  skills/vibe-coding/SKILL.md

合同层（跨仓唯一真源）
  skills/vibe-coding/references/workflow-contract.md
  skills/vibe-coding/references/evidence-contract.md
  skills/vibe-coding/references/workspace-contract.md
  skills/vibe-coding/references/design-standards/   # LOAD-MAP·tokens·pages·overlays·copy·anchor…
  skills/design/references/product-package.md
  skills/testing/references/product-regression.md

执行层（按 Rail）
  skills/design
  skills/spec
  skills/testing
  skills/deploy          # 发布 P0–P6（证据→方案→批准→执行→冒烟关版）
  skills/debug
  skills/dispatch-codex   # 可选：Cursor/Claude 指挥 → Codex 施工

宿主脚手架层（可被 scaffold 复制）
  templates/AGENTS.md          # 唯一宿主项目事实面
  templates/docs/**            # 槽位与空表，不复制合同正文
  templates/architecture/**    # 可选：docs/architecture/ 边界槽位（full profile）
  scripts/scaffold.sh          # detect|minimal|full；--root / SDD_ROOT；探测 OK/SKIP/BLOCK；永不覆盖
  skills/.../docs-root.md      # 宿主 AGENTS「SDD docs root」解析约定

校验层（维护者 · 本机私有，不进公开 GitHub）
  evals/                       # verify / fixtures / live 评测；见 .gitignore
  plans/                       # 内部设计笔记
```

## 真源边界

- 流程、状态词、完成声明、Harness 适配（含可选指挥施工）、证据分级：只改 `workflow-contract.md`
- 验证层次、**Evidence Kind**、行为优先、Deliver Gate、Fail 分类：只改 `evidence-contract.md`
  （证伪执行：`skills/testing/references/falsify-checklist.md`；弱 Oracle：`skills/spec/references/oracle-strength.md`；
  **关版三钉**（verify-deliver 戳 / Oracle 冻结 / maker≠grader）：`verification-loop.md`；
  系列全角色矩阵：`skills/testing/references/version-acceptance-matrix.md`）
- 发布阶段 P0–P6、定级裁剪、方案模板：只改 `skills/deploy/`（关版硬门仍在 evidence-contract + verification-loop 钉 1）
- Workspace / Worktree / Claim：只改 `workspace-contract.md`
- 产品包章节与剪枝：只改 `skills/design/references/product-package.md`
- 系统架构 / UX / 视觉 / 页面门控社区底线：只改 `skills/vibe-coding/references/design-standards/`
  （Verify 接线薄页 `skills/testing/references/ux-standards.md`；启发式正文在 design-standards）
- 产品回归启用条件与分层：只改 `skills/testing/references/product-regression.md`
- Build 期自动化测试通则（含红绿证据）：只改 `skills/vibe-coding/references/automated-tests.md`
- 事实映射门、纵向切片、测试合同门、Plan 流程、**check_spec 机检**（含 verify-deliver 戳 / oracle-freeze）：只改 `skills/spec/`（含 `scripts/check_spec.py`）
- Cursor/Claude → Codex 派单与指挥侧验收（禁 Codex 主验收）：只改 `skills/dispatch-codex/SKILL.md`（CLI 预检同目录 `scripts/`）
- 单个 Rail 的前台话术与执行约束：改对应 `skills/<rail>/SKILL.md`
- 宿主填写槽位与文档模板：改 `templates/docs/**` 与 `templates/AGENTS.md`
- 结构校验规则：改本机 `evals/tools/check_docs.py`（公开仓无此目录）
- 关版脚本：`scripts/verify-deliver.sh`（`make verify-deliver`）

`templates/docs` 只保留最小落盘结构并链接合同真源；合同正文在 skills。

## 常见改动路径

| 目标 | 首选修改点 | 联动检查 |
|---|---|---|
| 新增状态词或调整语义 | `workflow-contract.md` | `templates/docs/product/*`, `VERSION.md`, `check_docs.py` |
| 调整 Fail 分类 | `evidence-contract.md` | `templates/docs/specs/_template/run.md` |
| 调整 Workspace 字段 | `workspace-contract.md` | `plan.md`, `spec/SKILL.md`, `check_docs.py` |
| 调整 optional 文档策略 | `optional/README.md` | 对应 optional 模板 |
| 调整产品回归策略 | `skills/testing/references/product-regression.md` | `regression-register.md`, `regression-map.md` |
| 调整项目类型 / 冷启动 Init·Onboard | `project-kind.md` + `design/references/project-init.md` | entry/shape 硬闸、`vibe-coding` 路由、`AGENTS` 槽 |
| 调整产品包骨架 | `skills/design/references/product-package.md` | `design/SKILL.md` |
| 调整设计规范包 | `skills/vibe-coding/references/design-standards/` | `design`/`spec`/`testing` SKILL、`ux-standards.md`、AGENTS 槽位、`check_spec` |
| 调整 Spec 机检 | `skills/spec/scripts/check_spec.py` | `verify-deliver.sh`、`dispatch-codex` 预检、Makefile |
| 调整关版三钉 | `verification-loop.md` | `check_spec`、`verify-deliver.sh`、testing/deploy/vibe/dispatch |
| 调整测试合同结构 | `tests.md` 模板 + `spec/SKILL.md` | `check_docs.py`, `testing/SKILL.md` |
| 调整指挥施工派单/验收 | `dispatch-codex/SKILL.md` + workflow「指挥施工」 | `vibe-coding/SKILL.md`, `verify.sh` |
| 调整发布生命周期 | `skills/deploy/` | `evidence-contract` Deliver Gate、`run.md` 模板、`vibe-coding` 路由 |

## Spec 文件名迁移（历史对照）

| 旧 | 新 |
|---|---|
| `context.md` + `requirements.md` | `contract.md` |
| `scenario-spec.md` | `tests.md` |
| `technical-plan.md` | `plan.md` |
| `spec-run.md` + `validation.md` | `run.md` |

## 防双写清单

提交前确认：

1. 一个概念只在一个合同文件定义；
2. 模板没有复制同一合同大段正文；
3. `AGENTS.md` 是宿主唯一项目事实面（无 `docs/guides/` 第二份）；
4. 本机有 `evals/` 时跑 `make verify`；公开克隆可跳过；
5. 文档中的状态词与 `workflow-contract.md` 一致。

## 维护者附录：外借实践（BORROW）

记录外项目吸收决策时，可在插件仓或宿主 `docs/product/decisions/` 自建笔记；
不进入默认 scaffold。建议字段：状态、日期、来源、吸收层、明确不吸收、撤销条件。
