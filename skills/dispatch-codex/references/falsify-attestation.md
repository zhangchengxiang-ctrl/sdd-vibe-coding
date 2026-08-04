# 指挥侧证伪取证（Falsify Attestation）

> maker ≠ grader 的**机检载荷**真源。  
> 写入：`record-conductor-falsify.sh`（推荐）或手写等价字段。  
> 校验：`require-conductor-falsify.sh`（默认强制结构化字段）。

## 为什么

仅写 `VERDICT: PASS` 可被空写绕过。取证须绑定**实际跑过的命令与退出码**。

## 必填字段（每行 `KEY: value`）

| 字段 | 规则 |
|------|------|
| `COMMAND` | 非空；指挥侧实际执行的证伪命令（可含参数） |
| `EXIT_CODE` | 非负整数；`VERDICT: … PASS` 时**必须为 0** |
| `VERDICT` | 含 `PASS` 或 `FAIL`（大小写不敏感）；建议 `VERDICT: <SLICE> PASS` |

## 推荐字段

| 字段 | 规则 |
|------|------|
| `SLICE` | 本片 ID（与 `plan.md` 一致） |
| `RUN_ID` | 对应 `codex-dispatch` 的 `run_id` |
| `RECORDED_AT` | ISO8601 UTC |
| `ARTIFACT` | 可选：关键产物路径（相对宿主根或绝对） |
| `ARTIFACT_SHA256` | 若写了 `ARTIFACT` 且文件存在，**必须**有本字段（文件 sha256） |

## 推荐写法

```bash
make record-falsify LOG_DIR=<host>/.codex-dispatch-logs RUN_ID=<id> SLICE=S1 -- \
  <证伪命令…>
# 等价：
bash skills/dispatch-codex/scripts/record-conductor-falsify.sh \
  --log-dir <host>/.codex-dispatch-logs --run-id <id> --slice S1 -- \
  <证伪命令…>
```

成功后日志含 `COMMAND` / `EXIT_CODE: 0` / `VERDICT: S1 PASS`，再：

```bash
make require-falsify LOG_DIR=<host>/.codex-dispatch-logs RUN_ID=<id>
```

## 旁路（仅维护者）

| 环境变量 | 行为 |
|----------|------|
| `SKIP_FALSIFY_VERDICT=1` | 只检查日志非空（**禁止**用户会话） |
| `SKIP_STRUCTURED_FALSIFY=1` | 跳过 COMMAND/EXIT_CODE，仍要 `VERDICT: PASS`（迁移用） |
| `SKIP_FALSIFY_GATE=1` | `wish-orchestrate` 跳过片间闸（**禁止**用户会话） |

旁路写入 stderr 警告；无审计库时以日志 WARN 为准。
