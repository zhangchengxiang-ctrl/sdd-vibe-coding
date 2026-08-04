---
name: dispatch-codex
description: >-
  可选指挥施工 + 许愿编排：将完成单元派给 Codex（gpt-5.6-sol × medium/high）。
  触发：派 Codex / 用 Codex 做 / 许愿研发编排 Build。Build 须 Context Pack
  （build_context_pack.py）；一次只派一个纵向切片。通道：codex-dispatch.sh /
  wish-orchestrate.sh。仅在 Cursor/Claude 指挥侧使用。
---

# Dispatch Codex：指挥施工

本 Skill 只跑在 **Cursor / Claude Code** 指挥侧。先读宿主 `AGENTS.md` 与
[`workflow-contract.md`](../vibe-coding/references/workflow-contract.md)「指挥施工 Harness」、
[`context-pack.md`](./references/context-pack.md)。

施工侧 Codex 须已安装同版本 `sdd-vibe-coding`（建议 `make install-dev` 软链），质量条由其
默认执行。派单只含 **Context Pack / 薄模板**，合同正文由施工侧读磁盘。

**有 UI 的 Plan/Build：** Pack/薄派单须点名服从宿主已声明的 `UI surface` / `page_kind|motif`，并要求施工侧
先读插件 `design-standards/LOAD-MAP.md`；勿在派单里粘贴长合同。

> **档位真源：** Plan → AD-P（2026-07-27）；Build → AD-B（2026-07-28）。  
> 选用 `gpt-5.6-sol` × medium/high。

## 何时用

| 用 | 指挥侧自做 |
|---|---|
| 用户明示派 Codex / 用 Codex 施工 | 纯小改 / Polish（非 material）且用户未要求 Codex |
| **许愿路径方案确认后的 Build 切片**（硬门：须 Codex + Context Pack） | Shape / 产品拍板 / **验收对话** |
| 已批准有界单元，用 Sol 离场施工 | 已在 Codex 会话里（走纯 Codex Harness） |
| 指挥侧 PATH 上有 `codex` CLI | 无 Oracle 的 Build（先 Plan） |
| 矩阵/剧本**草稿**（非关版） | **Verify / 系列验收 / 「验到可交付」**（钉 3：禁 Codex 主验收） |

**许愿研发编排硬门（Cursor/Claude）：** Spec 已落盘后，每个纵向切片的 Build **必须**经  
`wish-orchestrate.sh` 或「`build_context_pack.py` → `codex-dispatch.sh --unit build`」。  
禁止指挥侧在同一长会话里自己连做多片实现来「代替」Codex（上下文腐烂 + 与短窗口 Codex 目标冲突）。  
无 `codex` CLI → `blocked`，对人说明，勿假装已编排。

**硬门（钉 3）：** 禁止派 Codex 做主验收或「验到可交付」；超时窄派单 = 失败，不得扩成关版。

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
   - Plan：产品包 / 已确认方案 → 整份 Spec 落盘；
   - Build：已批准 Spec + `plan.md` 中**一个**切片（默认第一个未完成切片）；
   - Goal（可选）：仅当用户要连续多片且完成条件可写成验证命令时。
2. **Build 必做 Context Pack**（见 [`context-pack.md`](./references/context-pack.md)）
   ```bash
   python3 skills/dispatch-codex/scripts/build_context_pack.py <HOST> <SPEC_ID> <SLICE_ID> \
     > /tmp/pack.txt
   # 或一次编排多片：
   bash skills/dispatch-codex/scripts/wish-orchestrate.sh --cwd <HOST> --spec <SPEC_ID>
   bash skills/dispatch-codex/scripts/wish-orchestrate.sh --cwd <HOST> --spec <SPEC_ID> --slice S1
   ```
   Pack 含 Goal / Spec 指针 / 触及路径 / T-xxx / Constraints / Done when。  
   **禁止**手写超长 prompt 替代 Pack（缺字段 = 不合格派单）。
3. **预检**
   - Build / Goal：先跑 `check_spec`（CLI 包装默认强制）；
   - Build：确认该片 T-xxx 含 success + failure/permission；
   - 缺 Oracle 或 check_spec 未过 → 先走 Plan。
