---
name: spec
description: >-
  SDD 版本包工具箱：升格切版（generate）· 消歧（clarify）· 对照代码（converge）·
  覆盖度分析（analyze）· 需求质量七维（checklist）。
  触发：切版 / 开 Spec / clarify / converge / analyze / checklist /
  产品专家确认「开始做 / 实现 / 构建」。设计讨论本身不触发 generate。
---

# Spec（工具箱）

**先读**：[`vibe-coding`](../vibe-coding/SKILL.md) · [`SYSTEM.md`](../../SYSTEM.md) §2.1 · 宿主 `AGENTS.md` · `docs/README*`。

**DO NOT CODE**（generate / clarify 写合同；converge/analyze/checklist 默认只读建议）。编码回 `vibe-coding`。

按用户意图选模式；未指定时：实施意图 → **generate**；设计前消歧 → **clarify**；关版对照 → **converge**。

---

## A. Generate（升格切版）

### 模式

| 模式 | 触发 | 规则 |
|------|------|------|
| **A 蓝图升格** | modules 已确认进实施 | 忠实升格全文；Phase 只排顺序 |
| **B 用户拆版** | 用户明示「本版只做…」 | 仅确认子集进 In |
| **C 愿望升格** | 无完整蓝图；已确认开始实现 | 从 Kickoff / 首切片生成动态 Spec |
| **D 验收迭代** | 验收不 OK | Fail SC + 体验 → remediation |

「切版」= 升格实施真源，**不是**再砍范围。用户未缩 scope → 禁止把后续 Phase 塞进 Out。

### 核心工件

从宿主 `docs/specs/_template/`（或插件 templates）创建 `docs/specs/vYYYY.MM-<slug>/`。

**必有**：`VERSION.md` · `context.md` · `requirements.md` · `tasks.md` · `validation.md`

| 按需（从 `_template/optional/` 拷到 Spec **根**） | 触发 |
|------|------|
| `scenario-spec.md` | 新产品能力 / Major（**禁止**留在 optional/ 当真源） |
| `ux-standards.md` | UI / manual SC / 模式 D |
| `clarify.md` | 阻断实施的互斥决策 |
| `design.md` | 新模块 / 状态机 / 关键技术合同 |
| `scope.md` / `product-design.md` / `research.md` | 模式 A/B 或需保存塑形成果 |
| `experience-design.md` / `problem-map.md` | **模式 D 必建** experience-design |
| `test-plan.md` | 策略超出宿主默认定向验证 |
| `migration-design.md` / `threat-model.md` | DDL / 安全面 |
| `regression-map.md` | 关版维护态关键旅程晋升 |
| `evidence/` / `user-review.md` | 正式验收 |

### Ready Gate（实施前）

- `Requirements Lock=locked`
- 当前 Slice 的 Job、In/Out、AC 明确；Scenario 可执行
- Target Environment / 账号 / 依赖可用或标 blocked
- Effective Channel 与 Oracle 明确
- Major / 单向门已 Plan Approval

Ready 不成立 → 不得用文档完整度冒充可实施。

### 工作流摘要

1. **Ground**（内部 + 必要 External Research Gate）  
2. **Clarify / Shape** → Kickoff；每轮 ≤1–3 高价值问题  
3. **Ready Gate**  
4. **落盘** + handoff 加行 + 产品索引（蓝图状态→已切版）  
5. **Scenario 合同**：角色 × 旅程 × 成功/失败/权限；矩阵无空窗  
6. **体验合同**（有 UI）→ Jobs + [`ux-standards`](../vibe-coding/references/ux-standards.md)  
7. 一屏实施摘要 → 回 `vibe-coding` Build  

模式 D：必含 `experience-design.md`（体验方案，不只 bug）。详见 `acceptance-to-remediation`。

### 切版语义自检

落盘 `scope.md` 前：「我在做 A（忠实升格）还是 B（用户明示裁剪）？」用户没说缩 scope → 必须是 A。

### 禁止

要求用户填完整 PRD · 设计讨论就建 Spec · 已确认实施仍逼说「切版」 · 私自裁剪蓝图。

---

## B. Clarify（消歧）

1. 挂载 `docs/specs/<id>/`  
2. 扫描：模糊需求、未决选型、隐含假设、契约缺口、scope 漏洞、宿主红线（`AGENTS.md`）  
3. 写入 `clarify.md`；**禁止**开放「是否砍半」（升格后范围已锁）  
4. 全部 `[x]` → PASS；否则 BLOCK  

只写 clarify / 回填 requirements。

---

## C. Converge（对照代码）

关版时建议跑一次。读 VERSION / requirements / tasks / scenario → Glob 探测代码根（禁止写死 `apps/`）→ 已完成/未完成表 → 新 task 须用户确认后写入。系统性差距 → 宿主 `gap-register`（若有）。

---

## D. Analyze（覆盖度 · 只读）

AC × design × tasks × scenario × 测试矩阵 → P0/P1 问题表。

---

## E. Checklist（七维 · 只读）

1. Decision-readiness  
2. Substance over theater  
3. Strategic coherence（roadmap / 产品索引 / Gap）  
4. Done-ness clarity（validation / scenario / Jobs）  
5. Scope honesty  
6. Downstream usability  
7. Shape fit  

输出：评分 · 阻断项 · **PASS / PASS-WITH-WARNING / BLOCK**。
