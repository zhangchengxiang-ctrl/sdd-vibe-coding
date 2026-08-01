# Oracle 强度（Plan 硬闸）

> 弱 Then 会合法通过「有 ### Then」的机检，却无法证伪实现。本文件是 Plan 写 `tests.md` 时的强度真源；  
> 机检见 `check_spec.py`；证伪执行见 [`falsify-checklist.md`](../../testing/references/falsify-checklist.md)。

## 弱 Oracle（禁止单独作为 Then）

下列措辞**不能**作为某条 T-xxx 的全部可观察断言（可作导语，须另有可区分断言）：

- 能打开 / 页面打开 / 页面正常
- 有数据 / 列表有数据 / 表格出现 / 能看到列表
- 正常显示 / 渲染成功 / 加载成功
- 可以滚动 / 冒烟通过 / smoke pass / page loads / works

`check_spec`：Then 体去掉标签与弱词后几乎为空 → **fail**。

## 数据面必写（list / dashboard / 分页·排序·筛选）

当合同或 `page_kind`/`motif` 触及列表、看板、分页、无限滚动、排序、筛选时，适用 success 用例的 Then 须含**至少一类**可证伪断言：

| 行为 | Then 须能被一次命令打假 |
|---|---|
| 分页 / load-more | 两页（或两 offset/cursor）**首行主键或响应体不同**；写清参数名 |
| 排序 | 请求带排序参数（或等价）；结果序与方向一致 |
| 筛选 | 开/关后结果集可区分 |
| 交互真源 | 若存量已有页码分页，禁止再叠无限滚动（或反之）— 写进 Out / 失败用例 |

自动化行建议直接写证伪命令（例：`offset=0` vs `offset=N` 比首键）。

## Evidence Kind（写入 tests 自动化或 run 时）

Plan 阶段在「自动化」注明预期 Kind（`api-diff` / `network-har` / `browser-job` / …）。  
Verify 回写 `run.md` 时 Evidence 列必须带 `kind=`；纯 `window-smoke` / `health` 不得单独支撑 Pass。

## 好 / 坏对照

| 坏 Then | 好 Then |
|---|---|
| 列表有数据 | `offset=0` 与 `offset=1000` 首行 `id` 不同；`has_more` 与 total 一致 |
| 点击排序后正常 | 网络请求含 `order_by=amount&dir=desc`；首行 amount ≥ 次行 |
| 可以继续滚动加载 | 第二次 load-more 请求 offset/cursor 递增；响应主键与第一批无交集 |
| 页面能打开 | （数据面不够）+ 角色走完 Job 后表头与代表行符合合同 |
