# Rails（Build / Verify / Repair 清单）

> 进该轨才读。闸门 → [`gates.md`](./gates.md)；状态词 → [`states.md`](./states.md)。

## Build

- 覆盖当前 D 内 A 切片的入口、数据流、错误语义；先按事实映射核对
- 未点名切片：取打包后第一个未完成 D；「整份 Spec」→ 按 edit-wave 推进（每 D 仍须装进 272K）
- 新建 / 大改用户可见页面：先读 [LOAD-MAP](./design-standards/LOAD-MAP.md) + [product-judgment](./design-standards/product-judgment.md)
- 完成实现后冻结代码，跑完整单元测试批次；记录失败后统一 Repair
- 有自动化 → 先红后绿；红/绿写入 `run.md`「红绿证据」；Polish/trivial/无自动化写 `N/A`
- **硬门：** 只可报「实现完成」；禁止宣称「可交付」/ `acceptance-passed` 
- **声明派生：** 「实现完成」→ eligible：`dispatch-run-id:`；ineligible：`executor: conductor`；人强制自写：`override: 用户要求自写` / `polish · 用户本轮明示`；`acceptance-passed` → `make verify-deliver`（`check_spec --closing`）
- **硬门：** 禁止 Deploy P5/P6 或读写生产；须路由 Skill `deploy` + 本轮 P4
- **硬门（钉 2 · Oracle 冻结）：** 禁止改 `tests.md` 与产品包验收矩阵；`run.md` 须有 `oracle-freeze: intact`

## Verify

- 不改实现；先按 testing [`falsify-checklist`](../../testing/references/falsify-checklist.md) 证伪，再跑集成/场景/E2E
- **必须**产出 [`human-acceptance-pack`](../../testing/references/human-acceptance-pack.md)
- Evidence 写 `kind=`（evidence-contract）；工程 Pass 禁止仅 window-smoke / health
- 同会话不得把 Build 冒烟原样誊为 Verify Pass
- 结束信号与三钉：[`verification-loop.md`](./verification-loop.md)
- **关版分叉：** 无 UI 可机跑 → falsify + `verify-deliver` 后 `acceptance-passed`；有 UI → `awaiting-human-acceptance`，无人明示前禁止关版
- **钉 1：** 宣称 `acceptance-passed` / 可交付前须 `make verify-deliver`（`check_spec --closing`）exit 0
- **钉 3：** Verify 默认指挥侧执行；禁止派 Codex 做主验收
- 系列/多角色：[`version-acceptance-matrix.md`](../../testing/references/version-acceptance-matrix.md)

## Repair

- 只按已记录的统一 Repair 方案修改；新根因补入同一方案
- 修复后重跑完整单元与 Verify 批次
- **同钉 2：** 禁改 `tests.md` / 验收矩阵 Oracle

## Plan 落盘授权

下列任一 = 已批准进入 Plan，并在所属版本目录下写入 `docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/`（没有版本先建版本：原话 → 需求 → 裁定）：

- 切 Spec / 走 Plan / 拆解实施 / 做到可以编码 / 按产品设计切版 / 重切 Spec
- 就按这个做 / 确认方案 / 按这个方案做（许愿：确认后直接落盘并继续编排）
- 明确提出 infra/平台机制设计（kill/timeout/取消传播/RG/resource group/capacity/cancel/query gateway/中止 等）且任务本质是“可机检的机制与失败语义”（contract/tests 里写清 success 与 failure/permission 对应 T-xxx）：允许直接落盘 Plan 五件套，不要求先经历“确认方案”。

许愿路径：`check_spec` 通过后直接 Build 编排；经典路径：结束时出进入 Build 的批准卡。
