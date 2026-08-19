# Gates（常驻）

> 写码授权 · 人闸 · 施工通道 · 许愿自动编排。**唯一常驻合同。**  
> 状态词 → [`states.md`](./states.md)；Build/Verify/Repair 清单 → [`rails.md`](./rails.md)。  
> A == D:一个纵向切片（Skill `spec`）= 一次 Codex exec。依赖与编辑锁决定波次，不再按估算的 token 峰值打包。

## 人闸（质量两钉 + 生产另钉）

| 闸 | 人做什么 | 未过之前禁止 |
|----|----------|--------------|
| **方案闸** | 确认产品方案（「就按这个做 / 确认方案 / 按这个方案做」等） | 改业务代码、落实施 Spec（已有已确认 Spec 的 Repair、或 Polish (c) 除外） |
| **验收闸** | 有 UI：按[人类验收包](../../testing/references/human-acceptance-pack.md)点验；无 UI 可机跑：证据卡 | 有 UI 时宣称 `acceptance-passed` 前须人明示；无 UI 仍须 `verify-deliver` |
| **Deploy P4** | 本轮明示「发布 / 上线 / 部署」并批准 P2+P3 后的执行 | 任何生产发布、reload、改 live（关版**不**自动授权） |

## 写码授权 (a)(b)(c)

改业务代码前须至少一项：

| # | 条件 |
|---|---|
| **(a)** | 已确认实施 Spec：`docs/specs/<id>/`（含 Verify 后 Repair） |
| **(b)** | 本轮明确指令做具体事（开始做 / 实现 / 修复 / 确认方案 / 就按这个做…），范围可辨 |
| **(c)** | 本轮明示 Polish（polish / 抛光 / 前端小改 / 按 refinement 修），且 **非 material** |

皆无 → 只写 `docs/product/` + 只读调查。  
愿望/探讨（「我希望」「聊聊」「设计方案」「优化体验」）≠ 授权。  
(b)「确认方案」= 方案闸通过 → 自动编排；**≠** Deploy。  
谁动手仍按下方「施工通道」。material / Polish 细则：[`change-control.md`](./design-standards/change-control.md)。

## 施工通道（谁动手）

先判切片是否 **Codex eligible**（真源 [`codex-boundary.md`](../../dispatch-codex/references/codex-boundary.md)）。越界 **禁止派 Codex**（含用户口头「派 Codex」）。

| 宿主 / 判定 | 施工方式 |
|---|---|
| Cursor / Claude · **eligible** Build/Repair 单切片 | 派发：`codex-dispatch.sh --unit build` / `wish-orchestrate.sh`；一聊一个 edit-wave |
| Cursor / Claude · **ineligible** / Plan / Shape / Verify | **指挥侧自做**；`run.md` 写 `executor: conductor` |
| Codex 会话 | 仅实现当前 **eligible** 切片；一次 exec = 一个切片（A == D；禁止 compact 续跑） |
| **禁用** | `--unit plan`；Codex Desktop 交互长会话做交付；Verify 主验收 |

eligible 片可 `override: 用户要求自写`；ineligible 写 `executor: conductor`。无 codex 且 eligible → `blocked`。Verify 禁派 Codex。

## 方案确认后的自动编排

确认后连续执行至关版分叉——**不含 Deploy**：

1. Plan 落盘（指挥侧；事实映射、纵向切片、强 Oracle、`check_spec`）；禁止中途「待批准」
2. Build/Repair：仅 **eligible** 切片派 Codex；其余指挥侧；edit-wave 后 verify-wave 红绿 replay（`ship.sh --from-meta`，仅 Codex 片）
3. 全部 D 收口 → Agent Verify → 证据卡或人类验收包
4. Fail → 统一 Repair（eligible：fresh exec；ineligible：指挥侧）→ 回验

多 Spec / 多 D → 先出 DAG+波次；禁止单聊默默 for-loop。  
暂停仅限：产品互斥、不可逆、外部阻塞、Verified 事实与已确认方案冲突。

## 阶段闸门（摘要）

- **许愿路径：** Shape → 指挥侧 Plan → eligible 派 Codex → Verify → 关版（Deploy 须 P4）
- **经典路径：** 用户逐步批准；Deploy 遵 P0–P6；一聊一个 edit-wave
