---
name: spec
description: >-
  SDD Plan 专项：已确认产品切片 → Spec 执行合同、tests.md、实施方案。
  仅在 vibe-coding 已路由到 Plan，或用户显式 @spec /「切 Spec」时使用；
  写完 Given/When/Then 才可请求 Build。禁止把普通「做个计划」当触发。
disable-model-invocation: true
---

# Spec：Plan 技术方案

只在 Plan 模式使用。先读宿主 `AGENTS.md`、[`explore-deliver.md`](../vibe-coding/references/explore-deliver.md)（Deliver）、已确认产品真源、`workflow-contract.md`（含
**薄提示词原则**、**证据分级**、**施工通道**、**Plan 落盘授权**）、`workspace-contract.md`
与 `evidence-contract.md`，以及
[`design-standards/system-architecture.md`](../vibe-coding/references/design-standards/system-architecture.md)
（有 UI 时先读 [`LOAD-MAP.md`](../vibe-coding/references/design-standards/LOAD-MAP.md)；
合同字段强度只认该表；改存量注明 `change: refinement|redesign`）。
新建 Spec 与跨阶段批准以
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 硬闸与阶段闸门为准。

## 默认质量条

进入 Plan 后自动执行：

1. 先查真实代码 / Schema / 配置，再写 Requirement；
2. 按真实入口**纵向**切片；
3. 仅 `Verified` 进 P0 / Lock / 实施阻断；
4. `tests.md` 每个 P0 至少 1 success + 1 failure/permission，完整 Given/When/Then；
5. 本阶段只落盘 Spec（不改业务代码）；
6. 用户已说切 Spec/Plan，**或**许愿路径下方案已确认 → **直接写入** `docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/`（Spec 是版本拆出的工作包；还没有版本就先按 `templates/docs/iterations/_template/` 建一个，只有一个 Spec 也一样；不要再建 `docs/specs/<id>/`）。切之前读该版本的 `quote.md`、`requirements.md`、`decisions.md`：`requirements.md` 的待裁定项未在 `decisions.md` 有结论时不切；
7. 齐套后：许愿路径 → 直接进入 Build 编排；经典路径 → 批准卡（可附 Build 提示词）；
8. **骨架**：落盘 `VERSION` / `contract` / `tests` / `plan` / `run`；
9. **架构与设计边界轻门**：触及新入口 / 跨层 / 新存储 / 新权限模型 / 新部署单元时，
   `plan.md` 按 `system-architecture.md` §7 写明沿用或新开边界、C4 层级、ADR、Unverified；
   有 UI 时按 LOAD-MAP 字段门控补 Job Brief / `UI surface` / Design Read / `page_kind|motif` / `anchor` 等。齐套后再请求 Build。
10. **Infra 机制特别指引（当用户提出 kill/timeout/RG/cancel/query gateway/中止 等机制设计）**：
   - 套用 [`infra-mechanism-brief.md`](./references/infra-mechanism-brief.md) 的 Required 字段与 tests.md 断言建议，把“成功语义/失败语义/传播边界/幂等性”写进 contract/tests。
   - 在 contract/plan/tests 任一处包含 `ux: n/a` 或 `无 UI`，避免 `check_spec.py` 把 infra 误判成 UI（从而要求 UI 字段门控）。
   - P0 Oracle 默认使用 `unit` / `machine` 两态可机检脚本；不要在验收/证据内容里写“请人点验/请你自验”。
11. **机检**：宣称 Plan 可实施或派 Build 前，运行
    `python3 <plugin>/skills/spec/scripts/check_spec.py <host> <spec-id>`
   （见 [`scripts/check_spec.py`](./scripts/check_spec.py)）。通过后：eligible 切片才派 Codex，否则指挥侧实现。

## 核心工件

```text
docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/      # 模板：docs/specs/_template/
├── VERSION.md
├── contract.md   # 目标、事实映射、Requirements、In/Out
├── tests.md      # TDD 测试合同：索引 + Given/When/Then
├── plan.md       # 方案差量、纵向切片、单向门、Workspace
└── run.md        # 运行态（Plan 只初始化静态头）
```

