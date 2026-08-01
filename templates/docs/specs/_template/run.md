# Run · <version-id>

> 本 Spec 的唯一运行态：批次结果、Fail/Repair 与关版结论写在此文件。
> 预期 Oracle 在 `tests.md`；此处只记实际结果与证据路径（附件按需落盘）。

## 执行态

- 状态：`ready | building | unit-testing | verifying | repairing | blocked | acceptance-passed`
- 当前模式：`build | verify | repair`
- Owner / Workspace：
- 最后更新：
- 允许结束条件：`acceptance-passed | blocked | needs-authorization`

### Build

- 已覆盖入口：
- 未覆盖入口：
- 实现冻结时间（开始单元测试前）：

## 结果

> 测试开始后冻结改码；先收齐结果。

### 批次结果

| 层或命令 | 覆盖 Tests | 结果 | 证据（`kind=` · 路径） |
|---|---|---|---|
| | T-001 | Pass / Fail / Blocked | kind=… · |

### 追踪矩阵

| Requirement | Test | Implementation | Evidence（`kind=` · 路径） | Result |
|---|---|---|---|---|
| R-001 | T-001 | | kind=… · | Pass / Fail / Blocked |

> Pass 禁止仅 `kind=window-smoke` / `health` / 裸 `*smoke*.json`。数据面 success 须 `api-diff` 或 `network-har`。

### Fail / Blocked 分类

| Test | 表象 | 分类 | 根因 / 未知 | 统一 Repair 组 / 外部阻塞 |
|---|---|---|---|---|
| | | implementation / product-ux / plan / test-oracle / environment / new-request / unknown-root-cause | | |

### 统一 Repair 方案

> 所有适用测试完成后才填写。按根因分组，再集中修改。

| 根因组 | 受影响 Tests / 入口 | 修改面 | 回归批次 | 状态 |
|---|---|---|---|---|
| | | | | pending / repaired / blocked |

## 关版

### 结论

- 是否可以交付：`可交付 | 不可交付 | 受阻`
- 一句话原因：
- 本次验收覆盖：
- 验收时间：

### 如何体验

- 环境 / 入口：
- 适用角色：
- 代表性数据：
- 成功时应看到：

### 已验证的用户结果

| 用户要完成的事 | 操作 → 两态观察差 | 证据（`kind=`） | 结论 |
|---|---|---|---|
| | | kind=… · | 已通过 / 未通过 / 无法验证 |

> 无两态观察差不得写「已通过」。Build 轨不得填「是否可以交付：可交付」。

### 未通过或无法验证

| 问题 | 对用户的影响 | 严重度 | 原因或缺少什么 | 建议动作 |
|---|---|---|---|---|
| | | 阻断 / 严重 / 一般 / 轻微 | | |

### 限制与上线状态

- 未覆盖内容：
- 已知限制：
- 是否已上线：`未上线 | 已上线 | 未知 | 不适用`
- 上线后的观察：

### 需要用户做什么

- 用户验收动作：
- 下一步：

## 终态

- Matrix：`matrix-accounted | incomplete`
- Acceptance：`acceptance-passed | not-passed | n/a`
- 结论：`acceptance-passed | blocked | needs-authorization`
- Workspace / Branch / PR：
- 未完成项 / 外部阻塞：
- 直接证据：
- 下一步：

所有适用 Test 有终态只能声明 `matrix-accounted`；只有关版条件满足才是
`acceptance-passed`。二者都不是 Delivery Target（见 workflow-contract「状态词汇」）。

## Production Verification（适用时）

> 产品冒烟（目标环境 · P6）态写入后再报生产交付。`/health` 与进程 active 是 P5 过程信号。
> 通则见 `evidence-contract.md` Deliver Gate；阶段见 Skill `deploy` / `release-lifecycle.md`。

- 声明目标 / 实际达到：
- 定级 + 理由（若适用）：
- P2 发布方案（执行序 / sidecar 采纳或延期）：
- P3 验证方案（冒烟层勾选）：
- Deploy / rollback（P5）：
- Health（过程）：
- 环境门禁：
- 产品冒烟（目标环境 · P6）：通过 | 未过 | Blocked+原因
- 完成标签：`[部署·L#·prod-smoke …]`
- Open MUST（延期项 → 下次 P1）：
- 原始故障信号：
- 核心用户路径：
- 数据一致性：
- 监控观察窗口：
- 回滚点：
