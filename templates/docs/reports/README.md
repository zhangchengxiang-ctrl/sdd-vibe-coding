---
title: 报告（Reports）
type: reference
status: active
owner: <谁>
updated: YYYY-MM-DD
---

# 报告（Reports）

回答「某次调查、评审、审计、基准得出了什么结论」。**带日期、不可变**：写完后只在顶部追加更正，不改正文结论；结论过期就新写一份并在旧报告顶部指向它。

与其他目录的分工：要做什么 → `product/`；一轮迭代 → `iterations/`；事故 → `operations/incidents/`；系统设计缘由 → 宿主自有目录。

## 命名与头部

- 文件名 `<主题>-<YYYYMMDD>.md`；多文件的调查用目录，目录内放 `README.md`。模板：[`_template.md`](./_template.md)。
- 头部写明：`type: report`、子类（`review | audit | investigation | benchmark | analysis`）、窗口与数据来源、一句话结论、可信度说明。

## 索引

| 主题 | 报告 |
|---|---|
| | |
