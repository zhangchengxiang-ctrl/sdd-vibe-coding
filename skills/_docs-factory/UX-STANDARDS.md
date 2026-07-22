# UX Standards — Docs Factory（跨仓真源）

> **本文件是 Spec skill 体系的 UX 验收标准正文。**  
> 归属：`_docs-factory`（与 `CONVENTIONS` · `VALIDATION-REPORT` · `HANDOFF` 同级）。  
> **不是**个人附加 skill 的可选补丁。
>
> **Pass = 指定用户在真实情境下能有效、高效、满意地完成目标。**  
> 有控件 / Toast / API 200 / 空态文案 / 过滤噪音 **单独均不算 Pass。**

| 工件 | 角色 |
|------|------|
| **本文** `_docs-factory/UX-STANDARDS.md` | 定义 · ISO · Nielsen · 关版铁律 · 反模式（**标准正文**） |
| `docs/specs/<id>/ux-standards.md` | 本版 **Jobs + 通道约束**（切版时按触发表必建）；须声明服从本文 |
| `ux-test-results.md` | 实测账本（Jobs + H# findings） |
| `ux-walkthrough-skill` | 走查**步骤**；打分服从本文 + Spec Jobs |
| 个人 skill `ux-standards` | **别名入口** → 指向本文；正文不作第二份真源 |

触发表 → skill `spec`。收尾诚实度 → skill `testing`。主入口 → `vibe-coding`。

---

## 1. UX 是什么（NN/g · Don Norman）

来源：<https://www.nngroup.com/articles/definition-user-experience/>

1. **UX** 涵盖终端用户与公司、服务、产品的**全部交互**，不只是界面。  
2. 优秀体验第一要求：**准确满足需求，且不折腾**。  
3. **真·UX 远超** checklist 功能堆砌。  
4. **UX ≠ UI**。  
5. **UX ⊃ Usability**。

**禁止声称 UX / 体验完成**的情形：

- 仅证明工程回归 / scenario 窄 THEN / Toast 出现  
- 用户仍须靠 UUID、内部状态码、黑话才能办成事  
- 「有入口」但内容不足以达成目标  

---

## 2. 可用性度量（ISO 9241）

| 维度 | 含义 | 测法直觉 |
|------|------|----------|
| **Effectiveness 有效性** | 能否真完成目标 | 任务成功 / 失败，禁止代理指标冒充 |
| **Efficiency 效率** | 时间、步骤、认知成本 | 是否被迫抄 ID、来回猜导航 |
| **Satisfaction 满意度** | 是否顺、是否愿意再来 | 走查主观 + 人话障碍计数 |

人本设计（ISO 9241-210）要点：用户需求驱动评估 → 迭代 → **whole user experience**。

---

## 3. 十条可用性启发式（Jakob Nielsen / NN/g）

来源：<https://www.nngroup.com/articles/ten-usability-heuristics/>  
严重度：0 不是问题 · 1 妆容 · 2 小 · 3 重要 · **4 灾难（阻断核心 Job → Job Fail）**。

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

---

## 4. Spec 强制测法（切版/验收 IRON）

### 4.1 何时必建 `docs/specs/<id>/ux-standards.md`

满足任一即**必建**（缺则切版未完成 / 禁止关版）：

- 非 trivial 且含用户可感知 UI / 手动 `TEST_TYPE: manual` SC  
- 验收类 Spec（`*-acceptance` / `ux-test-*`）  
- 模式 D 迭代 Spec（含 `experience-design.md`）  
- `scenario-spec` / `user-review` 要以「办成事」判决  

不适用：纯后端无 UI、纯文档、纯 CI 配置（validation 写 **UX: N/A** + 理由）。

### 4.2 Spec 文件最低内容

1. 文首声明：**服从** `_docs-factory/UX-STANDARDS.md`（本工厂）  
2. **Jobs 表**（谁 × 情境 × 目标）；与 `ux-test-results` 对齐  
3. 本仓通道约束（例：禁某对话路径顶替安装证明）  
4. 链接：`ux-test-results.md` ·（若有）`experience-design.md`

正文 §1–§3 与 §5 **不要**在 Spec 再造一份冲突稿——引用本文即可；若复制须保持与工厂一致。

### 4.3 开测 / 关版

1. 写清 Jobs → Browser（或仓内约定通道）按 Job 走  
2. 用 §3 打分；**H=4 落在核心 Job → Job = Fail**  
3. 账本写 `ux-test-results.md`（Jobs 有效性 + findings，**禁止**仅用 SC Pass 数关版）  
4. 关版前：`validation.md` 勾选 —— 核心 Job Effective；无开放严重度 4（或产品人书面例外）

Holdout / `testing` 走查输入：`scenario-spec` + `requirements` + **本 Spec `ux-standards.md` Jobs** + 工厂本文定义。

---

## 5. 反模式（Agent 红线）

| 反模式 | 正确做法 |
|--------|----------|
| Toast / 「已安装」文案 → Pass | 用户是否达成 Job？ |
| API 200 → Pass | 发现面用户是否认得出变化？ |
| 过滤 e2e → 「质感 Pass」 | 条目是否可逛、够决策？ |
| 队列有按钮 → 治理 Pass | 能否凭**识别**而非回忆评审？ |
| 旁路脚本顶替主通道 → Pass | 目标产品路径是否真走通？ |
| 个人 skill 正文覆盖 Spec/工厂 | **禁止**；标准只在工厂 + Spec Jobs |

---

## 参考链接

- https://www.nngroup.com/articles/definition-user-experience/  
- https://www.nngroup.com/articles/ten-usability-heuristics/  
- https://www.iso.org/standard/77520.html  
