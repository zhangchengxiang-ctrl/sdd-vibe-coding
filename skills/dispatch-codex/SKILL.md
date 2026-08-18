---
name: dispatch-codex
description: >-
  Cursor/Claude 指挥侧把完成单元派给 Codex CLI（Build 默认 gpt-5.6-terra × medium）。
  vibe-coding Build/Repair 轨一律经本 Skill 派发——许愿「确认方案」与经典
  「开始做 / 实现 / Build S1」同样命中；用户明示「派 Codex」亦触发。
  须 Context Pack；一次一个切片（A == D）。
  禁止因改文档 / check_spec / 非 SDD 日常请求加载。通道：codex-dispatch.sh / wish-orchestrate.sh。
disable-model-invocation: true
---

# Dispatch Codex：指挥施工

本 Skill 只跑在 **Cursor / Claude Code** 指挥侧。先读宿主 `AGENTS.md` 与
[`gates.md`](../vibe-coding/references/gates.md)（施工通道）、
[`context-pack.md`](./references/context-pack.md)、
[`cli-authorization.md`](./references/cli-authorization.md)。

施工侧 Codex 须已安装同版本 `sdd-vibe-coding`（建议 `make install-dev` 软链），质量条由其
默认执行。派单只含 **Context Pack / 薄模板**，合同正文由施工侧读磁盘。

**有 UI 的 Plan/Build：** Pack/薄派单须点名服从宿主已声明的 `UI surface` / `page_kind|motif`，并要求施工侧
先读插件 `design-standards/LOAD-MAP.md`；勿在派单里粘贴长合同。

> **档位真源：** Plan → AD-P（2026-07-27）；Build → AD-B（2026-07-28）。  
> **档位 = 配额杠杆，非质量杠杆**（三档均过仓内 Plan 门；75 次全钉 Sol 烧穿了配额窗）。
> 预设在 `$CODEX_HOME/sdd-*.config.toml`，`--profile` 选。

## 何时用

| 用 | 指挥侧自做 |
|---|---|
| **vibe-coding Build/Repair 轨的每个 D**（许愿或经典「开始做」；打包 + Codex + Context Pack） | Polish / trivial；Repair 小缺口（≤2 文件）；用户明文「你自己写」（真源 [`gates.md`](../vibe-coding/references/gates.md)） |
| 用户明示派 Codex / 用 Codex 施工 | Shape / 产品拍板 / 改文档 / `check_spec` / 锁决策 / **验收对话** |
| 已批准有界单元，用 Sol 离场施工 | 已在 Codex 会话里（走纯 Codex Harness） |
| 矩阵/剧本**草稿**（非关版） | 无 Oracle 的 Build（先 Plan）；**Verify / 系列验收**（钉 3：禁 Codex 主验收） |

**施工通道硬门（Cursor/Claude，真源 workflow-contract「施工通道」）：** Spec 已落盘后，每个 **D** 的 Build **必须**经  
`wish-orchestrate.sh` 或「`pack_dispatch_units.py` → `build_context_pack.py` → `codex-dispatch.sh --unit build`」。  
禁止指挥侧在同一长会话里自己连做多 D 实现来「代替」Codex。一聊一个 edit-wave。  
无 `codex` CLI → `blocked`，对人说明，勿假装已编排。

**硬门（钉 3）：** 禁止派 Codex 做主验收或「验到可交付」；超时窄派单 = 失败，不得扩成关版。

## 模型与思考深度

| 完成单元 | 模型 | effort |
|---|---|---|
| Plan | `gpt-5.6-sol` | **high**（低频高杠杆，值这个钱） |
| Build 单 D | **`gpt-5.6-terra`** | **medium**（默认） |
| 机械改（rename / 格式 / 文档同步） | `gpt-5.6-luna` | **low** |

口诀：**Build 默认 terra×medium**，真难再升 sol。升档**不**修 Oracle 可执行性（terra×high 3/8 < medium 3/6）——靠机检门。

