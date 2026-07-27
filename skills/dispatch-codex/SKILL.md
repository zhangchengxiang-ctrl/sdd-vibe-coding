---
name: dispatch-codex
description: >-
  可选指挥施工：在 Cursor / Claude Code 上将一个完成单元派给 Codex 执行并验收。
  触发：派 Codex / 用 Codex 做 / 让 Codex 施工 / 省成本用 Codex。一次只派 Plan 整份 Spec
  或 Build 一个纵向切片；指挥侧必须对照仓库产物验收。仅在 vibe-coding 已路由到本模式，
  或用户显式调用时使用。不在纯 Codex 会话中调用本 Skill。
---

# Dispatch Codex：指挥施工

本 Skill 只跑在 **Cursor / Claude Code** 指挥侧。先读宿主 `AGENTS.md` 与
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)「指挥施工 Harness」。

施工侧 Codex 须已安装同版本 `sdd-vibe-coding`（建议 `make install-dev` 软链），质量条由其
默认执行；**派单禁止粘贴合同大段**。

## 何时用 / 何时不用

| 用 | 不用 |
|---|---|
| 用户明示派 Codex / 用 Codex 施工 | 用户未提 Codex（指挥侧自己干） |
| 需要省订阅成本跑 Plan 或单片 Build | 已在 Codex 会话里（走纯 Codex Harness） |
| 指挥侧可访问 Codex MCP 或 `codex` CLI | 无 Oracle 的 Build（先 Plan） |

## 流程（一次一个完成单元）

1. **选定单元**
   - Plan：产品包 / 已确认切片 → 整份 Spec 落盘；
   - Build：已批准 Spec + `plan.md` 中**一个**切片（默认第一个未完成切片）；
   - Goal（可选）：仅当用户要连续多片且完成条件可写成验证命令时。
2. **预检**
   - Build：打开 `tests.md`，确认该片 T-xxx 含 success + failure/permission 的 Given/When/Then；
   - 缺 Oracle → **不派单**，先走 Plan 或请用户补产品判定。
3. **薄派单**（见下方模板）→ 调用工具。
4. **验收**（maker ≠ grader）→ 对照仓库；失败则 `codex-reply` 打回。
5. **对人交付卡**：目标、结果、证据路径、要你决定（下一切片 / 进 Verify / 授权）。

## 工具

优先顺序：

1. **MCP** `user-codex`：`codex`（新开）/ `codex-reply`（续聊，需 `threadId`）
2. **CLI**：`codex exec -C <cwd> --sandbox danger-full-access`（或宿主约定沙箱）
3. 皆失败 → 状态 `blocked`，说明缺 MCP/CLI，**禁止**声称已派给 Codex

参数建议：`cwd` = 宿主仓根；`approval-policy=never`（派单已含范围）；sandbox 以能读库/写 Spec 与代码为准（常 `danger-full-access` 或 `workspace-write`）。

记录：`threadId`（若有）、派单时间、单元 ID，写入指挥侧回复的「技术详情（可选）」或 `handoff` 一句，不挡 PM 正文。

## 薄派单模板

### Plan

```text
cwd: <HOST_ROOT>
按 vibe-coding 走 Plan。产品真源：<PRODUCT_PATH>。
切一份新 Spec，直接落盘 VERSION/contract/tests/plan/run，不要改业务代码。
不要再问「批准落盘 Spec」；结束后只给能否进入 Build 的批准卡，并列出 Unverified。
```

### Build（单切片）

```text
cwd: <HOST_ROOT>
docs/specs/<SPEC_ID>/ 已批准。按 vibe-coding 只做 plan.md 中的切片 <SLICE_ID>（完成定义：<T-ids>）。
对照 contract 事实映射再改；做完跑该片验证，结果写入 run.md。
不要整包硬扛，不要用绝对路径/typecheck 旧债假阻塞。
切片完成后短报告：做成了什么、证据在哪、下一个切片是什么。
```

### Goal（多片 · 可选）

```text
cwd: <HOST_ROOT>
对 docs/specs/<SPEC_ID>/ 创建持久 Goal：按 plan.md 顺序做完剩余切片 <S_a…S_z>。
每片完成条件=对应 T-xxx 行为证据写入 run.md；禁改 Out of Scope；真阻塞或生产授权则 pause。
不要普通单轮假装一口气做完。
```

## 验收清单

### Plan 通过

- [ ] 存在 `docs/specs/<id>/{VERSION,contract,tests,plan,run}.md`
- [ ] `contract.md` 有入口事实映射与 Verified/Unverified
- [ ] `plan.md` 纵向切片，完成定义链 T-xxx（非 root/ACL 横轴）
- [ ] `tests.md` 每 P0 有完整 Given/When/Then（含 permission）
- [ ] 本轮无业务代码改动（或仅 docs/handoff）
- [ ] 未在落盘前停问「批准写 Spec」

### Build 通过

- [ ] diff 落在该切片相关路径，未静默扩到其它入口
- [ ] `run.md` 记录该片批次；T-xxx 有结果
- [ ] 无假 Lock / 以 typecheck 旧债结束
- [ ] 收口声明的是切片完成，非整份 Spec done（除非 Goal 真做完且证据齐）

任一失败 → 打回派单（具体缺陷一句）或新开 Plan；**不得**向用户报验收通过。

## 对人前台

只用「我理解的目标 / 当前进展 / 交付结果 / 需要你决定」。  
默认不展示 MCP、threadId、sandbox；用户追问再放「技术详情（可选）」。
