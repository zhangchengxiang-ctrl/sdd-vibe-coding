# SDD docs root

宿主交付记忆的根目录。默认 `docs`；存量宿主可改为 `docs/sdd` 等，避免与已有 `docs/product` 语义冲突。

## 如何读取

1. 打开宿主 `AGENTS.md`；
2. 找子弹 `- SDD docs root: <path>`（相对仓库根）；
3. 若缺失 → 视为 `docs`。

技能与合同中的 `docs/product/`、Spec 目录、`docs/reference/` 等，均指：

```text
<SDD docs root>/product/
<SDD docs root>/iterations/<yyyy-mm>/<w>/<版本>/            # 一个版本（迭代）：README（type: iteration）、baseline、decisions、release、retro
<SDD docs root>/iterations/<yyyy-mm>/<w>/<版本>/<spec-id>/  # 从该版本拆出的 Spec；关版后状态改 archived，原地不动
<SDD docs root>/specs/_template/                           # Spec 模板
<SDD docs root>/specs/<id>/ · specs/<archive>/<id>/        # 仅版本层之前的历史 Spec（只读，不再新建）
…
```

**Spec 是一个版本（迭代）拆出的工作上下文包，所以建在版本目录里。** 只有一个 Spec 的小改动也先建版本。`<yyyy-mm>` 是版本开始的月份，`<w>` 是开始那周在当月的序号（`w1`～`w5`，周一起算）；路径从版本开始就固定，跨周跨月也不搬。工具不依赖这两层的写法：`iterations/` 下 README 头部为 `type: iteration` 的目录就是版本，其下含 `VERSION.md` 的子目录就是 Spec。
按 id 找 Spec 的唯一实现是 `skills/spec/scripts/spec_paths.py`（`check_spec`、`build_context_pack`、`ship`、`close-spec`、`close-iteration` 都走它）；Spec id 与版本 id 各自全局唯一。

## 写入规则

- scaffold：`bash scripts/scaffold.sh HOST --root=<path>`（或 `SDD_ROOT=` / Make `SDD_ROOT=`）会写入树并**盖章** `AGENTS.md` 中的该子弹；
- 改 docs root 时同步改 `AGENTS.md` 盖章行；全仓只认这一套根；
- 默认根保持 `docs`；只有探测 `BLOCK` 或用户明确要求时才用备用根。

## 归档目录名

版本与其中的 Spec 关闭后都不搬动（状态词标明关闭）。归档目录只用于版本层之前的历史 Spec：默认 `<SDD docs root>/specs/archive/<id>/`。存量宿主若已用别的名字（例如 `_archive`），在 `AGENTS.md` 里声明，写法与 `SDD docs root` 相同：

```text
- SDD archive dir: _archive
```

`close-spec`、`check_spec`（含 `--all`）、`oracle-migration` 都读这一行；未声明则回退到 `archive`。以 `_` 开头的目录一律不被当作活跃 Spec。

## 与保留路径

保留名（`product/`、`specs/`、…）是 **相对 SDD docs root** 的，不是相对仓库根的绝对约定。  
仓库根下其它 `docs/architecture/` 等与 SDD 无关的树可并存。  
`docs/architecture/` 可选槽位由 scaffold **full** 从 `templates/architecture/` 生成（已存在则 SKIP）；
默认可执行原则仍在插件 `design-standards/`，不在宿主双写长文。
