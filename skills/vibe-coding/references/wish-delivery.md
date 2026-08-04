# 许愿式高质量交付

> **北极星：** 人用愿望驱动产品；插件保证高质量输出。  
> 闸门与状态词以 [`workflow-contract.md`](./workflow-contract.md) 为唯一真源。  
> Cursor/Claude 上许愿 Build：**Context Pack + Codex 逐片派发**为硬门（见 dispatch-codex）。  
> 运行时硬闸（可选）：[`runtime-hooks.md`](./runtime-hooks.md)（scaffold `--hooks`）。

## 1. 对人四步

```text
① 许愿 → ② 确认产品方案 → ③ AI 研发团队交付「可人验」产物
  → ④ 人按验收包自验关版 → （另批）⑤ 上线 Deploy
```

| 步 | 人 | AI |
|----|----|-----|
| ① | 说愿望 | 仅追问会改变产品结果的互斥点 |
| ② | **拍板产品方案** | 给出可确认方案（Job / 范围 / 非目标 / 主路径 / 风险） |
| ③ | 看进展摘要（可选） | Plan → **Pack+Codex 逐片 Build** → 证伪 → 走查 → Repair |
| ④ | **按验收包自验**；明示通过 → 关版 | 交「怎么验 + 验什么」；工程证伪为旁证；**不得**替人关版 |
| ⑤ | **另批**「发布 / 上线 / 部署」→ Deploy P4 | 关版后**只问**是否上线；**禁止**自动上生产 |

人对质量的贡献是两道闸：**定做对的事**、**验做成的事**。中间研发编排不甩给人。  
**关版 ≠ 上线：** 自动编排止于验收包 / `acceptance-passed`；生产动作须本轮明示 Deploy 批准（见 Skill `deploy`）。

## 2. 高质量内核（不可省略）

| 层 | 义务 | 缺了会怎样 |
|----|------|------------|
| 产品正确 | 方案闸：Job Brief、In/Out、失败/权限路径；人确认前不施工 | 做错产品 |
| 合同正确 | 事实映射 → 纵向切片 → Spec 五件套 → 强 Oracle | 无法判定做对 |
| 实现正确 | 一完成单元一片；Context Pack→Codex；Oracle 冻结；红绿证据 | 半截交付 / 漂移 |
| 验证正确 | 先证伪；走查；maker ≠ grader | 自嗨 Pass |
| 发布正确 | 人验关版后**另批** Deploy P4；施工/许愿自动段**禁**生产 | 误上线 |

设计质量条（LOAD-MAP / product-judgment 等）仍默认执行；许愿轨**不削弱**它们。

## 3. 研发半自动编排（方案确认之后）

> **诚实边界：** 机检编排 = 每片 Pack→Codex Build→**结构化证伪**→下一片。  
> Plan / Agent Verify / 人类验收包仍由指挥侧 Agent 调度；**不含 Deploy**。

用户确认产品方案后，Agent **默认可连续**（不必再等人说 Plan / Build / 验收）：

1. Plan：落盘 Spec（质量条 + `check_spec`）；**Codex Plan 须 `--spec` + 落盘硬验**（禁聊天「待批准」假成功）  
2. **Build（Cursor/Claude 硬门）：** 每切片  
   [`context-pack.md`](../../dispatch-codex/references/context-pack.md)  
   → `wish-orchestrate.sh`（幂等 + flock） / `codex-dispatch.sh`  
   → [`record-conductor-falsify`](../../dispatch-codex/references/falsify-attestation.md)（`COMMAND`+`EXIT_CODE: 0`+`VERDICT: PASS`）  
   → `require-conductor-falsify` 通过 → 下一片  
   （未结构化 PASS 不得连派；多片一次调用会在首片后 exit 3；已 PASSED 切片默认跳过）  
3. 单测 / 红绿证据写入 `run.md`  
4. Agent Verify：证伪 + 有 UI 则浏览器走查（**禁** Codex 主验收）  
5. Fail → Repair → 回验  
6. 产出 [`human-acceptance-pack`](../../testing/references/human-acceptance-pack.md)，请人自验  
7. **停。** 不得进入生产 Deploy；人关版后询问是否上线，得本轮「发布/上线」+ P4 再走 Skill `deploy`

**研发段人闸两钉：** 确认产品方案；按验收包关版。中间禁止「待批准 Plan/Build」停点。  
**生产另钉：** Deploy P4（及 P2+P3 方案先过）——不在自动编排内。

无 `codex` CLI → `blocked`。禁止指挥侧同会话连做多片实现代替 Codex。

**前台：** 说「方案 / 研发进展 / 请你验收 / 关版」；关版后再问「要不要上线」；默认不说 Rail / Spec / Oracle / dispatch。

## 4. 完成单元与 Context Pack

- 切轴：真实用户入口纵向切片。  
- Pack = Goal · Context（Spec 指针 + 触及路径）· Constraints · Done when。  
- **禁止**把愿望聊天或 Spec 全文塞进 Codex prompt。  
- 单 Spec 切片过多 → 拆多 Spec。  
- 记忆在磁盘；会话可丢。

## 5. 与经典 Rail 话术的关系

用户仍可用「切 Spec / 开始做 / 验收」逐步推进（经典闸门仍有效）。  
用户走许愿话术时，以本页 + workflow「许愿式交付」为准；Build 仍须 Pack+Codex。
