# Context Pack（Codex Build 上下文包）

> 给短窗口 Codex 的 **Outcome-first** 派单载荷。真源：OpenAI Codex Best practices  
> （Goal · Context · Constraints · Done when）+ 本插件完成单元合同。  
> 生成：`skills/dispatch-codex/scripts/build_context_pack.py`。  
> 派发：`codex-dispatch.sh --unit build`（许愿编排见 `wish-orchestrate.sh`）。

## 1. 为什么要 Pack

Codex 上下文短、易目标漂移。指挥侧不得把愿望聊天或整份 Spec 正文塞进 prompt。  
**耐久规则**在宿主 `AGENTS.md` + 插件 skills；**本轮任务**只给本切片的小包。

## 2. 必填字段

| 字段 | 含义 | 来源 |
|------|------|------|
| `SLICE_ID` | 唯一完成单元 | `plan.md` 纵向切片表 |
| `Goal` | 本片用户可观察结果（一句话） | 表「入口」+ 完成定义摘要 |
| `Context.pointers` | Spec 五件套路径（只指针） | `docs/specs/<id>/…` |
| `Context.paths` | 本片建议先看的代码/文档路径（宜 3–8 个） | 表「触及路径」或备注 `paths:` |
| `Context.t_ids` | 本片 Oracle | 表「完成定义」中的 `T-xxx` |
| `Constraints` | Out / 禁改 Oracle / 只做本片 | 合同 + 固定硬门 |
| `Done when` | 可执行验收句 | 对应 T-xxx + 写 `run.md` |

## 3. 硬门

1. **Build 派 Codex 必须带 Pack**（由 `build_context_pack.py` 生成或等价字段齐全）。  
2. Pack **禁止**内嵌：`tests.md` 全文、design-standards 长文、无关模块源码。  
3. 一次 Pack = **一个** `SLICE_ID`；多片 → 多次派发或（用户明示）`--unit goal`。  
4. 指挥侧验收：对照仓库 + ≥1 条**结构化证伪**（钉 3）；日志须含
   `COMMAND` / `EXIT_CODE: 0` / `VERDICT: … PASS`（见 [`falsify-attestation.md`](./falsify-attestation.md)）；  
   `wish-orchestrate` 在下一片前机检（`require-conductor-falsify`）；FAIL/缺省/无结构字段阻断。  
5. Plan：`--spec` + 落盘后 `assert_plan_artifacts.py`（禁聊天「待批准」假成功）。

## 4. `plan.md` 切片表约定

```markdown
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | Web：创建草稿 | T-001, T-002 | src/a.ts, src/b.ts | | |
```

- **触及路径**：可选；逗号/分号分隔；缺省时 Pack 只带 Spec 指针，由 Codex 按事实映射自搜。  
- 旧五列表（无触及路径）仍可解析。

## 5. 生成的派单形态

脚本输出的 prompt 固定四段（英文标签便于模型锚定）+ 中文说明，见  
`build_context_pack.py --help`。指挥侧可重定向到文件再喂给 `codex-dispatch.sh`。
