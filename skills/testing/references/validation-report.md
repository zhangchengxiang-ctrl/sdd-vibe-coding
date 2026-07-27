# Validation Report

> 正式验收落盘结构的唯一真源是宿主 Spec 模板
> `docs/specs/<id>/validation.md`（scaffold 来自插件
> `templates/docs/specs/_template/validation.md`）。
>
> 本文件**不**维护第二份报告骨架。Verify / Incident 写结论时直接编辑对应 Spec 的
> `validation.md`；Build 期内过程证据可写在 `spec-run.md`，关版与交付声明仍以
> `validation.md` 为准。

## 必读约束

- Fail 分类与下一 Rail → [`evidence-contract.md`](../../vibe-coding/references/evidence-contract.md) §5
- Delivery Target / 完成声明词汇 → [`workflow-contract.md`](../../vibe-coding/references/workflow-contract.md)「状态词汇」
- 报告必须先写 PM 验收摘要，再写工程矩阵；内部状态不能替代
  「可交付 / 不可交付 / 受阻」的前台结论
- 所有适用 Scenario 有终态 → 只能声明 `matrix-accounted`；关版条件满足 →
  `acceptance-passed`（二者都不是 Delivery Target）
