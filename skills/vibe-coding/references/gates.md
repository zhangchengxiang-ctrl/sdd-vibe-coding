# Gates（常驻）

> 写码授权 · 人闸 · 施工通道 · 许愿自动编排。**唯一常驻合同。**  
> 状态词 → [`states.md`](./states.md)；Build/Verify/Repair 清单 → [`rails.md`](./rails.md)。  
> A = 纵向切片（Skill `spec`）；D = 一次 Codex exec（[`dispatch-units.md`](../../dispatch-codex/references/dispatch-units.md)）。禁止把 A 焊成 D。

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

| 宿主 | 施工方式 |
|---|---|
| Cursor / Claude（指挥侧） | **派发**：打包 D → `codex-dispatch.sh` / `wish-orchestrate.sh`；一聊一个 edit-wave |
| Codex 会话 | 自己实现当前 D；一次 exec = 一个 D（估峰 >180K → 拆 D；禁止 compact 续跑） |

指挥侧例外（仅）：① Polish/trivial (c)；② Repair 小缺口（≤2 文件、不新增行为面）；③ 用户明文「你自己写 / 不用 Codex」。  
改文档 / `check_spec` / 锁决策 / 验收 → 指挥侧自做。Verify 主验收禁派（[`verification-loop`](./verification-loop.md) 钉 3）。  
无 `codex` → `blocked`。  
**声明派生（机检）：** `run.md` 写「实现完成」须引用 `.codex-dispatch-logs/<id>.jsonl`（或 `dispatch-run-id:`），否则写 `override: 用户要求自写|polish|trivial`（`check_spec` Fail）。

## 方案确认后的自动编排

确认后连续执行至关版分叉——**不含 Deploy**：

1. Plan 落盘（事实映射、纵向切片、强 Oracle、`check_spec`）；禁止中途「待批准」
2. Build/Repair 按施工通道派发；edit-wave 后 verify-wave 证伪（[`falsify-attestation`](../../dispatch-codex/references/falsify-attestation.md)）
3. 全部 D 收口 → Agent Verify → 证据卡或人类验收包
4. Fail → 统一 Repair（fresh exec）→ 回验

多 Spec / 多 D → 先出 DAG+波次；禁止单聊默默 for-loop。  
暂停仅限：产品互斥、不可逆、外部阻塞、Verified 事实与已确认方案冲突。

## 阶段闸门（摘要）

- **许愿路径：** Shape 等人确认 → 自动 Plan→Build→Verify→关版分叉 → 询问是否 Deploy（须本轮 P4）
- **经典路径：** 用户说 Rail 名时逐步跨阶段批准；Deploy 遵 P0–P6
- **一聊一个 edit-wave**；同区二次修复仍失败 → fresh exec / 新对话 Diagnose
