# 人类验收包

> 许愿式交付的**验收侧**真源。Agent 工程证伪是旁证；**关版主权在人**。  
> 闸门见 [`workflow-contract.md`](../../vibe-coding/references/workflow-contract.md)；  
> 走查执行见 [`browser-verify.md`](./browser-verify.md) / [`falsify-checklist.md`](./falsify-checklist.md)。

## 何时必须产出

研发自动编排收口、或 Verify 轨准备请人关版时，**必须**给出人类验收包。  
无此包 → 禁止请人关版，禁止宣称 `acceptance-passed`。

## 包内容（对人 · 产品语言）

1. **怎么验**  
   环境 / 入口 URL 或路径 / 角色或账号前提 / 代表性数据 / 逐步操作（人能照做）。

2. **验什么**  
   用例清单（主路径、关键失败与权限、方案里承诺的体验点）。  
   每条写清：操作 → 期望可观察结果。可在技术详情中映射 `T-xxx`，前台默认不暴露编号。

3. **AI 已做（旁证）**  
   单测 / 证伪 / 走查摘要与证据路径；**明确写：不能替代你亲自点验**。

4. **已知限制**  
   未覆盖项、环境差、需真人 SSO 等。

## 话术硬门

| 禁止 | 正确 |
|------|------|
| 「可交付」但未交验收包 | 先交包，结论写「待你按包验收」 |
| 把「请打开/硬刷看是否正常」当验收包 | 包内须有具体用例与期望结果 |
| Agent 自嗨 Pass 即关版 | 人明示「通过 / 没问题 / 关版」后才 `acceptance-passed` |
| 验收包通过后直接生产发布 | 关版后上线仍走 Deploy + P4 |

## 人反馈分流

| 人说 | Agent |
|------|--------|
| 某条不过 / 这里别扭 | 记入 Fail；非 material → Polish；material → 补方案或 Spec 再修；再给更新包 |
| 通过 / 没问题 / 可以关版 | 写 `acceptance-passed`；`VERSION=archived`；搬到 `docs/specs/archive/<id>/`；询问是否进入发布（Deploy） |
| 先上线 / 发布 | 仅在人验通过（或人明文豁免并担责）后进 Deploy |
