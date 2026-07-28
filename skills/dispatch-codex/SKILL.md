---
name: dispatch-codex
description: >-
  可选指挥施工：在 Cursor / Claude Code 上将一个完成单元派给 Codex（仅 gpt-5.6-sol
  × medium/high）执行并验收。触发：派 Codex / 用 Codex 做 / 让 Codex 施工 /
  省成本用 Codex。一次只派 Plan 整份 Spec 或 Build 一个纵向切片；指挥侧必须对照
  仓库产物验收。MCP 派单必须 approval-policy=never（禁 on-request，防挂死）。
  仅在 vibe-coding 已路由到本模式，或用户显式调用时使用。不在纯 Codex 会话中调用。
---

# Dispatch Codex：指挥施工

本 Skill 只跑在 **Cursor / Claude Code** 指挥侧。先读宿主 `AGENTS.md` 与
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)「指挥施工 Harness」。

施工侧 Codex 须已安装同版本 `sdd-vibe-coding`（建议 `make install-dev` 软链），质量条由其
默认执行；**派单禁止粘贴合同大段**。

> **评测依据（2026-07 AgentDeck AD-P）：** 复杂 Plan 仅 `gpt-5.6-sol` × medium/high 过线；
> Terra / Luna / sol×low 会交旧 Spec 骨架或无产物。详见
> `evals/fixtures/codex-live/RUN-capability-agentdeck-2026-07-27.md`。

## 何时用 / 何时不用

| 用 | 不用 |
|---|---|
| 用户明示派 Codex / 用 Codex 施工 | 用户未提 Codex（指挥侧自己干） |
| 已批准有界单元，用 **Sol** 离场施工以省指挥侧订阅 | 已在 Codex 会话里（走纯 Codex Harness） |
| 指挥侧可访问 Codex MCP 或 `codex` CLI | 无 Oracle 的 Build（先 Plan） |
| | Shape / 产品拍板 / 验收对话（指挥侧自做） |
| | 想「换便宜模型」→ **禁止** Terra/Luna 做 Plan/Build |

未触发「派 Codex」时：复杂 Plan **默认指挥侧自做**，不自动外包。

## 模型与思考深度（硬约束）

| 完成单元 | 模型 | effort | 说明 |
|---|---|---|---|
| Plan | `gpt-5.6-sol` | **medium**（默认） | 质量与速度折中；AD-P 过线 |
| Plan（加码） | `gpt-5.6-sol` | **high** | 首派失败、假 Lock 风险高、或用户要求更稳 |
| Build 单片 | `gpt-5.6-sol` | **medium**（默认）/ high（加码） | AD-B 前与 Plan 同严；勿降 Terra/Luna |
| Goal 多片 | `gpt-5.6-sol` | **high** | 仅用户明示长程；完成条件=验证命令 |
| — | `gpt-5.6-terra` / `gpt-5.6-luna` / sol×**low** | — | **禁止**用于 Plan / Build / Goal |

速度口诀：默认 **sol×medium**；只有翻车或真难才升 **high**。**从不靠降模型省时间。**

## 流程（一次一个完成单元）

1. **选定单元**
   - Plan：产品包 / 已确认切片 → 整份 Spec 落盘；
   - Build：已批准 Spec + `plan.md` 中**一个**切片（默认第一个未完成切片）；
   - Goal（可选）：仅当用户要连续多片且完成条件可写成验证命令时。
2. **预检**
   - Build：打开 `tests.md`，确认该片 T-xxx 含 success + failure/permission 的 Given/When/Then；
   - 缺 Oracle → **不派单**，先走 Plan 或请用户补产品判定。
3. **选定 sol × medium|high** → **薄派单** → **按下方质量门调用工具**（缺参则禁止调用）。
4. **验收**（maker ≠ grader）→ 对照仓库 + 下方勾选；失败则 `codex-reply` 打回（可升 high）或指挥侧自做。
5. **对人交付卡**：目标、结果、证据路径、要你决定（下一切片 / 进 Verify / 授权）。

## 工具

优先顺序：

1. **MCP** `user-codex`：`codex`（新开）/ `codex-reply`（续聊，需 `threadId`）——须带下方必传参数
2. **CLI 包装** `skills/dispatch-codex/scripts/codex-dispatch.sh`（**强制** `approval_policy=never` + 墙钟 `timeout` + 默认 JSONL 日志）——MCP 不可用、曾挂死、或要硬截止时**优先于**裸 `codex exec`
3. **裸 CLI**：`codex exec`（仅包装不可用时；参数须与下方质量门一致）
4. 皆失败 → 状态 `blocked`，说明缺 MCP/CLI，**禁止**声称已派给 Codex

### 必传参数（质量门 · 缺一禁止调用）

| 参数 | 值 | 硬约束 |
|---|---|---|
| `cwd` / `-C` | 宿主仓根（或约定 worktree） | **禁止**误指其它仓 |
| `model` / `-m` | `gpt-5.6-sol` | 禁止 terra/luna |
| `model_reasoning_effort` / config | `medium` 或 `high` | 禁止 `low` |
| `approval-policy` | **`never`** | **禁止** `on-request` / `untrusted`；漏传视为非法调用 |
| `sandbox` | Plan：`workspace-write`；Build/Goal：**`danger-full-access`**（默认） | Build 禁止只开 `workspace-write` 却指望沙箱内 listen/port 测试 |

> **为何 `never`：** 派单已是离场施工。`on-request` + MCP 同步 RPC 在 escalation
> （如 listen 本地端口）时经常**弹不出批准 UI**，Cursor 侧 `CallMcpTool` 会无限 pending。
> 实测：Codex 约 7 分钟写完，编排干等 40+ 分钟。

