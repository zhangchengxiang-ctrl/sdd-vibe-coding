# Tests · live-relay-1

> 无 UI。Oracle = pytest 断言状态码 / code / remaining。禁止只写「能跑」。

## 索引

| ID | R | Type | 层 | Channel | 标题 |
|---|---|---|---|---|---|
| T-001 | R-001 | success | V1 | unit | 合法 token validate ok + mint 往返 |
| T-002 | R-001 | failure / permission | V1 | unit | missing / invalid mac / expired |
| T-003 | R-002 | success | V1 | unit | 窗口内前 3 次不 limited，remaining 递减 |
| T-004 | R-002 | failure / permission | V1 | unit | 第 4 次 limited；窗口过期重置；token 隔离 |
| T-005 | R-003 | success | V1 | unit | 合法 event ingest 204 |
| T-006 | R-003 | failure / permission | V1 | unit | 缺 type / 空 type / payload 非 dict / 超大 → 400 |
| T-007 | R-004 | success | V1 | unit | gateway 合法 token+event → 204 |
| T-008 | R-004 | failure / permission | V1 | unit | gateway 401/429/400 |

## 执行约束

- 命令：`PYTHONPATH=. python3 -m pytest tests -q`
- Then 必须是具体 code/status/remaining，禁止只写通过
- 结果只记 `run.md`

---

## T-001 · 合法 token

- Requirement: R-001
- Type: success
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：ingest-worker 单测进程
- 数据 / 夹具：SECRET=`live-relay-fixture-secret`；exp=now+3600；mac=sha256(project.kid.exp.SECRET)[:16]
- 环境 / URL：PYTHONPATH=. 本地

### When

1. 构造 `projA.k1.{exp}.{mac}`
2. 调用 `validate(token, now=now)`
3. 调用 `mint("p2","kid9",exp)` 再 validate

### Then（Oracle）

- validate ok is True，project=`projA`，kid=`k1`，exp 等于输入
- mint 往返 validate ok，project=`p2`
- 返回 dict 不含原始 token 全串

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_token.py -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：ok False 或 project 不对

---

## T-002 · token 失败路径

- Requirement: R-001
- Type: failure / permission
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：ingest-worker
- 数据 / 夹具：空串；错误 mac；exp=now-10 的合法 mac token
- 环境 / URL：本地 pytest

### When

1. validate("")
2. validate(projA.k1.exp.deadbeefdeadbeef)
3. validate(过期但 mac 正确的 token)

### Then（Oracle）

- 空串 → `{ok: False, code: missing}`
- 错 mac → `{ok: False, code: invalid}`
- 过期 → `{ok: False, code: expired}`

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_token.py -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：任一 code 不对

---

## T-003 · 限流成功窗口

- Requirement: R-002
- Type: success
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：ingest-worker
- 数据 / 夹具：同一 token，window=10，limit=3，共享 store dict
- 环境 / URL：本地 pytest

### When

1. 同一 now 窗口内连续 check 3 次

### Then（Oracle）

- 三次 limited=False
- remaining 依次为 2、1、0

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_rate.py::test_allows_up_to_limit -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：remaining 不递减

---

## T-004 · 限流拒绝与重置

- Requirement: R-002
- Type: failure / permission
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：ingest-worker
- 数据 / 夹具：tok-b 打满 3 次；tok-c 打满后 now+11；tok-d 打满后换 tok-e
- 环境 / URL：本地 pytest

### When

1. 第 4 次 check tok-b
2. tok-c 在 now+11 再 check
3. tok-d 打满后 check tok-e

### Then（Oracle）

- 第 4 次 limited=True remaining=0
- 窗口过期后 limited=False remaining=2
- 另一 token limited=False

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_rate.py -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：第 4 次仍放行

---

## T-005 · ingest 合法事件

- Requirement: R-003
- Type: success
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：ingest-worker
- 数据 / 夹具：`{"type":"click","payload":{"x":1}}`
- 环境 / URL：本地 pytest

### When

1. ingest(合法 event)

### Then（Oracle）

- status 等于 204

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_collect.py::test_valid_event_204 -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：status 不是 204

---

## T-006 · ingest 拒绝坏事件

- Requirement: R-003
- Type: failure / permission
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：ingest-worker
- 数据 / 夹具：缺 type；type=""；payload 为 list；json 长度>8192 的 blob
- 环境 / URL：本地 pytest

### When

1. 分别 ingest 四种坏事件

### Then（Oracle）

- 缺 type / 空 type / payload 非 dict → status=400 code=`bad_event`
- 超大 → status=400 code=`too_large`

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_collect.py -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：仍返回 204

---

## T-007 · gateway 成功

- Requirement: R-004
- Type: success
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：cli-caller
- 数据 / 夹具：合法 mint/mac token + 合法 event + 空 store
- 环境 / URL：本地 pytest

### When

1. handle(token, event, now=now, store={})

### Then（Oracle）

- status 等于 204

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_gateway.py::test_gateway_ok_204 -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：NotImplementedError 或非 204

---

## T-008 · gateway 失败映射

- Requirement: R-004
- Type: failure / permission
- 层: V1
- Channel: unit

### Given

- 角色 / 账号：cli-caller
- 数据 / 夹具：非法 token；过期 token；同一 token 连打 4 次；缺 type 的 event
- 环境 / URL：本地 pytest

### When

1. handle("not-a-token", 合法 event)
2. handle(过期 token, 合法 event)
3. 同一 token handle 4 次
4. handle(合法 token, 缺 type event)

### Then（Oracle）

- 非法/过期 → 401
- 第 4 次 → 429
- 坏事件 → 400

### 自动化

- 命令：`PYTHONPATH=. python3 -m pytest tests/test_gateway.py -q`
- 预期 Evidence Kind：`unit`
- 红灯条件：状态码映射错误