## 流程（一次一个 D）

1. **选定单元**
   - Plan：产品包 / 已确认方案 → 整份 Spec 落盘；
   - Build：已批准 Spec → `pack_dispatch_units.py` 得到 D（默认第一个未完成 D）；
   - 多 Spec / 多 D：先出 DAG+波次；一聊一个 edit-wave。
2. **Build 必带 Context Pack**（见 [`context-pack.md`](./references/context-pack.md)）;一个切片 = 一次 exec，不再打包
   ```bash
   python3 skills/dispatch-codex/scripts/pack_dispatch_units.py <HOST> <SPEC_ID> --list
   python3 skills/dispatch-codex/scripts/build_context_pack.py <HOST> <SPEC_ID> S1 \
     > /tmp/pack.txt
   bash skills/dispatch-codex/scripts/wish-orchestrate.sh --cwd <HOST> --spec <SPEC_ID>
   bash skills/dispatch-codex/scripts/wish-orchestrate.sh --cwd <HOST> --spec <SPEC_ID> --slice S1
   ```
   Pack 含 SLICE_ID / allowlist / T-xxx / 冻结 Oracle / Done when。  
   **禁止**手写超长 prompt 替代 Pack；**禁止**空 allowlist。
3. **预检**
   - Build：先跑 `check_spec`（CLI 包装默认强制）；
   - Build：确认该片 T-xxx 含 success + failure/permission；
   - 缺 Oracle 或 check_spec 未过 → 先走 Plan。
4. **选定档位**（或 `--profile sdd-build`）→ **经 CLI 包装调用**（参数齐全后再跑）。
5. **验收**（maker ≠ grader）→ 对照仓库 + 证伪；未过则升 effort 再派或指挥侧自做**当前 D**。
6. **对人交付卡**：目标、结果、证据路径、要你决定（下一 edit-wave / 进 Verify / 授权）。

## 工具（正路径）

**硬门：** 派发只经下方 CLI；不经 `user-codex` / `CallMcpTool`（`codex` / `codex-reply`）。模型 `gpt-5.6-sol|terra|luna`，effort `minimal|low|medium|high|xhigh|max`。

优先顺序：

1. **CLI 包装（默认）**  
   `skills/dispatch-codex/scripts/codex-dispatch.sh`  
   （或 `make codex-dispatch`）— `approval_policy=never` + 墙钟 `timeout` + 默认 JSONL 日志
2. 包装缺失或 `codex` 不在 PATH → 状态 `blocked`，对人如实说。**没有裸命令兜底**（见下）。

### 必传参数

| 参数 | 值 |
|---|---|
| `cwd` / `-C` | 宿主仓根（或约定 worktree） |
| `model` / `-m` | `gpt-5.6-terra`（build 默认）· `gpt-5.6-sol`（plan） |
| `model_reasoning_effort` / config | `medium`（Build 默认）；或用 `--profile` |
| `approval-policy` | `never`（脚本写死） |
| `sandbox` | Plan：`workspace-write`；Build：`danger-full-access`（默认） |

### CLI 调用前自检

- [ ] 走的是 `codex-dispatch.sh` / `wish-orchestrate.sh` / `make codex-dispatch|wish-orchestrate`
- [ ] Build：prompt 来自 `build_context_pack.py`（或字段齐全的等价 Pack）
- [ ] 已跑 `make codex-preflight HOST=…`（trust 登记 / AGENTS 32KiB / profile）
- [ ] Build 已过 `check_spec`（或脚本 `--spec`）
- [ ] Plan：`--spec` + 落盘后 `assert_plan_artifacts`（脚本默认执行）
- [ ] 片间：`ship.sh --from-meta <run>.meta.txt` 红绿 replay 过（基线红→改后绿;基线也绿即无效 Oracle）
- [ ] 多切片必带 `--dispatch-id`（脚本硬拒无界多切片）
- [ ] prompt **无**合同大段 / tests 全文
- [ ] 调用勿用会吞失败码的管道（若 `| tee`，须 `set -o pipefail`）

