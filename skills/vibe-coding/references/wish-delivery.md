# 许愿式高质量交付

> **北极星：** 人用愿望驱动产品；插件保证高质量输出。  
> 闸门与状态词以 [`workflow-contract.md`](./workflow-contract.md) 为唯一真源。  
> Cursor/Claude 上许愿 Build：**打包 D（272K）+ Context Pack + edit-wave Codex**为硬门（见 dispatch-codex / [`dispatch-units.md`](../../dispatch-codex/references/dispatch-units.md)）。  
> 运行时硬闸（可选）：[`runtime-hooks.md`](./runtime-hooks.md)（scaffold `--hooks`）。

## 1. 对人四步

```text
① 许愿 → ② 确认产品方案 → ③ AI 研发团队交付工程证据
  → ④ 关版（无 UI 机器关版 / 有 UI 人点验）→ （另批）⑤ 上线 Deploy
```

| 步 | 人 | AI |
|----|----|-----|
| ① | 说愿望 | 仅追问会改变产品结果的互斥点 |
| ② | **拍板产品方案** | 给出可确认方案（Job / 范围 / 非目标 / 主路径 / 风险） |
| ③ | 看进展摘要（可选） | Plan → **打包 D→edit-wave Codex** → verify-wave 证伪 → 走查 → Repair |
| ④ | 有 UI：按包点验；无 UI：看证据卡（默认可不动作） | 无 UI 可机跑 → **机器关版**；有 UI → 交验收包等人。通过后 `make close-spec` 一条命令归档 |
| ⑤ | **另批**「发布 / 上线 / 部署」→ Deploy P4 | 关版后**只问**是否上线；**禁止**自动上生产 |

人对质量的贡献：**定做对的事**（方案闸）；有 UI / 人判断时 **验做成的事**；无 UI 可机跑 Oracle 不把人当 CI。  
**关版 ≠ 上线：** 自动编排止于 `acceptance-passed`；生产动作须本轮明示 Deploy 批准（见 Skill `deploy`）。

## 2. 高质量内核（不可省略）

| 层 | 义务 | 缺了会怎样 |
|----|------|------------|
| 产品正确 | 方案闸：Job Brief、In/Out、失败/权限路径；人确认前不施工 | 做错产品 |
| 合同正确 | 事实映射 → 纵向切片 → Spec 五件套 → 强 Oracle | 无法判定做对 |
| 实现正确 | 一 D 一次 exec（272K 打包）；Context Pack→Codex；Oracle 冻结；红绿证据 | 半截交付 / 漂移 / compact |
| 验证正确 | 先证伪；走查；maker ≠ grader（Codex≠指挥侧） | 自嗨 Pass |
| 发布正确 | 关版后**另批** Deploy P4；施工/许愿自动段**禁**生产 | 误上线 |

设计质量条（LOAD-MAP / product-judgment 等）仍默认执行；许愿轨**不削弱**它们。

## 3. 研发半自动编排（方案确认之后）

执行序与硬门真源：[`workflow-contract.md`](./workflow-contract.md)
「方案确认后的自动编排」+「施工通道」。本页不复述步骤，只钉对人语义：

- 方案确认后**默认连续**（Plan → 派发 Build → 证伪 → Verify → 关版分叉），中间禁止「待批准 Plan/Build」停点；**不含 Deploy**。  
- 关版分叉：无 UI 可机跑 → 证据卡 + `make close-spec` 机器关版；有 UI → 验收包等人点验后 close-spec。  
- 关版后只问「要不要上线」；生产须本轮 Deploy P4 批准。

**前台：** 说「方案 / 研发进展 / 证据卡或请你点验 / 关版」；默认不说 Rail / Spec / Oracle / dispatch。

## 4. 完成单元与 Context Pack

- **A 轴**：真实用户入口纵向切片（验收 / `T-xxx`）。  
- **D 轴**：272K 窗口打包的一次 `codex exec`（可含多个 A）。  
- Pack = Goal · Context（Spec 指针 + **allowlist**）· Constraints · Done when。  
- **禁止**把愿望聊天或 Spec 全文塞进 Codex prompt。  
- 单 Spec A 过多或单 D 超窗 → 拆多 Spec / 再拆 D，禁止 Goal 硬撑。  
- 记忆在磁盘；会话可丢。一聊一个 edit-wave。

## 5. 与经典 Rail 话术的关系

用户仍可用「切 Spec / 开始做 / 验收」逐步推进（经典闸门仍有效）。  
用户走许愿话术时，以本页 + workflow「许愿式交付」为准；Build 仍须 Pack+Codex。
