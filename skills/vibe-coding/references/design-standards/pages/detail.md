# Page: detail（B 端详情）

> 看清并操作**一个**实体。蒸馏 taste-saas detail-pages。  
> [../components/product-forms-states.md](../components/product-forms-states.md) · [../components/overlays.md](../components/overlays.md) · [../copy.md](../copy.md)

## 布局三选一（按内容形）

| 布局 | 何时 | 硬规格 |
|------|------|--------|
| **单栏阅读** | 长文/Markdown/代码为主 | `max-w-3xl` 级阅读宽；勿撑满导致行长失控 |
| **主栏+右轨** | ≥6 个常改小字段（工单/订单） | 双栏**独立 overflow**；轨宽 280–320；发丝分割；轨顶快捷操作 + **语义分组**属性卡（非字母序） |
| **三栏** | 收件箱式连扫 | list|body|meta；仅 triage；`~260 | 1fr | 260` |

元数据少改 → 可用顶栏属性条代替右轨（文档类）。元数据常改 → 右轨。

## 面包屑与标题

- 壳层面包屑叶 = 实体 ID/短名；**正文勿再重复同一 ID 作 h2**。  
- 正文 h1 = 实体标题（可 inline edit）。  
- 子实体：面包屑链含父级（数据返回后注入）。

## 硬约束

| 项 | 要求 |
|----|------|
| 单字段 | 值即触发器；禁单字段 Modal |
| 评论/子项 | single-field-add composer |
| 子列表 | 缩略 list 合同；「全部」回 list |
| 活动流 | 时间序 |
| 权限 | 无权限 ≠ 空 |
| Sheet | 从 list 预览用 Sheet，不是每次都路由 |

## 忌

- 全字段一长表单当详情  
- sticky 右轨挂错滚动父级  
- 无无意义卡片墙垫高度  

## 自检

- [ ] 布局形匹配内容  
- [ ] 分组语义化；主状态黄金位/首卡  
- [ ] 编辑形与 overlays 正确  
