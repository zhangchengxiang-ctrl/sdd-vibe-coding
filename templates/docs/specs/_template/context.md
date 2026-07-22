# Context · <version-id>

> **Agent 入口**：读完本文件后，按 [VERSION.md](./VERSION.md) manifest 顺序执行。

## 一句话目标

（一句话说明目标用户要办成什么事）

## 产品愿望与用户 Job

- **Wish**：
- **目标用户**：
- **在什么情境下**：
- **要办成什么事**：

## 首个价值切片

- **用户可感知结果**：
- **包含的 SC**：
- **为什么先做它**：

## 交付合同

- **Delivery Target**：与 `VERSION.md` 一致
- **Current Gate**：与 `VERSION.md` 一致
- **Requirements Lock**：`open / locked / reopened`；锁定日期与确认依据
- **Effective Channel**：用户实际生效入口
- **Target Environment**：
- **Oracle**：怎样观察到“真的办成”
## 为什么现在做

（链到 roadmap / 设计稿，2–3 句）

## 假设与待判决

| 项目 | 当前默认 / 假设 | 谁决定 | 何时必须决定 |
|------|-----------------|--------|----------------|
| | | Product Expert / Team Lead | |

## 外部调研摘要（若触发）

- **为什么需要联网**：
- **调研问题**：
- **关键事实与来源日期**：
- **对当前系统的启示**：
- **不适合照搬**：
- **未确认项**：
- **N/A 理由**：（内部事实足够 / 不影响当前决策）

## 硬约束

- 必须遵守 `AGENTS.md` 红线（Plan Approval、宿主浏览器验收约定）
- 本版本特有：
  - 

## 不在范围内



## 关键文件（代码）

| 区域 | 路径 |
|------|------|
| Web API | `<host-api-routes>/` |
| Worker | `<host-worker>/src/` |
| 前端 | `<host-ui>/src/components/` |
| 数据库 | `<host-db>/` 或 `<host-db>/` |
| 测试 | `tests/backend/` · `tests/e2e/` |

## 完成定义

- [ ] 达到 `VERSION.md` 声明的 Delivery Target
- [ ] `validation.md` 当前交付范围的适用项已有证据
- [ ] `commit-checklist.md`（仅本版创建时）
- [ ] `product/foundation/system-map.md` 已回写（若改变系统边界）

## 环境

- Dev / 预览 URL：（读宿主 `AGENTS.md`）
- 生产 URL：（读宿主 `AGENTS.md`）
- 账号 / 角色 / 数据：
- 外部依赖：
- 回滚边界：
- 验证：按当前 Slice 的直接验收条件选择定向检查；全量套件仅用于发布、CI、全局合同或用户明确要求

## Handoff 登记

实施升格后请在 [`reference/handoff.md`](../../reference/handoff.md) §活跃 Spec **加一行**（状态 / 下一步 / blocker）。

若本版源自 [`product/modules/`](../../product/modules/) 某篇：同步把该篇在 [design README](../../product/README.md) 索引表改为 **`已切版`** 并填 Spec 列（生命周期纪律的一部分，勿另开手工任务）。
