# 许愿式高质量交付

> **北极星：** 人用愿望驱动产品；插件保证高质量输出。  
> 闸门与状态词以 [`workflow-contract.md`](./workflow-contract.md) 为唯一真源。  
> Cursor/Claude 上许愿 Build：**Context Pack + Codex 逐片派发**为硬门（见 dispatch-codex）。

## 1. 对人四步

```text
① 许愿 → ② 确认产品方案 → ③ AI 研发团队交付「可人验」产物 → ④ 人按验收包自验 → 关版上线
```

| 步 | 人 | AI |
|----|----|-----|
| ① | 说愿望 | 仅追问会改变产品结果的互斥点 |
| ② | **拍板产品方案** | 给出可确认方案（Job / 范围 / 非目标 / 主路径 / 风险） |
| ③ | 看进展摘要（可选） | Plan → **Pack+Codex 逐片 Build** → 证伪 → 走查 → Repair |
| ④ | **按验收包自验**；通过后关版 / 上线 | 交「怎么验 + 验什么」；工程证伪为旁证；**不得**替人关版 |

人对质量的贡献是两道闸：**定做对的事**、**验做成的事**。中间编排不甩给人。

## 2. 高质量内核（不可省略）

| 层 | 义务 | 缺了会怎样 |
|----|------|------------|
| 产品正确 | 方案闸：Job Brief、In/Out、失败/权限路径；人确认前不施工 | 做错产品 |
| 合同正确 | 事实映射 → 纵向切片 → Spec 五件套 → 强 Oracle | 无法判定做对 |
| 实现正确 | 一完成单元一片；Context Pack→Codex；Oracle 冻结；红绿证据 | 半截交付 / 漂移 |
| 验证正确 | 先证伪；走查；maker ≠ grader | 自嗨 Pass |
| 发布正确 | 人验通过后再 Deploy；施工轨禁生产 | 误上线 |

设计质量条（LOAD-MAP / product-judgment 等）仍默认执行；许愿轨**不削弱**它们。

## 3. 研发自动编排（方案确认之后）

用户确认产品方案后，Agent **默认可连续**（不必再等人说 Plan / Build / 验收）：

1. Plan：落盘 Spec（质量条 + `check_spec`）；**Codex Plan 须 `--spec` + 落盘硬验**（禁聊天「待批准」假成功）  
2. **Build（Cursor/Claude 硬门）：** 每切片  
   [`context-pack.md`](../../dispatch-codex/references/context-pack.md)  
   → `wish-orchestrate.sh` / `codex-dispatch.sh`  
   → 指挥侧证伪（日志含 **`VERDICT: PASS`**）→ 下一片  
   （`wish-orchestrate` 默认片间硬闸：未 PASS 不得连派；多片一次调用会在首片后 exit 3）  
3. 单测 / 红绿证据写入 `run.md`  
4. Agent Verify：证伪 + 有 UI 则浏览器走查（**禁** Codex 主验收）  
5. Fail → Repair → 回验  
6. 产出 [`human-acceptance-pack`](../../testing/references/human-acceptance-pack.md)，请人自验  

**人闸只有两钉：** 确认产品方案；按验收包关版。研发段禁止中途「待批准」停点。

无 `codex` CLI → `blocked`。禁止指挥侧同会话连做多片实现代替 Codex。

**前台：** 说「方案 / 研发进展 / 请你验收 / 关版上线」；默认不说 Rail / Spec / Oracle / dispatch。

## 4. 完成单元与 Context Pack

- 切轴：真实用户入口纵向切片。  
- Pack = Goal · Context（Spec 指针 + 触及路径）· Constraints · Done when。  
- **禁止**把愿望聊天或 Spec 全文塞进 Codex prompt。  
- 单 Spec 切片过多 → 拆多 Spec。  
- 记忆在磁盘；会话可丢。

## 5. 与经典 Rail 话术的关系

用户仍可用「切 Spec / 开始做 / 验收」逐步推进（经典闸门仍有效）。  
用户走许愿话术时，以本页 + workflow「许愿式交付」为准；Build 仍须 Pack+Codex。
