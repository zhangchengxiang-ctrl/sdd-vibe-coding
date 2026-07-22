# 角色轨（Intake · Owner · Build）

> 挂在 `vibe-coding` 下。把「听用户 / 排期 / 落地」解耦成三条互不越权的轨。  
> 换轨交接仍用 [`acceptance-to-remediation`](./acceptance-to-remediation.md) §4 的 **`.next-rail.md` + 一行指针**（阶段 0）；本文件不引入自动 spawn。

---

## 0. 为什么拆

同一会话既听愿望、又排期、又改代码 → 边聊边切版、边排边修、完成定义漂移。  
SDD 已有分层（`product/` · 需求池 · `specs/` · handoff）；本文件把 **谁可写什么** 钉成角色门禁。

```text
Intake  →  需求池 / 产品包草稿（只塑形，不开发）
Owner   →  优先级 · 切片 · 升格 Spec · handoff 排期
Build   →  挂载单一 Spec 编码验证（现有执行纪律）
```

**假解耦**：同一会话只换口吻 → 禁止。真解耦 = **不同开门意图 + 不同可写路径**（新对话或显式换轨工单）。

---

## 1. 开机分流（先判轨）

| 用户说法（例） | 轨 | 主读 | 可写 |
|----------------|----|------|------|
| 我希望… / 坏了 / 卡住 / 吐槽 / 能不能… / 故障 | **Intake** | 相关 modules、代码（只读探活） | `demand-pool` 条目；可选 modules 草稿 |
| **优化… / 改进体验 / 改顶栏·导航·入口 / 信息架构**（未说开始做） | **Intake→塑形** | 现 modules | DEM + `product-design-package`；**禁止**业务代码 |
| 排期 / 优先 / 这周做什么 / 需求池 / 缓做 / 不做 / 拍板切片 | **Owner** | `demand-pool` · gap-register · handoff · roadmap | 池状态/优先级；筹备中；升格 Spec；`.next-rail`→Build |
| 开始做 / 实现 / 挂 Spec X / 修 remediation / 跑验收矩阵 | **Build** | `specs/<id>/` | Spec 内工件 + 代码（按该 Spec 合同） |
| 设计 / 写方案 / 帮我想（成块能力） | **Intake→塑形** | 现 modules | `product-design-package` → modules；**仍不写 specs/** |

歧义时：**默认 Intake**（只沉淀，不开发）。用户明示「排期/优先」才进 Owner；明示「开始做 + Spec/切片已锁」才进 Build。

### 假 Build 信号（禁止当编码许可证）

| 信号 | 错误反应 | 正确反应 |
|------|----------|----------|
| 「优化下 X」 | 直接改业务源码树 | Intake Card + DEM；成块 → modules |
| 编号清单 `1、2、3、4` + 截图 | 「很明确，直接改」 | 清单 = Wish 明细；先 Shape / 产品包 |
| 「应该打开新页 / 去掉提示 / 挪到我的」 | 当 ticket 逐条改 UI | 体验/IA 决策写入 01/03；发布模型写入 02 |
| 已有产品包上的入口·导航·发布源变更 | silent hotfix | **增量改包**，等「开始做」再升格 |

**可逆 trivial 例外**（可直修、无需开包）：纯文案笔误、单点 CSS、已知 bug 且不改产品合同。触及导航结构、跨表面入口、发布/安装模型、角色可见性 → **不是** trivial。

---

## 2. Intake（用户 / 故障入口）

**代表**：提需求、报障、谈体验的人。  
**目标**：把口述变成池子里可排期的条目（或产品包草稿），**先不开发**。

### 必须

1. 复述 Problem Framing（谁 · 场景 · 现状痛点 · 期望办成什么）。  
2. 调查相关蓝图与代码，标「已知 / 假设 / 未知」。  
3. 写入仓内 **`docs/product/demand-pool.md`**（新建 `DEM-NNN`），或更新已有条目。  
4. 成块新能力且值得蓝图 → 可调用 `product-design-package` 开/改 modules（状态保持 `调研`/`设计稿`）。  
5. 收束给一屏 **Intake Card**（见下）+ 可选写 Owner 轨工单。

### 禁止

| 禁止 | 改做 |
|------|------|
| 新建或改 `docs/specs/` | 只写 demand-pool / modules |
| 改业务代码 / 发版 / reload | 证据用只读探活；实现留给 Build |
| 「清单够清楚」就动手改码 | 先 DEM +（成块）产品包；等 Owner/「开始做」 |
| 擅自定「本周做 / P0」当排期承诺 | 可**建议**优先级，判决归 Owner |
| Requirements Lock 后直接编码 | Lock 只表示「条目可交 Owner」；编码须 Owner 派工或用户在 Build 轨明示 |

### Intake Card（聊天）

```markdown
## Intake Card
- 问题：…
- 类型：wish | fault | ux | other
- 池条目：DEM-NNN（路径）
- 建议优先级：（仅建议）
- 非目标：…
- 未决（≤3）：…
- 下一轨：执行 docs/product/.next-rail.md   # 若需 Owner 审池
```

### Intake → Owner 工单

路径优先：`docs/product/.next-rail.md`（产品层共用指针；正文写清轨）。

```markdown
# rail: owner
# task: 审需求池 / 排期

## 必读
docs/product/demand-pool.md   # 焦点 DEM-NNN …
docs/product/gap-register.md  # 若相关
docs/reference/handoff.md     # WIP / 筹备中

## 铁律
- 本对话 = Owner；禁止编码
- 判决：做 / 缓 / 不做 / 需补 Intake
- 若「做」：定首切片 + Delivery Target；再升格 Spec 或写入手筹备中
```

---

## 3. Owner（产品负责人）

**代表**：对「做什么、何时做、做到什么算够」负责。  
**目标**：维持需求池与排期真实；决定升格与派工。

### 必须

1. 读 `demand-pool`（+ 必要时 gap-register / roadmap / handoff）。  
2. 给出优先级与切片判决；回写池条目状态。  
3. 「做」且方向已够 → Kickoff/Decision 后走现有 Wish Lock → `spec`（或挂已有 Spec tasks）；handoff 加行或改「下一步」。  
4. 「缓/不做」→ 池内写明理由与复审条件。  
5. 派 Build 时写 Spec 侧 `.next-rail.md` + 一行指针（禁止只贴长提示词）。

### 禁止

| 禁止 | 改做 |
|------|------|
| 在 Owner 会话写业务实现 | 开 Build 轨 / `.next-rail` |
| 跳过池子直接口头「顺便做了」 | 先改 DEM 状态再升格 |
| 把 gap-register 当用户吐槽池 | gap = 蓝图−现状；用户口述 → demand-pool |
| 验收矩阵里热修 | 验收/修复走 acceptance-to-remediation |

### Owner Card（聊天）

```markdown
## Owner Card
- 池焦点：DEM-NNN …
- 判决：做 | 缓 | 不做 | 退回 Intake
- 优先级 / 首切片 / Delivery Target：…
- Spec / 筹备：…（路径或「未切」）
- WIP 影响：…（对照 handoff 上限）
- 下一轨：执行 docs/specs/<id>/.next-rail.md   # 若派 Build
```

---

## 4. Build（落地）

**代表**：执行已锁定合同的工程会话（含验收、remediation、再测）。  
**纪律**：[`execution-discipline.md`](./execution-discipline.md) · 验收换轨见 [`acceptance-to-remediation.md`](./acceptance-to-remediation.md)。

### 必须

- 默认只挂 **一个** `specs/<id>/`；用户未指明则问 Owner/handoff，不为仪式乱开版。  
- 完成带范围标签；换轨写 `.next-rail.md`。

### 禁止

- 把 Build 会话扩成新愿望排期（新口述 → 记 DEM 或请开 Intake，不静默扩 Spec In）。  
- 无 Spec 的 non-trivial 新产品能力直接大改（先 Owner/升格）。

---

## 5. 三池分工（防串台）

| 池 | 路径 | 装什么 | 谁写 |
|----|------|--------|------|
| **需求池** | `docs/product/demand-pool.md` | 用户愿望、故障、体验吐槽、待排条目 | Intake 追加；Owner 改状态/优先级 |
| **差距账** | `docs/product/gap-register.md` | 蓝图 vs 现状的能力缺口（roadmap 驱动） | Owner/架构讨论；关闭走 gap-closed |
| **实施** | `docs/specs/<id>/` + handoff | 已切版合同与并行路由 | Owner 升格后；Build 执行 |

DEM 升格落地后：池内链到 Spec/GAP；关版后 DEM → `done`/`wontfix`，正文可短。

---

## 6. 与现有 Wish Intake 的关系

`vibe-coding` §0 的 Wish→Shape→Lock **仍然有效**，但按轨切开：

| 原步骤 | 默认轨 |
|--------|--------|
| Ground · Clarify · Shape（未锁实施） | **Intake**（可停在池/产品包） |
| Requirements Lock + Plan Approval + `spec` | **Owner**（或用户在 Owner 语境下确认） |
| Build & Show · Verify · 验收换轨 | **Build** |

用户说「我希望…」且**未**说开始做 → **停在 Intake**：写 DEM，不升格 Spec。  
用户说「开始做 / 按这个来」且切片已在池或 Kickoff 确认 → 视为 **Owner 判决已发生**（可同会话完成升格，然后 **新对话** Build；或写 `.next-rail` 再 Build）。

---

## 7. 自检（开口前）

- [ ] 本会话轨是 Intake / Owner / Build 哪一条？可写路径是否越权？  
- [ ] 用户口述是否已进 demand-pool（Intake）或仅停在聊天？  
- [ ] 排期/优先级是否只有 Owner 在改池状态？  
- [ ] 编码是否只在 Build 且已挂 Spec？  
- [ ] 换轨是否落了 `.next-rail.md` + 一行指针（而非只贴大段）？
