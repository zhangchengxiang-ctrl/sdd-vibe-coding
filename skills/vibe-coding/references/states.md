# States（关版 / 状态词）

> 状态词汇唯一真源。闸门 → [`gates.md`](./gates.md)；轨清单 → [`rails.md`](./rails.md)。

## 1. Version（`VERSION.md`）

`draft | ready | in-progress | verifying | blocked | archived | cancelled`

| 状态 | 目录 | 含义 |
|---|---|---|
| 施工态（`draft`…`blocked`） | `docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/`（Spec 在所属版本目录下） | 施工队列；`check_spec --all` 扫全部版本与历史 `specs/<id>/` |
| `archived` | 原地不动（仍在所属版本目录下） | 关版只改状态位，路径不变、链接不断；版本层之前的历史 Spec 才搬入 `specs/<archive>/<id>/` |
| `cancelled` | 原地不动 | 明确不做；理由记入所属版本的 `decisions.md` |

**状态写法**：`VERSION.md` 的状态单元格必须以词表词开头，词后可跟注释，例如 ``| **状态** | `verifying`（已上线 main=abc，待复测） |``；`check_spec` 对不以词表词开头的状态给出警告。`close-spec` 会整格替换为 `archived`，并把原单元格文字写进变更记录行。

### 关版归档（一条命令，同回合必做）

关版授权 = 无 UI 机器关版条件达成，**或**人本轮明示「通过了 / 没问题 / 关版 / 归档 / 可以归档了」。命中即执行，**禁止再反问**：

```bash
make close-spec HOST=<repo> SPEC=<id>
# = verify-deliver → VERSION=archived（原地不动；历史 specs/<id>/ 才搬入归档并改写链接）→ journey 收口
```

关版前先**晋升**：仍然成立的结论写回常青文档（产品页、系统页）或新开 ADR（文档标准「六条规则」第 3 条）。
版本内所有 Spec 关完、`retro.md` 写好后：`make close-iteration HOST=<repo> ITERATION=<版本>`（版本 README 状态改 `archived`，不搬目录）。

Agent 另做：询问是否 Deploy（**不**自动上生产）。

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

## 5. 工作项（需求池 / gap / 请求单 / 事故单共用）

`open → shaping → ready → planned → done`，休眠或终止：`parked | dropped | merged`。

| 词 | 含义 | 必填 |
|---|---|---|
| `open` | 刚记下或刚证实 | 复审日（需求池、gap） |
| `shaping` | 在调研或出方案，或方案已出、等用户拍板 | 复审日 |
| `ready` | 方案已确认（方案闸通过，即旧称 `design-ready`） | 复审日 |
| `planned` | 已进版本 | 版本链接（需求池真源列、gap `version:`） |
| `done` | 已交付；gap 另写 `released: true / false` | — |
| `parked` | 暂缓 | 重启条件 + 复审日 |
| `dropped` | 不做，含接受风险 | 原因 |
| `merged` | 并入其他条目 | 去向 |

复审日默认是记录当天加 60 天；到期进入月度复审，结论只能是 `planned`、`parked`（给新复审日）或 `dropped`。版本 README 的状态 `draft | active | archived | cancelled` 由其中的 Spec 推导，不手写。报告、能力页、枢纽页不写状态，报告被推翻时用 `superseded-by:`。以上规则由 `scripts/sdd_docs.py check` 执行（C2、C3、C8）。