任一项未满足 → 先改参数再调用。

### 失败分类（别把配额当能力）

| meta 字段 / exit | 含义 | 该怎么办 |
|---|---|---|
| `failure_class=quota` · exit **75** | 订阅窗口烧穿，**没连上模型**。附 `quota_retry_hint=` | 降档（`--model gpt-5.6-terra\|luna`）或等重置；**不是实现失败，不要改代码** |
| exit `124`/`137` | 墙钟到点 | 对照仓库产物验收 |
| `run_state=started` 但无 `run_state=finished` | 进程被杀/崩溃 | 判失败重派；**不得当成功** |
| jsonl 无 `turn.completed` | 未收尾 | 判失败（所有 unit 通用） |

### 红绿 replay（`ship.sh`）

派发回来后，**由指挥侧**逐条 replay 冻结 Oracle，而不是读 Codex 写的台账：

```bash
bash skills/dispatch-codex/scripts/ship.sh --host <HOST> --spec <ID> --slice <S1> \
  --from-meta <LOG_DIR>/<RUN_ID>.meta.txt          # 基线 SHA 由派发时写入 meta
```

- **先红后绿**：基线就绿 → `nondiscriminating`（功能缺席时也过 ⇒ 什么都没量），且不跑 verify；
  因缺依赖/二进制而红 → `inconclusive`，不算证据（`--link` 挂依赖重跑）。
- `人工` Oracle 报 `OWED`：不进 replay 集，不由退出码结案。
- 取证 `<HOST>/.sdd-evidence/<spec>-<unit>.jsonl`（phase/tree/exit/sha256），`--resume` 续跑。
  exit 0 全绿 · 1 有判据未过 · 2 拒绝执行。

### 超时与验收

1. 脚本默认墙钟：Plan **900s** / Build **1200s**（可用 `--timeout` 覆盖）。
2. exit `124`/`137` → 立刻对照仓库产物验收（diff / Spec / `run.md`）。
3. 若产物已达完成定义 → 对人结案，注明「派发超时中断，已按仓库验收」。

### CLI 包装用法

```bash
# Plan（默认 15min / workspace-write / sol×high；必须 --spec；成功后验五件套落盘）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit plan --spec <SPEC_ID> -- <<'EOF'
<薄派单正文>
EOF

# Build 单切片（默认 20min / danger-full-access / medium）
bash skills/dispatch-codex/scripts/codex-dispatch.sh \
  --cwd <HOST_ROOT> --unit build --effort medium --spec <SPEC_ID> \
  --slice S1 -- <<'EOF'
<薄派单正文 / Context Pack>
EOF

# Wish edit-wave：一波切片（可并行 1–4）后 exit 3，红绿 replay 过再派下一波。
# 下一次调用会自己先跑 replay 门,不需要手动记账。
bash skills/dispatch-codex/scripts/wish-orchestrate.sh \
  --cwd <HOST_ROOT> --spec <SPEC_ID> --parallel 2
bash skills/dispatch-codex/scripts/wish-orchestrate.sh \
  --cwd <HOST_ROOT> --spec <SPEC_ID>
# 状态：wish-orchestrate … --status / --units

```

要点：

- 脚本写死 `approval_policy=never`
- **每单前置 CLI authorization 块**：覆盖宿主「先聊计划再等人批」；禁 `doc-coauthoring` / 反问收尾
- **许愿 Plan：禁止中途「待批准」**；Codex exit 0 但未落盘五件套 → 派发失败（exit 2）
- **验收靠 replay 不靠手写取证**：`ship.sh --from-meta <meta>` 逐条跑冻结的 Oracle，先证它在该派发
  的 `base_sha` 上是**红**的，改后必须绿。基线也绿 → 判 `nondiscriminating`（该 Oracle 什么都没测）
