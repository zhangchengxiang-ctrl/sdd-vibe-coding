---
name: testing
description: >-
  面向略懂技术产品经理的 Verify 专项 Skill：按真实用户旅程执行 Spec / Version
  或 Production 验证；亦覆盖 UX 走查 / 体验审计。先用交付卡给出可否交付的中文结论、
  证据和限制，再维护工程证据链。仅在 vibe-coding 已路由到 Verify，或用户显式调用
  本 Skill 时使用；不修改实现。
---

# Testing：Verify 与证据

本 Skill 只运行在已确认的 Verify Rail，不修改业务代码。

## FIRST ACTION（有 UI / UX 走查 · 硬门）

命中 **验收 / UX 走查 / 体验审计 / 走查页面** 且涉及用户可见界面时，在开浏览器或写交付卡之前，
**工具调用顺序必须满足**：

1. Read 本文件（若尚未 Read）；  
2. Read [`ux-standards.md`](./references/ux-standards.md)；  
3. Read [`design-standards/product-judgment.md`](../vibe-coding/references/design-standards/product-judgment.md)；  
4. Read [`design-standards/LOAD-MAP.md`](../vibe-coding/references/design-standards/LOAD-MAP.md)（至少扫 Verify 行 + 本任务场景行）。  

未完成 2–4 → **禁止**宣称已按 design-standards 走查；发现项应尽量引用 `rule/*`（见 product-judgment）。  
UX 走查变体再读 [`ux-walkthrough.md`](./references/ux-walkthrough.md)（**不能**用它替代 2–4）。

然后：宿主 `AGENTS.md`、当前声明范围、
[`evidence-contract.md`](../vibe-coding/references/evidence-contract.md) 和适用
`tests.md` 用例。
有界面时按 Spec 的 `UI surface`/`page_kind` 继续 LOAD-MAP 场景册；
遵守 [有界验收](./references/bounded-verify.md)、
[证伪清单](./references/falsify-checklist.md)（**先证伪再 Pass**）与
[验证环](../vibe-coding/references/verification-loop.md)（Floor≠关版；禁甩用户发现）；
UI / 浏览器真实通道再读
[浏览器验证](./references/browser-verify.md)；意见格式可参考
[critique-format](../design/references/critique-format.md)。
命中**整体验收 / 多 Spec 系列 / 多角色多表面 material** → 先读并落盘
[Version Acceptance 矩阵](./references/version-acceptance-matrix.md)，**禁止**用单 Spec Build Pass 冒充系列 Pass。
UI 回归定位可指向 [debug-playbook](../vibe-coding/references/design-standards/debug-playbook.md)（仍不改码）。

## 先声明验收层次

| 层次 | 要回答的问题 | 证据来源 |
|---|---|---|
| Build Validation | 当前 Spec 的实现与集成是否按合同完成？ | 本 Spec 实现与集成证据 |
| Version Acceptance | 当前版本是否满足产品结果？ | 整版产品结果证据 |
| Production Verification | 目标版本是否在**目标环境**真实生效（含产品冒烟）？ | 目标环境冒烟与观察（= 发布生命周期 P6） |

层次与证据对齐后再提高声明；细则见 `evidence-contract.md` 交付条件。  
用户要**整次上线**（方案+执行+关版）→ Skill [`deploy`](../deploy/SKILL.md)；本 Skill 可只跑 P6 核对。

## 执行

1. 固定环境、版本、角色、数据和声明范围；
2. 建立 Requirement → Test → Implementation → Evidence 追踪；
3. 从宿主 `AGENTS.md` 取得真实命令、URL、账号和工具；有可复用测试凭据时自行切换角色/账号
   继续跑矩阵（个人账号 / OAuth / 生产密钥 → `Blocked` / `needs-authorization`）；
4. **先跑证伪**（[falsify-checklist](./references/falsify-checklist.md)）：数据面至少做分页/排序/筛选的两态对比；失败直接 Fail；
5. 按触及面勾选验证层（见 [verification-loop](../vibe-coding/references/verification-loop.md)）；
   **Floor 入场 ≠ 关版**；走查变体按 [ux-walkthrough](./references/ux-walkthrough.md)
   扩检查面，仍记录 `Pass | Fail | Blocked`；