`contract.md` 定义做什么；`tests.md` 定义如何判定做对（完整可执行用例）；
`plan.md` 定义怎么做与隔离边界；`run.md` 是 Build/Verify/Repair 的唯一运行态。

`run.md` 由 scaffold 随模板复制。Plan 只初始化其状态头（若需要）；批次结果、追踪矩阵、
Fail/Repair、关版结论由 Build/Verify 填写。

## 事实映射门（Plan 硬前置）

在写 Requirement / plan 硬合同之前，在 `contract.md` 填完**入口事实映射**：

| 入口 | actor | 业务实体 / 表关系（含 FK） | 可信路径如何派生 | 代码调用点 | 越权反例 | 证据级 |
|---|---|---|---|---|---|---|
| … | … | … | … | … | … | Verified / Unverified |

规则：

1. 表关系与调用点填完后再设计抽象；
2. 仅 `Verified` 进入 P0 Requirement、Requirements Lock、实施阻断、DDL 条件；
3. `Unverified` 列在「待验证」；调查升级为 Verified，或明确降级为非阻断假设；
4. 「字段存了绝对路径」时，先验证能否用业务 ID / owner 关系重解析；
5. 宣称「可以实施」时，每个 In-scope 入口具备：输入 → 实体解析 → 授权 → canonical path → 操作 → 越权拒绝的证据链（或明确标 Unverified 且不进硬闸）。

## 测试合同门（TDD · Plan 硬闸）

在宣称 Plan 可实施 / 请求进入 Build 之前，`tests.md` 满足：

1. 每个 P0 Requirement 至少映射 **1 条 success + 1 条 failure/permission**（`T-xxx`）；
2. 每条用例含完整 **Given / When / Then（Oracle）**；Then 为可观察断言；
3. **Oracle 强度**：禁止弱 Then 独撑（见 [oracle-strength.md](./references/oracle-strength.md)）；
4. **数据面**（list/dashboard 或分页/排序/筛选）：Then 须含可两态证伪的断言（同文件）；
5. 层（V0–V3）与 Channel 已声明；自动化路径或 `manual-only` + 原因已写明；预期 Evidence Kind 建议写清；
6. 上述齐套后再进入 Build。

预期写在 `tests.md`；结果只写 `run.md`。Oracle 保持不变。
Verify 执行证伪见 testing [`falsify-checklist.md`](../testing/references/falsify-checklist.md)。

## 纵向切片

默认拆分单位是**纵向切片**（完成单元；服务质量，非 IDE hack）：

```text
真实入口 → 按关系解析实体与 owner → 可信路径 → 执行操作 → 验证成功与越权失败
```

| 正确切片轴 | 例 |
|---|---|
| 按真实用户入口 | Web 文件、Detached Job、Feishu、worktree、扩展包 |
| 先落地入口，重复后再抽 helper | 多切片重复同一逻辑后，再抽取共享 helper |
| 完成定义链到可运行 Oracle | 每个切片链到一小撮可一次跑完的 `T-xxx` |

**尺寸软约束：**

- 一切片 = 一条主用户旅程 + 其失败/越权路径；禁止把无关入口捆成一片。  
- 单 Spec 切片过多（经验：难以在一次研发编排中稳定收口）→ **拆成多 Spec**，产品包 `05`/`06` 串联关版。  
- 墙钟内无行为证据 → 回 Plan 再切，禁止硬撑。

### 切分互斥与并行

纵向切片定**验收边界**；能否并行、能否一次派给 Codex，由**触及路径**决定。

