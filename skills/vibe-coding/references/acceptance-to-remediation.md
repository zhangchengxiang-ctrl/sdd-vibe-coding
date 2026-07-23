# 验收闭环 → 修复迭代 Spec（Vibe Coding 关键工作流）

> 挂在 `vibe-coding` 下。触发：全路径验收 / 走查不 OK /「总结问题开修复版」/「给新对话提示词」。  
> 配套：`testing`（验收诚实度）· `spec`（验收驱动切版）。

---

## 0. 为什么单独成流

验收 Spec（`*-acceptance` / 走查）回答的是：**相对设计，用户能不能办成事？**  
修复 Spec（`*-remediation`）回答的是：**下一版怎么把断点 + 体验债一起做完？**

二者**禁止混在一个会话里假装关版**：验收不 OK → 开迭代 Spec → **新对话**编码测试。

**硬钉（与 vibe-coding 主文「3 硬钉」一致）**

- **验收禁改合同**：本轨禁止改实现 / 设计真源 / In-Out；发现 Fail 只记证据。热修 = 换轨到 remediation。
- **验收完成 = 矩阵终态齐全，≠ 全绿**：每条 SC 须有终态 `Pass` / `Fail` / `Blocked`（**Blocked 必写原因**）。总评 OK/不 OK 是跑完之后的判决；大量 Fail/Blocked 仍算验收完成。
- **全部跑完 = 矩阵范围**：不是无限路径；禁止把「全 Pass / 可关产品版」当成验收会话 Done。
- **完成必带范围标签**：例 `[验收·矩阵 18/18·已跑完·总评不OK]`（可附 Blocked 计数）；无标签禁止说完成。
- **对完成门禁（`rules/03`）**：本文件在验收轨 **优先于**「差的属于本目标 → 继续到齐」。
- **交接自动落盘**：矩阵**跑完**且（不 OK / 有 Fail）→ **必须**写 §4 轨工单；remediation 收束 → **必须**写 §4.1 轨工单。不问「要不要提示词」。**禁止**只把整段开工词贴在聊天里当唯一真源。

---

## 1. 端到端流水线

```text
① 设计真源锁定
   product/modules/<slug>/（明示边界；禁止串台到消费方产品包）

② 验收 Spec 切版（scenario 覆盖矩阵齐全）
   docs/specs/vYYYY.MM-<slug>-acceptance/

③ 真跑验收（Browser + 设计规定的生效通道）
   evidence/ + ux-test-results.md + user-review.md
   → **验收完成** = 矩阵每条终态齐全（Pass/Fail/Blocked+原因），≠ 全部 Pass
   → 总评 OK / 不 OK（用户办不成事 = 不 OK，不论 Pass 数）
   → 不 OK：写 §4 轨工单 `.next-rail.md` + 聊天一行指针

④ 若不 OK：问题总表 → 开「迭代 Spec」（缺陷 D* + 体验 E*）
   docs/specs/vYYYY.MM-<slug>-remediation/
   必含 experience-design.md（体验方案，不是只列 bug）

⑤ 新对话开工编码（执行 `.next-rail.md` / claim remediation）
   按 tasks Phase 修 + 定向验证
   → Phase/关版收束：写 §4.1 轨工单 + 一行指针

⑥ 再测对话：执行 `.next-rail.md` → 回归矩阵（原 Fail + SC-R* / SC-U*）+ handoff

⑦ 关版且模块进入/保持维护态：晋升关键可重复子集 → Spec/`_archive` `regression-map.md`
   + 登记宿主产品回归注册表（若有；
   正文不搬 modules）。此为**产品回归**，≠ 本轮验收矩阵全文。
```

---

## 1.1 验收轨连续性（防中途软停）

**验收完成 ≠ 全部 OK。** 完成条件 = 矩阵每条均有终态：

| 终态 | 含义 |
|------|------|
| **Pass** | WHEN 已执行且办成事 |
| **Fail** | WHEN 已执行且未办成 / 断点 |
| **Blocked** | **无法执行 WHEN**（环境、账号、依赖、权限、缺对照数据等）— **必须**写阻塞原因；禁止留空或用「未测」糊弄不写原因 |

矩阵未跑完（仍有**无终态**的 SC）时：