4. **选定 sol × medium|high** → **经 CLI 包装调用**（参数齐全后再跑）。
5. **验收**（maker ≠ grader）→ 对照仓库 + 证伪；未过则升 effort 再派或指挥侧自做**当前一片**。
6. **对人交付卡**：目标、结果、证据路径、要你决定（下一切片 / 进 Verify / 授权）。

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

- [ ] 走的是 `codex-dispatch.sh` / `wish-orchestrate.sh` / `make codex-dispatch|wish-orchestrate`
- [ ] Build：prompt 来自 `build_context_pack.py`（或字段齐全的等价 Pack）
- [ ] `model` = `gpt-5.6-sol`；effort = medium|high
- [ ] Build/Goal 的 `sandbox` = `danger-full-access`（或接受脚本默认）
- [ ] Build/Goal 已过 `check_spec`（或脚本 `--spec`）
- [ ] Plan：`--spec` + 落盘后 `assert_plan_artifacts`（脚本默认执行）
- [ ] 片间：`require-conductor-falsify` 且日志含 `VERDICT: … PASS`（`wish-orchestrate` 默认强制）
- [ ] 一次只一个完成单元
- [ ] prompt **无**合同大段 / tests 全文
- [ ] 调用勿用会吞失败码的管道（若 `| tee`，须 `set -o pipefail`）

任一项未满足 → 先改参数再调用。

### 超时与验收

1. 脚本默认墙钟：Plan **900s** / Build **1200s** / Goal **3600s**（可用 `--timeout` 覆盖）。
2. exit `124`/`137` → 立刻对照仓库产物验收（diff / Spec / `run.md`）。
3. 若产物已达完成定义 → 对人结案，注明「派发超时中断，已按仓库验收」。
4. 进度以仓库变化为准。

### CLI 包装用法

```bash
# Plan（默认 15min / workspace-write / medium；必须 --spec；成功后验五件套落盘）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit plan --spec <SPEC_ID> -- <<'EOF'
<薄派单正文>
EOF

# Build 单片（默认 20min / danger-full-access / medium；通常需 --spec）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit build --effort medium --spec <SPEC_ID> --slice S1 -- <<'EOF'
<薄派单正文>
EOF

# Wish 逐片：每片后 exit 3 直至 falsify VERDICT: PASS，再派下一片
bash skills/dispatch-codex/scripts/wish-orchestrate.sh \
  --cwd <HOST_ROOT> --spec <SPEC_ID> --slice S1
# 证伪日志须含：VERDICT: S1 PASS
make require-falsify LOG_DIR=<HOST>/.codex-dispatch-logs RUN_ID=<from meta>
bash skills/dispatch-codex/scripts/wish-orchestrate.sh \
  --cwd <HOST_ROOT> --spec <SPEC_ID> --slice S2

# Goal（默认 60min / danger-full-access / high）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit goal --spec <SPEC_ID> -- <<'EOF'
<薄派单正文>
EOF
```

要点：

- 脚本写死 `approval_policy=never`
- **每单前置 CLI authorization 块**：覆盖宿主「先聊计划再等人批」；禁 `doc-coauthoring` / 反问收尾
- **许愿 Plan：禁止中途「待批准」**；Codex exit 0 但未落盘五件套 → 派发失败（exit 2）
- **falsify 须 `VERDICT: PASS`**；仅有日志或 `VERDICT: FAIL` → `require-conductor-falsify` 失败
- 墙钟到点会 `SIGTERM`/`SIGKILL` 并 exit `124`——之后对照仓库验收
- 默认 `--json`：事件写入 `<cwd>/.codex-dispatch-logs/<unit>_<ts>_<pid>.jsonl`（可 `--log-dir` / `--no-json`）
- Make：`make codex-dispatch HOST=… UNIT=plan|build|goal PROMPT_FILE=…`（Plan/Build/Goal 传 `SPEC=`；Build 传 `SLICE=`）
- 离线门闩自检：`bash skills/dispatch-codex/scripts/selftest-gates.sh`

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
--spec <SPEC_ID>   # required: postflight assert_plan_artifacts
按 vibe-coding 走 Plan。产品真源：<PRODUCT_PATH>。
许愿路径：方案已确认 — 禁止「待批准」停点；必须落盘五件套（聊天计划不算完成）。
切一份新 Spec，直接写 VERSION/contract/tests/plan/run；本轮只改 docs。
有 UI：合同写 UI surface（及 page_kind|motif / Design Read / Build 前 anchor）；施工服从 LOAD-MAP（勿贴长文）。
骨架文件名用上述五件套；以插件质量条为准。
齐套后指挥侧跑 check_spec；许愿路径直接进 Build 编排（经典路径才出批准卡）。
```

### Build（单切片 · **必须用 Context Pack**）

```bash
python3 skills/dispatch-codex/scripts/build_context_pack.py <HOST> <SPEC_ID> <SLICE_ID> \
  | bash skills/dispatch-codex/scripts/codex-dispatch.sh \
      --cwd <HOST> --unit build --spec <SPEC_ID> --slice <SLICE_ID> --effort medium
