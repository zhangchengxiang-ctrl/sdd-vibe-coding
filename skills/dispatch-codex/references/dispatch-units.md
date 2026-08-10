# 派发单元（A / D / C）

> Codex 编排真源。验收轴仍见 Skill `spec` 纵向切片；本页只管 **272K 窗口** 与 **并行锁**。  
> 生成：`pack_dispatch_units.py` / `schedule_waves.py`。派发：`wish-orchestrate.sh` / `codex-dispatch.sh`。

## 1. 三层（禁止焊成一层）

| 层 | 是什么 | 谁写 | 谁消费 |
|---|---|---|---|
| **A 验收单元** | 纵向切片 / `T-xxx` | `plan.md` 按**用户入口** | `check_spec`、`run.md`、人/机器关版 |
| **D 派发单元** | 一次 fresh `codex exec` | **机器打包**，作者禁止手切 | `codex-dispatch`、Context Pack |
| **C 资源声明** | `writes[]` + `reads[]` + `depends_on[]` + `claims[]` + `oracle_kind` | `plan.md` 触及路径 / 依赖 / 备注（或列） | `schedule_waves.py` |

**一次 exec = 一个 D。** 「一次一个完成单元」只约束这件事，**不是**全机同时只能跑一个 Codex。

## 2. 窗口（gpt-5.6-sol / Codex CLI）

- 输入预算 **272K**（计费线）；有效约 **258K**。  
- 过线：整单加价，且 **auto-compact**（历史换成 handoff summary，有损）。  
- 打包阈值 **`compact_limit=180000`**（默认）；估峰超过 → **拆 D 或回 Plan**，禁止 `--unit goal` 硬撑。  
- 估峰：`baseline + pack + Σ(allowlist ∪ 1-hop) × chatter(3) + test_log_budget`。  
- 基线未测时默认 `40000`。宿主可把实测写入 `AGENTS.md`：`Codex harness baseline tokens: <n>`。  
- allowlist **必填**（来自触及路径）；空路径 = 不合格 Pack，不得派。  
- Repair = **新 exec**（diff + 失败测试 + allowlist）。  
- **结束信号：** `codex exec --json` 的 `turn.completed` + `--output-last-message`；进程 exit ≠ 猜测 `ls` meta。缺 `turn.completed` → 该 D 失败。  
- **compact：** 只认 jsonl 事件类型（`compaction` / `compact` / …），禁止用 `usage.input_tokens`（累计计费，常含 cache，不是窗宽）。命中 → 该 D 失败，禁止 resume。

Goal 仅当：**已经估过能装进 180K 的一个 D**（只是含多个 A）。不是「多片的官方出口」。

## 3. 打包规则（A → D）

1. 同一 write-set（路径相交、前缀包含、或 ≥3 段公共目录）且估峰 ≤ 180K → **合成一个 D**。  
2. 依赖只指向本 D 已含的 A（或无依赖）才可并入。  
3. 单 A 估峰 > 180K → 标 `too_large`，不得 Goal；回 Plan 砍 allowlist / 拆 Spec。  
4. `plan.md` 仍按入口写 A；**禁止**按「Codex 回合」手切 A。

## 4. 并行（两把锁）

| 锁 | 冲突 → 串行 | 不冲突 → 可并行 |
|---|---|---|
| **编辑锁** | write 相交，或 A.writes ∩ B.reads，或 DAG 有边 | 多路 `codex exec`（必要时 worktree） |
| **验证锁** | `claims` 相交（同一 lab / 端口 / 集群） | `oracle_kind=unit\|machine` 且 claims 空可并行 |

调度拆波：

```text
edit-wave    编辑锁就绪的 D → 扇出 ≤N 路 Codex（默认 N=2，上限 4）
verify-wave  验证锁就绪的 Oracle；共享 lab 排队
```

falsify **不得**挡住下一个编辑锁不冲突、DAG 无边的 edit-wave。  
`workspace-contract` §4 仍是文字合同；**执行**以本页 + `schedule_waves.py` 为准。

跨 Spec 依赖写成 `spec-id:slice-id`（如 `v2026.08-track-data-contract:S1`）。自由文本（`data-contract` / `D4`）不当硬边。

## 5. `oracle_kind` / `claims`（plan.md）

备注或可选列：

- `oracle:unit|machine|lab|human`（缺省 `machine`）  
- `claims:kind-datagate,port:9030`（缺省空）  
- lab/k8s/kind 出现在备注且未写 oracle → 视为 `lab`

## 6. 指挥侧

- 改文档 / `check_spec` / 锁决策 → **指挥侧自做**，禁止因此派 Codex。  
- 多 Spec / 预估多个 D：先出 DAG+波次，禁止单聊默默 for-loop。  
- 一聊默认最多 **一个 edit-wave**（或一个已估窗口的 D）；下一波新开。  
- 对人：无 UI 出[证据卡](../../testing/references/human-acceptance-pack.md)；有 UI 出验收包。
