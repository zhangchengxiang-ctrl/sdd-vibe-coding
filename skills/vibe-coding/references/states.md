# States（关版 / 状态词）

> 状态词汇唯一真源。闸门 → [`gates.md`](./gates.md)；轨清单 → [`rails.md`](./rails.md)。

## 1. Version（`VERSION.md`）

`draft | ready | in-progress | verifying | blocked | archived | cancelled`

| 状态 | 目录 | 含义 |
|---|---|---|
| 施工态（`draft`…`blocked`） | `docs/specs/<id>/` | 施工队列；`check_spec --all` 只扫这里 |
| `archived` | `docs/specs/archive/<id>/` | 关版即搬入；勿只改状态位留原地 |
| `cancelled` | `archive/` 或删除 | 明确不做 |

### 关版归档（一条命令，同回合必做）

关版授权 = 无 UI 机器关版条件达成，**或**人本轮明示「通过了 / 没问题 / 关版 / 归档 / 可以归档了」。命中即执行，**禁止再反问**：

```bash
make close-spec HOST=<repo> SPEC=<id>
# = verify-deliver → VERSION=archived → git mv 到 specs/archive/<id>/ → journey 收口
```

Agent 另做：更新宿主索引；询问是否 Deploy（**不**自动上生产）。

## 2. Delivery Target

| Target | 含义 |
|---|---|
| `code-ready` | 代码与合同就绪；不自动部署 |
| `dev-effective` | 开发/预览环境真实生效 |
| `production-delivered` | 生产真实生效（须 P6 冒烟；见 evidence-contract Deliver Gate） |

## 3. Spec Run（`run.md`）

`ready | building | unit-testing | verifying | repairing | blocked | awaiting-human-acceptance | acceptance-passed`

- `awaiting-human-acceptance`：仅有 UI / 人判断；待人按包点验
- 无 UI 机器关版可从 `verifying` 直接 `acceptance-passed`

## 4. 完成声明（阶段结束只能选其一）

- `awaiting-human-acceptance` — 有 UI；工程侧已证伪并交出验收包
- `acceptance-passed` — 关版条件有直接证据（无 UI 机器关版，或人已确认）
- `blocked` — 未完成项与外部阻塞可复现
- `needs-authorization` — 下一步是不可逆授权

## 相邻层（不写入 Delivery Target）

| 词 | 落盘 | 含义 |
|---|---|---|
| `matrix-accounted` | `run.md` | 适用 Test 已有终态 |
| `design-ready` | 产品包 / demand-pool | 产品方案已确认（方案闸通过） |
| `production-restored` | Incident | 生产已止血 ≠ 根因已修 |

## 证据分级

| 级别 | 含义 |
|---|---|
| `Verified` | 有当前代码 / Schema / 配置 / 运行证据 |
| `Unverified` / `Assumption` | 尚未证明；仅写「待验证」 |

冲突时以代码与数据库事实为准，先修 Spec 或标缺陷。
