# Spec Run · <version-id>

> 此文件是该 Spec 的持久执行状态。一个 Spec 只允许一个连续 Run；不得创建 Task、Route 或
> 每步交接来替代它。

## 交付目标

- 用户结果：
- In Scope：
- Out of Scope：
- 验收条件来源：`requirements.md` / `scenario-spec.md`

## 当前状态

- 状态：`ready | building | unit-testing | verifying | repairing | blocked | acceptance-passed`
- 当前模式：`build | verify | repair`
- Owner / Workspace：
- 最后更新：
- 允许结束条件：`acceptance-passed | blocked | needs-authorization`

## Build 完整实现

- 已覆盖入口：
- 未覆盖入口：
- 实现冻结时间（开始单元测试前）：

## 单元测试批次

> 测试开始后禁止改代码；先收齐结果。

| 命令 | 范围 | 结果 | 证据 |
|---|---|---|---|
| | | Pass / Fail / Blocked | |

## Verify 批次

> 统一运行集成、场景、端到端与真实探针；测试期间禁止改代码。

| 层 | 命令 / 场景 | 结果 | 证据 |
|---|---|---|---|
| integration / scenario / e2e / real-probe | | Pass / Fail / Blocked | |

## 失败集合与统一 Repair 方案

> 所有测试完成后才填写。按根因分组，再集中修改。

| 根因组 | 受影响 Scenario / 入口 | 修改面 | 回归批次 | 状态 |
|---|---|---|---|---|
| | | | | pending / repaired / blocked |

## 终态

- 结论：`acceptance-passed | blocked | needs-authorization`
- 未完成项 / 外部阻塞：
- 直接证据：
