# Overlays（Modal / Sheet / Drawer / 行内）

> 蒸馏自 taste-saas sheets + overlays。主轴是 **提交 vs 阅读**，不是「大或小」。  
> **先定交互单位与 Job**（[product-judgment.md](../product-judgment.md)），再选本册容器。  
> 容器选对 ≠ 任务设计对：Drawer 里仍可能是失败的授权/分发 IA。

## 决策表

| 用户在做什么 | 用 | 不用 |
|--------------|-----|------|
| **提交/确认**（新建、短表、删确认、脏离开） | **Modal** | Sheet（会失焦） |
| **看更多但留在列表上下文**（行预览、扫多条） | **Sheet**（右滑；移动端可底） | 整页跳转（除非用户明确进入） |
| **长表单且必须对照列表** | Sheet 可；多数仍 Modal | — |
| **改已渲染实体的一个字段** | **行内**（forms-states） | Modal |
| **往列表加一条**（评论等） | **行内 composer** | Modal |
| 全屏沉浸编辑 | 路由详情页 | 假 Sheet 撑满当页 |

不确定 → 问：在**生产输入**还是**消费上下文**？生产 → Modal；消费 → Sheet。默认偏 Modal。

## Modal 合同

- 焦点在对话框；背景可淡化。  
- 短；一个主任务。  
- 头/底用留白分层，勿靠重描边堆盒。  
- 危险确认：写清爆炸半径；危险钮不默认 focus。  
- 锚点：优先 **顶锚定**（如 top≈15vh）并限高滚动，禁内容变高时反复垂直居中跳动。  
- Esc / 显式关闭；焦点陷阱与还原。

## Sheet 合同

- 从右侧滑入（移动端可底）；宽约 **480–600px**。  
- **不**把背景糊到不可读（与 Modal 焦点模型相反）；点击遮罩可关。  
- 头高对齐 `--top-row-h`；内容水平垫对齐 `--page-pl`。  
- 行预览类 Sheet 提供 **展开到完整路由** 的入口。  
- 可选底栏；分隔靠留白优先。

## Drawer

- 与 Sheet 同族；导航型/滤镜型可用。  
- 勿与 Modal 混用同一视觉（又淡化又当导航）。

## 行内

- 见 [product-forms-states.md](./product-forms-states.md)。  
- 单字段禁 Modal；加一条禁 Modal。

## 禁令

- 一切用 Modal「省事」  
- Sheet 却强行全屏 dim = 假 Modal  
- 嵌套 Modal 叠 Sheet 无逃逸  
- `transition: all`；无视 `prefers-reduced-motion`

## 自检

- [ ] 提交/阅读选对容器  
- [ ] 锚点稳定；焦点与 Esc  
- [ ] 未用 Modal 代替行内  
