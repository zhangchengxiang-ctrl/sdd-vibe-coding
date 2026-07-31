---
name: dispatch-codex
description: >-
  可选指挥施工：在 Cursor / Claude Code 上将一个完成单元派给 Codex（gpt-5.6-sol
  × medium/high）执行并验收。触发：派 Codex / 用 Codex 做 / 让 Codex 施工 /
  省成本用 Codex。一次只派 Plan 整份 Spec 或 Build 一个纵向切片；指挥侧对照
  仓库产物验收。派发通道：CLI 包装 codex-dispatch.sh（或 make codex-dispatch）。
  仅在 vibe-coding 已路由到本模式，或用户显式调用时使用。不在纯 Codex 会话中调用。
---

# Dispatch Codex：指挥施工

本 Skill 只跑在 **Cursor / Claude Code** 指挥侧。先读宿主 `AGENTS.md` 与
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)「指挥施工 Harness」。

施工侧 Codex 须已安装同版本 `sdd-vibe-coding`（建议 `make install-dev` 软链），质量条由其
默认执行。派单只含薄模板，合同正文由施工侧插件执行。

**有 UI 的 Plan/Build：** 薄派单须点名服从宿主已声明的 `UI surface` / `page_kind|motif`，并要求施工侧
先读插件 `design-standards/LOAD-MAP.md`；勿在派单里粘贴长合同。

> **档位真源：** Plan → AD-P（2026-07-27）；Build → AD-B（2026-07-28）。  
> 选用 `gpt-5.6-sol` × medium/high。详见
> `evals/fixtures/codex-live/RUN-capability-agentdeck-2026-07-27.md`、
> `RUN-AD-B-2026-07-28.md`。

## 何时用

| 用 | 指挥侧自做 |
|---|---|
| 用户明示派 Codex / 用 Codex 施工 | 用户未提 Codex |
| 已批准有界单元，用 Sol 离场施工 | 已在 Codex 会话里（走纯 Codex Harness） |
| 指挥侧 PATH 上有 `codex` CLI | 无 Oracle 的 Build（先 Plan） |
| | Shape / 产品拍板 / 验收对话 |

未触发「派 Codex」时：复杂 Plan 默认指挥侧自做。

## 模型与思考深度

| 完成单元 | 模型 | effort |
|---|---|---|
| Plan | `gpt-5.6-sol` | **medium**（默认） |
| Plan（加码） | `gpt-5.6-sol` | **high**（首派失败、假 Lock 风险高、或用户要求更稳） |
| Build 单片 | `gpt-5.6-sol` | **medium**（默认）/ high（加码） |
| Goal 多片 | `gpt-5.6-sol` | **high**（仅用户明示长程；完成条件=验证命令） |

速度口诀：默认 **sol×medium**；翻车或真难再升 **high**。

## 流程（一次一个完成单元）

1. **选定单元**
   - Plan：产品包 / 已确认切片 → 整份 Spec 落盘；
   - Build：已批准 Spec + `plan.md` 中**一个**切片（默认第一个未完成切片）；
   - Goal（可选）：仅当用户要连续多片且完成条件可写成验证命令时。
2. **预检**
   - Build / Goal：先跑
     `python3 skills/spec/scripts/check_spec.py <host> <spec-id>`（或 `make check-spec`）；
     未通过则先修 Spec，再派单。CLI 包装默认强制该门（`--spec` 必填；`SKIP_SPEC_CHECK=1` 仅紧急绕过）。
   - Build：打开 `tests.md`，确认该片 T-xxx 含 success + failure/permission 的 Given/When/Then；
   - 缺 Oracle 或 check_spec 未过 → 先走 Plan 或请用户补产品判定。
3. **选定 sol × medium|high** → **薄派单** → **经下方 CLI 包装调用**（参数齐全后再跑）。
4. **验收**（maker ≠ grader）→ 对照仓库 + 下方勾选；未过则同参升高 effort 经 CLI 再派一次，或指挥侧自做。
5. **对人交付卡**：目标、结果、证据路径、要你决定（下一切片 / 进 Verify / 授权）。

## 工具（正路径）

**硬门：** 派发只经下方 CLI；不经 `user-codex` / `CallMcpTool`（`codex` / `codex-reply`）。模型固定 `gpt-5.6-sol`，effort 仅 medium|high。

优先顺序：

1. **CLI 包装（默认）**  
   `skills/dispatch-codex/scripts/codex-dispatch.sh`  
   （或 `make codex-dispatch`）— `approval_policy=never` + 墙钟 `timeout` + 默认 JSONL 日志
2. **裸 `codex exec`**：仅包装脚本缺失时；参数与下方质量门一致，并自带 `timeout`
3. 皆失败 → 状态 `blocked`，说明缺 `codex` CLI，对人如实说 Blocked

### 必传参数

| 参数 | 值 |
|---|---|
| `cwd` / `-C` | 宿主仓根（或约定 worktree） |
| `model` / `-m` | `gpt-5.6-sol` |
| `model_reasoning_effort` / config | `medium` 或 `high` |
| `approval-policy` | `never`（脚本写死） |
| `sandbox` | Plan：`workspace-write`；Build/Goal：`danger-full-access`（默认） |

