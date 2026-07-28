# System Architecture（系统架构默认）

> 面向 AI 施工的**可执行边界**，不是完整架构方法论。社区锚点：[C4 model](https://c4model.com/)、ADR/MADR、分层/端口适配实践。  
> 加载合同 → [README.md](./README.md)。

## 1. 先边界后功能

在堆功能前先回答：什么属于 core / application / infrastructure / UI（或宿主等价分层）。

| 层 | 职责 | 边界 |
|---|---|---|
| Core / Domain | 业务规则、不变量 | 经端口访问 DB、HTTP、UI |
| Application | 用例编排、事务边界 | 存储方言留在基础设施侧 |
| Infrastructure | DB、队列、第三方、文件系统 | 业务规则留在 Domain / Application |
| UI / Adapter | 呈现与输入适配 | 经授权与用例入口访问业务规则 |

宿主目录名可不同；**依赖方向**单向，跨层只经明确端口。以 `AGENTS.md`「架构与写入边界」为准。

## 2. C4 默认表达深度

| 层级 | 何时需要 | 默认落点 |
|---|---|---|
| L1 Context | 新系统、新外部依赖、跨系统集成 | `docs/architecture/` 或 Spec `plan.md` 摘要 |
| L2 Container | 新进程/部署单元、新数据存储、新消息通道 | 同上 |
| L3 Component | 单 Container 内大改模块边界时 | Spec `plan.md` 差量即可 |
| L4 Code | 默认不写；跟代码走 | — |

绿场或跨进程变更：Plan 至少给出 L1 或 L2 意图（可用 Mermaid），边界写清进程与数据归属。

## 3. ADR（何时必写）

触及下列之一时，在 `docs/architecture/adr/` 或 Spec `optional/` 留一条短 ADR（上下文 → 选项 → 决定 → 后果）：

- 新存储 / 新消息系统 / 新鉴权模型；
- 改变公共 API 或 schema 真源；
- 打破既有依赖方向或写入边界；
- 多方案互斥且后果跨多个 Spec。

常规纵向切片不为每个小改写 ADR。

## 4. 纵向切片 vs 横向平台

与 Skill `spec` 一致：

- 按真实用户/系统入口纵向交付；
- 共享 helper：≥2 切片 Verified 重复同一逻辑后再抽。

**硬门：** 切片轴是入口，不是 root / resolver / ACL / registry / readiness 等横向模块任务。

## 5. 生产向不变量（适用则写进 plan）

- **副作用**：可重试路径具备幂等键或等价去重；
- **关键资源**：明确单写者或冲突策略；
- **多租户 / 权限**：读与写均带 scope（查询即带租户/角色条件）；
- **公共契约**：schema / OpenAPI / 事件合同有单一真源（见 AGENTS）。

## 6. 绿场默认施工序

1. 契约与数据模型（或最小 schema）  
2. Domain / Application + 入口适配  
3. UI  
4. 可观测与失败路径  

## 7. Plan 轻门（请求 Build 前）

当本版触及**新入口、跨层、新存储、新权限模型、新部署单元**时，`plan.md`「架构与设计边界」写明：

1. 沿用哪条宿主边界 / Playbook 条款，或是否新开边界；  
2. C4 影响层级（L1–L3 或 N/A）；  
3. 是否需要 ADR（是/否 + 路径）；  
4. `Unverified` 项清单（仅 Verified 进 Lock）。

未触及上述变更：写「沿用现有边界，无架构差量」即可。

## 8. 模块级 context

优先在模块目录维护短 README（职责、入口、依赖边界），作为 Agent 局部 context；与产品包 `modules/` 产品决策不双写实现细节。
