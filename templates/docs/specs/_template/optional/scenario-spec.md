# Scenario Spec · <version-id>

> **验收规格**：可被 spec-analyze / E2E / 人工走查消费。
> **落盘**：将本文件从 `_template/optional/` **复制到 Spec 根** `docs/specs/<id>/scenario-spec.md` 再填写；**禁止**把运行真源留在 `optional/`。  
> **面向测试切版**：新产品能力 / Major Spec 的当前 In 范围应有根目录本文 + 下方覆盖矩阵。
> **SC-ID 契约**：场景标题必须 `## SC-N — <名称>`；`TEST_TYPE: e2e|integration` 且 AC 勾选后，`tests/` 中必须存在含 `SC-N` 的用例（CI grep 对账）；`TEST_TYPE: manual` = 浏览器走查剧本。

---

## 覆盖矩阵（切版必填）

> 行 = **角色** × **主旅程**（scope In）；列 = 成功 / 关键失败或降级 / In 内分支。  
> 每格填 `SC-N` 或 `N/A` + 一句话理由。禁止留空。

| 角色 × 旅程 | 成功路径 | 失败 / 降级 | In 内分支（修订/取消/权限等） |
|-------------|----------|-------------|-------------------------------|
| （例）成员 × 首次定制 | SC-1 | SC-2 | SC-3 |
| | | | |

**角色清单**（来自设计稿 personas；无多角色则写「单角色：…」）：

- …

**主旅程清单**（来自设计稿 01-experience / scope In）：

- …

---

## Scenario 格式

```markdown
## SC-N — [功能/场景名称]

GIVEN [前置状态/条件]
WHEN [用户/系统的操作]
THEN [预期结果]
ORACLE [如何观察到结果真实成立]
EFFECTIVE_CHANNEL [真实生效入口 / 环境]
EVIDENCE [测试、截图、日志或用户判决]
FAILURE_ROUTE [失败后回到 shape / build / deliver / blocked]

ACCEPTANCE_CRITERIA:
  - [ ] <具体可验证的条件>
TEST_TYPE: unit | integration | e2e | manual
```

---

## SC-1 — [主要功能]

GIVEN
WHEN
THEN
ORACLE
EFFECTIVE_CHANNEL
EVIDENCE
FAILURE_ROUTE

ACCEPTANCE_CRITERIA:
  - [ ]

TEST_TYPE:

---

## 验收门

### 门 0：覆盖矩阵
- [ ] 矩阵无空格；每个非 N/A 的 `SC-N` 均有正文
- [ ] In 内角色与主旅程均已出现在矩阵行中

### 门 1：Ready
- [ ] 当前交付范围的 Scenario 可执行；环境、账号、角色、数据和依赖可用
- [ ] ORACLE、EFFECTIVE_CHANNEL 与 FAILURE_ROUTE 明确

### 门 2：Verify / Demo
- [ ] 当前交付范围 Scenario 的 ACCEPTANCE_CRITERIA 全部满足（`[x]`）
- [ ] 与本版直接相关的检查和测试通过
- [ ] TEST_TYPE=e2e|integration 的有对应 `tests/` 用例且标题/注释含 `SC-N`
- [ ] 真实生效通道已验证；未达到时不得提高 Delivery Target
