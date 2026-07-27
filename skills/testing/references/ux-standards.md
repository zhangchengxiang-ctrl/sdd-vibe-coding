# UX Validation Standards

> 用户可见 Scenario 的判定标准；产品专有 Oracle 仍以当前 Spec 为准。  
> 专家走查步骤 → [ux-walkthrough.md](./ux-walkthrough.md)（Verify 变体，非独立 Skill）。

## 核心原则

**Pass = 指定用户在真实情境下能有效、高效、满意地完成目标。**  
有控件 / Toast / API 200 / 空态文案 **单独均不算 Pass。**

- 验证用户 Job，不只验证控件或接口；
- 使用目标角色、真实入口和代表性数据；
- 观察系统反馈、错误恢复和最终状态；
- 截图或录像必须让未参与实现的人判断场景与结果；
- 不能执行时标记 Blocked，不用 mock、API 或口头推演冒充真实通道。

## 可用性度量（ISO 9241）

| 维度 | 含义 |
|------|------|
| Effectiveness | 能否真完成目标 |
| Efficiency | 时间、步骤、认知成本 |
| Satisfaction | 是否顺、是否愿意再来 |

## 检查维度

| 维度 | 最低问题 |
|---|---|
| 可发现 | 用户能找到正确入口吗？ |
| 可理解 | 文案、状态和下一步是否明确？ |
| 可控 | 用户能取消、返回或修正吗？ |
| 反馈 | 操作后是否及时显示真实状态？ |
| 错误恢复 | 失败是否说明原因和可行下一步？ |
| 一致性 | 相同概念、动作和权限是否一致？ |
| 可访问 | 键盘、焦点、对比度和语义是否满足宿主标准？ |
| 完成感 | 用户能确认 Job 已完成且知道影响范围吗？ |

## Nielsen 十条启发式（严重度 0–4）

0 不是问题 · 1 妆容 · 2 小 · 3 重要 · **4 灾难（阻断核心 Job → Job Fail）**。

| # | 启发式 | 评分时问什么 |
|---|--------|--------------|
| H1 | Visibility of system status | 是否知道自己在哪、系统在干什么？ |
| H2 | Match system ↔ real world | 是否人话？顺序是否符合任务心智？ |
| H3 | User control and freedom | 误操作能否撤销/退出？ |
| H4 | Consistency and standards | 一词一义？符合行业习惯？ |
| H5 | Error prevention | 高代价错误是否被挡住？ |
| H6 | Recognition rather than recall | 关键信息是否可见？是否逼人记 UUID？ |
| H7 | Flexibility and efficiency | 新手可起步、熟手有捷径？ |
| H8 | Aesthetic and minimalist | 无关信息是否淹没关键信息？ |
| H9 | Help recover from errors | 错误是否人话并给下一步？ |
| H10 | Help and documentation | 最好自解释；帮助是否任务向？ |

## Spec 工件（有 UI / 手动验收时）

| 工件 | 角色 |
|------|------|
| 本文（插件） | 定义 · ISO · Nielsen · 反模式 |
| `docs/specs/<id>/tests.md` | 本版 Jobs / Then Oracle + 通道；声明服从本文 |
| `run.md`（Evidence 列 / 附件路径） | 实测账本（Jobs + H# findings） |

不适用：纯后端无 UI、纯文档、纯 CI（`run.md` 写 UX: N/A + 理由）。

## 反模式

| 反模式 | 正确做法 |
|--------|----------|
| Toast / 「已安装」文案 → Pass | 用户是否达成 Job？ |
| API 200 → Pass | 发现面用户是否认得出变化？ |
| 旁路脚本顶替主通道 → Pass | 目标产品路径是否真走通？ |
| 仅用 SC Pass 数关版 | Jobs 有效性 + 无开放严重度 4 |

## 证据

每个关键 Job 至少记录入口、步骤、期望、实际结果、环境/版本和一份可复核证据。严重阻断
核心 Job 的问题不得判 Version Acceptance 通过。
