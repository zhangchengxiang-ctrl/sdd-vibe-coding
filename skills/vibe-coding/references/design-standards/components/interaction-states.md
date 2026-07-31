# Interaction states（交互五态预算）

> 蒸馏：using-ui-stack。与业务空/载/错（[product-forms-states.md](./product-forms-states.md)）互补：  
> **业务态** = 数据/权限处境；**交互态** = 指针与键盘对控件的反馈。

## 每个可交互控件须覆盖

| 态 | 要求 |
|----|------|
| **default** | 可辨可点；对比度达标 |
| **hover** | 指针设备有可见变化（底/边/字色）；触控主路径不依赖 hover |
| **active / pressed** | 按下反馈短（`--dur-quick`） |
| **focus-visible** | 键盘焦点环可见；禁无替代的 `outline: none` |
| **disabled** | 不吞点击语义；`aria-disabled` 或原生 disabled；说明为何不可用（必要时） |

另：**loading**（请求中）不算第五交互态，但按钮须有进度且防重复提交。

## 触控

主行动目标 ≥ **44×44**（consumer / 触控）；product 桌面密级可用 32，但触控适配面仍 ≥44。

## 暗色 / 主题

若宿主有暗色：五态须有完整 token 映射，禁止只反转 default 而丢 focus/hover。

## 自检

- [ ] 主 CTA / 主输入 / 行可点区五态齐全  
- [ ] 焦点环与 hover 不互相抹掉  
- [ ] disabled 可理解  