### CLI 调用前自检

- [ ] 走的是 `codex-dispatch.sh` / `make codex-dispatch`
- [ ] `model` = `gpt-5.6-sol`；effort = medium|high
- [ ] Build/Goal 的 `sandbox` = `danger-full-access`（或接受脚本默认）
- [ ] Build/Goal 已过 `check_spec`（或脚本 `--spec`）
- [ ] 一次只一个完成单元
- [ ] prompt 为薄模板，无合同大段

任一项未满足 → 先改参数再调用。

### 超时与验收

1. 脚本默认墙钟：Plan **900s** / Build **1200s** / Goal **3600s**（可用 `--timeout` 覆盖）。
2. exit `124`/`137` → 立刻对照仓库产物验收（diff / Spec / `run.md`）。
3. 若产物已达完成定义 → 对人结案，注明「派发超时中断，已按仓库验收」。
4. 进度以仓库变化为准。

### CLI 包装用法

```bash
# Plan（默认 15min / workspace-write / medium）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit plan -- <<'EOF'
<薄派单正文>
EOF

# Build 单片（默认 20min / danger-full-access / medium；通常需 --spec）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit build --effort medium --spec <SPEC_ID> -- <<'EOF'
<薄派单正文>
EOF

# Goal（默认 60min / danger-full-access / high）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit goal --spec <SPEC_ID> -- <<'EOF'
<薄派单正文>
EOF
```

要点：

- 脚本写死 `approval_policy=never`
- 墙钟到点会 `SIGTERM`/`SIGKILL` 并 exit `124`——之后对照仓库验收
- 默认 `--json`：事件写入 `<cwd>/.codex-dispatch-logs/<unit>_<ts>_<pid>.jsonl`（可 `--log-dir` / `--no-json`）
- Make：`make codex-dispatch HOST=… UNIT=plan|build|goal PROMPT_FILE=…`（Build/Goal 另传 `SPEC=`）

裸 `codex exec` 兜底（仅包装缺失时）：

```bash
timeout 20m codex exec -C <HOST_ROOT> -s danger-full-access -m gpt-5.6-sol \
  -c model_reasoning_effort=\"medium\" -c approval_policy=\"never\" \
  --skip-git-repo-check --json "<薄派单正文>"
```

记录：model、effort、approval-policy、sandbox、派单时间、单元 ID、dispatch log / meta 路径 → 可选「技术详情」。

## 薄派单模板

### Plan

```text
cwd: <HOST_ROOT>
model: gpt-5.6-sol
effort: medium
approval-policy: never
sandbox: workspace-write
按 vibe-coding 走 Plan。产品真源：<PRODUCT_PATH>。
切一份新 Spec，直接落盘 VERSION/contract/tests/plan/run；本轮只改 docs。
有 UI：合同写 UI surface（及 page_kind|motif / Design Read / Build 前 anchor）；施工服从 LOAD-MAP（勿贴长文）。
骨架文件名用上述五件套；以插件质量条为准。
结束后只给能否进入 Build 的批准卡，并列出 Unverified。
```

### Build（单切片）

```text
cwd: <HOST_ROOT>
model: gpt-5.6-sol
effort: medium
approval-policy: never
sandbox: danger-full-access
docs/specs/<SPEC_ID>/ 已批准。按 vibe-coding 只做 plan.md 中的切片 <SLICE_ID>（完成定义：<T-ids>）。
对照 contract 事实映射再改；有 UI 先按 LOAD-MAP 读必读册；改存量注明 refinement|redesign。
做完跑该片验证，结果写入 run.md。
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
每片完成条件=对应 T-xxx 行为证据写入 run.md；遵守 Out of Scope；真阻塞或生产授权则 pause。
```

## 验收清单

### Plan 通过

- [ ] 存在 `docs/specs/<id>/{VERSION,contract,tests,plan,run}.md`（或等价扩展名）
- [ ] 有 `contract.md`；骨架为上述五件套
- [ ] `contract.md` 有入口事实映射与 Verified/Unverified
- [ ] `plan.md` 纵向切片，完成定义链 T-xxx
- [ ] `tests.md` 每 P0 有完整 Given/When/Then（含 permission）
- [ ] 本轮仅 docs/handoff 改动
- [ ] 落盘后给出能否进入 Build 的批准卡

**硬门（打回）：** 无 `contract.md`，或仅有 context/requirements/tasks/validation/scenario-spec 旧骨架 → 经 CLI 升 `effort=high` 重派或指挥侧自做。

### Build 通过

- [ ] diff 落在该切片相关路径
- [ ] `run.md` 记录该片批次；T-xxx 有结果
- [ ] 完成定义以该片行为证据收口（非整份 Spec done，除非 Goal 真做完且证据齐）

未过 → 经 CLI 打回派单（具体缺陷一句）或指挥侧自做；对人只报真实验收结论。

## 对人前台

只用「我理解的目标 / 当前进展 / 交付结果 / 需要你决定」。  
默认可说：「复杂 Spec/切片用 Codex Sol；小改我这边做。」  
默认不展示 sandbox、model id、dispatch log；用户追问再放「技术详情（可选）」。  
超时中断且仓库已达标时，对人只说结果与证据。