### MCP 调用前自检（必须全部为真再 CallMcpTool）

- [ ] arguments 含 `approval-policy: "never"`（字面量，不可省略）
- [ ] `model` = `gpt-5.6-sol`；effort = medium|high
- [ ] Build/Goal 的 `sandbox` = `danger-full-access`
- [ ] 一次只一个完成单元（非 S1–S9 打包）
- [ ] prompt 为薄模板，无合同大段

任一项为假 → **不得发起调用**；先改参数。

### 挂死与超时（编排侧义务）

MCP `codex` 是同步 RPC：整轮不结束就不返回。指挥侧必须：

1. **墙钟上限约 15 分钟**（Plan）/ **20 分钟**（Build 单片）。超时仍 pending → **中断工具调用**，不得干等。
2. 中断后立刻 **对照仓库产物验收**（diff / Spec / `run.md`），不以 MCP 是否 return 为准。
3. 若产物已达完成定义 → 对人结案，注明「MCP 未正常收口，已按仓库验收」。
4. 若 escalation / sandbox 仍卡住 → 改用 **CLI**（带 `approval_policy=never`）重派，或指挥侧补跑该条验证。
5. **禁止**把「tool 还在 running」当成进度；无仓库变化即无进展。
6. 超时/中断后默认改走 **`codex-dispatch.sh`**，不要对同一挂死 MCP 调用死磕。

### CLI 包装（推荐）

仓库内路径（安装后随 skill 一并存在）：

`skills/dispatch-codex/scripts/codex-dispatch.sh`

```bash
# Plan（默认 15min / workspace-write / medium）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit plan -- <<'EOF'
<薄派单正文>
EOF

# Build 单片（默认 20min / danger-full-access / medium）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit build --effort medium -- <<'EOF'
<薄派单正文>
EOF

# Goal（默认 60min / danger-full-access / high）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit goal -- <<'EOF'
<薄派单正文>
EOF
```

要点：

- **不能**关掉 `never`；脚本写死 `approval_policy=never`
- 墙钟到点会 `SIGTERM`/`SIGKILL` 并 exit `124`——之后**对照仓库**验收
- 默认 `--json`：事件写入 `<cwd>/.codex-dispatch-logs/<unit>_<ts>_<pid>.jsonl`（可 `--log-dir` / `--no-json`）
- 禁 terra/luna、禁 effort=`low`（与质量门一致）
- Make：`make codex-dispatch HOST=… UNIT=plan|build|goal PROMPT_FILE=…`

裸 `codex exec` 兜底（仅包装缺失时）：

```bash
timeout 20m codex exec -C <HOST_ROOT> -s danger-full-access -m gpt-5.6-sol \
  -c model_reasoning_effort=\"medium\" -c approval_policy=\"never\" \
  --skip-git-repo-check --json "<薄派单正文>"
```

记录：`threadId`（若有）、model、effort、approval-policy、sandbox、派单时间、单元 ID、dispatch log 路径 → 可选「技术详情」。

## 薄派单模板

### Plan

```text
cwd: <HOST_ROOT>
model: gpt-5.6-sol
effort: medium
approval-policy: never
sandbox: workspace-write
按 vibe-coding 走 Plan。产品真源：<PRODUCT_PATH>。
切一份新 Spec，直接落盘 VERSION/contract/tests/plan/run，不要改业务代码。
只写上述新骨架；禁止旧文件名（context、requirements、tasks、validation、scenario-spec）。
以插件质量条为准，不要照抄 docs/specs/_template 的旧文件名。
不要再问「批准落盘 Spec」；结束后只给能否进入 Build 的批准卡，并列出 Unverified。
```

### Build（单切片）

```text
cwd: <HOST_ROOT>
model: gpt-5.6-sol
effort: medium
approval-policy: never
sandbox: danger-full-access
docs/specs/<SPEC_ID>/ 已批准。按 vibe-coding 只做 plan.md 中的切片 <SLICE_ID>（完成定义：<T-ids>）。
对照 contract 事实映射再改；做完跑该片验证，结果写入 run.md。
不要整包硬扛，不要用绝对路径/typecheck 旧债假阻塞。
切片完成后短报告：做成了什么、证据在哪、下一个切片是什么。
```

### Goal（多片 · 可选）

```text
cwd: <HOST_ROOT>
model: gpt-5.6-sol
effort: high
approval-policy: never
sandbox: danger-full-access
对 docs/specs/<SPEC_ID>/ 创建持久 Goal：按 plan.md 顺序做完剩余切片 <S_a…S_z>。
每片完成条件=对应 T-xxx 行为证据写入 run.md；禁改 Out of Scope；真阻塞或生产授权则 pause。
不要普通单轮假装一口气做完。
```

## 验收清单

### Plan 通过

- [ ] 存在 `docs/specs/<id>/{VERSION,contract,tests,plan,run}.md`（或等价扩展名）
- [ ] **否决：** 无 `contract.md`，或同时存在 ≥3 个旧骨架文件（`context` / `requirements` / `tasks` / `validation` / `scenario-spec`）
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

任一失败 → 打回派单（具体缺陷一句；旧骨架可升 `effort=high` 重派一次）或指挥侧自做；**不得**向用户报验收通过，**不得**改派 Terra/Luna「再试」。

## 对人前台

只用「我理解的目标 / 当前进展 / 交付结果 / 需要你决定」。  
默认可说：「复杂 Spec/切片用 Codex Sol；小改我这边做。」  
默认不展示 MCP、threadId、sandbox、model id；用户追问再放「技术详情（可选）」。
若因挂死中断且仓库已达标，对人只说结果与证据，不展开 MCP 术语。