| 必须 | 禁止 |
|------|------|
| **每轮结尾**一行：`[验收·矩阵 k/n·下一 SC-x]`（或 blocker） | 问「要不要继续测」 |
| 下一动作 = **继续跑下一 SC**（写 `ux-test-results`） | 改代码 / 开修 / 闲聊收工 |
| 遇阻塞 → 标 **Blocked** + 原因，计入 k，继续下一条 | 因一条阻塞就整场停摆且不标注 |
| 上下文将满 → 落盘检查点后写「续跑」轨工单（仍验收轨）+ 一行指针 | 用「先修一点」逃避续跑；只贴聊天大段 |

「禁止提前收工」= 尚有无终态 SC 就总结交卷 = 说谎。允许的收束：全部 Pass/Fail/**Blocked(原因)** + 总评（OK 或 不 OK）。

---

## 2. 验收阶段铁律（复发纠正）

| 纠正（用户） | Agent 必须 |
|--------------|------------|
| 禁止同会话边验边修 | Fail → 记表；修代码 / 改合同 → remediation + **新对话** |
| 禁止「均已动手/跑完」粉饰 | 「跑完/验收完成」= 每条有终态；WHEN 真执行或 **Blocked+原因**；写「执行诚实度」 |
| 禁止 API/读代码顶 Browser | UI 路径 Pass 必须 Browser（或仓内约定 MCP）证据 |
| 禁止夹具/脚本绕过产品路径 | 例：手动塞 skills 目录 ≠「Prompt 安装 Pass」 |
| 禁止控件存在 = 用户能办成事 | `user-review.md` 以办成事为准；Pass 表为辅 |
| 禁止提前收工 / 中途软停 | 见 §1.1；继续跑或标 Blocked，禁止无终态交卷 |
| 禁止阻塞不标注 | 无法测 → **Blocked** + 原因；禁止省略或 silently skip |
| 收束不 OK 无轨工单 | **自动**写 §4 `.next-rail.md` + 一行指针；禁止只丢 Fail 表等用户要；禁止只贴聊天大段 |
| 生效通道按设计 | 若设计是 Cursor Agent，禁止用工作台对话冒充「装上了」 |
| 设计真源隔离 | 验收某平台时禁止串读消费方产品包当 UX 真源 |

详见 `testing` skill「评审铁律」。

---

## 3. 从验收到迭代 Spec（切版形态）

验收总评 **不 OK**（或有 Fail 需改合同/实现）→ **自动**进入本 Mode（不必等用户再说「开修复版」）。用户说「总结问题 / 开修复版 / 系统迭代」同触发。

### 3.1 In 必须同时有两类

| 类 | 内容 | 典型工件 |
|----|------|----------|
| **D\*** 工程断点 | Fail SC、闭环断裂、错 API、权限/投影不一致 | `requirements` R* · `design.md` |
| **E\*** 体验方案 | user-review 的心智乱/Demo 感/死按钮/脏列表/文案 | **`experience-design.md`（必建）** |

用户纠正：**「不仅仅是 bug，体验问题也要设计方案进版本」** → 缺 `experience-design.md` = 切版未完成。

### 3.2 迭代 Spec 最小清单

```text
VERSION.md · context.md · problem-map.md（验收 SC→D/E）
experience-design.md     ← 体验目标态（原则/信息架构/CTA/空态/文案）
scope.md · clarify.md · requirements.md · design.md
scenario-spec.md         ← SC-R* 回归 Fail + SC-U* 体验
tasks.md · test-plan.md · validation.md
```

### 3.3 与并行 Spec

撞文件时：**remediation 优先于** 未关的迁入/增强 Spec（在 scope 写明）；acceptance Spec 转为输入、不关产品版。

---

## 4. 轨工单交接（阶段 0 · 消灭人肉搬提示词）

### 4.0 合同（IRON）

换轨时 **真源在盘上**，聊天只给一行指针。禁止把整段 §4/§4.1 正文只留在聊天里。

| 项 | 必须 |
|----|------|
| **路径** | `docs/specs/<mount-id>/.next-rail.md`，`<mount-id>` = **下一对话要挂载的 Spec** |
| **写时机** | 验收总评不 OK / 需改实现或合同；remediation Phase 或关版收束；验收上下文将满需续跑 |
| **聊天产出** | **仅**一行指针（可附范围标签），**不要**再贴整份开工词 |
| **新对话第一句** | 用户粘贴该行，或 `@` 该文件并说「执行」 |
| **禁止** | 验收会话热修；本阶段 **禁止** 自动 `agent -p` / Shell spawn 开修（调度器另议，不在阶段 0） |
| **消费后** | 下一轨 Agent 开工读完后：更新 handoff「下一步」；工单过时可删或改名为 `.next-rail.done.md`（可选，不强制） |

**一行指针模板（聊天必贴）：**

```text
下一轨 → 新对话粘这一行：
执行 docs/specs/<mount-id>/.next-rail.md
```

### 4.1 修复轨工单（模板 · 验收收束必写）

总评不 OK，或存在需改实现/合同的 Fail → **必须**写入  
`docs/specs/<remediation-id>/.next-rail.md`（可与开 remediation Spec 同轮），聊天只出 §4.0 一行指针：

```markdown
# rail: remediation
# task: <产品> 验收修复迭代（编码 + 定向验证）

## 挂载 Spec
docs/specs/<remediation-id>/
读序：VERSION → context → problem-map → experience-design → scope → clarify → requirements → design → scenario-spec → tasks（从 R1）

只读输入：docs/specs/<acceptance-id>/ux-test-results.md · user-review.md
设计真源：docs/product/modules/<slug>/（禁止串台）

## 铁律
- Plan Approval 后再改代码
- 本对话 = remediation 轨；禁止当验收会话热修
- claim 本 Spec；Browser + 设计规定的生效通道；禁止假 Pass
- 体验 E* 与缺陷 D* 同等交付
- 本 Phase/关版收束时必须写再测轨工单（见 §4.2）+ 一行指针

## 优先 Phase
（从 tasks.md R1 抄 3–5 条）

## 环境
（URL / 验证命令 / 账号注意）

## 开工
1. 读本文件 + Spec + git status
2. 聊天给出本 Phase 计划
3. 等批准后编码；子集验证写 evidence
```

### 4.2 再测轨工单（模板 · remediation 收束必写）

本 Phase 或 remediation 关版条件达到 → **必须**写入  
`docs/specs/<acceptance-id>/.next-rail.md`（或 remediation 内若回归节挂在本版，则写该版路径），聊天只出 §4.0 一行指针：

```markdown
# rail: retest
# task: <产品> 修复后回归验收（只测不改）

## 挂载 Spec
docs/specs/<acceptance-id>/   # 或本 remediation 的 scenario-spec 回归节
轨：验收（禁改合同/实现）

## 必跑
- 原 Fail / Partial：<列 SC-id>
- SC-R* / SC-U*：（从 remediation scenario-spec 抄）
- 写入：ux-test-results.md · evidence/ · 范围标签 [验收·矩阵 k/n·…]

## 铁律
- 只记证据；Fail → 新问题进表，不热修
- 矩阵连续性：每轮 [验收·矩阵 k/n·下一 SC-x]
- 不 OK → 再开/更新 remediation + 写 §4.1 修复轨工单

## 环境
（URL / 账号 / 与修复对话的 diff 边界）
```

### 4.3 验收续跑工单（可选 · 上下文将满）

仍属验收轨。写入当前 acceptance Spec 的 `.next-rail.md`：

```markdown
# rail: acceptance-continue
# task: <产品> 验收矩阵续跑（只测不改）

## 挂载 Spec
docs/specs/<acceptance-id>/
轨：验收（禁改合同/实现）

## 进度
- 已终态：k/n
- 下一 SC：SC-x
- 检查点：ux-test-results.md · evidence/

## 铁律
- 继续跑或标 Blocked+原因；禁止热修
```

---

## 5. Agent 自检清单

验收会话（每轮 / 收束）：

- [ ] 本会话是否改过实现/合同？（是 → 违规，应换轨）
- [ ] 结尾是否有 `[验收·矩阵 k/n·下一 SC-x]`（或已收束总评）？
- [ ] 矩阵未完时是否在继续跑下一 SC（而非停等用户）？
- [ ] 「验收完成」是否只表示矩阵终态齐全（含 Blocked+原因），而非全部 Pass？
- [ ] 阻塞项是否均已标 **Blocked** 并写原因？
- [ ] Fail 是否都有用户可感知说明 + 证据路径？
- [ ] 不 OK / 有 Fail 需修 → 是否已开或更新 remediation（含 experience-design）？
- [ ] 是否**已写入** `docs/specs/<remediation-id>/.next-rail.md` 且聊天**只有**一行指针？（不是「若用户要」；不是只贴大段）

编码会话（remediation 收束）：

- [ ] 是否只挂 remediation（非验收轨热修）？
- [ ] 报完成是否带 `[remediation·Phase/SC·Delivery Target]`？
- [ ] 改 UI/文案是否对照 experience-design，而非只修 API？
- [ ] 是否**已写入**再测 `.next-rail.md` 且聊天只有一行指针？
- [ ] 回归 SC 列表是否写入再测工单（原 Fail + SC-U*）？
