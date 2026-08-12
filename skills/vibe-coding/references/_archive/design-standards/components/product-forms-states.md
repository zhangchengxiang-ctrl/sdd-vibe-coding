# Product forms & states（B 端 · 蒸馏）

> 来源意图：taste-saas forms + empty-states。

## 三种表单形（勿混用）

| 形 | 何时 | 提交 |
|----|------|------|
| **Inline edit** | 已渲染实体上改 **一个** 字段 | 选即存 / blur·Enter 存；Esc 撤销；**不要**为单字段开模态 |
| **Single-field-add** | 往已有列表追加一项（评论、子项、标签） | 行内 composer；Enter 或 ⌘Enter；空则禁用主钮；乐观插入 |
| **Create / wizard / Settings** | 新建实体 ≥3 字段，或一组设置 | 显式主钮；校验贴字段；可模态或设置分区 |

### Inline 禁令

- 单字段却弹大模态  
- 值旁永久「编辑」铅笔抢位（值本身即触发器）  
- 单选还要再点 Save  

### Single-field-add 禁令

- 为「加一条评论」开模态（常见 AI 味）  
- Composer 水平垫与列表项不一致  

### Create 形

- 对齐 [product-primitives.md](./product-primitives.md) Input/Button  
- 提交前主钮可点；请求中给进度；失败 focus 首错  
- 不禁粘贴；正确 `autocomplete` / `type`

## 空态两分（最常见反模式：合成一个）

| 态 | 检测意图 | UI |
|----|----------|-----|
| **First-run** | 从未有过该类实体 + 无筛选 | 英雄：缺什么 / 为何重要 / 主 CTA（+ 可选次链）；可小插画/字母标 |
| **No results** | 有数据但筛/搜为空 | 短标题 +「清除筛选」；无大插画、无大 CTA |
| **Error** | 加载失败 | 具体原因 + 重试 |
| **Loading** | 首载 | 骨架镜像终态 |

工具条（筛选/搜索）在空态时 **仍显示**；空态只替换表体。

## Toast / 确认

- 可撤销 → 优先 toast+撤销窗；不可逆 → 模态写清爆炸半径。  
- 危险钮不默认 focus。  
- 系统级失败可用 toast；字段错贴字段。

## 交互五态

可点击控件另遵 [interaction-states.md](./interaction-states.md)（default/hover/active/focus-visible/disabled）。

## 自检

- [ ] 表单形选对  
- [ ] first-run ≠ no-results  
- [ ] 无单字段模态、无「加一条」模态滥用  
- [ ] 主控件五态齐全  
