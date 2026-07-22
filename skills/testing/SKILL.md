---
name: testing
description: >-
  跨项目定向测试与验收；正式验收/发布按需使用 VALIDATION-REPORT。
  验收诚实度：禁止假跑完、API 顶 Browser、夹具顶产品路径；跑通=scenario 矩阵；
  验收禁同会话热修；不 OK → vibe-coding acceptance-to-remediation。
  触发：测试 / test / E2E / 验证报告 / 回归 / 收尾验收 / 走查 / 用户评审。
---

# 测试与验收

**先读**：宿主 `AGENTS.md` 与当前任务的直接验收条件。已挂载 Spec 再读
`scenario-spec.md` / `validation.md`；体验验收再读工厂 `UX-STANDARDS.md`。

## 默认原则

- 主代理直接完成定向验证；默认不派 tester。
- 选择能证明当前验收条件的**最小**验证。
- 全量套件只用于全局合同、发布前、CI 或用户明确要求。
- 验证通过且代码未变化 → 不重复运行。
- 只处理本次 diff 引入或直接阻断验收的失败；无关失败确认一次后记录退出。

## 证据分层（V0–V3）

| 层 | 证明什么 | 典型证据 |
|----|----------|----------|
| **V0** | diff / 静态合同 | lint、类型、确定性检查 |
| **V1** | 实现逻辑正确 | 定向单测 / 集成 / API |
| **V2** | SC 在真实生效通道有效 | Browser、运行时、用户 Job |
| **V3** | 全局回归 / 发布 | 全量、CI、发布检查 |

UI 的 Demo Gate 至少一次 V2。`validation.md` 须能追踪：
`SC → 用户结果 → 实现 → 正确性 → 环境 → 体验 → 交付状态`。

## 探测命令（禁止写死）

从宿主 `AGENTS.md` / `Makefile` / `package.json` 读取静态检查、单测、E2E、浏览器验收入口。

## 改动 → 最低验收

| 改动 | 原则 |
|------|------|
| 后端 only | 相关静态 + 后端测试 |
| 前端 only | 相关前端测试 + **宿主要求的浏览器验收** |
| 全栈 | 直接相关前后端 + 当前 In 的 scenario |
| DB | migrate + health（或宿主等价） |
| 碰单向门 | 定向测试 + 人眼审 diff |

## 面向测试验收

新产品能力 / Major：`scenario-spec.md` 覆盖角色 × 旅程 × 失败/权限。  
`TEST_TYPE: e2e|integration` → 测试标题/注释含 `SC-N`；`manual` → 走查留证据。

## 面向体验验收

有 UI / manual SC / 模式 D：

1. 工厂 `UX-STANDARDS.md` + Spec `ux-standards.md` Jobs  
2. `ux-test-results.md` 含 Jobs 有效性 + 启发式 findings  
3. 核心 Job Fail 或开放严重度 4 → 不得关版  

## 验收类证据落盘（IRON）

| 必须 | 落点 |
|------|------|
| 关键屏截图 | `docs/specs/<id>/evidence/screenshots/` |
| 证据索引 | `evidence/README.md` |
| 用户判决 | `user-review.md` |
| 失败复现 | meta/日志进 evidence |

**评审铁律：**

1. 目标用户不查文档能否办成主任务？不能 → 总评不 OK  
2. Pass 不得粉饰空态/脏数据/闭环断裂  
3. 夹具绕过产品路径 ≠ 产品路径 Pass  
4. 每条 SC 须有终态 Pass/Fail/**Blocked+原因**；验收完成 ≠ 全部 OK  
5. 矩阵未完禁止软停；每轮 `[验收·矩阵 k/n·下一 SC-x]`  
6. 不 OK → remediation + `.next-rail`（见 `acceptance-to-remediation`）

## 正式报告

用 [`VALIDATION-REPORT.md`](../_docs-factory/VALIDATION-REPORT.md)。未挂 Spec 的 ordinary fix → **Docs: N/A**。

## 收尾

报告实际验证与未覆盖项；状态变化才改 handoff 对应行。