```

Pack 已含 Goal / Context / Constraints / Done when。勿再粘贴 tests 全文。  
手写兜底（仅 Pack 脚本不可用时）须仍含 `SLICE_ID=`、Spec 路径指针、T-xxx、Done when：

```text
SLICE_ID=<SLICE_ID>
SPEC_ID=<SPEC_ID>
## Goal
完成切片 <SLICE_ID>：<入口一句话>（Oracle：<T-ids>）
## Context
- docs/specs/<SPEC_ID>/{contract,tests,plan,run}.md
- paths: <3-8 paths>
## Constraints
只做本片；禁改 tests.md；服从 AGENTS + vibe-coding。
## Done when
T-xxx 行为证据写入 run.md；oracle-freeze: intact；短报告下一片。
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
- [ ] 落盘后给出能否进入 Build 的批准卡（含新对话 Build 提示词）

**硬门（打回）：** 无 `contract.md`，或仅有 context/requirements/tasks/validation/scenario-spec 旧骨架 → 经 CLI 升 `effort=high` 重派或指挥侧自做。

### Build 通过

- [ ] diff 落在该切片相关路径
- [ ] **diff 不含** Spec `tests.md`、产品包 `06-acceptance-matrix` 等验收矩阵（钉 2；改 Oracle 须回 Plan）
- [ ] `run.md` 有 `oracle-freeze: intact` + 红绿证据（或 `N/A · polish|trivial|无自动化`）
- [ ] `run.md` 记录该片批次；T-xxx 有结果（Evidence 含 `kind=`；禁仅 smoke）
- [ ] 完成定义以该片行为证据收口（非整份 Spec done，除非 Goal 真做完且证据齐）
- [ ] **指挥侧证伪**：亲自跑 ≥1 条 falsify（分页两 offset / 排序参数 / 合同 Then）；未跑不算验收通过
- [ ] 证伪输出已 tee 到 `.codex-dispatch-logs/<run-id>_falsify.log`，且  
      `make require-falsify LOG_DIR=<cwd>/.codex-dispatch-logs RUN_ID=<run-id>` 通过
- [ ] 未向用户宣称「可交付」（除非已走 Verify + `make verify-deliver` 且戳在）

**Build 派单：** `--slice <id>` 或 prompt 含 `SLICE_ID=` / `S#`；禁止一次多片（多片 → `--unit goal` + `GOAL_APPROVED=1`）。

未过 → 经 CLI 打回派单（具体缺陷一句）或指挥侧自做；对人只报真实验收结论。

### Verify 禁派（钉 3）

- [ ] 未把「验收 / 验到可交付 / 系列 Version Acceptance」派给 Codex 做主验收
- [ ] 若仅派窄命令：墙钟 ≤20min、完成条件=指定命令 stdout；超时=失败
- [ ] 关版前指挥侧亲自 ≥1 条证伪；可交付前 `make verify-deliver`

## 对人前台

只用「我理解的目标 / 当前进展 / 交付结果 / 需要你决定」。  
默认可说：「复杂 Spec/切片用 Codex Sol；小改我这边做。」  
默认不展示 sandbox、model id、dispatch log；用户追问再放「技术详情（可选）」。  
超时中断且仓库已达标时，对人只说结果与证据。
