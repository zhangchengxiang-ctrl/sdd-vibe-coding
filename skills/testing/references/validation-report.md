# 验证报告模板（正式验收 / 发布 / PR）

普通修复只需在最终回复列出实际验证；正式验收、发布或 PR 需要结构化记录时
使用本模板。未运行的检查不必为了填表而补跑。

```markdown
### 验证报告
- **改动范围**：（路径摘要）
- **Trivial 判定**：trivial / small / non-trivial / major
- **Version**：`docs/specs/<id>/` 或 **Docs: N/A**（理由：___）
- **Delivery Target / Current Gate**：___ / ___
- **实际达到**：design-ready / code-ready / dev-effective / production-delivered / user-accepted
- **定向检查**：（实际命令 → 结果）
- **全量回归**：命令 → 结果 / N/A（仅发布、CI、全局合同或用户明确要求）
- **迁移**：命令 → 结果 / N/A
- **浏览器**：宿主浏览器验收 → OK / N/A（理由）
- **交付证据**：环境 / 版本 / deploy / health / 关键路径 / N/A
- **Docs 回填**：
  - [ ] specs/<id>/tasks · validation
  - [ ] product/foundation/system-map.md（若改进程边界）
  - [ ] product/README.md 索引状态（若绑定设计稿）
  - [ ] handoff.md
  - 或 **Docs: N/A**：___
- **过渡态**：（代码与文档不一致时写明，避免下一 Agent 误判）
- **结论**：可合并 / 待用户确认 / 阻塞于 ___
```

**禁止**：未填 Version 或 Docs 行就声称完成（文档回填规则）。
