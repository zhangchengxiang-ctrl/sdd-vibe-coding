# SDD docs root

宿主交付记忆的根目录。默认 `docs`；存量宿主可改为 `docs/sdd` 等，避免与已有 `docs/product` 语义冲突。

## 如何读取

1. 打开宿主 `AGENTS.md`；
2. 找子弹 `- SDD docs root: <path>`（相对仓库根）；
3. 若缺失 → 视为 `docs`。

技能与合同中的 `docs/product/`、`docs/specs/<id>/`、`docs/reference/` 等，均指：

```text
<SDD docs root>/product/
<SDD docs root>/specs/<id>/
…
```

## 写入规则

- scaffold：`bash scripts/scaffold.sh HOST --root=<path>`（或 `SDD_ROOT=` / Make `SDD_ROOT=`）会写入树并**盖章** `AGENTS.md` 中的该子弹；
- Agent **禁止**在未改 `AGENTS.md` 的情况下另起第二套根；
- 默认根保持 `docs`；只有探测 `BLOCK` 或用户明确要求时才用备用根。

## 与保留路径

保留名（`product/`、`specs/`、…）是 **相对 SDD docs root** 的，不是相对仓库根的绝对约定。  
仓库根下其它 `docs/architecture/` 等与 SDD 无关的树可并存。
