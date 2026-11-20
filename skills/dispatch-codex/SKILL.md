---
name: dispatch-codex
description: >-
  Cursor/Claude 指挥侧把 **Codex-eligible** 完成单元派给 Codex CLI（Build 默认 gpt-6.1-sol × low；路由/阶梯/验收见 references/delegation-policy.md）。
  仅当切片过 [`codex-boundary.md`](references/codex-boundary.md)：机验 Oracle、文件级 allowlist、无 UI/Plan。
  许愿「确认方案」与经典「开始做」命中后先判边界；越界禁止自动派；用户明确命令派发即放行（CODEX_DISPATCH_OVERRIDE=user-command）。只读审计/盘点走 --unit audit。
  须 Context Pack；一次一个切片（A == D）。
  禁止因改文档 / check_spec / 非 SDD 日常请求加载。通道：codex-dispatch.sh / wish-orchestrate.sh。亦覆盖派发链路的配额检测、完成信号、多切片并行隔离、preflight 环境门。
disable-model-invocation: true
---

# Dispatch Codex：指挥施工

本 Skill 只跑在 **Cursor / Claude Code** 指挥侧。先读宿主 `AGENTS.md` 与
[`gates.md`](../vibe-coding/references/gates.md)（施工通道）、
[`codex-boundary.md`](./references/codex-boundary.md)、
[`delegation-policy.md`](./references/delegation-policy.md)（路由 / 档位阶梯 / 成本与验收协议）、
[`dispatch-hardening.md`](./references/dispatch-hardening.md)（配额分类 / 完成信号 / worktree 隔离 / preflight）、
[`context-pack.md`](./references/context-pack.md)、
[`cli-authorization.md`](./references/cli-authorization.md)。

施工侧 Codex 须已安装同版本 `sdd-vibe-coding`（建议 `make install-dev` 软链），质量条由其
默认执行。派单只含 **Context Pack / 薄模板**，合同正文由施工侧读磁盘。

**有 UI 的切片：禁止派 Codex**（指挥侧做）。Pack 只服务 eligible 后端/机械片。

> **档位真源：** Build → AD-B（2026-07-28）。Plan **不派 Codex**。  
> **档位 = 配额杠杆，非质量杠杆**。预设在 `$CODEX_HOME/sdd-*.config.toml`，`--profile` 选。

## 何时用

真源 [`codex-boundary.md`](./references/codex-boundary.md)：先 `assert_codex_eligible.py`；eligible → Pack + `--unit build`；否则指挥侧 + `executor: conductor`。用户明确命令派发 = 放行（override 留痕）。`--unit plan` 默认拒绝。钉 3：禁 Codex 主验收。

## 模型与思考深度

| 完成单元 | 模型 | effort |
|---|---|---|
| Build 单 D（eligible） | **`gpt-6.1-sol`** | **low**（默认；2026-11-17 矩阵） |
| 机械改（rename / 格式 / 文档同步） | `gpt-5.6-luna` | **low** |

口诀：**Build 默认 sol×low**；配额耗尽（exit 75）降 `gpt-6.1-terra medium`；验收红一轮后同档补修一次，再红升 `gpt-6-astra medium` 一次，仍红指挥侧自做。
**升 effort 不换质量**（2026-07：terra×high 3/8 < medium 3/6；2026-11-17：sol×low ≥ sol×medium，terra×low 与 luna×low 在最难任务上做不成）——杠杆是**模型档位**，不是深度。
`luna` 任何档位都不用于非机械任务。完整路由（含 Haiku 子代理、DeepSeek 通道、成本协议、行为评审）见 [`delegation-policy.md`](./references/delegation-policy.md)。

## 流程（一次一个切片）

1. **选定单元**
   - Plan：产品包 / 已确认方案 → **指挥侧**整份 Spec 落盘（禁止 `--unit plan`）；
   - Build：已批准 Spec → `assert_codex_eligible.py`；不合格指挥侧做；合格才 `build_context_pack.py --waves`；
   - 多 Spec：一聊一个 edit-wave。