- **wish-orchestrate：** per-spec flock + per-切片锁；波次内可并行（依赖 + 编辑锁决定，不再按估峰打包）；`PASSED_SLICES` 幂等跳过；`--force-slice` 才重派
- **动作计数不是估峰**：meta 记 `actions=`，≥150 警告。实测悬崖 200（≤50 → 3%、51–200 → 64%、200+ → 100% 被压缩）
- 墙钟到点会 `SIGTERM`/`SIGKILL` 并 exit `124`——之后对照仓库验收
- `--json` 是**必需**（完成信号=`turn.completed`）；`--no-json` 被拒，除非 `SKIP_TURN_CHECK=1`。日志目录可 `--log-dir`
- Make：`make codex-dispatch HOST=… UNIT=plan|build PROMPT_FILE=…`（都传 `SPEC=`；Build 传 `SLICE=`）
- 离线门闩自检：`bash skills/dispatch-codex/scripts/selftest-gates.sh`

**无裸 `codex exec` 兜底。** 手搓命令会丢掉配额分类、`run_state`、`turn.completed` 判定
与 worktree 隔离（四个已修失效一次复原）。包装缺失 → `blocked`。

## 薄派单模板

### Plan

```text
cwd: <HOST_ROOT>
model: gpt-5.6-sol
effort: high
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

### Build（一个切片 · **必须用 Context Pack**）

```bash
python3 skills/dispatch-codex/scripts/build_context_pack.py <HOST> <SPEC_ID> S1 \
  | bash skills/dispatch-codex/scripts/codex-dispatch.sh \
      --cwd <HOST> --unit build --spec <SPEC_ID> --slice S1 --effort medium
```

Pack 已含 SLICE_ID / Goal / Context / Constraints / 冻结 Oracle / Done when。勿再粘贴 tests 全文。  
手写兜底（仅 Pack 脚本不可用时）须仍含 `SLICE_ID=`、Spec 路径指针、T-xxx、Done when：

```text
SLICE_ID=S1
SPEC_ID=<SPEC_ID>
## Goal
完成切片 S1：<入口一句话>（Oracle：<T-ids>）
## Context
- docs/specs/<SPEC_ID>/{contract,tests,plan,run}.md
- paths: <3-8 paths>
## Constraints
只做本 D allowlist；禁改 tests.md；服从 AGENTS + vibe-coding。
## Done when
各片 T-xxx 行为证据写入 run.md；oracle-freeze: intact；短报告下一 edit-wave。
```

## 验收清单（只列派发特有项）

**共有的 Build/Verify 关版判据不在本文件** —— owner 是
[`rails.md`](../vibe-coding/references/rails.md)（钉 1/2、`oracle-freeze`、红绿证据、
`verify-deliver`、关版分叉）与 [`verification-loop.md`](../vibe-coding/references/verification-loop.md)（钉 3）。

### Plan 派发通过

- [ ] 五件套落盘（脚本 postflight `assert_plan_artifacts` 已强制）
- [ ] 本轮仅 docs/handoff 改动
- [ ] 硬门：无 `contract.md` 或仅旧骨架 → 升 effort 重派或指挥侧自做

### Build 派发通过

- [ ] diff 落在该 D 的 allowlist（Pack 必填；空 allowlist 不得派）

### Verify 禁派（钉 3 · 收窄）

- [ ] Codex **可**做 diff 对冻结 Oracle 的机检与对抗审计（`codex exec -s read-only`）
- [ ] **关版授权仍只属指挥侧/人**；不得把「验到可交付」整体派出
- [ ] 若仅派窄命令：墙钟 ≤20min、完成条件=指定命令 stdout；超时=失败

## 对人前台

只用「我理解的目标 / 当前进展 / 交付结果 / 需要你决定」。  
默认可说：「复杂 Spec/切片用 Codex Sol；小改我这边做。」  
默认不展示 sandbox、model id、dispatch log；用户追问再放「技术详情（可选）」。  
超时中断且仓库已达标时，对人只说结果与证据。