| 规则 | 内容 |
|---|---|
| 边界 | 一个 Spec 对应一个可度量结果，含 2～4 个切片，超过则拆 Spec。**可独立开关 / 独立回滚的行为也是合法的拆 Spec 理由** |
| 声明 | `plan.md` 切片表的 `触及路径` 必填，写 `文件` 或 `文件::符号`，不写目录 |
| 并行判据 | 两个单元仅当触及路径不相交、且不共享迁移 / 公共 API / 生成物，才可同时派发。相交 = 同文件且任一方未写符号，或写了同一符号 |
| 读方 | 改共享数据形状（labels 键、API 字段、事件、表列）时，把仓内所有读方列入触及路径，或由前序切片先改。推荐：依赖未满足时，依赖方的 Oracle 必须为红 |
| 合并与下限 | 同文件且必须串行的切片合并为一片（除非 Oracle 需独立冻结）；目标约 50～200 行、1～3 个源文件；低于约 50 行不建议单独派发，可 `executor: conductor` 合并执行并写明理由 |
| 热点 | 同一文件在一个迭代内被 ≥ 3 个切片修改：进同一串行车道，或先开拆文件的前置 Spec |
| 迭代矩阵 | 同一版本的多个 Spec（即该版本目录下的全部 Spec），在版本 README 里放并行矩阵（见 `templates/docs/iterations/README.md`）；`check_spec` 按目录判同版本并检查触及路径重叠 |

阈值（50 / 200 行、1～3 文件）是起点，来自有限样本，以真实使用校准。

数据库迁移仅在某个切片 **Verified** 证明现有关联无法唯一解析时才出现。

纵向切片既是验收单元，也是 Codex 一次 exec 的范围（A == D）。按用户入口切，**禁止**按 Codex 回合手切。

## Plan 流程

Plan 是一次连续动作：在同一阶段内一口气产出整份 Spec 的全部设计工件。按以下顺序连续完成，把结论直接写入对应文件：

1. **入口事实映射**（写入 `contract.md`；齐后再写硬合同）；
2. 对照代码与宿主事实确认现状（补全 `contract.md`）；
3. 建立 Requirement → Test 映射（`contract.md` Requirements + `tests.md` 完整用例）；每条 P0
   标注证据级，并满足测试合同门；
4. 按纵向切片形成最小技术方案与执行顺序（`plan.md`；切片完成定义链 `T-xxx`）；
5. 填写「架构与设计边界」（`plan.md`；对照 design-standards 与 AGENTS / `docs/architecture/`）；
6. 写清单向门、外部依赖、授权、回滚与**仅 Verified** 的真实 Blocker（`plan.md`）；
7. 为整个 Spec 选择 Workspace、owner、外部 Claim 和集成重测（Workspace Strategy 槽位）；
8. 初始化 `run.md` 状态头，并结构自检。

一次产出：`VERSION.md`、`contract.md`、`tests.md`、`plan.md`，以及 `run.md` 的静态头
（按需 `optional/`）。调查结论边查边写进文件。

阶段内暂停仅限：产品互斥选择、不可逆授权、真实外部阻塞。

可实施条件：有独立事实复核；`tests.md` 含 Given/When/Then 正文；质量条与 `check_spec` 已过。

## 机检（check_spec）

```bash
python3 skills/spec/scripts/check_spec.py <host> <spec-id>
# 或：bash skills/spec/scripts/check_spec.sh <host> <spec-id>
# 全部非模板 Spec：… --all
# 仅 AGENTS 就绪度警告：… --agents-only
```

校验：核心五件套、骨架文件名、事实映射列与填充、P0↔tests、Given/When/Then 正文、
弱 Oracle / 数据面证伪断言、`plan.md` 架构与设计边界、`run.md` 诚实性
（acceptance/可交付 vs Fail/Blocked；Pass 禁纯 smoke Evidence）、
可选 AGENTS 空槽 WARN。清单真源：
[`design-standards/*.checklist.json`](../vibe-coding/references/design-standards/)。
Oracle 强度说明：[oracle-strength.md](./references/oracle-strength.md)。

阶段边界语义以 [`workflow-contract.md`](../vibe-coding/references/workflow-contract.md) 为唯一真源。
Plan 阶段全部工件**已落盘**后：

- **许愿路径**（方案已确认 / 自动编排）：`check_spec` 通过后**直接**进入 Build 完成单元，前台短报进展；不必等人粘贴提示词。  
- **经典路径**：用一张卡汇总技术方案、纵向切片、测试合同、执行边界、风险和未决项；卡尾**可**附「新对话 Build 提示词」，同聊「批准 Build / 开始做」仍有效。