2. **Build 必带 Context Pack**（见 [`context-pack.md`](./references/context-pack.md)）;一个切片 = 一次 exec，不再打包
   ```bash
   bash skills/dispatch-codex/scripts/wish-orchestrate.sh --cwd <HOST> --spec <SPEC_ID> --units
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
   - 缺 Oracle 或 check_spec 未过 → 先走 Plan（指挥侧）。
   - 边界未过 → 指挥侧实现，不派。
4. **选定档位**（或 `--profile sdd-build`）→ **经 CLI 包装调用**（参数齐全后再跑）。
5. **验收**（maker ≠ grader）→ 对照仓库 + 证伪；未过则升 effort 再派或指挥侧自做**当前 D**。
6. **对人交付卡**：目标、结果、证据路径、要你决定（下一 edit-wave / 进 Verify / 授权）。

## 工具（正路径）

只读审计/盘点：`codex-dispatch.sh --cwd <DIR> --unit audit -- <prompt>`（固定 read-only，无需 Spec）。

**硬门：** 派发只经下方 CLI；不经 `user-codex` / `CallMcpTool`（`codex` / `codex-reply`）。模型 `gpt-5.6-sol|terra|luna`，effort `minimal|low|medium|high|xhigh|max`。

优先顺序：

1. **CLI 包装（默认）**  
   `skills/dispatch-codex/scripts/codex-dispatch.sh`  
   （或 `make codex-dispatch`）— `approval_policy=never` + 墙钟 `timeout` + 默认 JSONL 日志
2. 包装缺失或 `codex` 不在 PATH → 状态 `blocked`，对人如实说。**不裸跑 codex exec：只读任务用 --unit audit，用户命令越界用 override；包装缺失才是 blocked。**（见下）。

### 必传参数

| 参数 | 值 |
|---|---|
| `cwd` / `-C` | 宿主仓根（或约定 worktree） |
| `model` / `-m` | `gpt-5.6-terra`（build 默认） |
| `model_reasoning_effort` / config | `medium`（Build 默认）；或用 `--profile` |
| `approval-policy` | `never`（脚本写死） |
| `sandbox` | Build：`danger-full-access`（默认） |

### CLI 调用前自检

- [ ] 走的是 `codex-dispatch.sh` / `wish-orchestrate.sh` / `make codex-dispatch|wish-orchestrate`
- [ ] Build：prompt 来自 `build_context_pack.py`（或字段齐全的等价 Pack）
- [ ] 已跑 `make codex-preflight HOST=…`（trust 登记 / AGENTS 32KiB / profile）
- [ ] Build 已过 `check_spec`（或脚本 `--spec`）且 `assert_codex_eligible.py` 为 eligible
- [ ] `--unit plan` **不得**出现在用户会话（维护者才可 `SKIP_CODEX_BOUNDARY=1`）
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

1. 脚本默认墙钟：Build **1200s**（可用 `--timeout` 覆盖）。
2. exit `124`/`137` → 立刻对照仓库产物验收（diff / Spec / `run.md`）。
3. 若产物已达完成定义 → 对人结案，注明「派发超时中断，已按仓库验收」。

### CLI 包装用法

```bash
# Build 单切片（默认 20min / danger-full-access / medium）— 须 Codex eligible
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
- **许愿 Plan：指挥侧落盘**；禁止派 `--unit plan`
- Make：`make codex-dispatch HOST=… UNIT=build PROMPT_FILE=…`（传 `SPEC=` + `SLICE=`）;自检 `make dispatch-gates-selftest`
- **验收靠 replay 不靠手写取证**：`ship.sh --from-meta <meta>` 逐条跑冻结的 Oracle，先证它在该派发
  的 `base_sha` 上是**红**的，改后必须绿。基线也绿 → 判 `nondiscriminating`（该 Oracle 什么都没测）
- **wish-orchestrate：** per-spec flock + per-切片锁；波次内可并行（依赖 + 编辑锁决定，不再按估峰打包）；`PASSED_SLICES` 幂等跳过；`--force-slice` 才重派
- **动作计数不是估峰**：meta 记 `actions=`，≥150 警告。实测悬崖 200（≤50 → 3%、51–200 → 64%、200+ → 100% 被压缩）
- 墙钟到点 `SIGTERM`/`SIGKILL` + exit `124`;`--json` **必需**（完成信号=`turn.completed`），`--no-json` 被拒

**不裸跑 codex exec：只读任务用 --unit audit，用户命令越界用 override；包装缺失才是 blocked。** 手搓命令会丢掉配额分类、`run_state`、`turn.completed` 判定
与 worktree 隔离（四个已修失效一次复原）。包装缺失 → `blocked`。

## 薄派单模板

Plan **不派 Codex**。指挥侧按 Skill `spec` 落盘五件套后，只对 eligible 片生成 Pack。

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
- docs/iterations/<yyyy-mm>/<w>/<版本>/<SPEC_ID>/{contract,tests,plan,run}.md
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

### Plan 落盘（指挥侧，不派 Codex）

- [ ] 五件套落盘（指挥侧跑 `assert_plan_artifacts` / `check_spec`）
- [ ] 本轮仅 docs/handoff 改动

### Build 派发通过

- [ ] diff 落在该 D 的 allowlist（Pack 必填；空 allowlist 不得派）

### Verify 禁派（钉 3 · 收窄）

- [ ] Codex **可**做 diff 对冻结 Oracle 的机检与对抗审计（`codex exec -s read-only`）
- [ ] **关版授权仍只属指挥侧/人**；不得把「验到可交付」整体派出
- [ ] 若仅派窄命令：墙钟 ≤20min、完成条件=指定命令 stdout；超时=失败

## 对人前台

**Explore**（用户未进 Deliver）：直接答问题 + 证据/命令摘要；**不用**固定四段卡片。  
**Deliver**：用「交付结果 / 需要你决定」；Build/Verify 可附进展。  
默认可说：「过边界的切片用 Codex；Plan/UI/判断力任务我这边做。」  
Explore/Deliver 真源：[`explore-deliver.md`](../vibe-coding/references/explore-deliver.md)。  
默认不展示 sandbox、model id、dispatch log；用户追问再放「技术详情（可选）」。  
超时中断且仓库已达标时，对人只说结果与证据。
