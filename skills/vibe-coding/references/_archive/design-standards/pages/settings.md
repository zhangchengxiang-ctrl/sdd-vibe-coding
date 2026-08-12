# Page: settings（B 端设置）

> 低频配置。蒸馏 taste-saas settings-pages。  
> [../components/product-forms-states.md](../components/product-forms-states.md) · [../copy.md](../copy.md)

## 结构

```text
Settings
┌ 子导航 ≈220px ────────┬ 分区卡 ────────────────┐
│ 范围 Personal/Workspace│ SECTION                 │
│  · Profile            │ 字段…                   │
│  · Members            │ [保存] [放弃]           │
│ ── 危险 ──            │                         │
│  · Delete             │                         │
└───────────────────────┴─────────────────────────┘
```

## 硬约束

| 项 | 要求 |
|----|------|
| 双层导航 | 范围 + 段；禁 30 项扁平 |
| 深链 | **每段一 URL**（路径或 `?tab=`）；禁仅内存 tab |
| 分区卡 | 一卡一关注点；每卡 Save/Discard（唯一自动保存如主题须写明） |
| 危险 | 独立分组；强确认 + copy 含对象 |
| 成员等集合 | 嵌 **list** 合同，不是把设置做成密表首页 |
| 子导航宽 | 固定 ≈220；勿随文案把轨撑乱 |

## 忌

- 整页左右「标签\|输入」超长古风表  
- 无深链  
- 危险操作混在普通字段中  

## 自检

- [ ] page_kind=settings；段可书签  
- [ ] 危险隔离；文案达标  
