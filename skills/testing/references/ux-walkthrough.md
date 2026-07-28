# UX 专家走查（Verify 变体）

在 Verify 中，当用户要 **UX 走查 / 体验审计**，或 UI Scenario 需要分级启发式发现时启用。
仍服从 [ux-standards.md](./ux-standards.md)（规范正文
[design-standards/ux.md](../../vibe-coding/references/design-standards/ux.md) /
[visual.md](../../vibe-coding/references/design-standards/visual.md)）与 Verify「不改实现」；
前台仍先给交付卡结论。

## 流程

1. **理解**：Spec requirements / Jobs（若有）· `docs/product/` · 角色旅程 · 入口（宿主探测）
2. **定范围**：按用户 Job 列流程与优先级
3. **走查**：每个 Job 问有效 / 高效 / 满意障碍；用 Nielsen H1–H10（严重度 0–4；4 → Job Fail）
4. **证据**：截图路径写入 `run.md` Evidence 列（可落 Spec 下任意约定目录）；关版看 Job 证据与严重度，不只看 Pass 计数
5. **分级发现**：P0 阻断核心 Job · P1 应修 · P2 可改进；含位置、现象、影响、建议
6. **复验**（修复后）：原问题与回归

## 最小检查面

加载与失败提示（H1/H9）· 状态与反馈（H1，有反馈≠Job 完成）· 撤销/退出（H3）·
人话与心智顺序（H2）· 一致（H4）· 防错（H5）· 识别而非逼记 UUID（H6）·
空态 / 长列表 / 极端文案 · 错误恢复路径（H9）

## 与交付卡的关系

走查发现写入「未通过或无法验证」与正式证据；`product / ux` Fail → 回 Shape。
无浏览器时标明推演限制，结果记为推演而非真实通道 Pass。
