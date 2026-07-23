# 角色轨 · 卡片与可写细则

> 判轨 / 假 Build / trivial → **权威** 插件 `rules/00`（禁止本文件复述）。  
> 产品记忆闸 → `rules/01`。换轨工单模板 → [`acceptance-to-remediation`](./acceptance-to-remediation.md) §4。  
> 本文件只保留：**必须/禁止清单 · 聊天卡片 · 三池**。

```text
Intake → 池 / modules 草稿　　Owner → 排期 / 升格 Spec
Build  → 挂 Spec 编码　　　　Accept → 只测（见 acceptance-to-remediation）
```

口语触发（无斜杠命令）：「走 Intake / 排期 / 开始做 / 跑验收 / 切版 / 空仓 scaffold」→ 对应下表轨或 skill。

---

## 1. Intake

**必须**（逐步）：

1. 复述 Problem Framing（谁 · 场景 · 痛点 · 期望）
2. 查 modules/代码（只读）→ 写 / 更新 `demand-pool`（`DEM-NNN`）
3. 成块 IA/导航/入口/发布模型 → 调 `design` 写 `modules/`
4. 输出一屏 **Intake Card** → **停**

**禁止**：`docs/specs/` · 业务代码 · 发版 · 把编号清单/截图当已批准 Build · 擅自承诺「本周 P0」。  
空仓先：`bash <plugin>/scripts/scaffold.sh .`（scaffold ≠ 编码许可证）。

```markdown
## Intake Card
- 问题：…
- 类型：wish | fault | ux | other
- 池条目：DEM-NNN（路径）
- 建议优先级：（仅建议）
- 非目标：…
- 未决（≤3）：…
- 下一轨：执行 docs/product/.next-rail.md
```

```markdown
# rail: owner
# task: 审需求池 / 排期
## 必读
docs/product/demand-pool.md   # 焦点 DEM-NNN
docs/reference/handoff.md
## 铁律
- 本对话 = Owner；禁止编码
- 判决：做 / 缓 / 不做 / 退回 Intake
- 若「做」：首切片 + Delivery Target → 升格 Spec 或筹备中
```

---

## 2. Owner

**必须**（逐步）：

1. 读 `docs/product/demand-pool.md`（+ gap-register / roadmap / handoff）
2. 判决：做 / 缓 / 不做 / 退回 Intake；回写池状态
3. 「做」→ Kickoff/Decision Card → 调 `spec` 升格（或挂已有 Spec）
4. 派 Build：写 `docs/specs/<id>/.next-rail.md` + 聊天一行指针

**禁止**：本会话写业务实现 · 跳过需求池口头「顺便做了」 · 把 gap-register 当吐槽池 · Accept 会话热修。

```markdown
## Owner Card
- 池焦点：DEM-NNN …
- 判决：做 | 缓 | 不做 | 退回 Intake
- 优先级 / 首切片 / Delivery Target：…
- Spec / 筹备：…
- 下一轨：执行 docs/specs/<id>/.next-rail.md
```

```markdown
## Demo / Delivery Card
- 入口：…
- 证据：…
- 范围标签：[轨·范围·Delivery Target]
- 已知限制：…
```

---

## 3. Build

**必须**（逐步）：

1. 确认已挂 `docs/specs/<id>/`（或用户明示「开始做」且切片已锁）
2. 按当前 Phase 最小实现 → 一次定向验证（`execution-discipline`）
3. 完成带范围标签 `[轨·范围·Delivery Target]`
4. Demo / Delivery Card

**禁止**：无 Spec 的 non-trivial 新产品能力直接大改 · 静默扩大 Spec In（新愿望 → DEM）· Agent 自建 git worktree（除非用户明示）。

「开始做」且切片已确认 → 可同会话 Owner 升格，再 **新对话** Build（或 `.next-rail`）。

---

## 4. Accept（只测）

强制 **Accept**（Build 族只测模式）。读 `testing` + [`acceptance-to-remediation`](./acceptance-to-remediation.md)（3 硬钉）。

**必须**：挂载验收 Spec → 按 `scenario-spec` 矩阵逐条跑 → 每轮 `[验收·矩阵 k/n·下一 SC-x]` → 每条 Pass/Fail/**Blocked+原因** → 总评不 OK 则 remediation + `.next-rail` + 一行指针。

**禁止**：同会话热修 · API/`curl` 冒充 Browser 合同（若宿主要求浏览器）· 无终态交卷 · 把本会话标成可写业务码的 Build。

---

## 5. 三池

| 池 | 路径 | 谁写 |
|----|------|------|
| 需求池 | `docs/product/demand-pool.md` | Intake 追加；Owner 改状态 |
| 差距账 | `docs/product/gap-register.md` | Owner/架构；关闭 → gap-closed |
| 实施 | `docs/specs/<id>/` + handoff | Owner 升格；Build 执行 |

DEM ≠ 编码许可证（`rules/01`）。