6. 单 Spec：按 `tests.md` 执行；系列/整体验收：按
   [version-acceptance-matrix](./references/version-acceptance-matrix.md) 执行矩阵 P0；
7. 记录命令、时间、环境、版本、观察值；Evidence 写 `kind=… · 路径`（见 evidence-contract §1.1）；
8. 对全部 Fail 统一归因、聚类并形成一份 Repair 方案；Verify 只读实现；
9. 给出实际 Delivery Target、下一 Rail 建议和阶段总结，并等待用户批准后才转换。

UI/人工 Test 至少需要一次真实通道 V2（见 [browser-verify](./references/browser-verify.md)）。  
**硬门：** Oracle 保持在 `tests.md`（或系列矩阵真源）；观察结果只写 `run.md`。  
**硬门：** API/DOM/Toast/`/health`/window-smoke/脚本旁路单独不构成 Job 通过。  
**硬门：** 同会话 Build 冒烟结果不得原样誊为 Verify Pass。  
**硬门：** 暖缓存/HIT 结果不得冒充用户冷路径 Pass。  
**硬门：** 授权/配置类须消费侧 Before→After；管理面「已生效」单独不够。  
**硬门（钉 3）：** Verify / 系列验收默认在本轨（Cursor/指挥侧）执行；**禁止**派 Codex 做主验收或「验到可交付」。Codex 最多生成矩阵草稿，或 ≤20min、完成条件=指定命令 stdout 的窄派单。  
**硬门（钉 1）：** 宣称 `可交付` / `acceptance-passed` 前必须 `make verify-deliver HOST=<repo> SPEC=<id>` exit 0，且 `run.md` 有 `verify-deliver: ok · <时间>`。

## 用户前台输出

验收结果先输出“交付结果”，再按需展开工程矩阵。交付卡包含：

- **结论**：可交付、不可交付或受阻，并用一句话说明原因；
- **如何体验**：环境、入口、适用角色和代表性数据（**说明用**，不是派用户去发现故障）；
- **已验证的用户结果**：每项写**操作 → 两态观察差 → 证据**；无两态差不得写「已通过」；
- **未通过或无法验证**：写用户影响、严重度和原因，不能只写内部分类；
- **已知限制**：包括未覆盖内容；
- **上线状态**：未上线、已上线、未知或不适用；
- **探活执行者**：`agent`（默认）或 `blocked-needs-auth`；
- **需要用户做什么**：默认 **`无需动作`**；仅允许：批准下一轨 / Repair、真人 SSO/个人 OAuth、生产密钥；

聊天前台默认不显示 Requirement、Test、Oracle、V0–V3、Rail、Delivery Target、
Matrix、commit、Workspace 等工程术语。正式报告仍保存完整工程证据；用户明确要求或走查变体
需要分级发现时，在交付卡之后展开“技术详情（可选）”或 P0/P1/P2 列表。  
若确有待决，交付卡后可单列一句「下一步」——**禁止**把可自跑的打开/硬刷/确认是否正常写成下一步。

**话术硬门：** Build 结束只说「实现完成」；「可交付」仅在本轨证伪通过后使用。  
**话术硬门：** 禁止「有条件可交付」掩盖未证 P0；未证 = Fail 或 Blocked。  
**关版硬门：** 对用户说可交付前跑通：`make verify-deliver HOST=<repo> SPEC=<id>`（写入 `verify-deliver: ok · <时间>`；缺戳则 `check_spec` fail）。

## Fail 路由

分类与下一 Rail 以 [`evidence-contract.md`](../vibe-coding/references/evidence-contract.md)
§5 为唯一真源；本 Skill 不另维护表。

全部适用 Test 有结果后，再设计并执行统一 Repair。

## 声明

所有适用 Test 有终态 → `matrix-accounted`；关版条件全部满足 → `acceptance-passed`
（二者都不是 Delivery Target，见 workflow-contract「状态词汇」）。
正式结果写入当前 Spec 的 `run.md`（结构见 scaffold 模板；说明见
[Validation Report](./references/validation-report.md)），同时写通过证据、失败、
Blocked、未覆盖项和限制。报告先写 PM 验收摘要（关版结论），再写工程矩阵。

长期产品回归（可选）合同见
[product-regression](./references/product-regression.md)；启用后维护
`docs/product/regression-register.md`。
