# Context Pack（Codex Build 上下文包）

> 给 Codex 的 Outcome-first 派单载荷。真源：OpenAI Codex Best practices  
> （Goal · Context · Constraints · Done when）。一个切片 = 一个派发单元。  
> 生成：`skills/dispatch-codex/scripts/build_context_pack.py`（可一次多 A）。  
> 一个切片 = 一个派发单元（无独立打包器；`wish-orchestrate.sh --units` 列出单元）。派发：`codex-dispatch.sh --unit build` / `wish-orchestrate.sh`。

## 1. 为什么要 Pack

Codex 有效窗约 258K，过线会 **auto-compact**（有损）。指挥侧不得把愿望聊天或整份 Spec 正文塞进 prompt。  
**耐久规则**在宿主 `AGENTS.md` + 插件 skills；**本轮任务**只给**本切片**的小包 + **硬 allowlist**。

## 2. 必填字段

| 字段 | 含义 | 来源 |
|------|------|------|
| `DISPATCH_ID` | 派发单元 id（等于切片 id，如 S1） | `build_context_pack.py` |
| `SLICE_IDS` | 本 D 含有的 A 切片（可多个） | 打包结果 |
| `SLICE_ID` | 主切片（兼容旧解析，取第一个） | `SLICE_IDS[0]` |
| `Goal` | 本 D 用户可观察结果 | 各 A「入口」+ `T-xxx` |
| `Context.pointers` | Spec 五件套路径（只指针） | `docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/…` |
| `Context.paths` / allowlist | **硬写入面**（必填） | 表「触及路径」并集 |
| `Context.t_ids` | 冻结 Oracle 本体（机检组 replay / 人工组不进 replay 集） | 各 A 完成定义 |
| `Constraints` | Out / 禁改 Oracle / 只做本 D / 不准 compact 续跑 | 合同 + 固定硬门 |
| `Done when` | 可执行验收句 | 对应 `T-xxx` + 写 `run.md` |

## 3. 硬门

1. **Build 派 Codex 必须带 Pack**（由 `build_context_pack.py` 生成或等价字段齐全）。  
2. Pack **禁止**内嵌：`tests.md` 全文、design-standards 长文、无关模块源码。  
3. 一次 Pack = **一个切片**（A == D）。多切片一次 exec → 拒绝;整份 Spec 交给 wish-orchestrate 分波。  
4. **allowlist 必填**；空触及路径 = 不合格 Pack，不得派。  
5. 验收是红绿 replay（钉 3，真源见 [`verification-loop`](../../vibe-coding/references/verification-loop.md)）;它不挡编辑锁不冲突的下一波。  
6. jsonl 须有 **`turn.completed`**；仅当出现 **compact 事件类型** 才判窗损。禁止把 `usage.input_tokens` 当窗宽。失败 → fresh exec。  
7. Plan 由指挥侧落盘（`--unit plan` 默认拒绝）。

## 4. `plan.md` 切片表约定

```markdown
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | Web：创建草稿 | T-001, T-002 | src/a.ts, src/b.ts | | oracle:unit |
```

- **触及路径**：allowlist；逗号/分号分隔；**空则不得派 Build**。  
- **依赖**：`S2` 或 `other-spec:S1`。  
- **备注**：`oracle:unit|machine|lab|human`；`claims:…`。  
- 旧五列表仍可解析。

## 5. 生成的派单形态

脚本输出含 `DISPATCH_ID` / `SLICE_IDS` / allowlist。指挥侧可重定向到文件再喂给 `codex-dispatch.sh`。
