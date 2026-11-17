# 派发基础设施加固（Phase A 六项）

> 原独立技能 `codex-dispatch-hardening`，2026-11-17 并入 `dispatch-codex`（同一条流水线的基础设施部分，默认值曾在两处各写一遍）。默认档位与阶梯以 [`delegation-policy.md`](./delegation-policy.md) 为准。

## 适用场景
- 由 orchestration 脚本把任务派给 codex exec 的生产链路；代理执行不稳定、失败难归因。
- 需要区分配额耗尽/崩溃/超时，保证并行切片零污染，未登记宿主不无人值守。

## 前置条件
- codex-cli 已装（本技能基线 0.147.0）；mock codex 用于本地实测。
- 宿主 trust 已登记（`[projects."<path>"] trust_level = "trusted"`），否则无人值守会卡。

## 步骤（A1-A6）
1. **档位白名单代替硬 die**：MODEL 默认 gpt-6.1-sol、effort 默认 low（2026-11-17 矩阵；原 build→terra×medium 已被取代，配额耗尽按 `dispatch-codex/references/delegation-policy.md` 阶梯降 terra medium），白名单外 warning 不 die；--profile 透传，profile 只在 -m/-c effort 省略时生效。
2. **失败分类**：usage limit → failure_class=quota + exit 75(EX_TEMPFAIL) + 落盘重试时间；崩溃/超时/能力失败分开。
3. **完成信号**：meta 先写 run_state=started，结束写 finished + exit_status；turn.completed 判定扩到所有 unit；拒 --no-json。
4. **多切片护栏**：多切片无 --dispatch-id 硬拒 + slice token 格式校验。
5. **并行隔离**：git worktree（钉 SHA、路径含 CWD 哈希、脏树拒复用、日志集中到仓外且显式 --log-dir）；不再对每路传同一 --cwd。
6. **preflight**：scripts/codex-preflight.sh + make codex-preflight；检查 trust 未登记、**项目** AGENTS.md 链对 32 KiB 上限（`~/.codex/AGENTS.md` 全局文件单独加载，**不计入**；2026-11-17 实测 32,287 B 的项目文档在默认配置下完整加载、未截断，旧口径把全局文件加进去会误报 FAIL）。

## 红线 / 注意
- **配额检测作用域**：只扫 error/turn.failed 事件 + stderr 兜底，绝不全文扫 jsonl——脚本自身文本就可能含匹配串，误判配额耗尽（实测自伤）。
- 新门必须接线 + 探针：「有目标≠会跑」——检查脚本是否被 Makefile/public-gates 引用；探针必须能变异变红（否则是装饰）。
- 软链的 node_modules 会让脏树检查误判 → 过滤自建软链。
- gate-cases.tsv 类登记册：REF 必须绑定到 runner 亲自跑过的探针；不加静态「口号存在性」断言。
- 独立审查（codex exec -s read-only）：提 10 条采纳 8；注意它可能读修复前 diff，逐条判后修。

## 验收标准
- 三类失败（配额/崩溃/超时）可区分；无 exit_status 判失败。
- 并行 N 路主仓零污染、各 worktree 文件哈希不同。
- 关键探针做过变异测试；selftest 计数不下降。
