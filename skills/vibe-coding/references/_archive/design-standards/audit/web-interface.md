# Web Interface Audit（交互审计）

> 蒸馏自 Vercel Web Interface Guidelines；**无色板**。有 UI 时 Verify / 自检使用。  
> 完整上游：`tmp/research/docs/vercel/web-interface-guidelines.command.md`（若本地有调研副本）。

## 必过（摘录）

**a11y / 语义**

- 图标按钮有 `aria-label`；表单有 label；按钮/链接用正确元素  
- 标题层级有序；焦点可见（禁无替代 `outline: none`）  
- 异步反馈考虑 `aria-live`；装饰图标 `aria-hidden`

**表单**

- 正确 `type` / `autocomplete`；不禁粘贴  
- 错误贴字段；提交中可显示进度；未保存离开要警告（若有脏数据）  
- placeholder 示例态，以 `…` 结尾

**动效 / 触控**

- `prefers-reduced-motion`；只动画 transform/opacity；禁 `transition: all`  
- 主触控目标足够大；模态 `overscroll-behavior: contain`

**状态与 URL**

- 筛选/分页/Tab 等尽量进 URL  
- 破坏性操作要确认或可撤销  
- 空态有行动；长文本可截断且 flex 子项 `min-width: 0`

**文案**

- 按钮具体（「保存 API Key」非「继续」）  
- 错误含下一步；数字用数字而非「八个」

## 反模式（发现即记）

`user-scalable=no`、禁粘贴、`transition: all`、无 label 的 input、无维度图片、大列表无虚拟化、div 当按钮。
