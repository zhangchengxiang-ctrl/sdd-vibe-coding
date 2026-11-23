# 需求池

还没排期的愿望、想法、体验反馈先记录在这里；生产事故另见 `docs/operations/incidents/`。
**一个想法一行**，可能做、也可能不做，不要求原话、需求、裁定。

- 调研与讨论的结论写进 `reports/<slug>-<YYYYMMDD>.md`，本表只链接，不写长文。
- 排进一轮即建版本 `docs/iterations/<yyyy-mm>/<w>/<版本>/`，原话移入该版本的 `quote.md`，本行改 `planned` 并链到版本。
- **开新话题前先查本表**：已调研、已搁置、已决定不做的，不要重复调研。
- 本表的行**不是** gap：只有暴露出「蓝图与现状的差距」才登记 gap；纯想法不登记。

## 状态（条目态）

词表与 gap、请求单、事故单共用，见插件 vibe-coding `references/states.md` §5：`open → shaping → ready → planned → done`，以及 `parked`（说明列写重启条件，必填复审日）、`dropped`（写原因）、`merged`（写去向）。`open` / `shaping` / `ready` / `parked` 必填复审日（默认当天加 60 天），到期进入月度复审。由 `scripts/sdd_docs.py check` 执行。

与能力地图态区分：本表跟踪单条愿望；`product/README` 能力地图跟踪成块能力。

## 条目

类型：`wish`（愿望）/ `fault`（故障反馈）/ `ux`（体验反馈）/ `other`。优先级建议：`P0` / `P1` / `P2` / `park`，或写对应 roadmap 序号。

| ID | 日期 | 类型 | 用户问题 / 目标 | 优先级建议 | 状态 | 复审日 | 说明 | 真源 / 版本 / 报告 |
|---|---|---|---|---|---|---|---|---|
| DEM-001 | YYYY-MM-DD | wish / fault / ux / other | | P0 / P1 / P2 / park | `open` | YYYY-MM-DD | | |
