# Page: form（B 端整页/大表单）

> 多字段创建或编辑。短单字段 → 勿用本页，用 forms-states 行内。  
> 机制：[../components/product-forms-states.md](../components/product-forms-states.md) · [../components/overlays.md](../components/overlays.md) · [../copy.md](../copy.md)

## 何时整页 vs Modal

| 条件 | 容器 |
|------|------|
| ≥5–7 字段、多分组、需向导 | **整页**或分步向导页 |
| 3–6 字段、一次提交 | **Modal** |
| 1 字段 | **行内** |

## 结构

1. 页题 = 任务（「新建项目」），非表名。  
2. **分组**：语义 section；每组短说明可选。  
3. 字段：label 可见；助文在下；错贴字段。  
4. 主键/外键 → 选择器（ui-page-gate）。  
5. 底栏：主提交 + 取消；脏离开警告。  
6. 向导：步骤指示；允许回看；最后一步才提交副作用（除非显式分步保存）。

## 硬约束

- 不按 DB 列序平铺。  
- 默认值能预填则预填。  
- 提交中按钮状态明确；失败 focus 首错。  
- 不禁粘贴；正确 type/autocomplete。

## 自检

- [ ] page_kind=form；容器选对  
- [ ] 分组有意义；选择器优先于手填 ID  
- [ ] copy：主钮动词具体  
