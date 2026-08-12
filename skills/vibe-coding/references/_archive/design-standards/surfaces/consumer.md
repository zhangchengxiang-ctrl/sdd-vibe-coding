# Surface: consumer（C 端）

> 个人用户产品。营销落地 = **本册 growth 分节**，非第三 surface。  
> Token → [../tokens/](../tokens/)；控件 → [../components/consumer-primitives.md](../components/consumer-primitives.md)  
> 页面级约束（结算、登录墙等）→ [../pages/consumer.md](../pages/consumer.md)  
> 模板脸禁令真源 → [../audit/ai-tells.md](../audit/ai-tells.md)（本册只写 C 端增量）

## 共用

- 主用户是个人。  
- **禁止**默认侧栏 + 密表 + sticky thead 运营脸（那是 product）。  
- 支付/隐私等敏感信息静态可见。  
- 主 CTA ≥44；路径短；状态五态仍要。

## A · in-product（motif 寄存器）

| motif | 主画布 | 硬忌 |
|-------|--------|------|
| feed | 信息流；分页或无限滚 | 后台表当首页 |
| chat | 会话列 + 消息区 | 多列管理表 |
| commerce | 商列→详→车→结算 | 运营筛选条当购物体 |
| media | 播放/内容主区 | KPI 墙 |
| utility | 短任务/工具表单 | 无必要复杂 IA |

- 列表项：标题 > 元数据；长文本 `line-clamp`；flex 子项 `min-width:0`。  
- 手势/系统返回优先于纯 hover 菜单。  
- 动效：短反馈；高频可不动画（见 ai-tells 频率门）。

### in-product 反模式（增量；通用模板脸见 ai-tells）

- 把 DataTable 三定律当 C 端默认（除非「我的订单」类清单且仍避免运营壳）  
- 图标彩圆三列特性 + 紫渐变英雄塞进已登录 App  

## B · growth（落地 / 活动 / 品牌获客）

`motif:growth` 或 `context:growth-web`（与 `page_kind: growth` 等价）。

| 项 | 硬规格 |
|----|--------|
| 定调门 | 字体配对 + 主色气质 + 1–2 参考未定 → **不写视觉码** |
| Uniqueness plan | **两 pass**：先写紧凑 token/构图计划 → 对照 brief 查是否撞「奶油衬线 / 黑底酸绿 / 三特性卡 / AI 紫」→ **修订后再写码** |
| Signature | **一处**记忆点做 bold；其余 quiet；交付前 **删一件**装饰 |
| 首屏预算 | **只许** 品牌 + 1 标题 + 1 短句 + CTA 组 + 1 主视觉 |
| 字号 | 封闭阶梯 `type-2xl`/`type-display`；禁半档、禁装饰 all-caps eyebrow 刷屏 |
| CTA | ≥44；文案=下一动作；次行动用文字链 |
| 媒体 | 主导视觉平面；忌无叙事 inset 卡片墙、假截图、库存插画堆 |
| 色 | 可品牌表达；仍禁无品牌增量的 AI 紫模板 |
| 动效 | 同屏可见 ≤3（见 tokens/motion） |

### growth 拒绝列表（增量；其余见 ai-tells）

- 通用居中英雄 + 三特性卡 + 双主钮  
- 仪表盘式指标条抢首屏  
- 未做 uniqueness 修订就直接套模板脸  

## 与 product 边界

商家后台 / 运营分析 / 租户配置 → **product**，即使同仓。

## 自检

- [ ] surface=consumer；motif/page_kind 已设  
- [ ] growth 则定调 + uniqueness + 首屏预算过门  
- [ ] signature 克制；ai-tells 已扫  
- [ ] 无运营密表默认  
