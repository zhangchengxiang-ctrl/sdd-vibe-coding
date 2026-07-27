# Version · <version-id>

| 字段 | 值 |
|---|---|
| **ID** | `vYYYY.MM-<slug>` |
| **标题** | |
| **状态** | `draft` |
| **Delivery Target** | `code-ready` |
| **Requirements Lock** | `open` |
| **产品决定依据** | |
| **创建日期** | YYYY-MM-DD |
| **目标环境** | |

状态只使用：
`draft | ready | in-progress | verifying | blocked | done | archived | cancelled`。

Delivery Target 只使用：
`code-ready | dev-effective | production-delivered`（见插件 workflow-contract「状态词汇」）。
`matrix-accounted` / `design-ready` / `production-restored` 不是本字段。

Rail 属于对话，不属于 Version；当前 Rail 只在 `reference/handoff.md` 记录。

## Manifest

| # | 文件 | 作用 |
|---|---|---|
| 1 | [context.md](./context.md) | 目标、范围和环境 |
| 2 | [requirements.md](./requirements.md) | Requirement 与 AC |
| 3 | [technical-plan.md](./technical-plan.md) | 技术方案与单向门 |
| 4 | [scenario-spec.md](./scenario-spec.md) | 可执行用户结果 |
| 5 | [validation.md](./validation.md) | 实现、集成与版本验收 |
| 6 | [spec-run.md](./spec-run.md) | 连续 Build、批量测试与统一 Repair 状态 |
| 7 | [evidence/](./evidence/) | 可复核证据 |

按风险添加 `clarify.md`、`migration-design.md`、`threat-model.md`、`test-plan.md` 等。不要为
凑齐模板生成空文档。

## Optional 文件选择（按需）

决策顺序：先看 `AGENTS.md` 默认门禁和当前 Spec 风险，再决定是否新增 optional 文件。
只在会改变实施边界、验收范围或单向门策略时创建；否则不建空壳。

| 文件 | 何时需要 | 不需要时 |
|---|---|---|
| `optional/clarify.md` | 存在阻断当前切片的高价值产品决策 | 保持 `Requirements Lock=open` 并继续 Plan |
| `optional/scope.md` | 需要单列跨系统依赖、影响面或多入口边界 | In/Out 已能在 `context.md` 表达清楚 |
| `optional/test-plan.md` | 验证策略明显超出 `AGENTS.md` 默认门禁 | 直接在 `validation.md` 写验证批次 |
| `optional/migration-design.md` | 触发数据库迁移、兼容窗口或回滚复杂度高 | 普通 schema 变更可在 `technical-plan.md` 覆盖 |
| `optional/threat-model.md` | 权限/安全边界变化或高风险数据流 | 安全影响低且已有宿主默认控制 |
| `optional/experience-design.md` | Verify 出现 product/ux Fail 需回 Shape 重设体验合同 | 纯 implementation Fail 走 Repair |
| `optional/ux-standards.md` | 当前版本需要新增/收紧专有 UX Oracle 或设备约束 | 沿用插件 `testing/references/ux-standards.md` |
| `optional/regression-map.md` | 计划把本版关键旅程晋升为长期产品回归面 | 不做长期回归沉淀时不创建 |
| `optional/research.md` | 方案依赖外部事实且证据影响取舍 | 仅内部代码事实即可决策 |
| `optional/problem-map.md` | 需要集中归因多类 Fail / 反馈并追踪路由 | 单一根因可直接进入 Repair 方案 |
| `optional/product-design.md` | 本版要同步产品层叙事给非技术干系人 | 仅技术实施可不写 |
| `optional/commit-checklist.md` | 宿主要求关版前人工核对发布清单 | 自动门禁已覆盖 |

## 变更记录

| 日期 | 变更 | 依据 |
|---|---|---|
| | 初版 | |
